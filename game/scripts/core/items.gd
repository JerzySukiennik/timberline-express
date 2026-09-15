# Item database: every inventory item, its stack size, tool stats and the model used in hand, in the world and for icons.
extends Node

const M := "res://assets/models/"
const DEFS := {
	# tools: tool = what it acts like, power scales damage
	"stone_axe": {"name": "Stone Axe", "kind": "tool", "tool": "axe", "power": 0.55, "stack": 1, "durability": 90, "model": M + "tools/stone_axe.glb", "equip": "equip_axe", "rig": "axe"},
	"stone_pickaxe": {"name": "Stone Pickaxe", "kind": "tool", "tool": "pickaxe", "power": 0.55, "stack": 1, "durability": 90, "model": M + "tools/stone_pickaxe.glb", "equip": "equip_pickaxe", "rig": "stone_pickaxe"},
	"stone_knife": {"name": "Stone Knife", "kind": "tool", "tool": "knife", "power": 0.6, "stack": 1, "durability": 120, "model": M + "tools/stone_knife.glb", "equip": "equip_knife", "rig": "knife"},
	"axe": {"name": "Iron Axe", "kind": "tool", "tool": "axe", "power": 1.0, "stack": 1, "durability": 260, "model": M + "tools/wooden_axe_03.glb", "equip": "equip_axe", "rig": "axe"},
	"pickaxe": {"name": "Iron Pickaxe", "kind": "tool", "tool": "pickaxe", "power": 1.0, "stack": 1, "durability": 260, "model": M + "tools/picke_dirty_01.glb", "equip": "equip_pickaxe", "rig": "pickaxe"},
	"knife": {"name": "Hunting Knife", "kind": "tool", "tool": "knife", "power": 1.0, "stack": 1, "durability": 300, "model": M + "tools/knife.glb", "equip": "equip_knife", "rig": "knife"},
	"hammer": {"name": "Hammer", "kind": "tool", "tool": "hammer", "power": 1.0, "stack": 1, "durability": 400, "model": M + "tools/hammer.glb", "equip": "equip_axe", "rig": "hammer"},
	"spear": {"name": "Spear", "kind": "tool", "tool": "spear", "power": 0.9, "stack": 1, "durability": 80, "model": M + "tools/spear.glb", "equip": "equip_hand", "rig": "spear"},
	"bow": {"name": "Bow", "kind": "tool", "tool": "bow", "power": 1.0, "stack": 1, "durability": 200, "model": M + "tools/bow.glb", "equip": "equip_hand", "rig": "bow"},
	# materials
	"stone": {"name": "Stone", "kind": "resource", "stack": 40, "model": M + "items/stone.glb"},
	"stick": {"name": "Stick", "kind": "resource", "stack": 40, "model": M + "items/stick.glb", "fuel_kg": 1.0},
	"log": {"name": "Log", "kind": "resource", "stack": 12, "model": M + "items/log.glb", "fuel_kg": 6.0},
	"plank": {"name": "Plank", "kind": "resource", "stack": 40, "model": M + "items/plank.glb", "fuel_kg": 2.0},
	"fiber": {"name": "Fiber", "kind": "resource", "stack": 40, "model": M + "items/fiber.glb"},
	"rope": {"name": "Rope", "kind": "resource", "stack": 20, "model": M + "items/rope.glb"},
	"coal": {"name": "Coal", "kind": "resource", "stack": 40, "model": M + "items/coal.glb", "fuel_kg": 3.0},
	"iron_ore": {"name": "Iron Ore", "kind": "resource", "stack": 30, "model": M + "items/iron_ore.glb"},
	"copper_ore": {"name": "Copper Ore", "kind": "resource", "stack": 30, "model": M + "items/copper_ore.glb"},
	"iron_ingot": {"name": "Iron Ingot", "kind": "resource", "stack": 30, "model": M + "items/iron_ingot.glb"},
	"copper_ingot": {"name": "Copper Ingot", "kind": "resource", "stack": 30, "model": M + "items/copper_ingot.glb"},
	"nails": {"name": "Nails", "kind": "resource", "stack": 99, "model": M + "items/nails.glb"},
	"leather": {"name": "Leather", "kind": "resource", "stack": 20, "model": M + "items/leather.glb"},
	"arrow": {"name": "Arrow", "kind": "resource", "stack": 30, "model": M + "items/arrow.glb"},
	# food & drink
	"berries": {"name": "Wild Berries", "kind": "food", "stack": 20, "model": M + "items/berries.glb", "food": 9.0, "water": 3.0, "heal": 1.0, "eat": "eat_crunch"},
	"mushroom": {"name": "Mushroom", "kind": "food", "stack": 20, "model": M + "items/mushroom.glb", "food": 11.0, "water": 1.0, "heal": 0.0, "poison": 0.12, "eat": "eat_crunch"},
	"raw_meat": {"name": "Raw Meat", "kind": "food", "stack": 10, "model": M + "items/raw_meat.glb", "food": 14.0, "water": 0.0, "heal": -6.0, "poison": 0.4, "eat": "eat_meat"},
	"cooked_meat": {"name": "Cooked Meat", "kind": "food", "stack": 10, "model": M + "items/cooked_meat.glb", "food": 42.0, "water": 0.0, "heal": 8.0, "eat": "eat_meat"},
	"bandage": {"name": "Bandage", "kind": "food", "stack": 10, "model": M + "items/bandage.glb", "food": 0.0, "water": 0.0, "heal": 30.0, "eat": "craft_rope"},
	"torch": {"name": "Torch", "kind": "light", "stack": 5, "model": M + "items/stick.glb", "light": true},
	"bucket": {"name": "Bucket", "kind": "container", "stack": 1, "model": M + "props/wooden_bucket_01.glb"},
	"bucket_water": {"name": "Bucket of Pond Water", "kind": "drink", "stack": 1, "model": M + "props/wooden_bucket_01.glb", "water": 45.0, "food": 0.0, "heal": 0.0, "poison": 0.2, "leaves": "bucket", "eat": "drink_gulp"},
	"bucket_boiled": {"name": "Bucket of Boiled Water", "kind": "drink", "stack": 1, "model": M + "props/wooden_bucket_01.glb", "water": 55.0, "food": 0.0, "heal": 2.0, "leaves": "bucket", "eat": "drink_gulp"},
	"jerrycan": {"name": "Empty Jerrycan", "kind": "container", "stack": 1, "model": M + "items/jerrycan.glb"},
	"jerrycan_fuel": {"name": "Jerrycan of Fuel", "kind": "container", "stack": 1, "model": M + "items/jerrycan.glb"},
	# placeables
	"campfire": {"name": "Campfire", "kind": "placeable", "stack": 5, "model": M + "props/campfire.glb", "station": "campfire"},
	"workbench": {"name": "Workbench", "kind": "placeable", "stack": 2, "model": M + "props/workbench.glb", "station": "workbench"},
	"furnace": {"name": "Furnace", "kind": "placeable", "stack": 2, "model": M + "props/furnace.glb", "station": "furnace"},
	"chest": {"name": "Storage Chest", "kind": "placeable", "stack": 5, "model": M + "props/chest.glb", "station": "chest"},
	"bed": {"name": "Bed", "kind": "placeable", "stack": 2, "model": M + "props/bed.glb", "station": "bed"},
	# rail kits
	"flatcar_kit": {"name": "Flatcar Kit", "kind": "kit", "stack": 3, "model": M + "items/rail_kit.glb"},
	"steam_kit": {"name": "Steam Engine Kit", "kind": "kit", "stack": 1, "model": M + "items/steam_kit.glb"},
	"electric_kit": {"name": "Electric Drive Kit", "kind": "kit", "stack": 1, "model": M + "items/electric_kit.glb"},
	"rail_kit": {"name": "Rail Section", "kind": "resource", "stack": 10, "model": M + "items/rail_kit.glb"},
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


func tool_type(id: String) -> String:
	return str(def(id).get("tool", ""))


func tool_power(id: String) -> float:
	return float(def(id).get("power", 0.0))


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


func is_consumable(id: String) -> bool:
	return def(id).get("kind", "") in ["food", "drink"]


func ids() -> Array:
	return DEFS.keys()
