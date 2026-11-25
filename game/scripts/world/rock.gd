# Mineable boulder from a pre-fractured hierarchy: level 0 (static) -> 3 tumbling chunks -> 9 small chunks -> stones.
class_name MineRock
extends RigidBody3D

const HP := [9.0, 4.0, 2.0]
const DIR := "res://assets/models/rocks/boulder/"

static var _meta := {}
static var _outer: StandardMaterial3D
static var _inner: StandardMaterial3D

var level := 0
var ore := ""                # "", "iron_ore", "copper_ore", "coal"
var key := "boulder_l0"
var hp := 9.0
var _wobble := 0.0
var _model: Node3D


static func create(parent: Node, xf: Transform3D, lvl := 0, piece := "boulder_l0", ore_kind := "") -> MineRock:
	var r := MineRock.new()
	r.ore = ore_kind
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
	if Net.local_spawn_blocked():
		r.queue_free()
	elif NetSync.hosting():
		NetSync.inst.register(r, "rock")
	return r


static func meta() -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open(DIR + "fracture.json", FileAccess.READ)
		if f:
			_meta = JSON.parse_string(f.get_as_text())
	return _meta


static var _ore_mats := {}


static func ore_material(kind: String) -> StandardMaterial3D:
	if kind == "":
		return materials()[0]
	if not _ore_mats.has(kind):
		var m := (materials()[0] as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.albedo_color = {"iron_ore": Color(0.85, 0.55, 0.42), "copper_ore": Color(0.55, 0.78, 0.66), "coal": Color(0.32, 0.31, 0.31)}[kind]
		_ore_mats[kind] = m
	return _ore_mats[kind]


static func materials() -> Array:
	if _outer == null:
		# triplanar in object space: decimated rock meshes have torn UVs, this ignores them and sticks to the rock
		_outer = StandardMaterial3D.new()
		_outer.albedo_texture = load("res://assets/textures/ground/rockface_diff.jpg")
		_outer.normal_enabled = true
		_outer.normal_texture = load("res://assets/textures/ground/rockface_nor.jpg")
		_outer.roughness = 0.9
		_outer.uv1_triplanar = true
		_outer.uv1_triplanar_sharpness = 4.0
		_outer.uv1_scale = Vector3(0.9, 0.9, 0.9)
		_outer.albedo_color = Color(0.78, 0.76, 0.72)
		_inner = StandardMaterial3D.new()
		_inner.albedo_texture = load("res://assets/textures/ground/rockface_diff.jpg")
		_inner.normal_enabled = true
		_inner.normal_texture = load("res://assets/textures/ground/rockface_nor.jpg")
		_inner.uv1_triplanar = true
		_inner.uv1_scale = Vector3(1.6, 1.6, 1.6)
		_inner.albedo_color = Color(0.62, 0.6, 0.57)
		_inner.roughness = 0.95
	return [_outer, _inner]


static var _moss_rock: StandardMaterial3D


## Shared material for decorative moss rocks (same UV problem).
static func moss_material() -> StandardMaterial3D:
	if _moss_rock == null:
		_moss_rock = (materials()[0] as StandardMaterial3D).duplicate() as StandardMaterial3D
		_moss_rock.albedo_color = Color(0.66, 0.68, 0.6)
		_moss_rock.uv1_scale = Vector3(0.45, 0.45, 0.45)
	return _moss_rock


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
			m.set_surface_override_material(si, mats[1] if inner else ore_material(ore))
		var cs := CollisionShape3D.new()
		cs.shape = m.mesh.create_convex_shape(true, true)
		cs.transform = Terrain._rel(_model, m)
		add_child(cs)


func tool_hit(tool_id: String, point: Vector3, normal: Vector3, player: Node) -> bool:
	var dmg: float = {"pickaxe": 1.0, "axe": 0.25, "hammer": 0.2}.get(Items.tool_type(tool_id), 0.0) * Items.tool_power(tool_id)
	Sfx.play_at("hit_rock", point, -1.0 if dmg >= 0.5 else -6.0, 0.12)
	Fx.burst(get_tree().current_scene, point, normal, "rock", 10 if dmg >= 0.5 else 4)
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
			var chunk := MineRock.create(scene, xf, level + 1, name, ore)
			var out := (xf.origin - global_position).normalized()
			chunk.linear_velocity = linear_velocity + (out + Vector3.UP * 0.5) * randf_range(1.0, 2.2) - normal * 0.8
			chunk.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	else:
		for i in randi_range(2, 3):
			var p := Pickup.spawn(scene, "stone", 1, global_position + Vector3(randf_range(-0.15, 0.15), 0.25 + i * 0.1, randf_range(-0.15, 0.15)))
			p.linear_velocity = Vector3(randf_range(-1.5, 1.5), 2.5, randf_range(-1.5, 1.5))
		if ore != "":
			for k in randi_range(1, 2):
				Pickup.spawn(scene, ore, 1, global_position + Vector3(randf_range(-0.1, 0.1), 0.45 + k * 0.1, randf_range(-0.1, 0.1)))
		elif randf() < 0.15:
			Pickup.spawn(scene, "coal", 1, global_position + Vector3(0, 0.4, 0))
	queue_free()


func _physics_process(_dt: float) -> void:
	if global_position.y < -40.0:
		queue_free()
