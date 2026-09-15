# Physical item lying in the world; picked up with E or an empty-hand click.
class_name Pickup
extends RigidBody3D

var item_id := ""
var count := 1
var dur := -1


static func spawn(parent: Node, id: String, n: int, pos: Vector3) -> Pickup:
	var p := Pickup.new()
	p.item_id = id
	p.count = n
	p.collision_layer = 16
	p.collision_mask = 1 | 4 | 16
	p.mass = 2.0
	p.continuous_cd = true
	var model := Items.instance(id)
	p.add_child(model)
	var aabb := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a := Terrain._rel(model, m) * m.get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
	if model is MeshInstance3D:
		aabb = (model as MeshInstance3D).get_aabb()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = aabb.size.clamp(Vector3(0.06, 0.06, 0.06), Vector3(1.2, 1.2, 1.2))
	cs.shape = b
	cs.position = aabb.get_center()
	p.add_child(cs)
	parent.add_child(p)
	p.global_position = pos
	p.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	return p


func label() -> String:
	return Items.display_name(item_id) + ("  x%d" % count if count > 1 else "")


func _physics_process(_dt: float) -> void:
	if global_position.y < -50.0:
		queue_free()
