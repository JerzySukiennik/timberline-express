# Deterministic world functions from a seed: terrain height, forest density, and the region grid of rail nodes.
# Rails run east-west along region rows (valleys); some nodes get a north connector over a mountain pass.
class_name WorldGen
extends RefCounted

const REGION := 640.0
const JITTER := 90.0

var seed := 1
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _forest := FastNoiseLite.new()
var _warp := FastNoiseLite.new()


func _init(s: int) -> void:
	seed = s
	_hills.seed = s
	_hills.frequency = 0.0022
	_hills.fractal_octaves = 3
	_detail.seed = s + 11
	_detail.frequency = 0.03
	_detail.fractal_octaves = 2
	_ridge.seed = s + 23
	_ridge.frequency = 0.0035
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 4
	_forest.seed = s + 37
	_forest.frequency = 0.008
	_forest.fractal_octaves = 3
	_warp.seed = s + 41
	_warp.frequency = 0.004


func hash2(i: int, j: int, salt := 0) -> float:
	var h := (i * 73856093) ^ (j * 19349663) ^ (seed * 83492791) ^ (salt * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / float(0xFFFFFF)


# ---------------------------------------------------------------- rail grid

## Node world position for region cell (i, j). Row j lies along z = -j * REGION (north is -z).
func node_xz(i: int, j: int) -> Vector2:
	return Vector2(i * REGION + (hash2(i, j, 1) - 0.5) * JITTER * 2.0, -j * REGION + (hash2(i, j, 2) - 0.5) * JITTER)


## Connector from (i, j) north to (i, j+1). Only on even i+j so a node never has two branches.
func has_connector(i: int, j: int) -> bool:
	if (i + j) % 2 != 0:
		return false
	if i == 0 and j == 0:
		return true
	return hash2(i, j, 3) < 0.45


func has_branch(i: int, j: int) -> bool:
	return has_connector(i, j) or has_connector(i, j - 1)


func node_height(i: int, j: int) -> float:
	var p := node_xz(i, j)
	var h := 0.0
	for o in [Vector2.ZERO, Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40)]:
		h += base_height(p.x + o.x, p.y + o.y)
	return h / 5.0


# ---------------------------------------------------------------- terrain

## Distance (in z) from the nearest rail row and whether a pass (connector) is nearby.
func _valley_factor(x: float, z: float) -> float:
	var jf := -z / REGION
	var j := int(round(jf))
	var dz := absf(jf - j) * REGION
	var wz := _warp.get_noise_2d(x, z) * 25.0
	var mountain := smoothstep(215.0, 320.0, dz + wz)
	# carve passes where connectors cross between rows
	var i := int(round(x / REGION))
	for di in [-1, 0, 1]:
		var ii: int = i + di
		var jlow := int(floor(jf))
		if has_connector(ii, jlow):
			var cx := node_xz(ii, jlow).x + 190.0
			var dx := absf(x - cx)
			mountain *= smoothstep(120.0, 330.0, dx)
	return mountain


func base_height(x: float, z: float) -> float:
	var h := _hills.get_noise_2d(x, z) * 22.0 + _detail.get_noise_2d(x, z) * 1.2
	var m := _valley_factor(x, z)
	var r := (_ridge.get_noise_2d(x, z) * 0.5 + 0.5)
	h += m * (70.0 + r * 190.0)
	return h


func forest_density(x: float, z: float, height: float) -> float:
	var f := _forest.get_noise_2d(x, z) * 0.5 + 0.55
	f *= 1.0 - smoothstep(150.0, 230.0, height)   # tree line
	return clampf(f, 0.0, 1.0)


func slope(x: float, z: float) -> float:
	var hx := base_height(x + 1.5, z) - base_height(x - 1.5, z)
	var hz := base_height(x, z + 1.5) - base_height(x, z - 1.5)
	return Vector2(hx, hz).length() / 3.0


# ---------------------------------------------------------------- ponds

## Up to two small flat-bottomed ponds per region cell, only on gentle ground near the valley floor.
func ponds_near(x: float, z: float) -> Array:
	var out := []
	var ci := int(round(x / REGION))
	var cj := int(round(-z / REGION))
	for di in [-1, 0, 1]:
		for dj in [-1, 0, 1]:
			var i: int = ci + di
			var j: int = cj + dj
			for k in 6:
				if hash2(i, j, 40 + k) > 0.75:
					continue
				var nx := node_xz(i, j)
				var side := 1.0 if hash2(i, j, 50 + k) > 0.5 else -1.0
				var c := Vector2(nx.x + (hash2(i, j, 60 + k) - 0.5) * REGION * 0.9, nx.y + side * (45.0 + hash2(i, j, 70 + k) * 95.0))
				out.append({"c": c, "r": 7.0 + hash2(i, j, 80 + k) * 12.0, "key": Vector3i(i, j, k)})
	return out


## Cached pond definitions with water level, filtered by slope. Safe to call from worker threads.
var _pond_cache := {}
var _pond_mutex := Mutex.new()


func pond(defn: Dictionary) -> Dictionary:
	var key: Vector3i = defn.key
	_pond_mutex.lock()
	var cached: Variant = _pond_cache.get(key)
	_pond_mutex.unlock()
	if cached != null:
		return cached
	var c: Vector2 = defn.c
	var r: float = defn.r
	var valid := slope(c.x, c.y) < 0.16 and base_height(c.x, c.y) < 60.0
	var lowest := INF
	for a in 8:
		var q := c + Vector2(cos(a * TAU / 8.0), sin(a * TAU / 8.0)) * r * 1.2
		lowest = minf(lowest, base_height(q.x, q.y))
	var res := {"c": c, "r": r, "level": lowest - 0.35, "depth": 1.4 + r * 0.06, "valid": valid}
	_pond_mutex.lock()
	_pond_cache[key] = res
	_pond_mutex.unlock()
	return res


func carve_ponds(x: float, z: float, h: float, ponds: Array) -> float:
	for p in ponds:
		if not p.valid:
			continue
		var d := Vector2(x, z).distance_to(p.c)
		var r: float = p.r
		if d > r * 1.6:
			continue
		var bowl: float = p.level - p.depth * (1.0 - clampf(d / r, 0.0, 1.0) * clampf(d / r, 0.0, 1.0))
		if d < r:
			h = minf(h, bowl)
		else:
			var k := smoothstep(r * 1.6, r, d)
			h = minf(h, lerpf(h, p.level + 0.15, k))
	return h


# ---------------------------------------------------------------- rail geometry

static func hermite(p0: Vector2, t0: Vector2, p1: Vector2, t1: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return p0 * (2 * t3 - 3 * t2 + 1) + t0 * (t3 - 2 * t2 + t) + p1 * (-2 * t3 + 3 * t2) + t1 * (t3 - t2)


## Polyline for an edge between two nodes with given start/end directions and a gentle lateral wander.
func edge_points(a: Vector2, dir_a: Vector2, ha: float, b: Vector2, dir_b: Vector2, hb: float, tangent_len: float, salt: int) -> PackedVector3Array:
	var n := maxi(int(a.distance_to(b) * 1.6 / 4.0), 40)
	var raw: Array[Vector2] = []
	var chord := (b - a).normalized()
	var perp := Vector2(-chord.y, chord.x)
	var amp := 12.0 + hash2(salt, 7, 5) * 22.0
	var freq: float = 1.0 + floor(hash2(salt, 9, 6) * 2.0)
	for k in n + 1:
		var t := float(k) / n
		var p := hermite(a, dir_a * tangent_len, b, dir_b * tangent_len, t)
		var w := sin(t * PI)
		p += perp * sin(t * PI * freq + hash2(salt, 3, 8) * TAU) * amp * w * w
		raw.append(p)
	# resample to even ~4 m spacing
	var pts2: Array[Vector2] = [raw[0]]
	var acc := 0.0
	for k in range(1, raw.size()):
		var seg_len := raw[k].distance_to(raw[k - 1])
		acc += seg_len
		if acc >= 4.0 or k == raw.size() - 1:
			pts2.append(raw[k])
			acc = 0.0
	# height profile: terrain, smoothed, grade-limited, anchored to node heights
	var hs := PackedFloat32Array()
	for p in pts2:
		hs.append(base_height(p.x, p.y))
	hs = _smooth(hs, 14)
	var m := hs.size()
	for k in m:
		var t := float(k) / maxf(m - 1, 1)
		hs[k] += (1.0 - t) * (ha - hs[0]) + t * (hb - hs[m - 1])
	for _iter in 3:
		for k in range(1, m):
			hs[k] = clampf(hs[k], hs[k - 1] - 4.0 * 0.045, hs[k - 1] + 4.0 * 0.045)
		for k in range(m - 2, -1, -1):
			hs[k] = clampf(hs[k], hs[k + 1] - 4.0 * 0.045, hs[k + 1] + 4.0 * 0.045)
		var da := ha - hs[0]
		var db := hb - hs[m - 1]
		for k in m:
			var t2 := float(k) / maxf(m - 1, 1)
			hs[k] += (1.0 - t2) * da + t2 * db
	var out := PackedVector3Array()
	for k in m:
		out.append(Vector3(pts2[k].x, hs[k], pts2[k].y))
	return out


static func _smooth(a: PackedFloat32Array, radius: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in a.size():
		var s := 0.0
		var c := 0
		for k in range(maxi(0, i - radius), mini(a.size(), i + radius + 1)):
			s += a[k]
			c += 1
		out[i] = s / c
	return out
