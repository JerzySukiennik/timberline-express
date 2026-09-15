# Raft-style building on rail vehicles: grid-snapped wooden pieces that become collision shapes of the vehicle.
class_name Building
extends RefCounted

const CELL := 1.5
const STOREY := 2.5
const PIECES := {
	"floor": {"name": "Floor", "cost": {"plank": 4, "nails": 4}, "kind": "cell"},
	"wall": {"name": "Wall", "cost": {"plank": 6, "nails": 6}, "kind": "edge"},
	"window": {"name": "Window Wall", "cost": {"plank": 5, "nails": 6}, "kind": "edge"},
	"doorway": {"name": "Doorway", "cost": {"plank": 4, "nails": 5}, "kind": "edge"},
	"railing": {"name": "Railing", "cost": {"plank": 2, "nails": 2}, "kind": "edge"},
	"roof": {"name": "Roof", "cost": {"plank": 4, "nails": 4}, "kind": "top"},
	"stairs": {"name": "Stairs", "cost": {"plank": 6, "nails": 6}, "kind": "cell"},
}
const ORDER := ["floor", "wall", "window", "doorway", "railing", "roof", "stairs"]

static var _mat: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_texture = load("res://assets/textures/ground/planks_diffuse.jpg")
		_mat.normal_enabled = true
		_mat.normal_texture = load("res://assets/textures/ground/planks_nor_gl.jpg")
		_mat.uv1_triplanar = true
		_mat.uv1_scale = Vector3(0.55, 0.55, 0.55)
		_mat.roughness = 0.9
		_mat.albedo_color = Color(0.85, 0.78, 0.7)
	return _mat


## Box parts (size, center) in piece-local space. Edge pieces are built along X at z=0; cells are centred.
static func parts(piece: String) -> Array:
	var t := 0.12
	match piece:
		"floor":
			return [[Vector3(CELL, t, CELL), Vector3(0, t * 0.5, 0)]]
		"roof":
			return [[Vector3(CELL + 0.1, t, CELL + 0.1), Vector3(0, STOREY - t * 0.5, 0)]]
		"wall":
			return [[Vector3(CELL, STOREY, t), Vector3(0, STOREY * 0.5, 0)]]
		"railing":
			return [[Vector3(CELL, 0.08, 0.08), Vector3(0, 1.0, 0)], [Vector3(0.08, 1.0, 0.08), Vector3(-CELL * 0.45, 0.5, 0)], [Vector3(0.08, 1.0, 0.08), Vector3(CELL * 0.45, 0.5, 0)], [Vector3(CELL, 0.06, 0.06), Vector3(0, 0.55, 0)]]
		"window":
			return [[Vector3(CELL, 0.9, t), Vector3(0, 0.45, 0)], [Vector3(CELL, 0.7, t), Vector3(0, STOREY - 0.35, 0)], [Vector3(0.35, 0.9, t), Vector3(-CELL * 0.5 + 0.175, 1.35, 0)], [Vector3(0.35, 0.9, t), Vector3(CELL * 0.5 - 0.175, 1.35, 0)]]
		"doorway":
			return [[Vector3(0.3, STOREY, t), Vector3(-CELL * 0.5 + 0.15, STOREY * 0.5, 0)], [Vector3(0.3, STOREY, t), Vector3(CELL * 0.5 - 0.15, STOREY * 0.5, 0)], [Vector3(CELL, 0.4, t), Vector3(0, STOREY - 0.2, 0)]]
		"stairs":
			var out := []
			for i in 6:
				out.append([Vector3(CELL * 0.9, 0.1, CELL / 6.0), Vector3(0, STOREY * (i + 1) / 6.0 - 0.05, -CELL * 0.5 + CELL / 12.0 + i * CELL / 6.0)])
			out.append([Vector3(0.08, STOREY, CELL), Vector3(-CELL * 0.45, STOREY * 0.5, 0)])
			return out
	return []


static func can_afford(piece: String, inv: Inventory) -> bool:
	var cost: Dictionary = PIECES[piece].cost
	for id in cost:
		if inv.count(id) < int(cost[id]):
			return false
	return true


static func cost_text(piece: String, inv: Inventory) -> String:
	var parts2 := PackedStringArray()
	var cost: Dictionary = PIECES[piece].cost
	for id in cost:
		parts2.append("%s %d/%d" % [Items.display_name(id), inv.count(id), int(cost[id])])
	return "  ·  ".join(parts2)


## Grid bounds of a vehicle deck: cells in x and z and the deck top height (vehicle local).
static func deck_of(v: RailVehicle) -> Dictionary:
	if v is Flatcar:
		return {"nx": 2, "nz": 4, "top": 0.87}
	if v is Handcar:
		return {"nx": 1, "nz": 1, "top": 0.73}
	if v is Tender:
		return {"nx": 1, "nz": 2, "top": 1.08}
	return {}


class Piece:
	extends Node3D
	var piece := ""
	var cell := Vector3i.ZERO     # x, storey, z
	var edge := 0                 # 0 N, 1 E, 2 S, 3 W (edge pieces) or rotation (cells)
	var hp := 100.0
	var vehicle: RailVehicle
	var shapes: Array[CollisionShape3D] = []

	func key() -> String:
		return "%s:%d:%d:%d:%d" % [PIECES[piece].kind, cell.x, cell.y, cell.z, edge]


static func local_transform(v: RailVehicle, piece: String, cell: Vector3i, edge: int) -> Transform3D:
	var deck := deck_of(v)
	var ox := (cell.x - (int(deck.nx) - 1) * 0.5) * CELL
	var oz := (cell.z - (int(deck.nz) - 1) * 0.5) * CELL
	var y: float = deck.top + cell.y * STOREY
	var kind: String = PIECES[piece].kind
	if kind == "edge":
		var offs := [Vector3(0, 0, -CELL * 0.5), Vector3(CELL * 0.5, 0, 0), Vector3(0, 0, CELL * 0.5), Vector3(-CELL * 0.5, 0, 0)]
		return Transform3D(Basis(Vector3.UP, -PI * 0.5 * edge), Vector3(ox, y, oz) + offs[edge])
	return Transform3D(Basis(Vector3.UP, -PI * 0.5 * edge), Vector3(ox, y, oz))


static func build(v: RailVehicle, piece: String, cell: Vector3i, edge: int) -> Piece:
	var p := Piece.new()
	p.piece = piece
	p.cell = cell
	p.edge = edge
	p.vehicle = v
	v.add_child(p)
	p.transform = local_transform(v, piece, cell, edge)
	for part in parts(piece):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		mi.mesh = bm
		mi.material_override = material()
		mi.position = part[1]
		p.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = part[0]
		cs.shape = bs
		cs.set_meta("surface", "wood")
		v.add_child(cs)
		cs.transform = p.transform * Transform3D(Basis.IDENTITY, part[1])
		p.shapes.append(cs)
	if not v.has_meta("pieces"):
		v.set_meta("pieces", {})
	(v.get_meta("pieces") as Dictionary)[p.key()] = p
	return p


static func remove(p: Piece) -> void:
	for cs in p.shapes:
		if is_instance_valid(cs):
			cs.queue_free()
	if p.vehicle and p.vehicle.has_meta("pieces"):
		(p.vehicle.get_meta("pieces") as Dictionary).erase(p.key())
	p.queue_free()


static func piece_from_shape(v: RailVehicle, shape_idx: int) -> Piece:
	if not v.has_meta("pieces"):
		return null
	var owner_id := v.shape_find_owner(shape_idx)
	var node := v.shape_owner_get_owner(owner_id)
	for p in (v.get_meta("pieces") as Dictionary).values():
		if node in (p as Piece).shapes:
			return p
	return null
