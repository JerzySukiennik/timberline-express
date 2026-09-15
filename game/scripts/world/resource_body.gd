# Collision for every harvestable thing in a chunk; a tool hit finds which resource by shape owner and spawns
# the interactive version (falling tree, fracturing boulder) while the chunk forgets the static one.
class_name ResourceBody
extends StaticBody3D

var world: ChunkWorld
var chunk: ChunkWorld.Chunk
var owners := {}


func tool_hit_shape(tool_id: String, point: Vector3, normal: Vector3, player: Node, shape_idx: int) -> bool:
	var owner_id := shape_find_owner(shape_idx)
	if not owners.has(owner_id):
		return false
	var info: Dictionary = owners[owner_id]
	var data: Dictionary = info.data
	var scene := get_tree().current_scene
	match info.kind:
		"tree":
			if not Items.is_tool(tool_id):
				return false
			var xf: Transform3D = data.xf
			var t := ChopTree.create(scene, xf.origin, data.variant, float(data.scale))
			t.rotation.y = xf.basis.get_euler().y
			_forget(owner_id, data.id)
			return t.tool_hit(tool_id, point, normal, player)
		"boulder":
			var r := MineRock.create(scene, data.xf, 0, "boulder_l0", str(data.get("ore", "")))
			world.hide_slot(chunk, info.get("slot", []))
			_forget(owner_id, data.id)
			return r.tool_hit(tool_id, point, normal, player)
		"bush":
			var b := Bush.create(scene, (data.xf as Transform3D).origin, 1.0)
			b.hp = 3
			_forget(owner_id, data.id)
			return b.tool_hit(tool_id, point, normal, player)
	return false


func _forget(owner_id: int, id: String) -> void:
	shape_owner_clear_shapes(owner_id)
	owners.erase(owner_id)
	world.harvest(chunk, id)


func prompt_shape(shape_idx: int, player: Node) -> String:
	var owner_id := shape_find_owner(shape_idx)
	if not owners.has(owner_id):
		return ""
	var info: Dictionary = owners[owner_id]
	match info.kind:
		"bush":
			return "[E] Pick berries" if info.data.get("berry", false) else ""
		"mushroom":
			return "[E] Pick mushroom"
		"branch":
			return "[E] Pick up sticks"
		"pebble":
			return "[E] Pick up stone"
	return ""


func use_shape(shape_idx: int, player: Node) -> bool:
	var owner_id := shape_find_owner(shape_idx)
	if not owners.has(owner_id):
		return false
	var info: Dictionary = owners[owner_id]
	var inv: Inventory = player.inventory
	match info.kind:
		"bush":
			if not info.data.get("berry", false):
				return false
			var n := randi_range(2, 4)
			if inv.add("berries", n) >= n:
				return false
			info.data["berry"] = false
			world.hide_slot(chunk, info.data.get("slot", []))
			Sfx.play_at("berries_pick", (info.data.xf as Transform3D).origin, -4.0)
			world.harvest(chunk, "p" + str(info.data.id))
			return true
		"branch", "pebble":
			var item := "stick" if info.kind == "branch" else "stone"
			var count := 2 if info.kind == "branch" else 1
			if inv.add(item, count) >= count:
				return false
			world.hide_slot(chunk, info.get("slot", []))
			Sfx.play("pickup", -6.0)
			_forget(owner_id, info.data.id)
			return true
		"mushroom":
			if inv.add("mushroom", 1) > 0:
				return false
			world.hide_slot(chunk, info.get("slot", []))
			Sfx.play("pickup", -6.0)
			_forget(owner_id, info.data.id)
			return true
	return false
