# Builds the endless rail network region by region around points of interest (player, vehicles).
class_name InfiniteTracks
extends RefCounted

var gen: WorldGen
var net: TrackNetwork
var _nodes := {}      # Vector2i -> TrackNode
var _edges := {}      # "e:i:j" / "n:i:j" -> TrackSegment
var branch_nodes: Array = []


func _init(g: WorldGen, n: TrackNetwork) -> void:
	gen = g
	net = n


func node(i: int, j: int) -> TrackNetwork.TrackNode:
	var key := Vector2i(i, j)
	if not _nodes.has(key):
		var xz := gen.node_xz(i, j)
		var sw := gen.has_branch(i, j)
		var nd := net.new_node(Vector3(xz.x, gen.node_height(i, j), xz.y), sw)
		nd.name = "junction %d,%d" % [i, j]
		_nodes[key] = nd
		if sw:
			branch_nodes.append(nd)
	return _nodes[key]


func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(round(pos.x / WorldGen.REGION)), int(round(-pos.z / WorldGen.REGION)))


## Ensure every edge touching cells within `radius` of `pos` exists. Returns newly created segments.
func ensure(pos: Vector3, radius := 1) -> Array:
	var created := []
	var c := cell_of(pos)
	for i in range(c.x - radius - 1, c.x + radius + 1):
		for j in range(c.y - radius, c.y + radius + 1):
			var e := _edge_east(i, j)
			if e:
				created.append(e)
			if gen.has_connector(i, j):
				var n := _edge_north(i, j)
				if n:
					created.append(n)
	for j in range(c.y - radius - 1, c.y - radius):
		for i in range(c.x - radius - 1, c.x + radius + 1):
			if gen.has_connector(i, j):
				var n2 := _edge_north(i, j)
				if n2:
					created.append(n2)
	return created


func _edge_east(i: int, j: int) -> TrackNetwork.TrackSegment:
	var key := "e:%d:%d" % [i, j]
	if _edges.has(key):
		return null
	var a := node(i, j)
	var b := node(i + 1, j)
	var pts := gen.edge_points(Vector2(a.pos.x, a.pos.z), Vector2.RIGHT, a.pos.y, Vector2(b.pos.x, b.pos.z), Vector2.RIGHT, b.pos.y, WorldGen.REGION * 0.9, i * 31 + j * 17)
	var seg := net.add_segment(pts, a, 1 if a.is_switch else -1, b, 0 if b.is_switch else -1)
	_edges[key] = seg
	return seg


func _edge_north(i: int, j: int) -> TrackNetwork.TrackSegment:
	var key := "n:%d:%d" % [i, j]
	if _edges.has(key):
		return null
	var a := node(i, j)
	var b := node(i, j + 1)
	# leaves a heading east, loops over the pass, arrives at b heading west (b's branch also points east)
	var pts := gen.edge_points(Vector2(a.pos.x, a.pos.z), Vector2.RIGHT, a.pos.y, Vector2(b.pos.x, b.pos.z), Vector2.LEFT, b.pos.y, 900.0, i * 13 + j * 29 + 7)
	var seg := net.add_segment(pts, a, 2, b, 2, 1.0)
	_edges[key] = seg
	return seg


func start_segment() -> TrackNetwork.TrackSegment:
	ensure(Vector3.ZERO, 1)
	return _edges.get("e:0:0")
