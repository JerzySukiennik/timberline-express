# A rigidly coupled group of rail vehicles sharing one along-track velocity; integrates forces and dead-end stops.
class_name Consist
extends RefCounted

var vehicles: Array[RailVehicle] = []
var v := 0.0
var net: TrackNetwork
var obstacles: TrackObstacles


func mass() -> float:
	var m := 0.0
	for veh in vehicles:
		m += veh.mass
	return m


func lead() -> RailVehicle:
	return vehicles[0]


func tail() -> RailVehicle:
	return vehicles[vehicles.size() - 1]


## Couple vehicles front-to-back starting from the lead's current position.
func build(list: Array) -> void:
	for veh in list:
		vehicles.append(veh)
		veh.consist = self
	for i in range(1, vehicles.size()):
		var prev := vehicles[i - 1]
		var cur := vehicles[i]
		var c := prev.center_cursor()
		c.move(-(prev.coupler_rear + cur.coupler_front + 0.05), false)
		cur.place(c)


## Re-lay every vehicle behind the lead (after teleporting the lead).
func reposition() -> void:
	for i in range(1, vehicles.size()):
		var prev := vehicles[i - 1]
		var cur := vehicles[i]
		var c := prev.center_cursor()
		c.move(-(prev.coupler_rear + cur.coupler_front + 0.05), false)
		cur.place(c)


func step(dt: float) -> Dictionary:
	var M := mass()
	var push := 0.0
	var brake := 0.0
	var any_broken := false
	for veh in vehicles:
		veh.sim(dt, v)
		if veh.broken():
			any_broken = true
		push += veh.drive_force(v, dt) if not veh.broken() else 0.0
		push -= veh.mass * RailVehicle.G * veh.forward().y
		brake += veh.brake_amount() * 0.2 * veh.mass * RailVehicle.G
	var roll := 0.0025 * M * RailVehicle.G
	var drag := 0.9 * v * absf(v)
	var nv := v + (push - drag) / M * dt
	var fr := (roll + brake) / M * dt
	if absf(nv) <= fr:
		nv = 0.0 if absf(push) <= roll + brake else nv
	else:
		nv -= signf(nv) * fr
	v = nv
	if any_broken:
		brake += 0.6 * M * RailVehicle.G
	var ds := v * dt
	var impact := 0.0
	if obstacles and absf(ds) > 0.0:
		var end_v := lead() if ds > 0.0 else tail()
		var end_pos := end_v.end_cursor(ds > 0.0).position()
		var fwd := end_v.forward() * signf(ds)
		var blk := obstacles.blocking_distance(end_pos, fwd)
		if blk.d < absf(ds) + 0.25:
			var o: Dictionary = blk.o
			var speed := absf(v)
			var plow := lead().has_plow and ds > 0.0 and str(o.kind) != "gap"
			if plow and speed > 3.0 and str(o.kind) == "tree":
				if is_instance_valid(o.node):
					o.node.queue_free()
				obstacles.clear(o.id)
				Sfx.play_at("plow_impact", end_pos, 2.0)
				v *= 0.7
				end_v.damage(speed * 0.8)
			else:
				ds = signf(ds) * maxf(blk.d - 0.25, 0.0)
				if speed > 2.0:
					end_v.damage(speed * speed * 0.9)
					Sfx.play_at("metal_crash" if str(o.kind) != "tree" else "wood_crash", end_pos, 3.0)
				impact = speed
				v = -v * 0.1
	if absf(ds) > 0.0:
		var probe := lead().end_cursor(true) if ds > 0.0 else tail().end_cursor(false)
		var left := probe.move(ds + signf(ds) * 0.02, false)
		if left != 0.0:
			ds -= left
			if signf(ds) != signf(v) and absf(ds) > 0.0:
				ds = 0.0
			impact = absf(v)
			v = -v * 0.12
	for veh in vehicles:
		veh.advance(ds)
	return {"ds": ds, "impact": impact}


func end_points() -> Array:
	return [lead().end_cursor(true).position(), tail().end_cursor(false).position()]
