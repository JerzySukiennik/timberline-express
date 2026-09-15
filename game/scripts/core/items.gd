# Item database: every inventory item, its stack size, tool stats and the model used in hand, in the world and for icons.
extends Node

const DEFS := {
	"pickaxe": {"name": "Pickaxe", "kind": "tool", "stack": 1, "durability": 220, "model": "res://assets/models/tools/picke_dirty_01.glb", "equip": "equip_pickaxe"},
	"axe": {"name": "Axe", "kind": "tool", "stack": 1, "durability": 220, "model": "res://assets/models/tools/wooden_axe_03.glb", "equip": "equip_axe"},
	"knife": {"name": "Knife", "kind": "tool", "stack": 1, "durability": 300, "model": "res://assets/models/tools/knife.glb", "equip": "equip_knife"},
	"stone": {"name": "Stone", "kind": "resource", "stack": 40, "model": "res://assets/models/items/stone.glb"},
	"log": {"name": "Log", "kind": "resource", "stack": 12, "model": "res://assets/models/items/log.glb", "fuel_kg": 6.0},
	"coal": {"name": "Coal", "kind": "resource", "stack": 40, "model": "res://assets/models/items/coal.glb", "fuel_kg": 3.0},
	"fiber": {"name": "Fiber", "kind": "resource", "stack": 40, "model": "res://assets/models/items/fiber.glb"},
	"bucket": {"name": "Bucket", "kind": "container", "stack": 1, "model": "res://assets/models/props/wooden_bucket_01.glb"},
	"bucket_water": {"name": "Bucket of Water", "kind": "container", "stack": 1, "model": "res://assets/models/props/wooden_bucket_01.glb"},
	"jerrycan": {"name": "Empty Jerrycan", "kind": "container", "stack": 1, "model": "res://assets/models/items/jerrycan.glb"},
	"jerrycan_fuel": {"name": "Jerrycan of Fuel", "kind": "container", "stack": 1, "model": "res://assets/models/items/jerrycan.glb"},
}

var _scenes := {}
var icons: Node


func def(id: String) -> Dictionary:
	return DEFS.get(id, {})


func stack_size(id: String) -> int:
	return int(def(id).get("stack", 1))


func display_name(id: String) -> String:
	return str(def(id).get("name", id))


func is_tool(id: String) -> bool:
	return def(id).get("kind", "") == "tool"


func scene(id: String) -> PackedScene:
	if _scenes.has(id):
		return _scenes[id]
	var path: String = def(id).get("model", "")
	var ps: PackedScene = load(path) if path != "" and ResourceLoader.exists(path) else null
	_scenes[id] = ps
	return ps


func instance(id: String) -> Node3D:
	var ps := scene(id)
	if ps == null:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		(mi.mesh as BoxMesh).size = Vector3(0.15, 0.15, 0.15)
		return mi
	return ps.instantiate() as Node3D


func ids() -> Array:
	return DEFS.keys()
