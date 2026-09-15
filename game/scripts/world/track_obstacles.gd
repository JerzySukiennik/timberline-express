# Deterministic obstacles along generated rails: fallen trees, boulders and missing rail sections.
# Trains stop (or crash) at them; players clear them with an axe / pickaxe or repair the gap with a rail section.
class_name TrackObstacles
extends Node3D

const SPACING := 260.0

var main: Node
var net: TrackNetwork
var tracks: InfiniteTracks
var gen: WorldGen
var active := {}        # id -> {id, kind, seg, s, pos, node, cleared}
var _timer := 0.0


func obstacles_for(seg: TrackNetwork.TrackSegment) -> Array:
	var key := tracks.key_of(seg)
	if key == "" or key == "e:0:0":
		return []
	var out := []
	var n := int(seg.length / SPACING)
	for i in n:
		var h := gen.hash2(key.hash(), i, 101)
		if h > 0.4:
			continue
		var s := (i + 0.5) * SPACING + (gen.hash2(key.hash(), i, 102) - 0.5) * 80.0
		var kind := "tree" if h < 0.2 else ("boulder" if h < 0.32 else "gap")
		out.append({"id": "obs:%s:%d" % [key, i], "kind": kind, "seg": seg, "s": clampf(s, 20.0, seg.length - 20.0)})
	return out


func _process(dt: float) -> void:
	_timer -= dt
	if _timer > 0.0 or main.player == null:
		return
	_timer = 1.0
	var p: Vector3 = main.player.global_position
	var removed: Dictionary = main.world.removed.get("obstacles", {})
	for seg in net.segments:
		if seg.visual == null:
			continue
		for o in obstacles_for(seg):
			if active.has(o.id) or removed.has(o.id):
				continue
			var pos: Vector3 = (o.seg as TrackNetwork.TrackSegment).point(o.s)
			if Vector2(pos.x - p.x, pos.z - p.z).length() > 240.0:
				continue
			o["pos"] = pos
			o["node"] = _spawn(o)
			o["cleared"] = false
			active[o.id] = o
	for id in active.keys():
		var o: Dictionary = active[id]
		if Vector2(o.pos.x - p.x, o.pos.z - p.z).length() > 420.0:
			if is_instance_valid(o.node):
				o.node.queue_free()
			active.erase(id)
		elif not o.cleared and not is_instance_valid(o.node):
			clear(id)


func _spawn(o: Dictionary) -> Node3D:
	var seg: TrackNetwork.TrackSegment = o.seg
	var t := seg.tangent(o.s)
	var side := t.cross(Vector3.UP).normalized()
	var pos: Vector3 = o.pos
	match str(o.kind):
		"tree":
			var body := FallenLog.new()
			body.obstacles = self
			body.id = o.id
			add_child(body)
			body.global_transform = Transform3D(Basis(t, Vector3.UP, side.cross(t)).orthonormalized().rotated(Vector3.UP, PI * 0.5 + randf_range(-0.3, 0.3)), pos + Vector3.UP * 0.25)
			return body
		"boulder":
			var r := MineRock.create(main, Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * 0.9), pos + Vector3.DOWN * 0.1))
			r.set_meta("obstacle", o.id)
			return r
		"gap":
			var marker := RailGap.new()
			marker.obstacles = self
			marker.id = o.id
			add_child(marker)
			marker.global_transform = Transform3D(Basis(side, Vector3.UP, -t).orthonormalized(), pos)
			return marker
	return null


func clear(id: String) -> void:
	if not main.world.removed.has("obstacles"):
		main.world.removed["obstacles"] = {}
	main.world.removed["obstacles"][id] = true
	if active.has(id):
		active[id].cleared = true
		if str(active[id].kind) == "gap":
			var seg: TrackNetwork.TrackSegment = active[id].seg
			if seg.visual:
				seg.visual.queue_free()
				seg.visual = null
				net.build_segment_visual(seg)


## Along-track distance from a consist end to the nearest uncleared obstacle ahead in `dir` (INF if none close).
func blocking_distance(end_pos: Vector3, fwd: Vector3) -> Dictionary:
	var best := {"d": INF}
	for o in active.values():
		if o.cleared:
			continue
		var to: Vector3 = o.pos - end_pos
		var along := to.dot(fwd)
		var lateral := (to - fwd * along).length()
		if along > -0.5 and along < best.d and lateral < 2.2 and absf(to.y) < 3.0:
			best = {"d": along, "o": o}
	return best


## Gap segments the rail mesh should skip (s ranges).
func gaps_on(seg: TrackNetwork.TrackSegment) -> Array:
	var out := []
	var removed: Dictionary = main.world.removed.get("obstacles", {}) if main and main.world else {}
	for o in obstacles_for(seg):
		if o.kind == "gap" and not removed.has(o.id):
			out.append(Vector2(float(o.s) - 2.5, float(o.s) + 2.5))
	return out


class FallenLog:
	extends StaticBody3D
	var obstacles: TrackObstacles
	var id := ""
	var hp := 8.0

	func _ready() -> void:
		collision_layer = 1 | 32
		set_meta("surface", "wood")
		var log := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.32
		cyl.bottom_radius = 0.4
		cyl.height = 7.0
		log.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/textures/ground/rockface_diff.jpg") if not ResourceLoader.exists("res://assets/models/items/log.glb") else null
		log.rotation.z = PI * 0.5
		var bark := (load("res://assets/models/trees/fir_b.glb") as PackedScene).instantiate() as Node3D
		for mi in bark.find_children("Trunk", "MeshInstance3D", true, false):
			log.material_override = (mi as MeshInstance3D).mesh.surface_get_material(0)
		bark.free()
		add_child(log)
		var cs := CollisionShape3D.new()
		var cap := CylinderShape3D.new()
		cap.radius = 0.38
		cap.height = 7.0
		cs.shape = cap
		cs.rotation.z = PI * 0.5
		add_child(cs)

	func tool_hit(tool_id: String, point: Vector3, normal: Vector3, player: Node) -> bool:
		var dmg: float = {"axe": 1.0, "pickaxe": 0.3, "knife": 0.1}.get(Items.tool_type(tool_id), 0.0) * Items.tool_power(tool_id)
		Sfx.play_at("chop", point, -1.0, 0.12)
		Fx.burst(get_tree().current_scene, point, normal, "wood", 10)
		if dmg <= 0.0:
			return false
		hp -= dmg
		if hp <= 0.0:
			for i in 4:
				Pickup.spawn(get_tree().current_scene, "log", 1, global_transform * Vector3(-2.4 + i * 1.6, 0.5, 0))
			Sfx.play_at("wood_crash", global_position, 0.0)
			obstacles.clear(id)
			queue_free()
		return true


class RailGap:
	extends Node3D
	var obstacles: TrackObstacles
	var id := ""

	func _ready() -> void:
		var sign_mesh := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.08, 1.2, 0.08)
		sign_mesh.mesh = b
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.75, 0.2, 0.12)
		sign_mesh.material_override = m
		sign_mesh.position = Vector3(2.2, 0.5, 0)
		add_child(sign_mesh)
		var it := Interactable.make(self, 2.2, Vector3(0, 0.3, 0))
		it.prompt = func(p: Node) -> String:
			if (p as Player).equipped_id == "hammer" and (p as Player).inventory.count("rail_kit") > 0:
				return "[E] Repair the missing rails (uses 1 rail section)"
			return "Missing rails — needs a rail section and a hammer"
		it.on_use = func(p: Node) -> void:
			var pl := p as Player
			if pl.equipped_id == "hammer" and pl.inventory.remove("rail_kit", 1):
				Sfx.play_at("rail_repair", global_position, 0.0)
				pl.viewmodel.request_swing()
				obstacles.clear(id)
				queue_free()
