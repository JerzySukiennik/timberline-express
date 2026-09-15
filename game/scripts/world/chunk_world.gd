# Endless terrain: 64 m chunks generated on worker threads around the player, LOD by ring, forest + mineable
# resources in near chunks, persistent removal of harvested resources, rail network and track visuals streamed along.
class_name ChunkWorld
extends Node3D

const SIZE := 64.0
const RINGS := [2, 4, 7]           # chunk rings for LOD 0 (1 m grid + resources), 1 (2 m), 2 (4 m)
const STEPS := [1, 2, 4]
const IMPOSTOR_H := {"fir_a": 19.26, "fir_b": 12.24, "fir_c": 21.74}
const VARIANTS := ["fir_a", "fir_b", "fir_c"]

var gen: WorldGen
var net: TrackNetwork
var tracks: InfiniteTracks
var focus: Node3D
var extra_focus: Array = []       # vehicles keep their rail regions generated
var removed := {}                 # "cx,cz" -> {"t12": true, "b1": true, ...}
var chunks := {}                  # Vector2i -> Chunk
var _pending := {}                # Vector2i -> {"lod", "task"}
var _results: Array = []
var _mutex := Mutex.new()
var _last_cell := Vector2i(999999, 999999)
var _track_timer := 0.0
var _ground_mat: ShaderMaterial
var _tree_meshes := {}            # variant -> ArrayMesh (trunk + foliage + tip surfaces)
var _impostor_mesh := {}          # variant -> QuadMesh cross
var _boulder_mesh: Mesh
var _boulder_shape: Shape3D
var _shrub_meshes: Array = []
var _fern_meshes: Array = []
var _rock_meshes: Array = []
var _rock_shapes: Array = []
var _horizon: MeshInstance3D
var _mushroom_mesh: Mesh
var _branch_mesh: Mesh
var _pebble_mesh: Mesh
var _berry_cluster: Mesh
var _water_mat: ShaderMaterial
var _horizon_center := Vector2(INF, INF)
var _tasks: Array[int] = []


func _exit_tree() -> void:
	for t in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_tasks.clear()


class Chunk:
	extends RefCounted
	var key := Vector2i.ZERO
	var lod := -1
	var root: Node3D
	var heights := PackedFloat32Array()
	var res := 65
	var step := 1
	var dist := PackedFloat32Array()
	var trees: Array = []        # [{xf, variant, idx}]
	var boulders: Array = []
	var bushes: Array = []
	var groups := {}
	var body: StaticBody3D


func setup(g: WorldGen, network: TrackNetwork) -> void:
	gen = g
	net = network
	tracks = InfiniteTracks.new(gen, net)
	_ground_mat = Terrain.ground_material()
	_prepare_assets()


func _prepare_assets() -> void:
	for v in VARIANTS:
		var inst := (load("res://assets/models/trees/%s.glb" % v) as PackedScene).instantiate()
		var parts := []
		for m in Terrain.collect_meshes(inst):
			var nm: String = m.name
			var mat: Material = null
			if nm.begins_with("Foliage"):
				mat = Terrain.foliage_material(load("res://assets/textures/trees/fir_branch_card.png"), 14.0, Color(0.74, 0.82, 0.66), true)
			parts.append({"mesh": m.mesh, "mat": mat})
		_tree_meshes[v] = parts
		inst.free()
		_impostor_mesh[v] = _make_impostor(v)
	var b := (load("res://assets/models/rocks/boulder/boulder_l0.glb") as PackedScene).instantiate()
	for m in Terrain.collect_meshes(b):
		_boulder_mesh = m.mesh
	b.free()
	var mats := MineRock.materials()
	var bm := _boulder_mesh.duplicate() as Mesh
	for si in bm.get_surface_count():
		var src := bm.surface_get_material(si)
		bm.surface_set_material(si, mats[1] if src and src.resource_name.contains("Inner") else mats[0])
	_boulder_mesh = bm
	_boulder_shape = _boulder_mesh.create_convex_shape(true, true)
	for m in Terrain.collect_meshes((load("res://assets/models/items/mushroom.glb") as PackedScene).instantiate()):
		_mushroom_mesh = m.mesh
	_berry_cluster = _make_berry_cluster()
	_branch_mesh = _merged_mesh("res://assets/models/items/stick.glb")
	for m in Terrain.collect_meshes((load("res://assets/models/items/stone.glb") as PackedScene).instantiate()):
		_pebble_mesh = m.mesh
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/water.gdshader")
	var wn := NoiseTexture2D.new()
	wn.width = 256
	wn.height = 256
	wn.seamless = true
	wn.as_normal_map = true
	wn.bump_strength = 6.0
	var wfn := FastNoiseLite.new()
	wfn.frequency = 0.03
	wn.noise = wfn
	_water_mat.set_shader_parameter("wave_noise", wn)
	for f in ["shrub_02_a", "shrub_02_b", "shrub_02_d"]:
		_shrub_meshes.append(_mesh_with_foliage("res://assets/models/plants/%s.glb" % f, 2.0))
	for f in ["fern_02_a", "fern_02_b", "fern_02_c", "fern_02_d"]:
		_fern_meshes.append(_mesh_with_foliage("res://assets/models/plants/%s.glb" % f, 1.0))
	for f in ResourceLoader.list_directory("res://assets/models/rocks"):
		if f.begins_with("rock_moss") and f.ends_with(".glb"):
			var r := (load("res://assets/models/rocks/" + f) as PackedScene).instantiate()
			for m in Terrain.collect_meshes(r):
				_rock_meshes.append(m.mesh)
				_rock_shapes.append((m.mesh as Mesh).create_convex_shape(true, true))
			r.free()


func _mesh_with_foliage(path: String, sway: float) -> ArrayMesh:
	var inst := (load(path) as PackedScene).instantiate()
	var am := ArrayMesh.new()
	for m in Terrain.collect_meshes(inst):
		var mesh: Mesh = m.mesh
		for si in mesh.get_surface_count():
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(si))
			var src := mesh.surface_get_material(si) as BaseMaterial3D
			var mat: Material = src
			if src and src.albedo_texture:
				mat = Terrain.foliage_material(src.albedo_texture, sway, Color(0.9, 0.95, 0.85))
			am.surface_set_material(am.get_surface_count() - 1, mat)
	inst.free()
	return am


func _make_impostor(v: String) -> ArrayMesh:
	var h: float = IMPOSTOR_H[v]
	var w := h * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var ax := Vector3.RIGHT if k == 0 else Vector3.BACK
		var quad := [ax * -w * 0.5, ax * w * 0.5, ax * w * 0.5 + Vector3.UP * h, ax * -w * 0.5 + Vector3.UP * h]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[idx])
			st.add_vertex(quad[idx])
	var mesh := st.commit()
	var mat := Terrain.foliage_material(load("res://assets/textures/trees/%s_impostor.png" % v), 14.0, Color(0.72, 0.78, 0.68))
	mat.set_shader_parameter("backlight", 0.1)
	mesh.surface_set_material(0, mat)
	return mesh


func _merged_mesh(path: String) -> Mesh:
	var inst := (load(path) as PackedScene).instantiate()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat: Material
	for m in Terrain.collect_meshes(inst):
		st.append_from(m.mesh, 0, m.xform)
		mat = (m.mesh as Mesh).surface_get_material(0)
	inst.free()
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


func _make_berry_cluster() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	sphere.radial_segments = 8
	sphere.rings = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 22:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.15, 0.55)
		st.append_from(sphere, 0, Transform3D(Basis.IDENTITY, Vector3(cos(a) * r, rng.randf_range(-0.25, 0.35), sin(a) * r)))
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.04, 0.1)
	mat.roughness = 0.3
	mesh.surface_set_material(0, mat)
	return mesh


func _add_pond(root: Node3D, pp: Dictionary, lod: int) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = float(pp.r) * 1.45
	disc.bottom_radius = float(pp.r) * 1.45
	disc.height = 0.01
	disc.radial_segments = 32
	disc.rings = 1
	disc.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = _water_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var pc: Vector2 = pp.c
	mi.global_position = Vector3(pc.x, pp.level, pc.y)
	if lod == 0:
		var wb := WaterBody.new()
		wb.level = pp.level
		wb.collision_layer = 64
		wb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = float(pp.r) * 1.1
		cyl.height = 0.6
		cs.shape = cyl
		wb.add_child(cs)
		root.add_child(wb)
		wb.global_position = Vector3(pc.x, pp.level - 0.3, pc.y)


## Water surface height under a point, or -INF when not in a pond.
func water_level_at(x: float, z: float) -> float:
	for pd in gen.ponds_near(x, z):
		var pp := gen.pond(pd)
		if pp.valid and Vector2(x, z).distance_to(pp.c) < float(pp.r) * 1.3 and height_at(x, z) < pp.level:
			return pp.level
	return -INF


# ---------------------------------------------------------------- queries (same API as Terrain)

func cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / SIZE), floori(pos.z / SIZE))


func height_at(x: float, z: float) -> float:
	var c: Chunk = chunks.get(Vector2i(floori(x / SIZE), floori(z / SIZE)))
	if c and not c.heights.is_empty():
		var fx := (x - c.key.x * SIZE) / c.step
		var fz := (z - c.key.y * SIZE) / c.step
		var ix := clampi(int(fx), 0, c.res - 2)
		var iz := clampi(int(fz), 0, c.res - 2)
		var tx := clampf(fx - ix, 0.0, 1.0)
		var tz := clampf(fz - iz, 0.0, 1.0)
		var a := lerpf(c.heights[iz * c.res + ix], c.heights[iz * c.res + ix + 1], tx)
		var b := lerpf(c.heights[(iz + 1) * c.res + ix], c.heights[(iz + 1) * c.res + ix + 1], tx)
		return lerpf(a, b, tz)
	var near := net.nearest(x, z, 14.0)
	return shaped(gen.base_height(x, z), near.w, near.y)


## Height and rail distance from loaded chunk arrays only (fast, used for dense grass). Falls back to height_at.
func sample_fast(x: float, z: float) -> Vector2:
	var c: Chunk = chunks.get(Vector2i(floori(x / SIZE), floori(z / SIZE)))
	if c == null or c.heights.is_empty():
		return Vector2(height_at(x, z), INF)
	var fx := (x - c.key.x * SIZE) / c.step
	var fz := (z - c.key.y * SIZE) / c.step
	var ix := clampi(int(fx), 0, c.res - 2)
	var iz := clampi(int(fz), 0, c.res - 2)
	var tx := clampf(fx - ix, 0.0, 1.0)
	var tz := clampf(fz - iz, 0.0, 1.0)
	var a := lerpf(c.heights[iz * c.res + ix], c.heights[iz * c.res + ix + 1], tx)
	var b := lerpf(c.heights[(iz + 1) * c.res + ix], c.heights[(iz + 1) * c.res + ix + 1], tx)
	var di := clampi(int(round(fz)), 0, c.res - 1) * c.res + clampi(int(round(fx)), 0, c.res - 1)
	return Vector2(lerpf(a, b, tz), c.dist[di])


func ponds_for(center: Vector2, _radius: float) -> Array:
	var out := []
	for pd in gen.ponds_near(center.x, center.y):
		var pp := gen.pond(pd)
		if pp.valid:
			out.append(pp)
	return out


func dist_to_track(x: float, z: float) -> float:
	return net.nearest(x, z, 6.0).w


static func shaped(base: float, d: float, track_y: float) -> float:
	if d == INF:
		return base
	var th := track_y - 0.34
	var w := clampf(2.0 + absf(th - base) * 1.4, 2.0, 45.0)
	var k := 1.0 if d < 2.0 else 1.0 - smoothstep(2.0, 2.0 + w, d)
	return lerpf(base, th, k)


# ---------------------------------------------------------------- streaming

func _process(dt: float) -> void:
	if focus == null:
		return
	_track_timer -= dt
	if _track_timer <= 0.0:
		_track_timer = 0.5
		_update_tracks()
	var c := cell(focus.global_position)
	if c != _last_cell:
		_last_cell = c
		_schedule(c)
		_update_horizon()
	_integrate_results()


func _update_tracks() -> void:
	var points: Array = [focus.global_position]
	for v in extra_focus:
		if is_instance_valid(v):
			points.append((v as Node3D).global_position)
	for p in points:
		tracks.ensure(p, 1)
	var fp := focus.global_position
	for seg in net.segments:
		var a := seg.point(0.0)
		var b := seg.point(seg.length * 0.5)
		var e := seg.point(seg.length)
		var d := minf(minf(Vector2(a.x - fp.x, a.z - fp.z).length(), Vector2(b.x - fp.x, b.z - fp.z).length()), Vector2(e.x - fp.x, e.z - fp.z).length())
		var near := d < seg.length * 0.5 + 520.0
		if near and seg.visual == null:
			net.build_segment_visual(seg)
		elif not near and seg.visual != null and d > seg.length * 0.5 + 900.0:
			seg.visual.queue_free()
			seg.visual = null


func _want_lod(c: Vector2i, center: Vector2i) -> int:
	var r := maxi(absi(c.x - center.x), absi(c.y - center.y))
	for i in RINGS.size():
		if r <= RINGS[i]:
			return i
	return -1


func _schedule(center: Vector2i) -> void:
	var outer: int = RINGS[RINGS.size() - 1]
	var want := {}
	for dz in range(-outer, outer + 1):
		for dx in range(-outer, outer + 1):
			var k := center + Vector2i(dx, dz)
			want[k] = _want_lod(k, center)
	for k in chunks.keys():
		if not want.has(k):
			var ch: Chunk = chunks[k]
			if ch.root:
				ch.root.queue_free()
			chunks.erase(k)
	var order := want.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - center).length_squared() < (b - center).length_squared())
	for k in order:
		var lod: int = want[k]
		var ch: Chunk = chunks.get(k)
		if ch and ch.lod == lod:
			continue
		if _pending.has(k) and _pending[k].lod == lod:
			continue
		var rect := Rect2(k.x * SIZE - 60.0, k.y * SIZE - 60.0, SIZE + 120.0, SIZE + 120.0)
		var job := {"key": k, "lod": lod, "samples": net.samples_in_rect(rect), "removed": (removed.get("%d,%d" % [k.x, k.y], {}) as Dictionary).duplicate()}
		_pending[k] = {"lod": lod}
		_tasks.append(WorkerThreadPool.add_task(_build_job.bind(job), false, "chunk"))


func _build_job(job: Dictionary) -> void:
	var data := _generate(job)
	_mutex.lock()
	_results.append(data)
	_mutex.unlock()


func _prune_tasks() -> void:
	var keep: Array[int] = []
	for t in _tasks:
		if WorkerThreadPool.is_task_completed(t):
			WorkerThreadPool.wait_for_task_completion(t)
		else:
			keep.append(t)
	_tasks = keep


func _integrate_results() -> void:
	_prune_tasks()
	_mutex.lock()
	var batch := _results
	_results = []
	_mutex.unlock()
	var budget := 3
	var leftover: Array = []
	var center := _last_cell
	batch.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.key - center).length_squared() < (b.key - center).length_squared())
	for data in batch:
		if budget <= 0:
			leftover.append(data)
			continue
		var k: Vector2i = data.key
		if not _pending.has(k) or _pending[k].lod != data.lod:
			continue
		_pending.erase(k)
		if _want_lod(k, center) != data.lod:
			continue
		_instantiate(data)
		budget -= 1
	if not leftover.is_empty():
		_mutex.lock()
		_results.append_array(leftover)
		_mutex.unlock()


func pending_count() -> int:
	return _pending.size()


# ---------------------------------------------------------------- generation (worker thread)

func _generate(job: Dictionary) -> Dictionary:
	var k: Vector2i = job.key
	var lod: int = job.lod
	var step: int = STEPS[lod]
	var res := int(SIZE / step) + 1
	var ox := k.x * SIZE
	var oz := k.y * SIZE
	var samples: PackedVector3Array = job.samples
	var n := res * res
	# exact distance/height near the rails (every 2nd sample, 14 m) ...
	var dist := PackedFloat32Array()
	var th := PackedFloat32Array()
	dist.resize(n)
	th.resize(n)
	dist.fill(INF)
	var reach := int(ceil(14.0 / step))
	var si := 0
	for p in samples:
		si += 1
		if si % 2 == 0:
			continue
		var cx := int(round((p.x - ox) / step))
		var cz := int(round((p.z - oz) / step))
		if cx < -reach - 1 or cz < -reach - 1 or cx > res + reach or cz > res + reach:
			continue
		for dz in range(-reach, reach + 1):
			var gz := cz + dz
			if gz < 0 or gz >= res:
				continue
			for dx in range(-reach, reach + 1):
				var gx := cx + dx
				if gx < 0 or gx >= res:
					continue
				var d := Vector2(ox + gx * step - p.x, oz + gz * step - p.z).length()
				var idx := gz * res + gx
				if d < dist[idx]:
					dist[idx] = d
					th[idx] = p.y
	# ... and a coarse 4 m field out to 44 m for wide cuttings and embankments
	var cres := 17 + 2
	var cdist := PackedFloat32Array()
	var cth := PackedFloat32Array()
	cdist.resize(cres * cres)
	cth.resize(cres * cres)
	cdist.fill(INF)
	si = 0
	for p in samples:
		si += 1
		if si % 8 != 0:
			continue
		var ccx := int(round((p.x - ox) / 4.0)) + 1
		var ccz := int(round((p.z - oz) / 4.0)) + 1
		if ccx < -12 or ccz < -12 or ccx > cres + 11 or ccz > cres + 11:
			continue
		for dz in range(-11, 12):
			var gz2 := ccz + dz
			if gz2 < 0 or gz2 >= cres:
				continue
			for dx in range(-11, 12):
				var gx2 := ccx + dx
				if gx2 < 0 or gx2 >= cres:
					continue
				var d2 := Vector2(ox + (gx2 - 1) * 4.0 - p.x, oz + (gz2 - 1) * 4.0 - p.z).length()
				var ci := gz2 * cres + gx2
				if d2 < cdist[ci]:
					cdist[ci] = d2
					cth[ci] = p.y
	var ponds := []
	for pd in gen.ponds_near(ox + SIZE * 0.5, oz + SIZE * 0.5):
		var pp := gen.pond(pd)
		if not pp.valid:
			continue
		var pc: Vector2 = pp.c
		if pc.x + pp.r * 1.6 < ox or pc.x - pp.r * 1.6 > ox + SIZE or pc.y + pp.r * 1.6 < oz or pc.y - pp.r * 1.6 > oz + SIZE:
			continue
		ponds.append(pp)
	var heights := PackedFloat32Array()
	heights.resize(n)
	var cols := PackedColorArray()
	cols.resize(n)
	for gz in res:
		for gx in res:
			var idx := gz * res + gx
			var x := ox + gx * step
			var z := oz + gz * step
			var base := gen.base_height(x, z)
			if not ponds.is_empty():
				base = gen.carve_ponds(x, z, base, ponds)
			var d := dist[idx]
			var ty := th[idx]
			if d == INF:
				var ci2 := int(round(float(gz * step) / 4.0) + 1) * cres + int(round(float(gx * step) / 4.0)) + 1
				d = cdist[ci2]
				ty = cth[ci2]
				dist[idx] = maxf(d, 14.0) if d < INF else INF
			heights[idx] = shaped(base, d, ty)
			cols[idx] = Color(1.0 - smoothstep(2.3, 3.6, d) if d < INF else 0.0, 0, 0)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(n)
	norms.resize(n)
	for gz in res:
		for gx in res:
			var idx := gz * res + gx
			verts[idx] = Vector3(gx * step, heights[idx], gz * step)
			var hl := heights[gz * res + maxi(gx - 1, 0)]
			var hr := heights[gz * res + mini(gx + 1, res - 1)]
			var hd := heights[maxi(gz - 1, 0) * res + gx]
			var hu := heights[mini(gz + 1, res - 1) * res + gx]
			norms[idx] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
	var indices := PackedInt32Array()
	indices.resize((res - 1) * (res - 1) * 6)
	var w := 0
	for gz in res - 1:
		for gx in res - 1:
			var a := gz * res + gx
			indices[w] = a; indices[w + 1] = a + 1; indices[w + 2] = a + res
			indices[w + 3] = a + 1; indices[w + 4] = a + res + 1; indices[w + 5] = a + res
			w += 6
	var out := {"ponds": ponds, "key": k, "lod": lod, "step": step, "res": res, "heights": heights, "dist": dist, "verts": verts, "norms": norms, "cols": cols, "indices": indices}
	_generate_decor(out, job)
	return out


func _hsample(out: Dictionary, lx: float, lz: float) -> float:
	var step: int = out.step
	var res: int = out.res
	var heights: PackedFloat32Array = out.heights
	var fx := clampf(lx / step, 0.0, res - 1.001)
	var fz := clampf(lz / step, 0.0, res - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var a := lerpf(heights[iz * res + ix], heights[iz * res + ix + 1], fx - ix)
	var b := lerpf(heights[(iz + 1) * res + ix], heights[(iz + 1) * res + ix + 1], fx - ix)
	return lerpf(a, b, fz - iz)


func _dsample(out: Dictionary, lx: float, lz: float) -> float:
	var step: int = out.step
	var res: int = out.res
	var ix := clampi(int(round(lx / step)), 0, res - 1)
	var iz := clampi(int(round(lz / step)), 0, res - 1)
	return (out.dist as PackedFloat32Array)[iz * res + ix]


func _generate_decor(out: Dictionary, job: Dictionary) -> void:
	var k: Vector2i = job.key
	var lod: int = job.lod
	var removed_here: Dictionary = job.removed
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(k.x, k.y, gen.seed))
	var ox := k.x * SIZE
	var oz := k.y * SIZE
	var trees := {"fir_a": PackedFloat32Array(), "fir_b": PackedFloat32Array(), "fir_c": PackedFloat32Array()}
	var tree_list: Array = []
	var shadow := PackedFloat32Array()
	var boulders: Array = []
	var bushes: Array = []
	var rocks: Array = []
	var ferns: Array = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	var shrubs: Array = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	# candidate grid keeps generation identical across LODs (ids stay stable)
	var idx := 0
	for gz in 8:
		for gx in 8:
			for rep in 2:
				idx += 1
				var lx := (gx + rng.randf()) * 8.0
				var lz := (gz + rng.randf()) * 8.0
				var roll := rng.randf()
				var yaw := rng.randf() * TAU
				var scl := rng.randf_range(0.75, 1.3)
				var vr := rng.randi() % 3
				var x := ox + lx
				var z := oz + lz
				var h := _hsample(out, lx, lz)
				var d := _dsample(out, lx, lz)
				var dens := gen.forest_density(x, z, h)
				var steep := absf(_hsample(out, minf(lx + 2.0, SIZE), lz) - _hsample(out, maxf(lx - 2.0, 0.0), lz)) / 4.0
				if d < 7.5 or steep > 0.9 or _in_pond(out.ponds, x, z, 1.3):
					continue
				var id := "t%d" % idx
				if roll < dens * 0.62:
					if removed_here.has(id):
						continue
					var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scl), Vector3(x, h - 0.15, z))
					var v: String = VARIANTS[vr]
					_append_xf(trees[v], xf)
					_append_xf(shadow, xf * Transform3D(Basis.IDENTITY, Vector3(0, 7.8, 0)))
					tree_list.append({"xf": xf, "variant": v, "id": id, "scale": scl})
				elif roll > 0.978 and lod == 0:
					var bid := "b%d" % idx
					if not removed_here.has(bid):
						var ore_roll := gen.hash2(k.x * 131 + idx, k.y * 7, 17)
						var ore := "iron_ore" if ore_roll < 0.3 else ("copper_ore" if ore_roll < 0.42 else ("coal" if ore_roll < 0.55 else ""))
						boulders.append({"xf": Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.7, 1.05)), Vector3(x, h - 0.2, z)), "id": bid, "ore": ore})
				elif roll > 0.965 and roll <= 0.985 and lod <= 1:
					rocks.append({"xf": Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.4, 1.1)), Vector3(x, h - 0.3, z)), "i": vr})
				elif roll > 0.9 and roll <= 0.965 and lod == 0 and d > 4.0:
					var sid := "s%d" % idx
					if not removed_here.has(sid):
						var sxf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.8, 1.1)), Vector3(x, h - 0.05, z))
						var berry := gen.hash2(k.x * 97 + idx, k.y, 91) < 0.45 and not removed_here.has("p" + sid)
						bushes.append({"xf": sxf, "id": sid, "i": vr, "berry": berry})
						_append_xf(shrubs[vr], sxf)
	if lod == 0:
		for f in 36:
			var lx2 := rng.randf() * SIZE
			var lz2 := rng.randf() * SIZE
			var fi := rng.randi() % 4
			var yaw2 := rng.randf() * TAU
			var sc2 := rng.randf_range(0.7, 1.3)
			if _dsample(out, lx2, lz2) < 3.5:
				continue
			_append_xf(ferns[fi], Transform3D(Basis(Vector3.UP, yaw2).scaled(Vector3.ONE * sc2), Vector3(ox + lx2, _hsample(out, lx2, lz2) - 0.03, oz + lz2)))
	var mushrooms: Array = []
	if lod == 0:
		for mi in 4:
			if rng.randf() > 0.55 or tree_list.is_empty():
				continue
			var tt: Dictionary = tree_list[rng.randi() % tree_list.size()]
			var mid := "m%d" % mi
			var ang := rng.randf() * TAU
			var mp: Vector3 = (tt.xf as Transform3D).origin + Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.8, 1.8)
			if removed_here.has(mid):
				continue
			mp.y = _hsample(out, mp.x - ox, mp.z - oz)
			mushrooms.append({"xf": Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * rng.randf_range(0.9, 1.4)), mp), "id": mid})
	out["mushrooms"] = mushrooms
	var ground: Array = []
	if lod == 0:
		for gi in 7:
			var gx2 := rng.randf() * SIZE
			var gz2 := rng.randf() * SIZE
			var kind := "branch" if rng.randf() < 0.55 else "pebble"
			var gid := "g%d" % gi
			if removed_here.has(gid) or _dsample(out, gx2, gz2) < 3.0 or _in_pond(out.ponds, ox + gx2, oz + gz2, 1.2):
				continue
			ground.append({"xf": Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(ox + gx2, _hsample(out, gx2, gz2), oz + gz2)), "id": gid, "kind": kind})
	out["ground"] = ground
	var grass := PackedFloat32Array()
	if lod == 0:
		for gz3 in 64:
			for gx3 in 64:
				var lx3 := gx3 + rng.randf()
				var lz3 := gz3 + rng.randf()
				var r3 := rng.randf()
				var yaw3 := rng.randf() * TAU
				var d3 := _dsample(out, lx3, lz3)
				if d3 < 2.8 or _in_pond(out.ponds, ox + lx3, oz + lz3, 1.05):
					continue
				var h3 := _hsample(out, lx3, lz3)
				var dens3 := gen.forest_density(ox + lx3, oz + lz3, h3)
				# thinner under dense canopy, lush in clearings
				if r3 > 0.95 - dens3 * 0.55:
					continue
				var sc3 := rng.randf_range(0.7, 1.35) * (1.15 - dens3 * 0.4)
				_append_xf(grass, Transform3D(Basis(Vector3.UP, yaw3).scaled(Vector3(sc3, sc3, sc3)), Vector3(ox + lx3, h3 - 0.02, oz + lz3)))
	out["grass"] = grass
	out["trees"] = trees
	out["tree_list"] = tree_list
	out["shadow"] = shadow
	out["boulders"] = boulders
	out["bushes"] = bushes
	out["rocks"] = rocks
	out["ferns"] = ferns
	out["shrubs"] = shrubs


func _in_pond(ponds: Array, x: float, z: float, margin: float) -> bool:
	for p in ponds:
		if Vector2(x, z).distance_to(p.c) < float(p.r) * margin:
			return true
	return false


static func _append_xf(buf: PackedFloat32Array, t: Transform3D) -> void:
	var b := t.basis
	buf.append_array([b.x.x, b.y.x, b.z.x, t.origin.x, b.x.y, b.y.y, b.z.y, t.origin.y, b.x.z, b.y.z, b.z.z, t.origin.z])


# ---------------------------------------------------------------- instantiate (main thread)

func _instantiate(data: Dictionary) -> void:
	var k: Vector2i = data.key
	var old: Chunk = chunks.get(k)
	if old and old.root:
		old.root.queue_free()
	var ch := Chunk.new()
	ch.key = k
	ch.lod = data.lod
	ch.step = data.step
	ch.res = data.res
	ch.heights = data.heights
	ch.dist = data.dist
	var root := Node3D.new()
	root.name = "C%d_%d" % [k.x, k.y]
	add_child(root)
	root.position = Vector3(k.x * SIZE, 0, k.y * SIZE)
	ch.root = root
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = data.verts
	arr[Mesh.ARRAY_NORMAL] = data.norms
	arr[Mesh.ARRAY_COLOR] = data.cols
	arr[Mesh.ARRAY_INDEX] = data.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _ground_mat
	root.add_child(mi)
	var lod: int = data.lod
	if lod == 0:
		var body := StaticBody3D.new()
		body.set_meta("surface", "ground")
		var hs := HeightMapShape3D.new()
		hs.map_width = ch.res
		hs.map_depth = ch.res
		hs.map_data = ch.heights
		var cs := CollisionShape3D.new()
		cs.shape = hs
		cs.scale = Vector3(ch.step, 1.0, ch.step)
		cs.position = Vector3(SIZE * 0.5, 0, SIZE * 0.5)
		body.add_child(cs)
		root.add_child(body)
	# forest
	var abs_origin := Transform3D(Basis.IDENTITY, -root.position)
	for v in VARIANTS:
		var buf: PackedFloat32Array = data.trees[v]
		if buf.is_empty():
			continue
		if lod == 0:
			for part in _tree_meshes[v]:
				var tm := _add_mmi(root, part.mesh, buf, abs_origin, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				if part.mat:
					tm.material_override = part.mat
				tm.visibility_range_end = 105.0
				tm.visibility_range_end_margin = 12.0
				tm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				tm.set_meta("kind", "trees")
			var near_imp := _add_mmi(root, _impostor_mesh[v], buf, abs_origin, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			near_imp.visibility_range_begin = 105.0
			near_imp.visibility_range_begin_margin = 12.0
			near_imp.set_meta("kind", "trees")
		else:
			_add_mmi(root, _impostor_mesh[v], buf, abs_origin, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF).set_meta("kind", "trees")
	if lod <= 1 and not (data.shadow as PackedFloat32Array).is_empty():
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 2.6
		cone.height = 10.5
		cone.radial_segments = 6
		cone.rings = 1
		_add_mmi(root, cone, data.shadow, abs_origin, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY).set_meta("kind", "tree_shadows")
	if lod == 0 and not (data.grass as PackedFloat32Array).is_empty():
		var gm := _add_mmi(root, Terrain.grass_clump(), data.grass, abs_origin, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		gm.set_meta("kind", "chunk_grass")
		gm.visibility_range_end = 75.0
	if lod == 0:
		for i in 4:
			if not (data.ferns[i] as PackedFloat32Array).is_empty():
				var fm := _add_mmi(root, _fern_meshes[i], data.ferns[i], abs_origin, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				fm.set_meta("kind", "ferns")
				fm.visibility_range_end = 60.0
		for i in 3:
			if not (data.shrubs[i] as PackedFloat32Array).is_empty():
				_add_mmi(root, _shrub_meshes[i], data.shrubs[i], abs_origin, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF).set_meta("kind", "ferns")
		_build_resources(ch, data, root)
	for pp in data.ponds:
		var pc: Vector2 = pp.c
		if floori(pc.x / SIZE) == k.x and floori(pc.y / SIZE) == k.y:
			_add_pond(root, pp, lod)
	# decorative rocks: one multimesh per rock mesh, collision shapes on a single body
	if not _rock_meshes.is_empty() and not (data.rocks as Array).is_empty():
		var by_mesh := {}
		var rbody: StaticBody3D = null
		if lod == 0:
			rbody = StaticBody3D.new()
			rbody.set_meta("surface", "rock")
			root.add_child(rbody)
			rbody.global_transform = Transform3D.IDENTITY
		for r in data.rocks:
			var ri: int = int(r.i) % _rock_meshes.size()
			if not by_mesh.has(ri):
				by_mesh[ri] = PackedFloat32Array()
			_append_xf(by_mesh[ri], r.xf)
			if rbody:
				var rcs := CollisionShape3D.new()
				rcs.shape = _rock_shapes[ri]
				rcs.transform = r.xf
				rbody.add_child(rcs)
		for ri in by_mesh:
			var rm := _add_mmi(root, _rock_meshes[ri], by_mesh[ri], abs_origin, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
			rm.material_override = MineRock.moss_material()
	chunks[k] = ch


func _add_mmi(root: Node3D, mesh: Mesh, buf: PackedFloat32Array, local: Transform3D, shadow: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var count := buf.size() / 12
	mm.instance_count = count
	var local_buf := buf.duplicate()
	for i in count:
		local_buf[i * 12 + 3] += local.origin.x
		local_buf[i * 12 + 7] += local.origin.y
		local_buf[i * 12 + 11] += local.origin.z
	mm.buffer = local_buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = shadow
	root.add_child(mmi)
	return mmi


# ---------------------------------------------------------------- resources

func _build_resources(ch: Chunk, data: Dictionary, root: Node3D) -> void:
	var body := ResourceBody.new()
	body.world = self
	body.chunk = ch
	body.collision_layer = 1 | 32
	body.set_meta("surface", "wood")
	root.add_child(body)
	body.global_transform = Transform3D.IDENTITY
	ch.body = body
	for t in data.tree_list:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.32 * float(t.scale)
		cyl.height = 7.0
		cs.shape = cyl
		cs.position = (t.xf as Transform3D).origin + Vector3(0, 3.5, 0)
		body.add_child(cs)
		body.owners[body.get_shape_owners()[body.get_shape_owners().size() - 1]] = {"kind": "tree", "data": t}
		ch.trees.append(t)
	var groups := {}
	for b in data.boulders:
		var ore_key := "boulder:" + str(b.get("ore", ""))
		var cs := CollisionShape3D.new()
		cs.shape = _boulder_shape
		cs.transform = b.xf
		body.add_child(cs)
		body.owners[body.get_shape_owners()[body.get_shape_owners().size() - 1]] = {"kind": "boulder", "data": b, "slot": _group_add(groups, ore_key, b.xf)}
	for g in data.ground:
		var gslot := _group_add(groups, str(g.kind), (g.xf as Transform3D) * Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)))
		var gcs := CollisionShape3D.new()
		var gsp := SphereShape3D.new()
		gsp.radius = 0.25
		gcs.shape = gsp
		gcs.position = (g.xf as Transform3D).origin + Vector3(0, 0.1, 0)
		body.add_child(gcs)
		body.owners[body.get_shape_owners()[body.get_shape_owners().size() - 1]] = {"kind": g.kind, "data": g, "slot": gslot}
	for m in data.mushrooms:
		var mslot := _group_add(groups, "mushroom", m.xf)
		var mcs := CollisionShape3D.new()
		var msp := SphereShape3D.new()
		msp.radius = 0.18
		mcs.shape = msp
		mcs.position = (m.xf as Transform3D).origin + Vector3(0, 0.05, 0)
		body.add_child(mcs)
		body.owners[body.get_shape_owners()[body.get_shape_owners().size() - 1]] = {"kind": "mushroom", "data": m, "slot": mslot}
	for s in data.bushes:
		if s.berry:
			s["slot"] = _group_add(groups, "berries", (s.xf as Transform3D) * Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)))
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 0.7
		cs.shape = sp
		cs.position = (s.xf as Transform3D).origin + Vector3(0, 0.6, 0)
		cs.disabled = false
		body.add_child(cs)
		body.owners[body.get_shape_owners()[body.get_shape_owners().size() - 1]] = {"kind": "bush", "data": s}
	_groups_build(ch, root, groups)


func _group_add(groups: Dictionary, key: String, xf: Transform3D) -> Array:
	if not groups.has(key):
		groups[key] = []
	(groups[key] as Array).append(xf)
	return [key, (groups[key] as Array).size() - 1]


func _groups_build(ch: Chunk, root: Node3D, groups: Dictionary) -> void:
	var local := Transform3D(Basis.IDENTITY, -root.position)
	for key in groups:
		var mesh: Mesh = _boulder_mesh
		var mat: Material = null
		match str(key).get_slice(":", 0):
			"boulder":
				var ore := str(key).get_slice(":", 1)
				if ore != "":
					mat = MineRock.ore_material(ore)
			"branch":
				mesh = _branch_mesh
			"pebble":
				mesh = _pebble_mesh
			"mushroom":
				mesh = _mushroom_mesh
			"berries":
				mesh = _berry_cluster
		var buf := PackedFloat32Array()
		for xf in groups[key]:
			_append_xf(buf, xf)
		var mmi := _add_mmi(root, mesh, buf, local, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		if mat:
			mmi.material_override = mat
		ch.groups[key] = mmi


## Hides one instance of a grouped multimesh immediately (the chunk rebuild removes it for good).
func hide_slot(ch: Chunk, slot: Array) -> void:
	if slot.is_empty() or not ch.groups.has(slot[0]):
		return
	var mmi: MultiMeshInstance3D = ch.groups[slot[0]]
	if is_instance_valid(mmi):
		mmi.multimesh.set_instance_transform(int(slot[1]), Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3(0, -1000, 0)))


## Marks a resource harvested (persistent) and rebuilds the chunk without it.
func harvest(ch: Chunk, id: String) -> void:
	var key := "%d,%d" % [ch.key.x, ch.key.y]
	if not removed.has(key):
		removed[key] = {}
	removed[key][id] = true
	# rebuild quickly at the same LOD
	var rect := Rect2(ch.key.x * SIZE - 60.0, ch.key.y * SIZE - 60.0, SIZE + 120.0, SIZE + 120.0)
	var job := {"key": ch.key, "lod": ch.lod, "samples": net.samples_in_rect(rect), "removed": (removed[key] as Dictionary).duplicate()}
	_pending[ch.key] = {"lod": ch.lod}
	_tasks.append(WorkerThreadPool.add_task(_build_job.bind(job), false, "chunk rebuild"))


# ---------------------------------------------------------------- horizon

func _update_horizon() -> void:
	var p := Vector2(focus.global_position.x, focus.global_position.z)
	if p.distance_to(_horizon_center) < 320.0:
		return
	_horizon_center = p.snapped(Vector2(64, 64))
	var inner: float = SIZE * (RINGS[RINGS.size() - 1] + 0.5)
	var center := _horizon_center
	var ht := WorkerThreadPool.add_task(func() -> void:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var seg := 256
		var rings := 40
		var grid := []
		for r in rings:
			var row := []
			var rad := lerpf(inner, 2600.0, pow(float(r) / (rings - 1), 1.6))
			for s in seg:
				var a := TAU * s / seg
				var x := center.x + cos(a) * rad
				var z := center.y + sin(a) * rad
				row.append(Vector3(x, gen.base_height(x, z) - (2.5 if r == 0 else 0.0), z))
			grid.append(row)
		for r in rings:
			for s in seg:
				st.add_vertex(grid[r][s])
		for r in rings - 1:
			for s in seg:
				var s2 := (s + 1) % seg
				var a := r * seg + s
				var b := r * seg + s2
				var c := (r + 1) * seg + s
				var d := (r + 1) * seg + s2
				st.add_index(a); st.add_index(c); st.add_index(b)
				st.add_index(b); st.add_index(c); st.add_index(d)
		st.generate_normals()
		var mesh := st.commit()
		_set_horizon.call_deferred(mesh), false, "horizon")
	_tasks.append(ht)


func _set_horizon(mesh: ArrayMesh) -> void:
	if _horizon == null:
		_horizon = MeshInstance3D.new()
		_horizon.name = "Horizon"
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/mountains.gdshader")
		mat.set_shader_parameter("rock_tex", load("res://assets/textures/ground/rockface_diff.jpg"))
		mat.set_shader_parameter("grass_tex", load("res://assets/textures/ground/grass_diff.jpg"))
		_horizon.material_override = mat
		_horizon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_horizon)
	_horizon.mesh = mesh
