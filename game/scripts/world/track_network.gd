# Track graph (segments joined at nodes, switch nodes route traffic), layout generation and rail/sleeper/ballast meshes.
class_name TrackNetwork
extends Node3D

signal switch_changed(node: TrackNode)

const GAUGE := 1.435
const RAIL_H := 0.16
const LOOP_R := 28.6
const LOOP_HALF := 55.0
const SIDING_OFFSET := 4.5
const TURNOUT_LEN := 22.0
const STUB_LEN := 9.0
const SWITCH_X := [-45.0, -12.0, 21.0]
const HILL_H := 3.2


class TrackSegment:
	extends RefCounted
	var id := 0
	var curve: Curve3D
	var length := 0.0
	var nodes: Array = [null, null]   # TrackNode at s=0 and s=length
	var lateral := 0.0                # >0 for sidings: ballast drawn slightly lower
	var visual: Node3D

	func point(s: float) -> Vector3:
		return curve.sample_baked(clampf(s, 0.0, length), false)

	func tangent(s: float) -> Vector3:
		var a := point(s - 0.4)
		var b := point(s + 0.4)
		var t := b - a
		return t.normalized() if t.length() > 0.0001 else Vector3.RIGHT


class TrackNode:
	extends RefCounted
	var id := 0
	var pos := Vector3.ZERO
	var links: Array = []     # [{seg, end}] ; for switches links[0] is the trunk
	var is_switch := false
	var state := 0            # 0 -> links[1], 1 -> links[2]
	var name := ""

	func link_index(seg: TrackSegment, end: int) -> int:
		for i in links.size():
			if not links[i].is_empty() and links[i].seg == seg and links[i].end == end:
				return i
		return -1


## A position on the network plus which way "vehicle forward" points along the segment.
class Cursor:
	extends RefCounted
	var net: TrackNetwork
	var seg: TrackSegment
	var s := 0.0
	var flip := false   # true: vehicle forward points toward s=0

	func copy() -> Cursor:
		var c := Cursor.new()
		c.net = net; c.seg = seg; c.s = s; c.flip = flip
		return c

	func position() -> Vector3:
		return seg.point(s)

	func forward() -> Vector3:
		return -seg.tangent(s) if flip else seg.tangent(s)

	## Moves along the vehicle's forward axis. Returns the distance that could NOT be travelled (dead end).
	func move(d: float, spring_switches := true) -> float:
		var guard := 0
		var dir := (-1.0 if flip else 1.0) * signf(d)
		var left := absf(d)
		while left > 0.000001 and guard < 64:
			guard += 1
			var room := (seg.length - s) if dir > 0 else s
			if left <= room:
				s += dir * left
				return 0.0
			left -= room
			var end := 1 if dir > 0 else 0
			s = seg.length if end == 1 else 0.0
			var next := net.route(seg, end, spring_switches)
			if next.is_empty():
				return left * signf(d)
			seg = next.seg
			var new_dir := 1.0 if int(next.end) == 0 else -1.0
			s = 0.0 if int(next.end) == 0 else seg.length
			flip = signf(d) != new_dir
			dir = new_dir
		return 0.0


var segments: Array[TrackSegment] = []
var nodes: Array[TrackNode] = []
var switches: Array[TrackNode] = []
var dead_ends: Array[Dictionary] = []   # {node, seg, end}
var sidings: Array[TrackSegment] = []
var samples := PackedVector3Array()     # dense centerline samples for terrain shaping and surface queries
var _grid := {}

var rail_material: StandardMaterial3D
var sleeper_material: StandardMaterial3D
var ballast_material: StandardMaterial3D


func _new_node(pos: Vector3) -> TrackNode:
	var n := TrackNode.new()
	n.id = nodes.size()
	n.pos = pos
	nodes.append(n)
	return n


func _new_segment(points: PackedVector3Array, a: TrackNode, b: TrackNode) -> TrackSegment:
	var seg := TrackSegment.new()
	seg.id = segments.size()
	seg.curve = Curve3D.new()
	seg.curve.bake_interval = 0.2
	for p in points:
		seg.curve.add_point(p)
	seg.length = seg.curve.get_baked_length()
	seg.nodes = [a, b]
	a.links.append({"seg": seg, "end": 0})
	b.links.append({"seg": seg, "end": 1})
	segments.append(seg)
	return seg


## Routing at a node when leaving `seg` through `end`. Trailing moves spring the switch.
## Switch nodes keep links as [trunk, main, branch]; empty dicts are track that is not generated yet.
func route(seg: TrackSegment, end: int, spring := true) -> Dictionary:
	var node: TrackNode = seg.nodes[end]
	var i := node.link_index(seg, end)
	if not node.is_switch:
		if node.links.size() != 2:
			return {}
		var other: Dictionary = node.links[1 - i]
		return other if not other.is_empty() else {}
	if i == 0:
		var out: Dictionary = node.links[1 + node.state] if node.links.size() > 1 + node.state else {}
		return out
	if spring and node.state != i - 1:
		node.state = i - 1
		switch_changed.emit(node)
	return node.links[0]


func new_node(pos: Vector3, switch := false) -> TrackNode:
	var n := _new_node(pos)
	n.is_switch = switch
	if switch:
		n.links = [{}, {}, {}]
	return n


## Adds a segment and attaches its ends. For switch nodes pass the slot (0 trunk, 1 main, 2 branch).
func add_segment(points: PackedVector3Array, a: TrackNode, slot_a: int, b: TrackNode, slot_b: int, lateral := 0.0) -> TrackSegment:
	var seg := TrackSegment.new()
	seg.id = segments.size()
	seg.curve = Curve3D.new()
	seg.curve.bake_interval = 0.25
	for p in points:
		seg.curve.add_point(p)
	seg.length = seg.curve.get_baked_length()
	seg.nodes = [a, b]
	seg.lateral = lateral
	_attach(a, {"seg": seg, "end": 0}, slot_a)
	_attach(b, {"seg": seg, "end": 1}, slot_b)
	segments.append(seg)
	_add_samples(seg)
	return seg


func _attach(n: TrackNode, link: Dictionary, slot: int) -> void:
	if n.is_switch and slot >= 0:
		while n.links.size() < 3:
			n.links.append({})
		n.links[slot] = link
	else:
		n.links.append(link)


func _add_samples(seg: TrackSegment) -> void:
	var n := int(seg.length / 0.5) + 1
	for i in n + 1:
		var p := seg.point(seg.length * i / n)
		var key := Vector2i(floori(p.x / 4.0), floori(p.z / 4.0))
		if not _grid.has(key):
			_grid[key] = PackedVector3Array()
		_grid[key].append(p)
		samples.append(p)


## All centerline samples inside an XZ rectangle (for terrain shaping in chunk workers).
func samples_in_rect(r: Rect2) -> PackedVector3Array:
	var out := PackedVector3Array()
	for gx in range(floori(r.position.x / 4.0), floori(r.end.x / 4.0) + 1):
		for gz in range(floori(r.position.y / 4.0), floori(r.end.y / 4.0) + 1):
			var arr: PackedVector3Array = _grid.get(Vector2i(gx, gz), PackedVector3Array())
			out.append_array(arr)
	return out


# ---------------------------------------------------------------- layout

func loop_length() -> float:
	return 4.0 * LOOP_HALF + TAU * LOOP_R


## Stadium loop parameterised by arc length u. u=0 at (-LOOP_HALF, +R) heading +X.
func loop_point(u: float) -> Vector3:
	var L := 2.0 * LOOP_HALF
	var arc := PI * LOOP_R
	u = fposmod(u, loop_length())
	var p := Vector3.ZERO
	if u < L:
		p = Vector3(-LOOP_HALF + u, 0, LOOP_R)
	elif u < L + arc:
		var a := PI * 0.5 - (u - L) / LOOP_R
		p = Vector3(LOOP_HALF + cos(a) * LOOP_R, 0, sin(a) * LOOP_R)
	elif u < 2.0 * L + arc:
		p = Vector3(LOOP_HALF - (u - L - arc), 0, -LOOP_R)
	else:
		var a := -PI * 0.5 - (u - 2.0 * L - arc) / LOOP_R
		p = Vector3(-LOOP_HALF + cos(a) * LOOP_R, 0, sin(a) * LOOP_R)
	p.y = _hill(u)
	return p


func _hill(u: float) -> float:
	var center := 2.0 * LOOP_HALF + PI * LOOP_R + LOOP_HALF
	var d := absf(u - center)
	var t := clampf((d - 8.0) / 58.0, 0.0, 1.0)
	return HILL_H * (1.0 - t * t * (3.0 - 2.0 * t))


func _loop_points(u0: float, u1: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var n := maxi(2, int(ceil((u1 - u0) / 1.0)) + 1)
	for i in n:
		pts.append(loop_point(lerpf(u0, u1, float(i) / (n - 1))))
	return pts


func build_layout() -> void:
	var us: Array[float] = []
	for x in SWITCH_X:
		us.append(x + LOOP_HALF)
	var sw: Array[TrackNode] = []
	for u in us:
		var n := _new_node(loop_point(u))
		n.is_switch = true
		sw.append(n)
		switches.append(n)
	# trunk links must be added first: segment arriving from the west ends at each switch
	var total := loop_length()
	_new_segment(_loop_points(us[2], us[0] + total), sw[2], sw[0])   # long way round, ends at switch 0 (trunk)
	_new_segment(_loop_points(us[0], us[1]), sw[0], sw[1])           # ends at switch 1 (trunk), starts switch 0 (branch 0)
	_new_segment(_loop_points(us[1], us[2]), sw[1], sw[2])
	# reorder so links[0] is trunk (end 1 of the westward segment), then main branch, then siding
	for i in 3:
		var node := sw[i]
		var trunk: Dictionary = {}
		var main: Dictionary = {}
		for l in node.links:
			if int(l.end) == 1:
				trunk = l
			else:
				main = l
		node.links = [trunk, main]
	for i in 3:
		var x0: float = SWITCH_X[i]
		var pts := PackedVector3Array()
		var steps := 30
		for k in steps + 1:
			var t := float(k) / steps
			pts.append(Vector3(x0 + TURNOUT_LEN * t, 0, LOOP_R + SIDING_OFFSET * (1.0 - cos(PI * t)) * 0.5))
		for k in range(1, 10):
			pts.append(Vector3(x0 + TURNOUT_LEN + STUB_LEN * k / 9.0, 0, LOOP_R + SIDING_OFFSET))
		var end_node := _new_node(pts[pts.size() - 1])
		end_node.name = "buffer_%d" % i
		var seg := _new_segment(pts, sw[i], end_node)
		seg.lateral = 1.0
		sidings.append(seg)
		dead_ends.append({"node": end_node, "seg": seg, "end": 1})
		sw[i].name = "switch_%d" % (i + 1)
	_build_samples()


func _build_samples() -> void:
	samples.clear()
	_grid.clear()
	for seg in segments:
		_add_samples(seg)


## Nearest centerline point in XZ within `radius`; returns Vector4(x, y, z, dist) or dist = INF.
func nearest(x: float, z: float, radius := 12.0) -> Vector4:
	var best := Vector4(0, 0, 0, INF)
	var r := int(ceil(radius / 4.0))
	var cx := floori(x / 4.0)
	var cz := floori(z / 4.0)
	for gx in range(cx - r, cx + r + 1):
		for gz in range(cz - r, cz + r + 1):
			var arr: PackedVector3Array = _grid.get(Vector2i(gx, gz), PackedVector3Array())
			for p in arr:
				var d := Vector2(p.x - x, p.z - z).length()
				if d < best.w:
					best = Vector4(p.x, p.y, p.z, d)
	return best


func cursor_at(seg: TrackSegment, s: float, flip := false) -> Cursor:
	var c := Cursor.new()
	c.net = self
	c.seg = seg
	c.s = s
	c.flip = flip
	return c


# ---------------------------------------------------------------- meshes

func build_meshes() -> void:
	for seg in segments:
		build_segment_visual(seg)


## Rails, ballast and sleepers for one segment as a child node (seg.visual) so the world can stream them.
func build_segment_visual(seg: TrackSegment) -> Node3D:
	if rail_material == null:
		_materials()
	var root := Node3D.new()
	root.name = "Seg%d" % seg.id
	var rail_st := SurfaceTool.new()
	rail_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sweep_rails(rail_st, seg)
	rail_st.generate_normals()
	var rails := MeshInstance3D.new()
	rails.mesh = rail_st.commit()
	rails.material_override = rail_material
	root.add_child(rails)
	var ballast_st := SurfaceTool.new()
	ballast_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sweep_ballast(ballast_st, seg)
	ballast_st.generate_normals()
	var ballast := MeshInstance3D.new()
	ballast.mesh = ballast_st.commit()
	ballast.material_override = ballast_material
	root.add_child(ballast)
	var box := BoxMesh.new()
	box.size = Vector3(2.5, 0.15, 0.24)
	box.material = sleeper_material
	var n := int(seg.length / 0.62)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = n
	for i in n:
		var s := (i + 0.5) * seg.length / n
		var p := seg.point(s)
		var t := seg.tangent(s)
		var side := t.cross(Vector3.UP).normalized()
		mm.set_instance_transform(i, Transform3D(Basis(side, Vector3.UP, -t).orthonormalized(), p + Vector3(0, -RAIL_H - 0.08, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = 260.0
	root.add_child(mmi)
	add_child(root)
	seg.visual = root
	return root


func _materials() -> void:
	rail_material = StandardMaterial3D.new()
	rail_material.albedo_color = Color(0.33, 0.3, 0.28)
	rail_material.metallic = 0.75
	rail_material.roughness = 0.42
	sleeper_material = StandardMaterial3D.new()
	sleeper_material.albedo_texture = load("res://assets/textures/ground/planks_diffuse.jpg")
	sleeper_material.normal_enabled = true
	sleeper_material.normal_texture = load("res://assets/textures/ground/planks_nor_gl.jpg")
	sleeper_material.albedo_color = Color(0.62, 0.55, 0.5)
	sleeper_material.roughness = 0.92
	sleeper_material.uv1_triplanar = true
	sleeper_material.uv1_scale = Vector3(0.9, 0.9, 0.9)
	ballast_material = StandardMaterial3D.new()
	ballast_material.albedo_texture = load("res://assets/textures/ground/gravel_diff.jpg")
	ballast_material.normal_enabled = true
	ballast_material.normal_texture = load("res://assets/textures/ground/gravel_nor.jpg")
	ballast_material.roughness = 0.95
	ballast_material.uv1_triplanar = true
	ballast_material.uv1_scale = Vector3(0.45, 0.45, 0.45)
	ballast_material.albedo_color = Color(0.82, 0.8, 0.77)


func _frame(seg: TrackSegment, s: float) -> Array:
	var p := seg.point(s)
	var t := seg.tangent(s)
	var side := t.cross(Vector3.UP).normalized()
	return [p, side]


func _sweep_rails(st: SurfaceTool, seg: TrackSegment) -> void:
	# simplified flat-bottom rail profile (x across, y up), rail top at y = 0
	var prof := [Vector2(-0.035, 0.0), Vector2(0.035, 0.0), Vector2(0.035, -0.045), Vector2(0.009, -0.05),
		Vector2(0.009, -0.14), Vector2(0.065, -0.15), Vector2(0.065, -0.16), Vector2(-0.065, -0.16),
		Vector2(-0.065, -0.15), Vector2(-0.009, -0.14), Vector2(-0.009, -0.05), Vector2(-0.035, -0.045)]
	var n := maxi(2, int(seg.length / 0.7) + 1)
	for rail_side in [-1.0, 1.0]:
		var prev: Array = []
		for i in n + 1:
			var f := _frame(seg, seg.length * i / n)
			var center: Vector3 = f[0] + (f[1] as Vector3) * rail_side * (GAUGE * 0.5 + 0.035)
			var ring: Array = []
			for q in prof:
				ring.append(center + (f[1] as Vector3) * q.x + Vector3.UP * q.y)
			if not prev.is_empty():
				for k in prof.size():
					var k2 := (k + 1) % prof.size()
					st.add_vertex(prev[k]); st.add_vertex(ring[k]); st.add_vertex(ring[k2])
					st.add_vertex(prev[k]); st.add_vertex(ring[k2]); st.add_vertex(prev[k2])
			prev = ring


func _sweep_ballast(st: SurfaceTool, seg: TrackSegment) -> void:
	var drop := 0.02 * seg.lateral
	var prof := [Vector2(-2.6, -0.78), Vector2(-1.55, -RAIL_H - 0.12), Vector2(1.55, -RAIL_H - 0.12), Vector2(2.6, -0.78)]
	var n := maxi(2, int(seg.length / 1.0) + 1)
	var prev: Array = []
	for i in n + 1:
		var f := _frame(seg, seg.length * i / n)
		var ring: Array = []
		for q in prof:
			ring.append((f[0] as Vector3) + (f[1] as Vector3) * q.x + Vector3.UP * (q.y - drop))
		if not prev.is_empty():
			for k in prof.size() - 1:
				st.add_vertex(prev[k]); st.add_vertex(prev[k + 1]); st.add_vertex(ring[k + 1])
				st.add_vertex(prev[k]); st.add_vertex(ring[k + 1]); st.add_vertex(ring[k])
		prev = ring
