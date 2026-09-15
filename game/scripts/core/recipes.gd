# Crafting recipes (hand or workbench) and station processing (campfire, furnace). Every recipe is visible from the start.
class_name Recipes
extends RefCounted

const CRAFT := [
	{"out": "rope", "n": 1, "in": {"fiber": 3}, "at": "", "time": 1.2, "sound": "craft_rope"},
	{"out": "stick", "n": 3, "in": {"log": 1}, "at": "", "time": 1.5, "sound": "craft_wood"},
	{"out": "stone_axe", "n": 1, "in": {"stick": 2, "stone": 2, "rope": 1}, "at": "", "time": 3.0, "sound": "craft_stone"},
	{"out": "stone_pickaxe", "n": 1, "in": {"stick": 2, "stone": 3, "rope": 1}, "at": "", "time": 3.0, "sound": "craft_stone"},
	{"out": "stone_knife", "n": 1, "in": {"stick": 1, "stone": 1, "fiber": 2}, "at": "", "time": 2.0, "sound": "craft_stone"},
	{"out": "spear", "n": 1, "in": {"stick": 3, "stone": 1, "rope": 1}, "at": "", "time": 2.5, "sound": "craft_stone"},
	{"out": "torch", "n": 2, "in": {"stick": 1, "fiber": 2, "coal": 1}, "at": "", "time": 1.5, "sound": "craft_rope"},
	{"out": "bandage", "n": 1, "in": {"fiber": 4}, "at": "", "time": 1.5, "sound": "craft_rope"},
	{"out": "campfire", "n": 1, "in": {"log": 3, "stone": 6}, "at": "", "time": 3.0, "sound": "craft_stone"},
	{"out": "workbench", "n": 1, "in": {"log": 5, "stone": 4, "rope": 3}, "at": "", "time": 5.0, "sound": "craft_wood"},
	{"out": "plank", "n": 3, "in": {"log": 1}, "at": "workbench", "time": 2.0, "sound": "craft_wood"},
	{"out": "chest", "n": 1, "in": {"plank": 8, "rope": 2}, "at": "workbench", "time": 4.0, "sound": "craft_wood"},
	{"out": "bed", "n": 1, "in": {"plank": 8, "fiber": 14}, "at": "workbench", "time": 5.0, "sound": "craft_wood"},
	{"out": "furnace", "n": 1, "in": {"stone": 24, "log": 2}, "at": "workbench", "time": 6.0, "sound": "craft_stone"},
	{"out": "bucket", "n": 1, "in": {"plank": 4, "rope": 1}, "at": "workbench", "time": 3.0, "sound": "craft_wood"},
	{"out": "hammer", "n": 1, "in": {"stick": 1, "iron_ingot": 1}, "at": "workbench", "time": 3.0, "sound": "craft_metal"},
	{"out": "nails", "n": 10, "in": {"iron_ingot": 1}, "at": "workbench", "time": 2.5, "sound": "craft_metal"},
	{"out": "jerrycan", "n": 1, "in": {"iron_ingot": 3}, "at": "workbench", "time": 4.0, "sound": "craft_metal"},
	{"out": "axe", "n": 1, "in": {"iron_ingot": 3, "stick": 1, "rope": 1}, "at": "workbench", "time": 4.0, "sound": "craft_metal"},
	{"out": "pickaxe", "n": 1, "in": {"iron_ingot": 4, "stick": 1, "rope": 1}, "at": "workbench", "time": 4.0, "sound": "craft_metal"},
	{"out": "knife", "n": 1, "in": {"iron_ingot": 2, "stick": 1}, "at": "workbench", "time": 3.0, "sound": "craft_metal"},
	{"out": "bow", "n": 1, "in": {"stick": 4, "rope": 3}, "at": "workbench", "time": 4.0, "sound": "craft_wood"},
	{"out": "arrow", "n": 4, "in": {"stick": 1, "stone": 1, "fiber": 2}, "at": "workbench", "time": 2.0, "sound": "craft_wood"},
	{"out": "rail_kit", "n": 1, "in": {"iron_ingot": 3, "plank": 2}, "at": "workbench", "time": 4.0, "sound": "craft_metal"},
	{"out": "flatcar_kit", "n": 1, "in": {"plank": 24, "nails": 20, "iron_ingot": 8}, "at": "workbench", "time": 8.0, "sound": "craft_wood"},
	{"out": "steam_kit", "n": 1, "in": {"iron_ingot": 45, "plank": 16, "nails": 30, "coal": 10}, "at": "workbench", "time": 12.0, "sound": "craft_metal"},
	{"out": "electric_kit", "n": 1, "in": {"iron_ingot": 40, "copper_ingot": 30, "plank": 10}, "at": "workbench", "time": 12.0, "sound": "craft_metal"},
]

## Station processing: input -> output after `time` seconds while fuel burns.
const PROCESS := {
	"campfire": {"raw_meat": ["cooked_meat", 25.0], "bucket_water": ["bucket_boiled", 20.0]},
	"furnace": {"iron_ore": ["iron_ingot", 15.0], "copper_ore": ["copper_ingot", 15.0], "raw_meat": ["cooked_meat", 12.0]},
}

const FUEL_SECONDS := {"stick": 12.0, "plank": 25.0, "log": 70.0, "coal": 140.0}


static func can_craft(r: Dictionary, inv: Inventory) -> bool:
	for id in r.in:
		if inv.count(id) < int(r.in[id]):
			return false
	return true


static func take(r: Dictionary, inv: Inventory) -> bool:
	if not can_craft(r, inv):
		return false
	for id in r.in:
		inv.remove(id, int(r.in[id]))
	return true
