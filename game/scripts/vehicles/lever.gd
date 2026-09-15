# Draggable control: maps mouse drag to a 0..1 (or -1..1) value, rotates a model part, optional notches with clicks.
class_name Lever
extends RefCounted

var value := 0.0
var min_v := 0.0
var max_v := 1.0
var node: Node3D
var axis := Vector3.RIGHT
var angle_min := 0.0
var angle_max := 0.5
var drag_axis := "y"          # "x" or "y"
var sensitivity := 0.004
var notches := 0              # 0 = continuous
var label := "Lever"
var sound := "lever"
var _rest: Basis
var _last_notch := -999
var interact: Interactable


static func create(vehicle: RailVehicle, part_name: String, marker: String, lbl: String, a_min: float, a_max: float, rot_axis := Vector3.RIGHT, drag := "y", sens := 0.004, vmin := 0.0, vmax := 1.0, notch := 0) -> Lever:
	var l := Lever.new()
	l.node = vehicle.part(part_name)
	l.label = lbl
	l.angle_min = a_min
	l.angle_max = a_max
	l.axis = rot_axis
	l.drag_axis = drag
	l.sensitivity = sens
	l.min_v = vmin
	l.max_v = vmax
	l.value = clampf(0.0, vmin, vmax)
	l.notches = notch
	if l.node:
		l._rest = l.node.basis
	var m := vehicle.part(marker)
	var pos := vehicle.to_local(m.global_position) if m else Vector3.ZERO
	l.interact = Interactable.make(vehicle, 0.14, pos)
	l.interact.prompt = func(_p: Node) -> String: return "[Hold LMB + drag] %s  %s" % [l.label, l.readout()]
	l.interact.grab_drag = func(_p: Node, rel: Vector2) -> void: l.drag(rel)
	l.apply()
	return l


func readout() -> String:
	if min_v < 0.0:
		return "%+d%%" % int(round(value * 100.0))
	return "%d%%" % int(round((value - min_v) / (max_v - min_v) * 100.0))


func drag(rel: Vector2) -> void:
	var d := (-rel.y if drag_axis == "y" else rel.x) * sensitivity
	set_value(value + d)


func set_value(v: float) -> void:
	value = clampf(v, min_v, max_v)
	if notches > 0:
		var n := int(round((value - min_v) / (max_v - min_v) * notches))
		if n != _last_notch:
			if _last_notch != -999:
				Sfx.play_at(sound, node.global_position if node else Vector3.ZERO, -8.0, 0.15)
			_last_notch = n
	apply()


func stepped() -> float:
	if notches <= 0:
		return value
	return min_v + round((value - min_v) / (max_v - min_v) * notches) / notches * (max_v - min_v)


func apply() -> void:
	if node:
		var t := (stepped() - min_v) / (max_v - min_v)
		node.basis = _rest * Basis(axis, lerpf(angle_min, angle_max, t))
