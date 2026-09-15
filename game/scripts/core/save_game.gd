# Save/load: seed + everything the player changed. Track positions use stable edge keys, not segment ids.
class_name SaveGame
extends RefCounted

const DIR := "user://saves"


static func path(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, slot]


static func list() -> Array:
	var out := []
	for slot in 3:
		var f := FileAccess.open(path(slot), FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				out.append({"slot": slot, "time": d.get("saved_at", ""), "km": d.get("km", 0.0), "seed": d.get("seed", 0)})
	return out


static func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _to_v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _xf(t: Transform3D) -> Array:
	var b := t.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z]


static func _to_xf(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])), Vector3(a[9], a[10], a[11]))


static func save(main: Node, slot: int) -> bool:
	if main.world == null:
		return false
	var p: Player = main.player
	var d := {
		"version": 1,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"seed": main.world_seed,
		"km": main.distance_km,
		"time": main.day_night.time,
		"weather": main.day_night.weather,
		"player": {"pos": _v3(p.global_position), "yaw": p.rotation.y, "inv": p.inventory.slots.duplicate(true), "slot": p.selected_slot, "stats": p.survival.to_dict(), "stamina": p.stamina},
		"removed": main.world.removed.duplicate(true),
		"consists": [],
		"stations": [],
		"bags": [],
	}
	var tracks: InfiniteTracks = main.world.tracks
	for c in main.vehicles.consists:
		var lead: RailVehicle = c.lead()
		var cur := lead.center_cursor()
		var cd := {"edge": tracks.key_of(cur.seg), "s": cur.s, "flip": cur.flip, "v": c.v, "vehicles": []}
		for v in c.vehicles:
			var vd := {"type": _type(v), "state": _vehicle_state(v), "pieces": [], "stations": []}
			for pc in (v.get_meta("pieces", {}) as Dictionary).values():
				vd.pieces.append({"piece": pc.piece, "cell": [pc.cell.x, pc.cell.y, pc.cell.z], "edge": pc.edge, "hp": pc.hp})
			for st in v.get_children():
				if st is Station:
					vd.stations.append(_station_dict(st, st.transform))
			cd.vehicles.append(vd)
		d.consists.append(cd)
	for st in main.stations:
		if is_instance_valid(st) and st.vehicle == null:
			d.stations.append(_station_dict(st, st.global_transform))
	for bag in main.find_children("*", "DeathBag", true, false):
		d.bags.append({"pos": _v3((bag as Node3D).global_position), "inv": (bag as DeathBag).inventory.slots.duplicate(true)})
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	return true


static func _type(v: RailVehicle) -> String:
	if v is Handcar: return "handcar"
	if v is Flatcar: return "flatcar"
	if v is SteamLoco: return "steam"
	if v is Tender: return "tender"
	if v is ElectricLoco: return "electric"
	return "flatcar"


static func _vehicle_state(v: RailVehicle) -> Dictionary:
	if v is SteamLoco:
		var s := v as SteamLoco
		return {"energy": s.energy, "pressure": s.pressure, "reg": s.regulator.value, "rev": s.reverser.value, "brake": s.brake.value}
	if v is Tender:
		return {"water": (v as Tender).water}
	if v is ElectricLoco:
		var e := v as ElectricLoco
		return {"battery": e.battery, "fuel": e.fuel, "breaker": e.breaker, "dir": e.direction, "ctl": e.controller.value, "brake": e.brake.value}
	if v is Handcar:
		return {"dir": (v as Handcar).direction, "brake": (v as Handcar).brake.value}
	return {}


static func _station_dict(st: Station, xf: Transform3D) -> Dictionary:
	var sd := st.to_dict()
	sd["xf"] = _xf(xf)
	return sd


static func load_into(main: Node, slot: int) -> bool:
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null:
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return false
	var w: ChunkWorld = main.world
	w.removed = d.get("removed", {})
	main.day_night.time = float(d.get("time", 8.0))
	main.day_night.set_weather(str(d.get("weather", "clear")))
	main.distance_km = float(d.get("km", 0.0))
	# player
	var pd: Dictionary = d.player
	var p: Player = main.player
	for i in p.inventory.size():
		p.inventory.slots[i] = {}
	var inv: Array = pd.inv
	for i in mini(inv.size(), p.inventory.size()):
		var sl: Dictionary = inv[i]
		if not sl.is_empty():
			sl.count = int(sl.count)
			if sl.has("dur"):
				sl.dur = int(sl.dur)
		p.inventory.slots[i] = sl
	p.inventory.changed.emit()
	p.survival.from_dict(pd.stats)
	p.select_slot(int(pd.slot))
	main.spawn_point = _to_v3(pd.pos)
	p.rotation.y = float(pd.yaw)
	# trains
	for c in main.vehicles.consists.duplicate():
		for v in c.vehicles:
			v.queue_free()
	main.vehicles.consists.clear()
	main.handcar = null
	main.flatcar = null
	var tracks: InfiniteTracks = w.tracks
	var focus: Array = []
	for cd in d.consists:
		var seg := tracks.segment_for_key(str(cd.edge))
		if seg == null:
			continue
		var list: Array = []
		var steam_loco: SteamLoco = null
		for vd in cd.vehicles:
			var v = null
			match str(vd.type):
				"handcar": v = Handcar.new()
				"flatcar": v = Flatcar.new()
				"steam": v = SteamLoco.new()
				"tender": v = Tender.new()
				"electric": v = ElectricLoco.new()
			main.add_child(v)
			v.setup(main.network)
			list.append(v)
			if v is SteamLoco:
				steam_loco = v
				main.steam = v
			if v is Tender and steam_loco:
				steam_loco.tender = v
				main.tender = v
			if v is Handcar and main.handcar == null:
				main.handcar = v
			if v is Flatcar and main.flatcar == null:
				main.flatcar = v
			if v is ElectricLoco:
				main.electric = v
		(list[0] as RailVehicle).place(main.network.cursor_at(seg, float(cd.s), bool(cd.flip)))
		var c2: Consist = main.vehicles.add(list)
		c2.v = float(cd.v)
		focus.append(list[0])
		for i in list.size():
			var v2: RailVehicle = list[i]
			var vd2: Dictionary = cd.vehicles[i]
			_apply_state(v2, vd2.state)
			for pc in vd2.pieces:
				var piece := Building.build(v2, str(pc.piece), Vector3i(int(pc.cell[0]), int(pc.cell[1]), int(pc.cell[2])), int(pc.edge))
				piece.hp = float(pc.hp)
			for sd in vd2.stations:
				var st := Station.place(main, str(sd.kind), v2.global_transform * _to_xf(sd.xf), v2)
				_apply_station(st, sd)
	w.extra_focus = focus
	for sd in d.stations:
		var st2 := Station.place(main, str(sd.kind), _to_xf(sd.xf), main)
		_apply_station(st2, sd)
	for bd in d.bags:
		var tmp := Inventory.new(29)
		var arr: Array = bd.inv
		for i in mini(arr.size(), 29):
			var sl2: Dictionary = arr[i]
			if not sl2.is_empty():
				sl2.count = int(sl2.count)
			tmp.slots[i] = sl2
		DeathBag.spawn(main, _to_v3(bd.pos), tmp)
	return true


static func _apply_state(v: RailVehicle, st: Dictionary) -> void:
	if v is SteamLoco:
		var s := v as SteamLoco
		s.energy = float(st.get("energy", 0.0))
		s.pressure = float(st.get("pressure", 0.0))
		s.regulator.set_value(float(st.get("reg", 0.0)))
		s.reverser.set_value(float(st.get("rev", 0.0)))
		s.brake.set_value(float(st.get("brake", 0.6)))
	elif v is Tender:
		(v as Tender).water = float(st.get("water", 0.0))
	elif v is ElectricLoco:
		var e := v as ElectricLoco
		e.battery = float(st.get("battery", 10.0))
		e.fuel = float(st.get("fuel", 0.0))
		e.direction = int(st.get("dir", 0))
		if bool(st.get("breaker", false)):
			e._set_breaker(true)
		e.controller.set_value(float(st.get("ctl", 0.0)))
		e.brake.set_value(float(st.get("brake", 0.6)))
	elif v is Handcar:
		(v as Handcar).direction = float(st.get("dir", 1.0))
		(v as Handcar).brake.set_value(float(st.get("brake", 1.0)))


static func _apply_station(st: Station, sd: Dictionary) -> void:
	st.burn = float(sd.get("burn", 0.0))
	st.progress = float(sd.get("progress", 0.0))
	if st.inventory and sd.has("inv"):
		var arr: Array = sd.inv
		for i in mini(arr.size(), st.inventory.size()):
			var sl: Dictionary = arr[i]
			if not sl.is_empty():
				sl.count = int(sl.count)
			st.inventory.slots[i] = sl
