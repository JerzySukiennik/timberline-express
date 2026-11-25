# Ghost preview for placeable stations: aim at ground or a vehicle deck, R rotates, LMB places, red when blocked.
class_name Placer
extends Node3D

var player: Player
var item_id := ""
var ghost: Node3D
var yaw := 0.0
var valid := false
var _target: Object
var _xf := Transform3D.IDENTITY
var _mat_ok: StandardMaterial3D
var _mat_bad: StandardMaterial3D


func _ready() -> void:
	_mat_ok = _ghost_mat(Color(0.55, 0.9, 0.55, 0.45))
	_mat_bad = _ghost_mat(Color(0.95, 0.35, 0.3, 0.45))
	top_level = true


func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	return m


func set_item(id: String) -> void:
	if id == item_id:
		return
	item_id = id
	if ghost:
		ghost.queue_free()
		ghost = null
	if Items.def(id).get("kind", "") == "placeable":
		ghost = (load(Items.def(id).model) as PackedScene).instantiate() as Node3D
		add_child(ghost)
		_apply_mat(ghost, _mat_ok)


func _apply_mat(n: Node, m: Material) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_dt: float) -> void:
	if ghost == null or player == null:
		return
	if Input.is_action_just_pressed("rotate_build") and player.input_enabled:
		yaw += PI / 8.0
	var cam := player.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 5.0, 1 | 4)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.75:
		ghost.visible = hit.size() > 0
		valid = false
		if not hit.is_empty():
			ghost.global_position = hit.position
		_apply_mat(ghost, _mat_bad)
		return
	ghost.visible = true
	_target = hit.collider
	var base_yaw := player.global_rotation.y + PI
	if _target is RailVehicle:
		var v: RailVehicle = _target
		var local_yaw := snappedf(base_yaw - v.global_rotation.y + yaw, PI / 2.0)
		_xf = Transform3D(v.global_basis * Basis(Vector3.UP, local_yaw), hit.position)
	else:
		_xf = Transform3D(Basis(Vector3.UP, base_yaw + yaw), hit.position)
	ghost.global_transform = _xf
	var size: Vector3 = Station.SIZES.get(Items.def(item_id).station, Vector3.ONE)
	var sq := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = size * 0.9
	sq.shape = bs
	sq.transform = _xf * Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5 + 0.05, 0))
	sq.collision_mask = 1 | 2 | 4
	var hits := player.get_world_3d().direct_space_state.intersect_shape(sq, 4)
	valid = hits.filter(func(h: Dictionary) -> bool: return h.collider != _target).is_empty()
	_apply_mat(ghost, _mat_ok if valid else _mat_bad)


func try_place() -> bool:
	if ghost == null or not valid or not ghost.visible:
		return false
	var main: Node = player.main
	var slot := player.inventory.get_slot(player.selected_slot)
	if slot.is_empty() or slot.id != item_id:
		return false
	player.inventory.remove_at(player.selected_slot, 1)
	if NetSync.remote():
		NetSync.inst.request("place", {"kind": str(Items.def(item_id).station), "xf": NetSync._xf(_xf), "veh": NetSync.inst.nid_of(_target) if _target is RailVehicle else ""})
		return true
	Station.place(main, Items.def(item_id).station, _xf, _target)
	Sfx.play_at("build_place_wood", _xf.origin, -2.0)
	return true
