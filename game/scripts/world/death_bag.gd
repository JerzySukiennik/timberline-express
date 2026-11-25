# Backpack dropped where the player died; holds everything they carried until emptied.
class_name DeathBag
extends StaticBody3D

var inventory := Inventory.new(29)


static func spawn(main: Node, pos: Vector3, from: Inventory) -> DeathBag:
	var bag := DeathBag.new()
	if NetSync.hosting():
		NetSync.inst.register(bag, "bag")
	bag.collision_layer = 1
	for i in from.size():
		bag.inventory.slots[i] = from.get_slot(i).duplicate()
		from.slots[i] = {}
	from.changed.emit()
	main.add_child(bag)
	bag.global_position = pos
	var m := (load("res://assets/models/props/sack.glb") as PackedScene).instantiate() as Node3D
	bag.add_child(m)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.28
	cs.shape = sp
	cs.position.y = 0.2
	bag.add_child(cs)
	var light := OmniLight3D.new()
	light.light_color = Color(0.95, 0.75, 0.4)
	light.omni_range = 2.5
	light.light_energy = 0.6
	light.position.y = 0.8
	bag.add_child(light)
	var it := Interactable.make(bag, 0.4, Vector3(0, 0.3, 0))
	it.prompt = func(_p: Node) -> String: return "[E] Open your lost backpack"
	it.on_use = func(_p: Node) -> void:
		main.open_container(bag.inventory, "Lost Backpack", func() -> void:
			for s in bag.inventory.slots:
				if not s.is_empty():
					return
			bag.queue_free())
	if Net.local_spawn_blocked():
		bag.queue_free()
	return bag


func is_empty() -> bool:
	for s in inventory.slots:
		if not s.is_empty():
			return false
	return true
