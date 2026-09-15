# Mineable boulder from a pre-fractured hierarchy: level 0 (static) -> 3 tumbling chunks -> 9 small chunks -> stones.
class_name MineRock
extends RigidBody3D

const HP := [9.0, 4.0, 2.0]
const DIR := "res://assets/models/rocks/boulder/"

static var _meta := {}
static var _outer: StandardMaterial3D
static var _inner: StandardMaterial3D

var level := 0
var key := "boulder_l0"
var hp := 9.0
var _wobble := 0.0
var _model: Node3D


static func create(parent: Node, xf: Transform3D, lvl := 0, piece := "boulder_l0") -> MineRock:
	var r := MineRock.new()
	r.level = lvl
	r.key = piece
	r.hp = HP[lvl]
	r.collision_layer = 1 | 32
	r.collision_mask = 1 | 4 | 32
	r.set_meta("surface", "rock")
	r.mass = [8000.0, 700.0, 90.0][lvl]
	r.freeze = lvl == 0
	r.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	parent.add_child(r)
	r.global_transform = xf
	r._build()
	return r


static func meta() -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open(DIR + "fracture.json", FileAccess.READ)
		if f:
			_meta = JSON.parse_string(f.get_as_text())
	return _meta


static func materials() -> Array:
	if _outer == null:
		_outer = StandardMaterial3D.new()
		_outer.albedo_texture = load("res://assets/textures/rock/boulder_01_diff_1k.jpg")
		_outer.normal_enabled = true
		_outer.normal_texture = load("res://assets/textures/rock/boulder_01_nor_gl_1k.jpg")
		_outer.roughness_texture = load("res://assets/textures/rock/boulder_01_arm_1k.jpg")
		_outer.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		_outer.ao_enabled = true
		_outer.ao_texture = _outer.roughness_texture
		_outer.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		_outer.albedo_color = Color(0.72, 0.7, 0.68)
		_inner = StandardMaterial3D.new()
		_inner.albedo_texture = load("res://assets/textures/ground/rockface_diff.jpg")
		_inner.normal_enabled = true
		_inner.normal_texture = load("res://assets/textures/ground/rockface_nor.jpg")
		_inner.uv1_triplanar = true
		_inner.uv1_scale = Vector3(1.6, 1.6, 1.6)
		_inner.albedo_color = Color(0.75, 0.72, 0.68)
		_inner.roughness = 0.95
	return [_outer, _inner]


func _build() -> void:
	var ps: PackedScene = load(DIR + key + ".glb")
	_model = ps.instantiate() as Node3D
	add_child(_model)
	var mats := materials()
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for si in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(si)
			var inner := src != null and src.resource_name.contains("Inner")
			m.set_surface_override_material(si, mats[1] if inner else mats[0])
		var cs := CollisionShape3D.new()
		cs.shape = m.mesh.create_convex_shape(true, true)
		cs.transform = Terrain._rel(_model, m)
		add_child(cs)


func tool_hit(tool_id: String, point: Vector3, normal: Vector3, player: Node) -> bool:
	var dmg := {"pickaxe": 1.0, "axe": 0.25, "knife": 0.0}.get(tool_id, 0.0) as float
	Sfx.play_at("hit_rock", point, -1.0 if dmg >= 1.0 else -6.0, 0.12)
	Fx.burst(get_tree().current_scene, point, normal, "rock", 10 if dmg >= 1.0 else 4)
	if dmg <= 0.0:
		return false
	Fx.scar(self, point, normal, 0.18 + 0.05 * randf())
	hp -= dmg
	if player and player.has_method("shake"):
		player.shake(0.35)
	if not freeze:
		apply_impulse((-normal) * 30.0 * mass / 700.0, point - global_position)
	if hp <= 0.0:
		_break(normal)
	return true


func _break(normal: Vector3) -> void:
	var scene := get_tree().current_scene
	Sfx.play_at("rock_crack", global_position, 2.0, 0.08)
	Sfx.play_at("rock_debris", global_position, -2.0, 0.1)
	Fx.burst(scene, global_position + Vector3.UP * 0.4, Vector3.UP, "dust", 10)
	Fx.burst(scene, global_position + Vector3.UP * 0.3, Vector3.UP, "rock", 26)
	var pieces: Dictionary = meta().get("pieces", {})
	if level < 2:
		var prefix := "boulder_l1_" if level == 0 else key.replace("l1", "l2") + "_"
		for i in 3:
			var name := prefix + str(i)
			if not pieces.has(name):
				continue
			var off: Array = pieces[name].offset
			var local := Vector3(off[0], off[1], off[2])
			var xf := Transform3D(global_basis, global_transform * local)
			var chunk := MineRock.create(scene, xf, level + 1, name)
			var out := (xf.origin - global_position).normalized()
			chunk.linear_velocity = linear_velocity + (out + Vector3.UP * 0.5) * randf_range(1.0, 2.2) - normal * 0.8
			chunk.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	else:
		for i in randi_range(2, 3):
			var p := Pickup.spawn(scene, "stone", 1, global_position + Vector3(randf_range(-0.15, 0.15), 0.25 + i * 0.1, randf_range(-0.15, 0.15)))
			p.linear_velocity = Vector3(randf_range(-1.5, 1.5), 2.5, randf_range(-1.5, 1.5))
		if randf() < 0.5:
			Pickup.spawn(scene, "coal", 1, global_position + Vector3(0, 0.4, 0))
	queue_free()


func _physics_process(_dt: float) -> void:
	if global_position.y < -40.0:
		queue_free()
