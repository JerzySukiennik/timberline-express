# Dense grass carpet around the player, rebuilt in place as they move (chunk grass covers the mid distance).
class_name GrassField
extends MultiMeshInstance3D

var world: Node
var focus: Node3D
var radius := 22.0
var spacing := 0.42
var _center := Vector2(INF, INF)
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = Terrain.grass_clump()
	_noise.frequency = 0.08
	extra_cull_margin = 4.0


func _process(_dt: float) -> void:
	if focus == null or world == null:
		return
	var p := Vector2(focus.global_position.x, focus.global_position.z)
	if p.distance_to(_center) < 5.0:
		return
	_center = p.snapped(Vector2(1, 1))
	_rebuild()


func _rebuild() -> void:
	var ponds: Array = world.ponds_for(_center, radius + 20.0) if world.has_method("ponds_for") else []
	var buf := PackedFloat32Array()
	var n := int(radius * 2.0 / spacing)
	for gz in n:
		for gx in n:
			var x := floorf(_center.x - radius) + gx * spacing
			var z := floorf(_center.y - radius) + gz * spacing
			var key := int(round(x / spacing)) * 73856093 ^ int(round(z / spacing)) * 19349663
			_rng.seed = key
			var jx := x + _rng.randf() * spacing
			var jz := z + _rng.randf() * spacing
			var dx := jx - _center.x
			var dz := jz - _center.y
			if dx * dx + dz * dz > radius * radius:
				continue
			var nv := _noise.get_noise_2d(jx, jz)
			if nv < -0.35 or _rng.randf() > 0.75 + nv * 0.3:
				continue
			var hd: Vector2 = world.sample_fast(jx, jz)
			if hd.y < 2.9:
				continue
			var wet := false
			for pd in ponds:
				if Vector2(jx, jz).distance_to(pd.c) < float(pd.r) * 1.05:
					wet = true
					break
			if wet:
				continue
			var sc := _rng.randf_range(0.75, 1.35) * (1.0 + nv * 0.3)
			ChunkWorld._append_xf(buf, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(jx, hd.x - 0.02, jz)))
	multimesh.instance_count = buf.size() / 12
	multimesh.buffer = buf
