# Steps every consist before the player moves (priority -10), resolves consist-vs-consist buffer impacts.
class_name VehicleSystem
extends Node

var consists: Array[Consist] = []
var net: TrackNetwork
var obstacles: TrackObstacles


func _ready() -> void:
	process_physics_priority = -10


func add(list: Array) -> Consist:
	var c := Consist.new()
	c.net = net
	c.obstacles = obstacles
	c.build(list)
	consists.append(c)
	return c


func _physics_process(dt: float) -> void:
	if Net.is_client_online():
		# the host simulates; clients extrapolate along the rails and get corrected by snapshots
		for c in consists:
			var ds := c.v * dt
			for veh in c.vehicles:
				veh.advance(ds)
			for veh in c.vehicles:
				veh.apply_pose()
				veh.visuals(dt, c.v, ds)
		return
	var steps := {}
	for c in consists:
		steps[c] = c.step(dt)
	_collide(dt)
	for c in consists:
		var st: Dictionary = steps[c]
		Net.mute += 1
		for veh in c.vehicles:
			veh.apply_pose()
			veh.visuals(dt, c.v, st.ds)
		Net.mute -= 1
		if st.impact > 0.6:
			var p := c.lead().global_position if c.v <= 0.0 else c.tail().global_position
			Sfx.play_at("buffer_hit", p, linear_to_db(clampf(st.impact / 4.0, 0.25, 1.0)), 0.1)


func _collide(_dt: float) -> void:
	for i in consists.size():
		for j in range(i + 1, consists.size()):
			var a := consists[i]
			var b := consists[j]
			var ea := a.end_points()
			var eb := b.end_points()
			for ia in 2:
				for ib in 2:
					var pa: Vector3 = ea[ia]
					var pb: Vector3 = eb[ib]
					if pa.distance_to(pb) > 0.35 + absf(a.v - b.v) * 0.05:
						continue
					var sa := 1.0 if ia == 0 else -1.0
					var sb := 1.0 if ib == 0 else -1.0
					var ua := a.v * sa
					var ub := b.v * sb
					if ua + ub <= 0.0:
						continue
					var ma := a.mass()
					var mb := b.mass()
					var e := 0.2
					var xa := ua
					var xb := -ub
					var p := ma * xa + mb * xb
					var na := (p - mb * e * (xa - xb)) / (ma + mb)
					var nb := (p + ma * e * (xa - xb)) / (ma + mb)
					a.v = na * sa
					b.v = -nb * sb
					if ua + ub > 0.6:
						Sfx.play_at("buffer_hit", (pa + pb) * 0.5, linear_to_db(clampf((ua + ub) / 4.0, 0.25, 1.0)), 0.1)
