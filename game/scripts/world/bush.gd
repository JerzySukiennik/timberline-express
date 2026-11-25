# Knife-harvestable shrub: each cut drops fiber and shrinks it; regrows after a while.
class_name Bush
extends StaticBody3D

var hp := 3
var model: Node3D
var _base_scale := 1.0


static func create(parent: Node, pos: Vector3, scale := 1.0) -> Bush:
	var b := Bush.new()
	b.collision_layer = 32
	parent.add_child(b)
	b.global_position = pos
	b.rotation.y = randf() * TAU
	var files := ["shrub_02_a", "shrub_02_b", "shrub_02_d"]
	b.model = (load("res://assets/models/plants/%s.glb" % files[randi() % files.size()]) as PackedScene).instantiate() as Node3D
	b._base_scale = scale
	b.model.scale = Vector3.ONE * scale
	b.add_child(b.model)
	for mi in b.model.find_children("*", "MeshInstance3D", true, false):
		var src := (mi as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
		if src and src.albedo_texture:
			(mi as MeshInstance3D).material_override = Terrain.foliage_material(src.albedo_texture, 2.0, Color(0.9, 0.95, 0.85))
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.6 * scale
	cs.shape = sp
	cs.position.y = 0.6 * scale
	b.add_child(cs)
	b.set_meta("scale", scale)
	if Net.local_spawn_blocked():
		b.queue_free()
	elif NetSync.hosting():
		NetSync.inst.register(b, "bush")
	return b


func tool_hit(tool_id: String, point: Vector3, normal: Vector3, _player: Node) -> bool:
	Sfx.play_at("cut_foliage", point, -2.0, 0.12)
	Fx.burst(get_tree().current_scene, point, normal, "leaf", 18)
	var tt := Items.tool_type(tool_id)
	if tt != "knife" and tt != "axe":
		return false
	hp -= 1
	var p := Pickup.spawn(get_tree().current_scene, "fiber", 2 if tt == "knife" else 1, point + normal * 0.2)
	if randf() < 0.6:
		Pickup.spawn(get_tree().current_scene, "stick", 1, point + normal * 0.3 + Vector3.UP * 0.2)
	p.linear_velocity = normal * 1.5 + Vector3.UP
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3.ONE * _base_scale * (0.45 + 0.18 * hp), 0.2).set_trans(Tween.TRANS_BACK)
	if hp <= 0:
		visible = false
		collision_layer = 0
		get_tree().create_timer(60.0).timeout.connect(_regrow)
	return true


func _regrow() -> void:
	hp = 3
	visible = true
	collision_layer = 32
	model.scale = Vector3.ONE * _base_scale * 0.3
	create_tween().tween_property(model, "scale", Vector3.ONE * _base_scale, 3.0)
