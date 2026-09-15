# Choppable fir: axe hits chip the trunk, then it creaks, topples as a rigid body and splits into logs.
class_name ChopTree
extends StaticBody3D

var hp := 12.0
var model: Node3D
var height := 10.0
var _falling: RigidBody3D
var _fall_time := 0.0
var _landed := false
var _fall_dir := Vector3.FORWARD
var _base := Vector3.ZERO


static func create(parent: Node, pos: Vector3, variant := "fir_b", scale := 1.0) -> ChopTree:
	var t := ChopTree.new()
	t.collision_layer = 1 | 32
	t.set_meta("surface", "wood")
	parent.add_child(t)
	t.global_position = pos
	t.rotation.y = randf() * TAU
	t.model = (load("res://assets/models/trees/%s.glb" % variant) as PackedScene).instantiate() as Node3D
	t.model.scale = Vector3.ONE * scale
	t.add_child(t.model)
	for mi in t.model.find_children("Foliage*", "MeshInstance3D", true, false):
		var tex := "fir_tip_card" if String(mi.name) == "FoliageTip" else "fir_branch_card"
		(mi as MeshInstance3D).material_override = Terrain.foliage_material(load("res://assets/textures/trees/%s.png" % tex), 14.0)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var aabb := AABB()
	for mi in t.model.find_children("Trunk", "MeshInstance3D", true, false):
		aabb = (mi as MeshInstance3D).get_aabb()
	t.height = aabb.size.y * scale
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = maxf(aabb.size.x * 0.5 * scale * 0.8, 0.15)
	cyl.height = t.height
	cs.shape = cyl
	cs.position.y = t.height * 0.5
	t.add_child(cs)
	return t


func tool_hit(tool_id: String, point: Vector3, normal: Vector3, player: Node) -> bool:
	if _falling:
		return false
	var dmg := {"axe": 1.0, "pickaxe": 0.35, "knife": 0.1}.get(tool_id, 0.0) as float
	Sfx.play_at("chop", point, -1.0 if dmg >= 1.0 else -7.0, 0.12)
	Fx.burst(get_tree().current_scene, point, normal, "wood", 12 if dmg >= 1.0 else 4)
	if dmg <= 0.0:
		return false
	Fx.scar(self, point, normal, 0.16, Color(0.55, 0.42, 0.28, 0.9))
	hp -= dmg
	var tw := create_tween()
	tw.tween_property(model, "rotation:z", 0.012 * signf(randf() - 0.5), 0.08)
	tw.tween_property(model, "rotation:z", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC)
	if player and player.has_method("shake"):
		player.shake(0.25)
	if hp <= 0.0 and player:
		_fall((global_position - (player as Node3D).global_position))
	return true


func _fall(away: Vector3) -> void:
	away.y = 0
	_fall_dir = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	_base = global_position
	Sfx.play_at("tree_creak", global_position + Vector3.UP * 3.0, 2.0, 0.05)
	var body := RigidBody3D.new()
	body.mass = 600.0
	body.collision_layer = 1
	body.collision_mask = 1 | 4
	body.contact_monitor = true
	body.max_contacts_reported = 4
	get_parent().add_child(body)
	body.global_transform = global_transform.translated(Vector3.UP * 0.6)
	model.reparent(body, true)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = height * 0.9
	cs.shape = cap
	cs.position.y = height * 0.5
	body.add_child(cs)
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3(0, height * 0.45, 0)
	body.apply_impulse(_fall_dir * 900.0, Vector3.UP * height * 0.8)
	_falling = body
	for c in get_children():
		if c is CollisionShape3D:
			c.queue_free()
	var stump: PackedScene = load("res://assets/models/plants/tree_stump_01.glb")
	if stump:
		var s := stump.instantiate() as Node3D
		get_parent().add_child(s)
		s.global_position = _base - Vector3.UP * 0.3
		s.scale = Vector3.ONE * 0.45


func _physics_process(dt: float) -> void:
	if _falling == null:
		return
	_fall_time += dt
	if not _landed and _fall_time > 0.8 and (_falling.get_contact_count() > 0 and _falling.linear_velocity.length() < 3.0 or _fall_time > 4.0):
		_landed = true
		Sfx.play_at("tree_fall", _falling.global_position + _falling.global_basis.y * height * 0.5, 4.0, 0.05)
		Fx.burst(get_tree().current_scene, _falling.global_position + _falling.global_basis.y * height * 0.5, Vector3.UP, "dust", 12)
		Fx.burst(get_tree().current_scene, _falling.global_position + _falling.global_basis.y * height * 0.6, Vector3.UP, "leaf", 40)
		var pl := get_tree().get_first_node_in_group("player")
		if pl and (pl as Node3D).global_position.distance_to(_falling.global_position) < 20.0:
			pl.shake(0.6)
	if _landed and _fall_time > 3.2:
		var scene := get_tree().current_scene
		var n := clampi(int(height / 2.2), 3, 6)
		for i in n:
			var pos := _falling.global_transform * Vector3(0, height * (0.12 + 0.7 * i / n), 0)
			Pickup.spawn(scene, "log", 1, pos + Vector3.UP * 0.3)
		Fx.burst(scene, _falling.global_transform * Vector3(0, height * 0.5, 0), Vector3.UP, "leaf", 30)
		_falling.queue_free()
		queue_free()
