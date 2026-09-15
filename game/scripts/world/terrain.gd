# Terrain around the test loop: heightfield shaped to the track embankment, distant mountains and scattered forest decor.
class_name Terrain
extends Node3D

const HALF := 160
const RES := 321

var heights := PackedFloat32Array()
var gravel := PackedFloat32Array()
var track_dist := PackedFloat32Array()
var net: TrackNetwork
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var tree_colliders: StaticBody3D


func build(network: TrackNetwork) -> void:
	net = network
	rng.seed = 1207
	noise.seed = 77
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	_heights()
	_mesh()
	_collision()
	_mountains()


func _base(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var rim := smoothstep(92.0, 165.0, r)
	return noise.get_noise_2d(x, z) * 1.6 + rim * rim * 26.0 + noise.get_noise_2d(x * 3.1, z * 3.1) * 0.25


func _heights() -> void:
	heights.resize(RES * RES)
	gravel.resize(RES * RES)
	track_dist.resize(RES * RES)
	var track_h := PackedFloat32Array()
	track_h.resize(RES * RES)
	for i in RES * RES:
		track_dist[i] = INF
	for p in net.samples:
		var cx := int(round(p.x)) + HALF
		var cz := int(round(p.z)) + HALF
		for dz in range(-11, 12):
			for dx in range(-11, 12):
				var gx := cx + dx
				var gz := cz + dz
				if gx < 0 or gz < 0 or gx >= RES or gz >= RES:
					continue
				var d := Vector2(gx - HALF - p.x, gz - HALF - p.z).length()
				var idx := gz * RES + gx
				if d < track_dist[idx]:
					track_dist[idx] = d
					track_h[idx] = p.y
	for gz in RES:
		for gx in RES:
			var idx := gz * RES + gx
			var x := float(gx - HALF)
			var z := float(gz - HALF)
			var b := _base(x, z)
			var d := track_dist[idx]
			var h := b
			if d < INF:
				var th := track_h[idx] - 0.34
				var w := clampf(1.8 + absf(th - b) * 1.6, 1.8, 9.0)
				var k := 1.0 if d < 1.9 else 1.0 - smoothstep(1.9, 1.9 + w, d)
				h = lerpf(b, th, k)
				gravel[idx] = 1.0 - smoothstep(2.3, 3.6, d)
			heights[idx] = h


func height_at(x: float, z: float) -> float:
	var fx := clampf(x + HALF, 0.0, RES - 1.001)
	var fz := clampf(z + HALF, 0.0, RES - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := lerpf(heights[iz * RES + ix], heights[iz * RES + ix + 1], tx)
	var b := lerpf(heights[(iz + 1) * RES + ix], heights[(iz + 1) * RES + ix + 1], tx)
	return lerpf(a, b, tz)


func dist_to_track(x: float, z: float) -> float:
	var ix := clampi(int(round(x)) + HALF, 0, RES - 1)
	var iz := clampi(int(round(z)) + HALF, 0, RES - 1)
	return track_dist[iz * RES + ix]


func _mesh() -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(RES * RES)
	norms.resize(RES * RES)
	cols.resize(RES * RES)
	for gz in RES:
		for gx in RES:
			var i := gz * RES + gx
			verts[i] = Vector3(gx - HALF, heights[i], gz - HALF)
			var hl := heights[gz * RES + maxi(gx - 1, 0)]
			var hr := heights[gz * RES + mini(gx + 1, RES - 1)]
			var hd := heights[maxi(gz - 1, 0) * RES + gx]
			var hu := heights[mini(gz + 1, RES - 1) * RES + gx]
			norms[i] = Vector3(hl - hr, 2.0, hd - hu).normalized()
			cols[i] = Color(gravel[i], 0, 0)
	for gz in RES - 1:
		for gx in RES - 1:
			var a := gz * RES + gx
			var b := a + 1
			var c := a + RES
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	for n in ["forest", "leaves", "gravel"]:
		mat.set_shader_parameter(n + "_diff", load("res://assets/textures/ground/%s_diff.jpg" % n))
		mat.set_shader_parameter(n + "_nor", load("res://assets/textures/ground/%s_nor.jpg" % n))
	mat.set_shader_parameter("forest_arm", load("res://assets/textures/ground/forest_arm.jpg"))
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	nt.noise = fn
	mat.set_shader_parameter("macro_noise", nt)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)


func _collision() -> void:
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 1
	body.set_meta("surface", "ground")
	var shape := HeightMapShape3D.new()
	shape.map_width = RES
	shape.map_depth = RES
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _mountains() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 180
	var rings := 22
	var mn := FastNoiseLite.new()
	mn.seed = 5
	mn.frequency = 0.0028
	mn.fractal_octaves = 5
	var grid := []
	for r in rings:
		var row := []
		var rad := lerpf(150.0, 1100.0, pow(float(r) / (rings - 1), 1.3))
		for s in seg:
			var a := TAU * s / seg
			var x := cos(a) * rad
			var z := sin(a) * rad
			var ridge := 1.0 - absf(mn.get_noise_2d(x, z))
			var hgt := pow(ridge, 1.7) * 360.0 * smoothstep(170.0, 520.0, rad) + mn.get_noise_2d(x * 1.5, z * 1.5) * 25.0 + 24.0
			if r == 0:
				hgt = 20.0
			row.append(Vector3(x, hgt, z))
		grid.append(row)
	for r in rings - 1:
		for s in seg:
			var s2 := (s + 1) % seg
			var a: Vector3 = grid[r][s]
			var b: Vector3 = grid[r][s2]
			var c: Vector3 = grid[r + 1][s]
			var d: Vector3 = grid[r + 1][s2]
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
			st.add_vertex(b); st.add_vertex(c); st.add_vertex(d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Mountains"
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/mountains.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- decor

static func collect_meshes(root: Node) -> Array:
	var out := []
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		out.append({"name": String(mi.name), "mesh": mi.mesh, "xform": _rel(root, mi)})
	return out


static func _rel(root: Node, n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


static func foliage_material(tex: Texture2D, sway_height: float, tint := Color(0.78, 0.84, 0.72)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/foliage.gdshader")
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("sway_height", sway_height)
	m.set_shader_parameter("tint", tint)
	return m


func _free_spot(x: float, z: float, min_track: float, avoid: Array) -> bool:
	if dist_to_track(x, z) < min_track:
		return false
	for a in avoid:
		if Vector2(x - a.x, z - a.y).length() < a.z:
			return false
	return true


func scatter(avoid: Array) -> void:
	tree_colliders = StaticBody3D.new()
	tree_colliders.name = "TreeColliders"
	tree_colliders.set_meta("surface", "wood")
	add_child(tree_colliders)
	var variants := ["fir_a", "fir_b", "fir_c"]
	var xforms := {"fir_a": [], "fir_b": [], "fir_c": []}
	var tries := 0
	var placed := 0
	while placed < 260 and tries < 6000:
		tries += 1
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 150.0
		var x := cos(ang) * r
		var z := sin(ang) * r
		var inner := r < 18.0
		var density := 1.0 if r > 42.0 else (0.25 if inner else 0.08)
		if rng.randf() > density or not _free_spot(x, z, 7.0, avoid):
			continue
		var v: String = variants[rng.randi() % 3]
		var sc := rng.randf_range(0.8, 1.25)
		var y := height_at(x, z) - 0.15
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, y, z))
		xforms[v].append(t)
		var cs := CollisionShape3D.new()
		var cap := CylinderShape3D.new()
		cap.radius = 0.35 * sc
		cap.height = 6.0
		cs.shape = cap
		cs.position = Vector3(x, y + 3.0, z)
		tree_colliders.add_child(cs)
		placed += 1
	var all_trees: Array = []
	for v in variants:
		_multimesh_from_glb("res://assets/models/trees/%s.glb" % v, xforms[v], true)
		all_trees.append_array(xforms[v])
	_tree_shadow_proxies(all_trees)
	# rocks with collision
	var rock_files := []
	for f in ResourceLoader.list_directory("res://assets/models/rocks"):
		if f.ends_with(".glb"):
			rock_files.append("res://assets/models/rocks/" + f)
	placed = 0
	tries = 0
	while placed < 46 and tries < 3000 and not rock_files.is_empty():
		tries += 1
		var ang := rng.randf() * TAU
		var r := rng.randf_range(12.0, 140.0)
		var x := cos(ang) * r
		var z := sin(ang) * r
		if not _free_spot(x, z, 6.0, avoid):
			continue
		var ps: PackedScene = load(rock_files[rng.randi() % rock_files.size()])
		var inst := ps.instantiate() as Node3D
		var body := StaticBody3D.new()
		body.set_meta("surface", "rock")
		add_child(body)
		body.add_child(inst)
		var sc := rng.randf_range(0.5, 1.3)
		body.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, height_at(x, z) - 0.25 * sc, z))
		for m in collect_meshes(inst):
			var cs := CollisionShape3D.new()
			cs.shape = (m.mesh as Mesh).create_convex_shape(true, true)
			cs.transform = m.xform
			body.add_child(cs)
		placed += 1
	# ferns, shrubs, dry branches, stumps: visual only
	_scatter_plants("res://assets/models/plants", ["fern_02"], 380, 4.0, 110.0, 3.5, avoid, 1.0)
	_scatter_plants("res://assets/models/plants", ["shrub_02"], 90, 8.0, 140.0, 5.0, avoid, 2.0)
	_scatter_plants("res://assets/models/plants", ["dry_branches"], 120, 3.0, 140.0, 3.2, avoid, 1.0)
	_scatter_plants("res://assets/models/plants", ["tree_stump"], 25, 10.0, 140.0, 6.0, avoid, 1.0)


func _tree_shadow_proxies(xforms: Array) -> void:
	if xforms.is_empty():
		return
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 2.6
	cone.height = 10.5
	cone.radial_segments = 8
	cone.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = xforms.size()
	for i in xforms.size():
		var t: Transform3D = xforms[i]
		mm.set_instance_transform(i, t * Transform3D(Basis.IDENTITY, Vector3(0, 7.8, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "TreeShadows"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(mmi)


func _scatter_plants(dir: String, prefixes: Array, count: int, rmin: float, rmax: float, min_track: float, avoid: Array, sway_h: float) -> void:
	var files := []
	for f in ResourceLoader.list_directory(dir):
		for p in prefixes:
			if f.begins_with(p) and f.ends_with(".glb"):
				files.append(dir + "/" + f)
	if files.is_empty():
		return
	var per := {}
	for f in files:
		per[f] = []
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 8:
		tries += 1
		var ang := rng.randf() * TAU
		var r := rng.randf_range(rmin, rmax)
		var x := cos(ang) * r
		var z := sin(ang) * r
		if not _free_spot(x, z, min_track, avoid):
			continue
		var f: String = files[rng.randi() % files.size()]
		var sc := rng.randf_range(0.75, 1.3)
		per[f].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, height_at(x, z) - 0.03, z)))
		placed += 1
	for f in files:
		_multimesh_from_glb(f, per[f], false, sway_h)


func _multimesh_from_glb(path: String, xforms: Array, is_tree: bool, sway_h := 1.0) -> void:
	if xforms.is_empty() or not ResourceLoader.exists(path):
		return
	var inst := (load(path) as PackedScene).instantiate()
	for m in collect_meshes(inst):
		var mesh: Mesh = m.mesh
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, (xforms[i] as Transform3D) * (m.xform as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var nm: String = m.name
		if is_tree and nm.begins_with("Foliage"):
			var tex_name := "fir_tip_card" if nm == "FoliageTip" else "fir_branch_card"
			mmi.material_override = foliage_material(load("res://assets/textures/trees/%s.png" % tex_name), 14.0)
			# alpha-tested cards in four shadow cascades were the single biggest frame cost; cones cast the shadow instead
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif not is_tree:
			var src := mesh.surface_get_material(0) as BaseMaterial3D
			if src and src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or (src and src.albedo_texture and path.contains("fern")):
				mmi.material_override = foliage_material(src.albedo_texture, sway_h, Color(0.9, 0.95, 0.85))
			if path.contains("fern") or path.contains("shrub"):
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 220.0 if is_tree else 48.0
		add_child(mmi)
	inst.free()
