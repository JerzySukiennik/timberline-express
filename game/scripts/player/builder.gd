# Hammer build mode: RMB (or B) opens the piece picker, ghost snaps to the aimed vehicle grid, R rotates,
# LMB builds (pays planks + nails). Without a selected piece, LMB repairs and holding RMB takes a piece apart.
class_name Builder
extends Node3D

var player: Player
var selected := ""
var ghost: Node3D
var _cell := Vector3i.ZERO
var _edge := 0
var _vehicle: RailVehicle
var _valid := false
var _rot := 0
var _mat_ok: StandardMaterial3D
var _mat_bad: StandardMaterial3D
var _remove_hold := 0.0
var prompt := ""


func _ready() -> void:
	top_level = true
	_mat_ok = StandardMaterial3D.new()
	_mat_ok.albedo_color = Color(0.55, 0.9, 0.6, 0.4)
	_mat_ok.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ok.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_bad = _mat_ok.duplicate()
	_mat_bad.albedo_color = Color(0.95, 0.4, 0.3, 0.4)


func active() -> bool:
	return player.equipped_id == "hammer"


func select(piece: String) -> void:
	selected = piece
	if ghost:
		ghost.queue_free()
		ghost = null
	if piece == "":
		return
	ghost = Node3D.new()
	add_child(ghost)
	for part in Building.parts(piece):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0] + Vector3.ONE * 0.01
		mi.mesh = bm
		mi.position = part[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(mi)


func _set_ghost_mat(m: Material) -> void:
	for mi in ghost.get_children():
		(mi as MeshInstance3D).material_override = m


func _process(dt: float) -> void:
	prompt = ""
	if player == null or not active():
		if ghost:
			ghost.visible = false
		return
	var cam := player.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 6.0, 4)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var v: RailVehicle = hit.collider if not hit.is_empty() and hit.collider is RailVehicle else null
	if selected == "":
		_manage(v, hit, dt)
		return
	if ghost == null:
		return
	if v == null or Building.deck_of(v).is_empty():
		ghost.visible = false
		prompt = "Aim at a flatcar deck to build  ·  [RMB] pick piece"
		return
	var deck := Building.deck_of(v)
	var lp := v.to_local(hit.position)
	var storey := clampi(int(floor((lp.y - float(deck.top) + 0.3) / Building.STOREY)), 0, 2)
	var fx := lp.x / Building.CELL + (int(deck.nx) - 1) * 0.5
	var fz := lp.z / Building.CELL + (int(deck.nz) - 1) * 0.5
	var cx := clampi(int(round(fx)), 0, int(deck.nx) - 1)
	var cz := clampi(int(round(fz)), 0, int(deck.nz) - 1)
	var kind: String = Building.PIECES[selected].kind
	var edge := _rot % 4
	if kind == "edge":
		# nearest cell edge to the aim point
		var ux := fx - cx
		var uz := fz - cz
		if absf(ux) > absf(uz):
			edge = 1 if ux > 0 else 3
		else:
			edge = 2 if uz > 0 else 0
	if kind == "top":
		storey = clampi(storey, 0, 2)
	_cell = Vector3i(cx, storey, cz)
	_edge = edge
	_vehicle = v
	ghost.visible = true
	ghost.global_transform = v.global_transform * Building.local_transform(v, selected, _cell, _edge)
	var pieces: Dictionary = v.get_meta("pieces", {})
	var key := "%s:%d:%d:%d:%d" % [kind, _cell.x, _cell.y, _cell.z, _edge]
	_valid = not pieces.has(key) and Building.can_afford(selected, player.inventory)
	_set_ghost_mat(_mat_ok if _valid else _mat_bad)
	prompt = "[LMB] Build %s  ·  %s  ·  [R] rotate  ·  [RMB] pick piece" % [Building.PIECES[selected].name, Building.cost_text(selected, player.inventory)]


func _manage(v: RailVehicle, hit: Dictionary, dt: float) -> void:
	if v == null:
		_remove_hold = 0.0
		prompt = "[RMB] Choose something to build"
		return
	var p := Building.piece_from_shape(v, int(hit.shape))
	if p == null:
		_remove_hold = 0.0
		prompt = "[RMB] Choose something to build"
		return
	prompt = "%s  %d%%  ·  [LMB] repair (1 plank)  ·  hold [Q] take apart" % [Building.PIECES[p.piece].name, int(p.hp)]
	if Input.is_action_pressed("drop") and player.input_enabled:
		_remove_hold += dt
		prompt = "Taking apart…  %d%%" % int(_remove_hold / 1.2 * 100.0)
		if _remove_hold >= 1.2:
			_remove_hold = 0.0
			var cost: Dictionary = Building.PIECES[p.piece].cost
			for id in cost:
				player.inventory.add(id, int(ceil(int(cost[id]) * 0.5)))
			if NetSync.remote():
				NetSync.inst.request("takeapart", {"veh": NetSync.inst.nid_of(v), "key": p.key()})
				return
			Sfx.play_at("build_remove", p.global_position, -2.0)
			Building.remove(p)
	else:
		_remove_hold = 0.0


func primary() -> bool:
	if not active():
		return false
	if selected != "":
		if ghost and ghost.visible and _valid and _vehicle:
			var cost: Dictionary = Building.PIECES[selected].cost
			for id in cost:
				player.inventory.remove(id, int(cost[id]))
			if NetSync.remote():
				NetSync.inst.request("build", {"veh": NetSync.inst.nid_of(_vehicle), "piece": selected, "cell": [_cell.x, _cell.y, _cell.z], "edge": _edge})
				player.viewmodel.request_swing()
				return true
			var p := Building.build(_vehicle, selected, _cell, _edge)
			Sfx.play_at("build_place_wood", p.global_position + Vector3.UP, -1.0)
			player.viewmodel.request_swing()
		return true
	# repair the aimed piece
	var cam := player.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 4.0, 4)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider is RailVehicle:
		var p2 := Building.piece_from_shape(hit.collider, int(hit.shape))
		if p2 and p2.hp < 100.0 and player.inventory.remove("plank", 1):
			if NetSync.remote():
				NetSync.inst.request("repair", {"veh": NetSync.inst.nid_of(hit.collider), "key": p2.key()})
				player.viewmodel.request_swing()
				return true
			p2.hp = minf(100.0, p2.hp + 35.0)
			Sfx.play_at("hammer_hit", hit.position, -2.0)
			player.viewmodel.request_swing()
			return true
	return false


func rotate_piece() -> void:
	_rot += 1
