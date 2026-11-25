# Co-op replication. The host simulates the world; clients render it and send requests.
# Entities (vehicles, stations, pickups, rocks, trees, bushes, animals, bags) get string net ids. The host streams
# consists, moving bodies, entity state, players and one-shot events; client actions run on the host against a
# proxy Player that carries the client's inventory, and the resulting inventory goes back to the client.
class_name NetSync
extends Node

static var inst: NetSync

const RATE := 0.05

var main: Node
var ents := {}            # nid -> Node
var ready_peers := {}     # host: peer -> true once their game scene is up
var proxies := {}         # host: peer -> Player
var avatars := {}         # peer -> PlayerAvatar
var remote_states := {}   # peer -> last state
var _next := 1
var _clock := 0.0
var _scan_clock := 0.0
var _spawn_queue: Array = []
var _sent_state := {}     # nid -> json
var _sent_rows := {}      # nid -> Array
var _acting := 0          # host: peer whose request is running
var _close_cbs := {}      # host: peer -> Callable (container on_close)
var _cons_sig := ""
var _drag := Vector2.ZERO
var _drag_ref := {}
var _open_ref := {}       # client: container ref shown in the UI
var _open_inv: Inventory
var _cont_quiet := 0.0
var _welcome_parts := {}
var welcomed := false


static func active() -> bool:
	return inst != null and is_instance_valid(inst) and Net.is_online()


## True on a connected client: gameplay actions must go to the host.
static func remote() -> bool:
	return active() and Net.is_client_online()


static func hosting() -> bool:
	return active() and Net.is_host_online()


func _enter_tree() -> void:
	inst = self


func _exit_tree() -> void:
	if inst == self:
		inst = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -20
	Net.peer_left.connect(_on_peer_left)
	if Net.is_client_online():
		rpc_ready.rpc_id(1, Net.my_name)


# ---------------------------------------------------------------- ids / registry

func nid_of(n: Node) -> String:
	return str(n.get_meta("nid", "")) if n else ""


func register(n: Node, kind: String) -> String:
	if not Net.is_host_online() or n == null or n.has_meta("nid"):
		return nid_of(n)
	var id := "%s%d" % [kind.substr(0, 1), _next]
	_next += 1
	n.set_meta("nid", id)
	n.set_meta("nkind", kind)
	ents[id] = n
	n.tree_exiting.connect(func() -> void: _on_ent_exit(id), CONNECT_ONE_SHOT)
	_spawn_queue.append(id)
	return id


func _on_ent_exit(id: String) -> void:
	ents.erase(id)
	_sent_state.erase(id)
	_sent_rows.erase(id)
	if Net.is_host_online() and is_inside_tree() and not get_tree().current_scene == null:
		if id in _spawn_queue:
			_spawn_queue.erase(id)
			return
		op("despawn", id)


func _bind_client(n: Node, id: String, kind: String) -> void:
	n.set_meta("nid", id)
	n.set_meta("nkind", kind)
	ents[id] = n


## Walks up from a node to something both machines can name.
func ref_of(n: Node) -> Dictionary:
	var it: Interactable = n as Interactable
	var cur := n
	while cur and cur != main:
		if cur.has_meta("nid"):
			var d := {"n": str(cur.get_meta("nid"))}
			if it:
				d["i"] = _interactables(cur).find(it)
			return d
		if cur.has_meta("obstacle"):
			return {"o": str(cur.get_meta("obstacle")), "i": _interactables(cur).find(it) if it else -1}
		if cur.has_meta("stand"):
			return {"sw": str(cur.get_meta("stand")), "i": _interactables(cur).find(it) if it else -1}
		cur = cur.get_parent()
	return {}


func resolve(ref: Dictionary) -> Node:
	var owner: Node = null
	if ref.has("n"):
		owner = ents.get(str(ref.n))
	elif ref.has("o") and main.obstacles:
		var o: Dictionary = main.obstacles.active.get(str(ref.o), {})
		owner = o.get("node") if not o.is_empty() and is_instance_valid(o.get("node")) else null
	elif ref.has("sw"):
		for s in main._stands.values():
			if is_instance_valid(s) and str(s.get_meta("stand", "")) == str(ref.sw):
				owner = s
	if owner == null or not is_instance_valid(owner):
		return null
	var i := int(ref.get("i", -1))
	if i >= 0:
		var list := _interactables(owner)
		return list[i] if i < list.size() else null
	return owner


func _interactables(root: Node) -> Array:
	var out := []
	_collect(root, out, true)
	return out


func _collect(n: Node, out: Array, top: bool) -> void:
	if not top and (n.has_meta("nid") or n.has_meta("obstacle")):
		return
	if n is Interactable:
		out.append(n)
	for c in n.get_children():
		_collect(c, out, false)


# ---------------------------------------------------------------- transport helpers

func _broadcast(method: String, args: Array, except := 0) -> void:
	for peer in ready_peers:
		if peer != except:
			callv("rpc_id", [peer, method] + args)


static func _v3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


static func _to_v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _xf(t: Transform3D) -> Array:
	var q := t.basis.get_rotation_quaternion()
	var s := t.basis.get_scale()
	return [t.origin.x, t.origin.y, t.origin.z, q.x, q.y, q.z, q.w, s.x]


static func _to_xf(a: Array) -> Transform3D:
	var sc := float(a[7]) if a.size() > 7 else 1.0
	return Transform3D(Basis(Quaternion(float(a[3]), float(a[4]), float(a[5]), float(a[6]))).scaled(Vector3.ONE * sc), Vector3(float(a[0]), float(a[1]), float(a[2])))


# ---------------------------------------------------------------- connection lifecycle

@rpc("any_peer", "reliable")
func rpc_ready(player_name: String) -> void:
	if not Net.is_host_online():
		return
	var peer := multiplayer.get_remote_sender_id()
	Net.names[peer] = player_name.substr(0, 16)
	_scan()
	_flush_spawns()
	var snap := _snapshot()
	var text := var_to_str(snap)
	var parts := int(ceil(text.length() / 12000.0))
	for i in parts:
		rpc_welcome_part.rpc_id(peer, i, parts, text.substr(i * 12000, 12000))
	ready_peers[peer] = true
	_broadcast("rpc_names", [Net.names])
	_ensure_proxy(peer)
	_ensure_avatar(peer)
	main.toast("%s joined the crew" % Net.names.get(peer, "A survivor"))


@rpc("authority", "reliable")
func rpc_welcome_part(i: int, n: int, text: String) -> void:
	_welcome_parts[i] = text
	if _welcome_parts.size() < n:
		return
	var full := ""
	for k in n:
		full += str(_welcome_parts[k])
	_welcome_parts.clear()
	var snap: Variant = str_to_var(full)
	if snap is Dictionary:
		_apply_snapshot(snap)
		welcomed = true


func _on_peer_left(id: int) -> void:
	if avatars.has(id):
		(avatars[id] as Node).queue_free()
		avatars.erase(id)
	if proxies.has(id):
		(proxies[id] as Node).queue_free()
		proxies.erase(id)
	remote_states.erase(id)
	ready_peers.erase(id)
	_close_cbs.erase(id)
	if main and main.hud:
		main.toast("%s left" % Net.names.get(id, "A survivor"))


func _ensure_proxy(peer: int) -> Player:
	if proxies.has(peer):
		return proxies[peer]
	var p := Player.new()
	p.name = "Proxy_%d" % peer
	p.main = main
	p.net_peer = peer
	main.add_child(p)
	p.remove_from_group("player")
	p.collision_layer = 0
	p.collision_mask = 0
	p.input_enabled = false
	p.visible = false
	p.camera.current = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = main.player.global_position
	proxies[peer] = p
	return p


func _ensure_avatar(peer: int) -> PlayerAvatar:
	if peer == Net.my_id():
		return null
	if not avatars.has(peer):
		var a := PlayerAvatar.new()
		a.name = "Avatar_%d" % peer
		a.peer_id = peer
		main.add_child(a)
		a.set_display_name(str(Net.names.get(peer, "Survivor")))
		avatars[peer] = a
	return avatars[peer]


## Every player body the world should react to (animals, obstacles, chunk focus on the host).
func players() -> Array:
	var out: Array = [main.player]
	for p in proxies.values():
		if is_instance_valid(p):
			out.append(p)
	return out


# ---------------------------------------------------------------- snapshot (host -> joining client)

func _snapshot() -> Dictionary:
	var d := {
		"seed": main.world_seed, "km": main.distance_km, "removed": main.world.removed.duplicate(true),
		"switches": _switch_states(), "host_pos": main.player.global_position, "ents": [], "states": {},
		"cons": _cons_snapshot(), "env": _env(),
	}
	var order := ents.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return _spawn_rank(a) < _spawn_rank(b))
	for id in order:
		var rec := _spawn_record(id)
		if not rec.is_empty():
			d.ents.append(rec)
		var st := _ent_state(ents[id])
		if not st.is_empty():
			d.states[id] = st
	return d


func _spawn_rank(id: String) -> int:
	var k := str((ents[id] as Node).get_meta("nkind", ""))
	return 0 if k == "veh" else (1 if k == "station" else 2)


func _apply_snapshot(s: Dictionary) -> void:
	Net.applying += 1
	main.world.removed = s.removed
	main.distance_km = float(s.km)
	_apply_env(s.env)
	for rec in s.ents:
		_spawn_from(rec)
	for id in s.states:
		if ents.has(id):
			_apply_state(ents[id], s.states[id])
	_apply_switches(s.switches)
	Net.applying -= 1
	_apply_cons(s.cons)
	main.spawn_point = (s.host_pos as Vector3) + Vector3(1.2, 0.5, 0.8)
	if main.loading:
		main.player.global_position = main.spawn_point


func _switch_states() -> Dictionary:
	var out := {}
	for n in main.world.tracks.branch_nodes:
		if n.state != 0:
			out[n.name] = n.state
	return out


func _apply_switches(sw: Dictionary) -> void:
	for n in main.world.tracks.branch_nodes:
		var want := int(sw.get(n.name, 0))
		if n.state != want:
			n.state = want
			main.network.switch_changed.emit(n)


func _env() -> Dictionary:
	var dn: DayNight = main.day_night
	return {"t": dn.time, "w": dn.weather, "wa": dn.weather_amount, "km": main.distance_km}


func _apply_env(e: Dictionary) -> void:
	var dn: DayNight = main.day_night
	dn.locked = true
	var t := float(e.t)
	dn.time = t if absf(t - dn.time) > 0.1 else lerpf(dn.time, t, 0.3)
	if dn.weather != str(e.w):
		dn.set_weather(str(e.w))
	dn.weather_amount = float(e.wa)
	main.distance_km = float(e.km)


# ---------------------------------------------------------------- spawn records

func _spawn_record(id: String) -> Array:
	var n: Node = ents.get(id)
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return []
	var kind := str(n.get_meta("nkind"))
	var data := {}
	var xf := Transform3D.IDENTITY
	if n is Node3D:
		xf = (n as Node3D).global_transform
	match kind:
		"veh":
			data = {"type": SaveGame._type(n)}
		"station":
			var st := n as Station
			data = {"kind": st.kind, "veh": nid_of(st.vehicle) if st.vehicle else ""}
			if st.vehicle:
				xf = st.transform
		"pickup":
			var pk := n as Pickup
			data = {"id": pk.item_id, "n": pk.count, "dur": pk.dur, "frozen": pk.freeze, "vel": _v3(pk.linear_velocity)}
		"rock":
			var r := n as MineRock
			data = {"lvl": r.level, "key": r.key, "ore": r.ore, "vel": _v3(r.linear_velocity)}
		"tree":
			var t := n as ChopTree
			data = {"variant": t.get_meta("variant", "fir_b"), "scale": float(t.get_meta("scale", 1.0))}
		"bush":
			data = {"scale": float(n.get_meta("scale", 1.0))}
		"animal":
			data = {"species": (n as Animal).species}
		"bag":
			data = {}
	return [id, kind, data, _xf(xf)]


func _spawn_from(rec: Array) -> void:
	var id: String = rec[0]
	if ents.has(id) and is_instance_valid(ents[id]):
		return
	var kind: String = rec[1]
	var data: Dictionary = rec[2]
	var xf := _to_xf(rec[3])
	var n: Node = null
	Net.applying += 1
	match kind:
		"veh":
			var v: RailVehicle = null
			match str(data.type):
				"handcar": v = Handcar.new()
				"flatcar": v = Flatcar.new()
				"steam": v = SteamLoco.new()
				"tender": v = Tender.new()
				"electric": v = ElectricLoco.new()
			main.add_child(v)
			v.setup(main.network)
			v.global_position = Vector3(0, -500, 0)
			n = v
		"station":
			var veh: Node = ents.get(str(data.veh)) if str(data.veh) != "" else null
			var gxf := (veh as Node3D).global_transform * xf if veh else xf
			n = Station.place(main, str(data.kind), gxf, veh if veh else main)
		"pickup":
			var pk := Pickup.spawn(main, str(data.id), int(data.n), xf.origin)
			pk.dur = int(data.dur)
			pk.global_transform = xf
			pk.freeze = true
			pk.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			n = pk
		"rock":
			var r := MineRock.create(main, xf, int(data.lvl), str(data.key), str(data.ore))
			r.freeze = true
			r.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			n = r
		"tree":
			var t := ChopTree.create(main, xf.origin, str(data.variant), float(data.scale))
			t.global_transform = xf
			n = t
		"bush":
			var b := Bush.create(main, xf.origin, float(data.scale))
			b.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
			n = b
		"animal":
			var a := Animal.spawn(main, str(data.species), xf.origin)
			a.rotation.y = xf.basis.get_euler().y
			a.set_physics_process(false)
			n = a
		"bag":
			var tmp := Inventory.new(29)
			n = DeathBag.spawn(main, xf.origin, tmp)
	Net.applying -= 1
	if n:
		_bind_client(n, id, kind)


func _flush_spawns() -> void:
	if _spawn_queue.is_empty():
		return
	var recs := []
	for id in _spawn_queue:
		var en: Node = ents.get(id)
		if en and is_instance_valid(en) and en.has_meta("obstacle"):
			# deterministic obstacles are generated on every machine
			ents.erase(id)
			en.remove_meta("nid")
			continue
		var rec := _spawn_record(id)
		if not rec.is_empty():
			recs.append(rec)
	_spawn_queue.clear()
	recs.sort_custom(func(a: Array, b: Array) -> bool: return ["veh", "station"].find(a[1]) > ["veh", "station"].find(b[1]) if a[1] != b[1] else false)
	if not recs.is_empty():
		_broadcast("rpc_spawns", [recs])


@rpc("authority", "reliable")
func rpc_spawns(recs: Array) -> void:
	for rec in recs:
		if rec[1] == "veh":
			_spawn_from(rec)
	for rec in recs:
		if rec[1] != "veh":
			_spawn_from(rec)


# ---------------------------------------------------------------- per-entity state

func _ent_state(n: Node) -> Dictionary:
	if not is_instance_valid(n):
		return {}
	if n is RailVehicle:
		return _veh_state(n)
	if n is Station:
		var st := n as Station
		var d := {"b": snappedf(st.burn, 0.5), "pr": snappedf(st.progress, 0.25)}
		if st.inventory:
			d["inv"] = st.inventory.slots.duplicate(true)
		return d
	if n is DeathBag:
		return {"inv": (n as DeathBag).inventory.slots.duplicate(true)}
	if n is Bush:
		return {"hp": (n as Bush).hp}
	if n is Animal:
		return {"st": (n as Animal).state}
	return {}


func _veh_state(v: RailVehicle) -> Dictionary:
	var d := {"hp": snappedf(v.hp, 0.5), "plow": v.has_plow, "pc": {}}
	for pc in (v.get_meta("pieces", {}) as Dictionary).values():
		d.pc[pc.key()] = [pc.piece, pc.cell.x, pc.cell.y, pc.cell.z, pc.edge, snappedf(pc.hp, 1.0)]
	if v is Handcar:
		d.merge({"dir": (v as Handcar).direction, "br": snappedf((v as Handcar).brake.value, 0.01)})
	elif v is SteamLoco:
		var s := v as SteamLoco
		d.merge({"en": snappedf(s.energy, 0.5), "p": snappedf(s.pressure, 0.05), "fi": snappedf(s.fire, 0.02), "door": s.door_open, "reg": snappedf(s.regulator.value, 0.01), "rev": snappedf(s.reverser.value, 0.01), "br": snappedf(s.brake.value, 0.01), "va": snappedf(s.valve, 1.0)})
	elif v is Tender:
		d["w"] = snappedf((v as Tender).water, 1.0)
	elif v is ElectricLoco:
		var e := v as ElectricLoco
		d.merge({"bat": snappedf(e.battery, 0.05), "fuel": snappedf(e.fuel, 0.05), "brk": e.breaker, "gen": e.generator, "dir": e.direction, "ctl": snappedf(e.controller.value, 0.01), "br": snappedf(e.brake.value, 0.01), "kw": snappedf(e.power_kw, 0.5)})
	return d


func _apply_state(n: Node, d: Dictionary) -> void:
	if not is_instance_valid(n):
		return
	Net.applying += 1
	if n is RailVehicle:
		_apply_veh(n, d)
	elif n is Station:
		var st := n as Station
		st.burn = float(d.b)
		st.progress = float(d.pr)
		if st.inventory and d.has("inv") and not (_open_inv == st.inventory and _cont_quiet > 0.0):
			_set_slots(st.inventory, d.inv)
	elif n is DeathBag:
		if not (_open_inv == (n as DeathBag).inventory and _cont_quiet > 0.0):
			_set_slots((n as DeathBag).inventory, d.inv)
	elif n is Bush:
		var b := n as Bush
		var hp := int(d.hp)
		if hp != b.hp:
			b.hp = hp
			b.visible = hp > 0
			b.collision_layer = 32 if hp > 0 else 0
			b.model.scale = Vector3.ONE * float(b.get_meta("scale", 1.0)) * (1.0 if hp >= 3 else 0.45 + 0.18 * hp)
	elif n is Animal:
		var a := n as Animal
		var s := str(d.st)
		if s == "dead" and a.state != "dead":
			a.die()
		elif s != "dead":
			a.state = s
	Net.applying -= 1


func _apply_veh(v: RailVehicle, d: Dictionary) -> void:
	v.hp = float(d.hp)
	if bool(d.plow) and not v.has_plow:
		main.attach_plow(v)
	var pieces: Dictionary = v.get_meta("pieces", {})
	var want: Dictionary = d.pc
	for key in pieces.keys():
		if not want.has(key):
			Building.remove(pieces[key])
	for key in want:
		var row: Array = want[key]
		var pc: Building.Piece = pieces.get(key)
		if pc == null:
			pc = Building.build(v, str(row[0]), Vector3i(int(row[1]), int(row[2]), int(row[3])), int(row[4]))
		pc.hp = float(row[5])
	if v is Handcar:
		var h := v as Handcar
		if h.direction != float(d.dir):
			h.direction = float(d.dir)
			if h._dir_lever:
				h._dir_lever.basis = h._dir_rest * Basis(Vector3.RIGHT, 0.0 if h.direction > 0 else 0.6)
		h.brake.set_value(float(d.br))
	elif v is SteamLoco:
		var s := v as SteamLoco
		s.energy = float(d.en)
		s.pressure = float(d.p)
		s.fire = float(d.fi)
		s.valve = float(d.va)
		s._set_door(bool(d.door))
		s.regulator.set_value(float(d.reg))
		s.reverser.set_value(float(d.rev))
		s.brake.set_value(float(d.br))
		s._steam.emitting = s.pressure > SteamLoco.VALVE_P - 0.1 and s.valve > 0.0
	elif v is Tender:
		(v as Tender).water = float(d.w)
	elif v is ElectricLoco:
		var e := v as ElectricLoco
		e.battery = float(d.bat)
		e.fuel = float(d.fuel)
		if e.breaker != bool(d.brk):
			e._set_breaker(bool(d.brk))
		e.generator = bool(d.gen)
		if e.direction != int(d.dir):
			e.direction = int(d.dir)
			if e._rev_node:
				e._rev_node.basis = e._rev_rest * Basis(Vector3.UP, float(e.direction) * 0.7)
		e.controller.set_value(float(d.ctl))
		e.brake.set_value(float(d.br))
		e.power_kw = float(d.kw)


func _set_slots(inv: Inventory, arr: Array) -> void:
	for i in mini(arr.size(), inv.size()):
		inv.slots[i] = (arr[i] as Dictionary).duplicate()
	inv.changed.emit()


@rpc("authority", "unreliable_ordered")
func rpc_states(bundle: Dictionary) -> void:
	if not welcomed:
		return
	if bundle.has("_env"):
		_apply_env(bundle._env)
	for id in bundle:
		if id != "_env" and ents.has(id):
			_apply_state(ents[id], bundle[id])


# ---------------------------------------------------------------- consists

func _cons_snapshot() -> Array:
	var out := []
	var tracks: InfiniteTracks = main.world.tracks
	for c in main.vehicles.consists:
		var ids := []
		for v in c.vehicles:
			ids.append(register(v, "veh"))
		var cur: TrackNetwork.Cursor = c.lead().center_cursor()
		out.append({"vs": ids, "e": tracks.key_of(cur.seg), "s": snappedf(cur.s, 0.001), "f": cur.flip, "v": snappedf(c.v, 0.001)})
	return out


@rpc("authority", "unreliable_ordered")
func rpc_cons(list: Array) -> void:
	if welcomed:
		_apply_cons(list)


func _apply_cons(list: Array) -> void:
	var sig := JSON.stringify(list.map(func(cd: Dictionary) -> Array: return cd.vs))
	var vs: VehicleSystem = main.vehicles
	var tracks: InfiniteTracks = main.world.tracks
	if sig != _cons_sig:
		for cd in list:
			for id in cd.vs:
				if not ents.has(id):
					return
		var built: Array[Consist] = []
		for cd in list:
			var seg := tracks.segment_for_key(str(cd.e))
			if seg == null:
				return
		vs.consists.clear()
		for cd in list:
			var seg2 := tracks.segment_for_key(str(cd.e))
			var vlist: Array = []
			for id in cd.vs:
				vlist.append(ents[id])
			(vlist[0] as RailVehicle).place(main.network.cursor_at(seg2, float(cd.s), bool(cd.f)))
			var c := vs.add(vlist)
			c.v = float(cd.v)
			for v in c.vehicles:
				v.apply_pose(true)
			built.append(c)
		_cons_sig = sig
		_refresh_main_refs()
		return
	for i in mini(list.size(), vs.consists.size()):
		var cd: Dictionary = list[i]
		var c: Consist = vs.consists[i]
		var seg3 := tracks.segment_for_key(str(cd.e))
		if seg3 == null:
			continue
		var target: Vector3 = main.network.cursor_at(seg3, float(cd.s), bool(cd.f)).position()
		var cur: Vector3 = c.lead().center_cursor().position()
		var err := target - cur
		c.v = float(cd.v)
		if err.length() > 4.0:
			c.lead().place(main.network.cursor_at(seg3, float(cd.s), bool(cd.f)))
			c.reposition()
			for v in c.vehicles:
				v.apply_pose(true)
		else:
			var along := err.dot(c.lead().forward()) * 0.25
			if absf(along) > 0.0005:
				for v in c.vehicles:
					v.advance(along)


func _refresh_main_refs() -> void:
	main.handcar = null
	main.flatcar = null
	main.steam = null
	main.tender = null
	main.electric = null
	var focus: Array = []
	for c in main.vehicles.consists:
		focus.append(c.lead())
		for v in c.vehicles:
			if v is Handcar and main.handcar == null: main.handcar = v
			if v is Flatcar and main.flatcar == null: main.flatcar = v
			if v is SteamLoco: main.steam = v
			if v is Tender: main.tender = v
			if v is ElectricLoco: main.electric = v
	main.world.extra_focus = focus


# ---------------------------------------------------------------- players

func _my_state() -> Dictionary:
	var p: Player = main.player
	var d := {"p": p.global_position, "y": p.rotation.y, "pi": p.head.rotation.x, "eq": p.equipped_id, "sp": p.move_speed, "cr": p.crouching, "sn": p.sprinting, "fw": p.input_enabled and Input.is_action_pressed("move_forward"), "dead": p.survival.dead}
	if p.riding and is_instance_valid(p.riding) and p.riding.has_meta("nid"):
		d["r"] = nid_of(p.riding)
		d["l"] = p.riding.to_local(p.global_position)
	return d


@rpc("any_peer", "unreliable_ordered")
func rpc_my_state(d: Dictionary) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not ready_peers.has(peer):
		return
	remote_states[peer] = d
	var px := _ensure_proxy(peer)
	var pos: Vector3 = d.p
	if d.has("r") and ents.has(str(d.r)):
		pos = (ents[str(d.r)] as Node3D).to_global(d.l)
	px.global_position = pos
	px.rotation.y = float(d.y)
	px.head.rotation.x = float(d.pi)
	px.move_speed = float(d.sp)
	px.crouching = bool(d.cr)
	px.sprinting = bool(d.sn)
	px.remote_forward = bool(d.fw)
	px.survival.dead = bool(d.dead)
	_ensure_avatar(peer)


@rpc("authority", "unreliable_ordered")
func rpc_players(all: Dictionary) -> void:
	if not welcomed:
		return
	for peer in all:
		if int(peer) == Net.my_id():
			continue
		remote_states[int(peer)] = all[peer]
		_ensure_avatar(int(peer))
	for peer in avatars.keys():
		if not all.has(peer):
			(avatars[peer] as Node).queue_free()
			avatars.erase(peer)


@rpc("authority", "reliable")
func rpc_names(n: Dictionary) -> void:
	for k in n:
		Net.names[int(k)] = str(n[k])
		if avatars.has(int(k)):
			(avatars[int(k)] as PlayerAvatar).set_display_name(str(n[k]))


func _update_avatars() -> void:
	for peer in avatars:
		var st: Dictionary = remote_states.get(peer, {})
		if st.is_empty():
			continue
		var pos: Vector3 = st.p
		if st.has("r") and ents.has(str(st.r)):
			pos = (ents[str(st.r)] as Node3D).to_global(st.l)
		(avatars[peer] as PlayerAvatar).set_state(pos, float(st.y), float(st.pi), str(st.eq), float(st.sp), bool(st.cr), bool(st.get("dead", false)))


# ---------------------------------------------------------------- main loop

func _process(dt: float) -> void:
	if not Net.is_online():
		return
	_cont_quiet = maxf(0.0, _cont_quiet - dt)
	_update_avatars()
	if Net.is_host_online():
		_scan_clock -= dt
		if _scan_clock <= 0.0:
			_scan_clock = 0.25
			_scan()
		_flush_spawns()
	_clock += dt
	if _clock < RATE:
		return
	_clock = 0.0
	if Net.is_host_online():
		if ready_peers.is_empty():
			return
		_broadcast("rpc_cons", [_cons_snapshot()])
		_broadcast_rows()
		_broadcast_states()
		var all := {Net.my_id(): _my_state()}
		for peer in remote_states:
			all[peer] = remote_states[peer]
		_broadcast("rpc_players", [all])
	elif welcomed:
		rpc_my_state.rpc_id(1, _my_state())
		if _drag != Vector2.ZERO and not _drag_ref.is_empty():
			rpc_req.rpc_id(1, "gdrag", {"ref": _drag_ref, "rel": _drag})
			_drag = Vector2.ZERO


## Host: give net ids to things created without a hook (vehicles, stations, animals).
func _scan() -> void:
	for c in main.vehicles.consists:
		for v in c.vehicles:
			register(v, "veh")
	for s in main.stations:
		if is_instance_valid(s):
			register(s, "station")
	for a in get_tree().get_nodes_in_group("animals"):
		register(a, "animal")


func _broadcast_rows() -> void:
	var rows := []
	for id in ents:
		var n: Node = ents[id]
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var moving := false
		if n is RigidBody3D:
			moving = not (n as RigidBody3D).freeze and not (n as RigidBody3D).sleeping
		elif n is Animal:
			moving = true
		if not moving:
			continue
		var xf := (n as Node3D).global_transform
		var q := xf.basis.get_rotation_quaternion()
		var row := [id, snappedf(xf.origin.x, 0.01), snappedf(xf.origin.y, 0.01), snappedf(xf.origin.z, 0.01), snappedf(q.x, 0.01), snappedf(q.y, 0.01), snappedf(q.z, 0.01), snappedf(q.w, 0.01)]
		if n is Animal:
			row.append((n as Animal)._cur_anim)
			row.append(snappedf((n as Animal)._anim.speed_scale if (n as Animal)._anim else 1.0, 0.1))
		var last: Array = _sent_rows.get(id, [])
		if last == row:
			continue
		_sent_rows[id] = row
		rows.append(row)
	if not rows.is_empty():
		_broadcast("rpc_rows", [rows])


@rpc("authority", "unreliable_ordered")
func rpc_rows(rows: Array) -> void:
	for row in rows:
		var n: Node = ents.get(row[0])
		if n == null or not is_instance_valid(n):
			continue
		var xf := Transform3D(Basis(Quaternion(row[4], row[5], row[6], row[7]).normalized()), Vector3(row[1], row[2], row[3]))
		n.set_meta("net_target", xf)
		if n is Animal and row.size() > 8:
			var a := n as Animal
			var anim: String = row[8]
			if anim != "" and anim != a._cur_anim and a._anim and a._anim.has_animation(anim):
				a._cur_anim = anim
				var res := a._anim.get_animation(anim)
				if not (anim.contains("Death") or anim.contains("Attack") or anim.contains("Headbutt") or anim.contains("Hit")):
					res.loop_mode = Animation.LOOP_LINEAR
				a._anim.play(anim, 0.25)
			if a._anim:
				a._anim.speed_scale = float(row[9])


func _physics_process(dt: float) -> void:
	if not Net.is_client_online():
		return
	var k := clampf(dt * 14.0, 0.0, 1.0)
	for id in ents:
		var n: Node = ents[id]
		if not is_instance_valid(n) or not n.has_meta("net_target"):
			continue
		var t: Transform3D = n.get_meta("net_target")
		var cur := (n as Node3D).global_transform
		if cur.origin.distance_to(t.origin) > 6.0:
			(n as Node3D).global_transform = t
		else:
			var q := cur.basis.get_rotation_quaternion().slerp(t.basis.get_rotation_quaternion(), k)
			(n as Node3D).global_transform = Transform3D(Basis(q), cur.origin.lerp(t.origin, k))


func _broadcast_states() -> void:
	var bundle := {"_env": _env()}
	for id in ents:
		var n: Node = ents[id]
		var st := _ent_state(n)
		if st.is_empty():
			continue
		var js := JSON.stringify(st)
		if _sent_state.get(id, "") == js:
			continue
		_sent_state[id] = js
		bundle[id] = st
	# unreliable bundles can drop: resend everything now and then
	if Engine.get_process_frames() % 60 == 0:
		_sent_state.clear()
	_broadcast("rpc_states", [bundle])


# ---------------------------------------------------------------- events (host -> clients)

func op(kind: String, data: Variant, except := 0) -> void:
	if Net.is_host_online() and not ready_peers.is_empty():
		_flush_spawns()
		_broadcast("rpc_op", [[kind, data]], except)


@rpc("authority", "reliable")
func rpc_op(o: Array) -> void:
	if not welcomed:
		return
	var kind: String = o[0]
	var data: Variant = o[1]
	Net.applying += 1
	match kind:
		"despawn":
			_despawn(str(data))
		"harvest":
			main.world.apply_harvest(Vector2i(int(data[0]), int(data[1])), str(data[2]))
		"obs":
			main.world.removed.get_or_add("obstacles", {})[str(data)] = true
			if main.obstacles:
				main.obstacles.net_clear(str(data))
		"switch":
			for n in main.world.tracks.branch_nodes:
				if n.name == str(data[0]) and n.state != int(data[1]):
					n.state = int(data[1])
					main.network.switch_changed.emit(n)
		"tree_fall":
			var t: Node = ents.get(str(data[0]))
			if t and is_instance_valid(t):
				(t as ChopTree)._fall(data[1])
		"arrow":
			var a := Arrow.fire(main, data[0], data[1], float(data[2]), null, 0.0)
			a.cosmetic = true
		"explode":
			Fx.burst(main, data, Vector3.UP, "dust", 30)
	Net.applying -= 1


func _despawn(id: String) -> void:
	var n: Node = ents.get(id)
	ents.erase(id)
	if n == null or not is_instance_valid(n):
		return
	if n is RailVehicle:
		for c in main.vehicles.consists.duplicate():
			if n in c.vehicles:
				main.vehicles.consists.erase(c)
		_cons_sig = ""
		for rider in [main.player]:
			if rider.riding == n:
				rider.riding = null
	if n is Station:
		(n as Station).remove()
		return
	n.queue_free()


## Host: positional sound / particles for everyone else.
func sfx(cue: String, pos: Vector3, vol: float, spread: float, pitch: float, dist: float) -> void:
	if Net.mute > 0 or ready_peers.is_empty():
		return
	_broadcast("rpc_sfx", [[cue, pos, vol, spread, pitch, dist]])


@rpc("authority", "unreliable")
func rpc_sfx(a: Array) -> void:
	if welcomed:
		Sfx.play_at(a[0], a[1], a[2], a[3], a[4], a[5], true)


func fx(pos: Vector3, normal: Vector3, kind: String, amount: int) -> void:
	if Net.mute > 0 or ready_peers.is_empty():
		return
	_broadcast("rpc_fx", [[pos, normal, kind, amount]])


@rpc("authority", "unreliable")
func rpc_fx(a: Array) -> void:
	if welcomed:
		Fx.burst(main, a[0], a[1], a[2], a[3], true)


# ---------------------------------------------------------------- per-player UI redirection (host)

func acting_peer() -> int:
	return _acting


## Host: open a container on the client whose request is running. Returns false when no remote player is acting.
func redirect_container(inv: Inventory, title: String, on_close: Callable, station: Station) -> bool:
	if _acting == 0:
		return false
	var ref := {}
	if station:
		ref = {"n": nid_of(station)}
	elif inv:
		for id in ents:
			var n: Node = ents[id]
			if n is DeathBag and (n as DeathBag).inventory == inv:
				ref = {"n": id}
	if inv != null and ref.is_empty():
		return true
	if on_close.is_valid():
		_close_cbs[_acting] = on_close
	rpc_open.rpc_id(_acting, ref, title)
	return true


func redirect_toast(text: String) -> bool:
	if _acting == 0:
		return false
	rpc_toast.rpc_id(_acting, text)
	return true


@rpc("authority", "reliable")
func rpc_toast(text: String) -> void:
	main.hud.toast(text)


@rpc("authority", "reliable")
func rpc_open(ref: Dictionary, title: String) -> void:
	var owner: Node = resolve(ref) if not ref.is_empty() else null
	var inv: Inventory = null
	var station: Station = owner as Station
	if owner is Station:
		inv = (owner as Station).inventory
	elif owner is DeathBag:
		inv = (owner as DeathBag).inventory
	_open_ref = ref
	_open_inv = inv
	var watch := func() -> void: _container_edited()
	if inv:
		inv.changed.connect(watch)
	main.open_container(inv, title, func() -> void:
		if inv and inv.changed.is_connected(watch):
			inv.changed.disconnect(watch)
		_open_ref = {}
		_open_inv = null
		rpc_req.rpc_id(1, "cont_close", {}), station)


func _container_edited() -> void:
	if Net.applying > 0 or _open_inv == null:
		return
	_cont_quiet = 0.6
	rpc_req.rpc_id(1, "cont_set", {"ref": _open_ref, "slots": _open_inv.slots.duplicate(true), "inv": main.player.inventory.slots.duplicate(true)})


@rpc("authority", "reliable")
func rpc_inv(slots: Array) -> void:
	var inv: Inventory = main.player.inventory
	for i in mini(slots.size(), inv.size()):
		inv.slots[i] = (slots[i] as Dictionary).duplicate()
	inv.changed.emit()


@rpc("authority", "reliable")
func rpc_hurt(amount: float, cause: String) -> void:
	main.player.survival.damage(amount, cause)


## Host: damage aimed at a proxy goes to that client's real survival stats.
func hurt_peer(peer: int, amount: float, cause: String) -> void:
	if ready_peers.has(peer):
		rpc_hurt.rpc_id(peer, amount, cause)


# ---------------------------------------------------------------- client requests

## Client: forward an action to the host with the local inventory attached.
func request(kind: String, data: Dictionary) -> void:
	var p: Player = main.player
	data["inv"] = p.inventory.slots.duplicate(true)
	data["slot"] = p.selected_slot
	data["eq"] = p.equipped_id
	rpc_req.rpc_id(1, kind, data)


func request_interact(it: Interactable, action: String, arg: Variant = null) -> void:
	var ref := ref_of(it)
	if ref.is_empty():
		return
	if action == "gdrag":
		_drag_ref = ref
		_drag += arg
		return
	if action == "gend":
		if _drag != Vector2.ZERO:
			rpc_req.rpc_id(1, "gdrag", {"ref": ref, "rel": _drag})
			_drag = Vector2.ZERO
		_drag_ref = {}
	var d := {"ref": ref}
	if arg != null:
		d["arg"] = arg
	request(action, d)


## Client: describe a tool hit / shape use target so the host can find the same thing.
func target_ref(col: Object, shape_idx: int) -> Dictionary:
	if col is ResourceBody:
		var rb := col as ResourceBody
		var owner_id := rb.shape_find_owner(shape_idx)
		if not rb.owners.has(owner_id):
			return {}
		var info: Dictionary = rb.owners[owner_id]
		var data: Dictionary = info.data
		return {"res": [rb.chunk.key.x, rb.chunk.key.y], "id": str(data.id), "kind": str(info.kind), "xf": _xf(data.xf), "variant": str(data.get("variant", "fir_b")), "scale": float(data.get("scale", 1.0)), "ore": str(data.get("ore", "")), "berry": bool(data.get("berry", false))}
	if col is Node:
		var obs := col as Node
		if "obstacles" in obs and "id" in obs:
			return {"o": str(obs.id)}
		return ref_of(obs)
	return {}


@rpc("any_peer", "reliable")
func rpc_req(kind: String, d: Dictionary) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not Net.is_host_online() or not ready_peers.has(peer):
		return
	var p := _ensure_proxy(peer)
	if d.has("inv"):
		_set_slots(p.inventory, d.inv)
		p.selected_slot = int(d.slot)
		p.equipped_id = str(d.eq)
	var before := var_to_str(p.inventory.slots)
	_acting = peer
	_handle(kind, d, p, peer)
	_acting = 0
	if d.has("inv") and var_to_str(p.inventory.slots) != before:
		rpc_inv.rpc_id(peer, p.inventory.slots.duplicate(true))


func _handle(kind: String, d: Dictionary, p: Player, peer: int) -> void:
	match kind:
		"use", "sec", "hold", "rel", "gstart", "gend", "gdrag":
			var it := resolve(d.ref) as Interactable
			if it == null:
				return
			match kind:
				"use":
					if it.on_use.is_valid(): it.on_use.call(p)
				"sec":
					if it.on_secondary.is_valid(): it.on_secondary.call(p)
				"hold":
					if it.on_hold.is_valid(): it.on_hold.call(p, float(d.get("arg", 0.016)))
				"rel":
					if it.on_release.is_valid(): it.on_release.call(p)
				"gstart":
					if it.grab_start.is_valid(): it.grab_start.call(p)
				"gend":
					if it.grab_end.is_valid(): it.grab_end.call(p)
				"gdrag":
					if it.grab_drag.is_valid(): it.grab_drag.call(p, d.rel)
		"hit":
			_host_hit(d, p)
		"shape":
			_host_shape(d, p)
		"pickup":
			var pk: Node = ents.get(str(d.n))
			if pk is Pickup and is_instance_valid(pk):
				p.take_pickup(pk)
		"drop":
			var np := Pickup.spawn(main, str(d.id), int(d.n), d.pos)
			np.dur = int(d.dur)
			np.linear_velocity = d.vel
		"place":
			var target: Node = ents.get(str(d.veh)) if str(d.veh) != "" else null
			var gxf := _to_xf(d.xf)
			var st := Station.place(main, str(d.kind), gxf, target if target else main)
			register(st, "station")
			Sfx.play_at("build_place_wood", gxf.origin, -2.0)
		"build":
			var v := ents.get(str(d.veh)) as RailVehicle
			if v and not (v.get_meta("pieces", {}) as Dictionary).has("%s:%d:%d:%d:%d" % [Building.PIECES[str(d.piece)].kind, int(d.cell[0]), int(d.cell[1]), int(d.cell[2]), int(d.edge)]):
				var pc := Building.build(v, str(d.piece), Vector3i(int(d.cell[0]), int(d.cell[1]), int(d.cell[2])), int(d.edge))
				Sfx.play_at("build_place_wood", pc.global_position + Vector3.UP, -1.0)
		"repair", "takeapart":
			var v2 := ents.get(str(d.veh)) as RailVehicle
			if v2 == null:
				return
			var pc2: Building.Piece = (v2.get_meta("pieces", {}) as Dictionary).get(str(d.key))
			if pc2 == null:
				return
			if kind == "repair":
				pc2.hp = minf(100.0, pc2.hp + 35.0)
				Sfx.play_at("hammer_hit", pc2.global_position, -2.0)
			else:
				Sfx.play_at("build_remove", pc2.global_position, -2.0)
				Building.remove(pc2)
		"bag":
			var tmp := Inventory.new(29)
			_set_slots(tmp, d.slots)
			DeathBag.spawn(main, d.pos, tmp)
		"arrow":
			Arrow.fire(main, d.from, d.dir, float(d.speed), p, float(d.pwr))
		"cont_set":
			var owner: Node = resolve(d.ref)
			var inv: Inventory = null
			if owner is Station:
				inv = (owner as Station).inventory
			elif owner is DeathBag:
				inv = (owner as DeathBag).inventory
			if inv:
				_set_slots(inv, d.slots)
				_sent_state.erase(nid_of(owner))
				if owner is DeathBag and (owner as DeathBag).is_empty():
					owner.queue_free()
		"cont_close":
			var cb: Callable = _close_cbs.get(peer, Callable())
			_close_cbs.erase(peer)
			if cb.is_valid():
				cb.call()


func _host_hit(d: Dictionary, p: Player) -> void:
	var ref: Dictionary = d.ref
	var tool_id := str(d.tool)
	if ref.has("res"):
		var body := _res_body(ref)
		if body:
			for oid in body.owners:
				if str(body.owners[oid].data.id) == str(ref.id):
					body.hit_owner(oid, tool_id, d.point, d.normal, p)
					return
		# chunk not streamed on the host: rebuild the resource from the client's description
		var xf := _to_xf(ref.xf)
		match str(ref.kind):
			"tree":
				var t := ChopTree.create(main, xf.origin, str(ref.variant), float(ref.scale))
				t.rotation.y = xf.basis.get_euler().y
				t.tool_hit(tool_id, d.point, d.normal, p)
			"boulder":
				var r := MineRock.create(main, xf, 0, "boulder_l0", str(ref.ore))
				r.tool_hit(tool_id, d.point, d.normal, p)
			"bush":
				var b := Bush.create(main, xf.origin, 1.0)
				b.tool_hit(tool_id, d.point, d.normal, p)
		main.world.harvest_key(Vector2i(int(ref.res[0]), int(ref.res[1])), str(ref.id))
		return
	var target: Node = null
	if ref.has("o") and main.obstacles:
		var o: Dictionary = main.obstacles.active.get(str(ref.o), {})
		target = o.get("node") if not o.is_empty() and is_instance_valid(o.get("node")) else null
	else:
		target = resolve(ref)
	if target and target.has_method("tool_hit"):
		target.tool_hit(tool_id, d.point, d.normal, p)


func _res_body(ref: Dictionary) -> ResourceBody:
	var ch = main.world.chunks.get(Vector2i(int(ref.res[0]), int(ref.res[1])))
	if ch == null or ch.body == null or not is_instance_valid(ch.body):
		return null
	return ch.body as ResourceBody


func _host_shape(d: Dictionary, p: Player) -> void:
	var ref: Dictionary = d.ref
	var body := _res_body(ref)
	if body:
		for oid in body.owners:
			if str(body.owners[oid].data.id) == str(ref.id):
				body.use_owner(oid, p)
				return
	var key := Vector2i(int(ref.res[0]), int(ref.res[1]))
	match str(ref.kind):
		"bush":
			if bool(ref.berry) and p.inventory.add("berries", 3) < 3:
				main.world.harvest_key(key, "p" + str(ref.id))
		"branch":
			if p.inventory.add("stick", 2) < 2:
				main.world.harvest_key(key, str(ref.id))
		"pebble":
			if p.inventory.add("stone", 1) < 1:
				main.world.harvest_key(key, str(ref.id))
		"mushroom":
			if p.inventory.add("mushroom", 1) < 1:
				main.world.harvest_key(key, str(ref.id))
