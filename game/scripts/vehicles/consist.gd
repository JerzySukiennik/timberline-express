# A rigidly coupled group of rail vehicles sharing one along-track velocity; integrates forces and dead-end stops.
class_name Consist
extends RefCounted

var vehicles: Array[RailVehicle] = []
var v := 0.0
var net: TrackNetwork


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


func step(dt: float) -> Dictionary:
	var M := mass()
	var push := 0.0
	var brake := 0.0
	for veh in vehicles:
		veh.sim(dt, v)
		push += veh.drive_force(v, dt)
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
	var ds := v * dt
	var impact := 0.0
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
