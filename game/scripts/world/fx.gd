# One-shot particle bursts (rock chips, wood chips, leaves, dust) and hit decals.
class_name Fx
extends RefCounted

static var _mats := {}


static func burst(parent: Node, pos: Vector3, normal: Vector3, kind: String, amount := 14, from_net := false) -> void:
	if not from_net:
		if Net.applying > 0 and Net.is_client_online():
			return
		if NetSync.hosting():
			NetSync.inst.fx(pos, normal, kind, amount)
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 1.4 if kind != "dust" else 2.2
	p.explosiveness = 0.95
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = normal
	pm.spread = 55.0 if kind != "dust" else 80.0
	pm.initial_velocity_min = 1.5 if kind != "dust" else 0.3
	pm.initial_velocity_max = 4.0 if kind != "dust" else 1.2
	pm.gravity = Vector3(0, -9.8, 0) if kind in ["rock", "wood"] else Vector3(0, -1.2 if kind == "leaf" else 0.25, 0)
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.damping_min = 0.0 if kind in ["rock", "wood"] else 2.0
	pm.damping_max = 0.5 if kind in ["rock", "wood"] else 3.0
	pm.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	p.process_material = pm
	var mesh: Mesh
	match kind:
		"rock":
			var b := BoxMesh.new()
			b.size = Vector3(0.035, 0.025, 0.03)
			mesh = b
		"wood":
			var b2 := BoxMesh.new()
			b2.size = Vector3(0.05, 0.008, 0.02)
			mesh = b2
		_:
			var q := QuadMesh.new()
			q.size = Vector2(0.08, 0.08) if kind == "leaf" else Vector2(0.6, 0.6)
			mesh = q
	mesh.surface_set_material(0, _mat(kind))
	p.draw_pass_1 = mesh
	parent.add_child(p)
	p.global_position = pos + normal * 0.03
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"rock":
			m.albedo_color = Color(0.42, 0.4, 0.37)
			m.roughness = 1.0
		"wood":
			m.albedo_color = Color(0.72, 0.58, 0.4)
		"leaf":
			m.albedo_color = Color(0.3, 0.42, 0.2)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		"dust":
			m.albedo_color = Color(0.55, 0.52, 0.47, 0.35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.vertex_color_use_as_albedo = true
			var tex := GradientTexture2D.new()
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 1))
			g.set_color(1, Color(1, 1, 1, 0))
			tex.gradient = g
			tex.fill = GradientTexture2D.FILL_RADIAL
			tex.fill_from = Vector2(0.5, 0.5)
			tex.fill_to = Vector2(0.5, 0.0)
			m.albedo_texture = tex
	_mats[kind] = m
	return m


static func scar(parent: Node3D, pos: Vector3, normal: Vector3, size := 0.22, col := Color(0.12, 0.11, 0.1, 0.85)) -> void:
	var d := Decal.new()
	d.size = Vector3(size, 0.25, size)
	var tex := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, col)
	g.add_point(0.45, Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, col.a * 0.6))
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.02)
	d.texture_albedo = tex
	d.cull_mask = 1
	d.upper_fade = 0.1
	d.lower_fade = 0.1
	parent.add_child(d)
	d.global_position = pos
	var up := normal.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	d.global_basis = Basis(side, up, side.cross(up)).rotated(up, randf() * TAU)
