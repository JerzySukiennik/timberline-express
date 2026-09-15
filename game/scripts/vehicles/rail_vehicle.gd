# Base rail vehicle: rides two bogie cursors on the TrackNetwork, exposes forces to its Consist, animates wheels.
class_name RailVehicle
extends AnimatableBody3D

const G := 9.81

var net: TrackNetwork
var consist: Consist
var model: Node3D
var mass := 1000.0
var bogie_half := 1.0
var coupler_front := 1.5
var coupler_rear := 1.5
var cursor_f: TrackNetwork.Cursor
var cursor_r: TrackNetwork.Cursor
var wheels: Array = []          # [{node, radius}]
var travel := 0.0               # signed distance travelled
var last_delta := Transform3D.IDENTITY
var surface := "wood"
var display_name := "Vehicle"
var _clack_acc := 0.0
var _roll: AudioStreamPlayer3D
var _squeal: AudioStreamPlayer3D


func setup(network: TrackNetwork, model_path: String) -> void:
	net = network
	sync_to_physics = false
	collision_layer = 4 | 1
	collision_mask = 0
	set_meta("surface", surface)
	model = (load(model_path) as PackedScene).instantiate() as Node3D
	add_child(model)
	for n in model.find_children("Wheel_*", "", true, false):
		var nd := n as Node3D
		var r := 0.3
		var aabb := _aabb(nd)
		if aabb.size.y > 0.01:
			r = aabb.size.y * 0.5 / 1.08
		wheels.append({"node": nd, "radius": r})
	var mf := part("M_CouplerF")
	var mr := part("M_CouplerR")
	if mf:
		coupler_front = absf(mf.position.z)
	if mr:
		coupler_rear = absf(mr.position.z)
	_roll = Sfx.loop("rail_roll_loop", self, -80.0, 6.0, 70.0)
	_squeal = Sfx.loop("brake_squeal_loop", self, -80.0, 6.0, 70.0)


func part(n: String) -> Node3D:
	return model.find_child(n, true, false) as Node3D


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var a := (mi as MeshInstance3D).get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	if n is MeshInstance3D:
		var a := (n as MeshInstance3D).get_aabb()
		out = a if first else out.merge(a)
	return out


func add_box(size: Vector3, center: Vector3, surf := "") -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = center
	if surf != "":
		cs.set_meta("surface", surf)
	add_child(cs)
	return cs


func place(center: TrackNetwork.Cursor) -> void:
	cursor_f = center.copy()
	cursor_f.move(bogie_half, false)
	cursor_r = center.copy()
	cursor_r.move(-bogie_half, false)
	apply_pose(true)


func center_cursor() -> TrackNetwork.Cursor:
	var c := cursor_r.copy()
	c.move(bogie_half, false)
	return c


func advance(ds: float) -> void:
	cursor_f.move(ds)
	cursor_r.move(ds)
	travel += ds


func apply_pose(teleport := false) -> void:
	var pf := cursor_f.position()
	var pr := cursor_r.position()
	var fwd := (pf - pr)
	fwd = fwd.normalized() if fwd.length() > 0.001 else cursor_f.forward()
	var z := -fwd
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x).normalized()
	var xf := Transform3D(Basis(x, y, z), (pf + pr) * 0.5)
	last_delta = Transform3D.IDENTITY if teleport else xf * global_transform.affine_inverse()
	global_transform = xf


func forward() -> Vector3:
	return -global_basis.z


## Positive pushes the vehicle forward (N). Override in powered vehicles.
func drive_force(_v: float, _dt: float) -> float:
	return 0.0


## 0..1 brake application.
func brake_amount() -> float:
	return 0.0


func sim(_dt: float, _v: float) -> void:
	pass


func visuals(dt: float, v: float, ds: float) -> void:
	for w in wheels:
		(w.node as Node3D).rotate_object_local(Vector3.RIGHT, -ds / float(w.radius))
	var speed := absf(v)
	if _roll:
		_roll.volume_db = linear_to_db(clampf(speed / 8.0, 0.0, 1.0) * 0.8 + 0.0001) - 2.0
		_roll.pitch_scale = clampf(0.7 + speed / 14.0, 0.7, 1.6)
	if _squeal:
		var sq := clampf(brake_amount() * speed / 3.0, 0.0, 1.0)
		_squeal.volume_db = linear_to_db(sq * 0.6 + 0.0001)
	_clack_acc += absf(ds)
	if _clack_acc > 12.5:
		_clack_acc = 0.0
		if speed > 1.0:
			Sfx.play_at("rail_clack", global_position, linear_to_db(clampf(speed / 10.0, 0.2, 1.0)) - 4.0, 0.08, clampf(0.8 + speed / 20.0, 0.8, 1.3))


func end_cursor(front: bool) -> TrackNetwork.Cursor:
	if front:
		var c := cursor_f.copy()
		c.move(coupler_front - bogie_half, false)
		return c
	var c2 := cursor_r.copy()
	c2.move(-(coupler_rear - bogie_half), false)
	return c2
