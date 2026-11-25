# Keeps wildlife alive around the player: deer herds and foxes by day, wolf packs at dusk and night.
class_name AnimalDirector
extends Node

var main: Node
var _timer := 3.0
var night := false


func _process(dt: float) -> void:
	_timer -= dt
	if _timer > 0.0 or main == null or main.player == null or main.loading or Net.is_client_online():
		return
	_timer = 4.0
	var p: Vector3 = main.player.global_position
	var animals := get_tree().get_nodes_in_group("animals")
	var counts := {"deer": 0, "fox": 0, "wolf": 0}
	for a in animals:
		var d := (a as Node3D).global_position.distance_to(p)
		if d > 190.0:
			a.queue_free()
			continue
		counts[a.species] += 1
	if counts.deer < 6:
		_spawn_group("deer", randi_range(2, 4))
	if counts.fox < 2:
		_spawn_group("fox", 1)
	var wolves_wanted := 3 if night else (1 if randf() < 0.15 else 0)
	if counts.wolf < wolves_wanted:
		_spawn_group("wolf", randi_range(2, 3))


func _spawn_group(kind: String, n: int) -> void:
	var p: Vector3 = main.player.global_position
	for attempt in 8:
		var ang := randf() * TAU
		var r := randf_range(70.0, 120.0)
		var c := p + Vector3(cos(ang) * r, 0, sin(ang) * r)
		var w = main.terrain
		if w.dist_to_track(c.x, c.z) < 10.0:
			continue
		if w.has_method("water_level_at") and w.water_level_at(c.x, c.z) > -INF:
			continue
		if main.world:
			var ch = main.world.chunks.get(main.world.cell(c))
			if ch == null or ch.lod != 0:
				continue
		var group: Array = []
		for i in n:
			var off := Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			var pos := c + off
			pos.y = w.height_at(pos.x, pos.z) + 0.3
			group.append(Animal.spawn(main, kind, pos))
		for a in group:
			a.pack = group
		return
