# Ballistic arrow: gravity, segment raycasts each tick; wounds animals, sticks into the world as a pickup.
class_name Arrow
extends Node3D

var velocity := Vector3.ZERO
var shooter: Node
var power := 1.0
var _life := 8.0


static func fire(scene: Node, from: Vector3, dir: Vector3, speed: float, shooter_node: Node, pwr: float) -> Arrow:
	var a := Arrow.new()
	a.velocity = dir * speed
	a.shooter = shooter_node
	a.power = pwr
	scene.add_child(a)
	a.global_position = from
	var m := Items.instance("arrow")
	a.add_child(m)
	m.rotation.x = -PI * 0.5
	a.look_at(from + dir, Vector3.UP)
	return a


func _physics_process(dt: float) -> void:
	_life -= dt
	if _life <= 0.0:
		queue_free()
		return
	velocity.y -= 9.8 * dt
	var from := global_position
	var to := from + velocity * dt
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 32 | 128)
	if shooter is CollisionObject3D:
		q.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var col: Object = hit.collider
		if col is Animal:
			(col as Animal).damage(55.0 * power, shooter)
			Sfx.play_at("arrow_hit_flesh", hit.position, 0.0)
			queue_free()
			return
		Sfx.play_at("arrow_hit_wood", hit.position, -2.0)
		var p := Pickup.spawn(get_tree().current_scene, "arrow", 1, hit.position)
		p.freeze = true
		p.global_basis = global_basis
		queue_free()
		return
	global_position = to
	if velocity.length() > 0.1:
		look_at(to + velocity, Vector3.UP)
