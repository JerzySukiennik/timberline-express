# Pump handcar: drag a beam handle in rhythm with the crank to push; brake lever and direction lever.
class_name Handcar
extends RailVehicle

const CYCLE := 3.2        # metres travelled per full pump cycle
const BEAM_AMP := 0.32    # radians
const PUMP_FORCE := 1400.0
const MAX_PUMP_SPEED := 8.5

var direction := 1.0
var brake: Lever
var _beam: Node3D
var _rod: Node3D
var _crank: Node3D
var _dir_lever: Node3D
var _dir_rest: Basis
var _pump_force := 0.0
var _pump_rate := 0.0
var _last_beam_dir := 0.0
var pumping_player: Node = null


func _init() -> void:
	mass = 420.0
	bogie_half = 0.75
	display_name = "Handcar"
	surface = "wood"


func setup(network: TrackNetwork, _path := "") -> void:
	super.setup(network, "res://assets/models/vehicles/handcar.glb")
	add_box(Vector3(1.9, 0.12, 2.6), Vector3(0, 0.67, 0), "wood")
	add_box(Vector3(0.5, 1.0, 0.7), Vector3(0, 1.23, 0), "wood")
	_beam = part("PumpBeam")
	_rod = part("PumpRod")
	_crank = part("Crank")
	_dir_lever = part("DirLever")
	if _dir_lever:
		_dir_rest = _dir_lever.basis
	for m in ["M_PumpHandleF", "M_PumpHandleR"]:
		var mk := part(m)
		var front: bool = m.ends_with("F")
		for side in [-0.42, 0.0, 0.42]:
			var it := Interactable.make(self, 0.16, to_local(mk.global_position) + Vector3(side, 0, 0))
			it.prompt = func(_p: Node) -> String: return "[Hold LMB] Grab pump — move the mouse or hold W  ·  %d km/h" % int(absf(consist.v) * 3.6)
			it.grab_drag = func(p: Node, rel: Vector2) -> void: _pump(p, rel, front)
			it.grab_start = func(p: Node) -> void: pumping_player = p
			it.grab_end = func(_p: Node) -> void: pumping_player = null
			it.hand_point = Node3D.new()
			_beam.add_child(it.hand_point)
			it.hand_point.global_position = mk.global_position + global_basis.x * side
	brake = Lever.create(self, "BrakeLever", "M_BrakeGrip", "Brake", 0.0, 0.55, Vector3.RIGHT, "y", -0.004)
	var dk := part("M_DirKnob")
	var dir_it := Interactable.make(self, 0.14, to_local(dk.global_position))
	dir_it.prompt = func(_p: Node) -> String: return "[E] Direction: %s" % ("Forward" if direction > 0 else "Reverse")
	dir_it.on_use = func(_p: Node) -> void:
		direction = -direction
		Sfx.play_at("lever", dk.global_position, -4.0)
		if _dir_lever:
			_dir_lever.basis = _dir_rest * Basis(Vector3.RIGHT, 0.0 if direction > 0 else 0.6)


func _phase() -> float:
	return travel / CYCLE * TAU


## Any up/down stroke of the handle pushes the car in the selected direction; faster strokes push harder.
func _pump(p: Node, rel: Vector2, _front: bool) -> void:
	var stroke := absf(rel.y) + absf(rel.x) * 0.3
	add_pump(p, clampf(stroke / 18.0, 0.0, 1.6))


func add_pump(p: Node, strength: float) -> void:
	if strength <= 0.0:
		return
	if brake.value > 0.0:
		brake.set_value(0.0)
	var push := PUMP_FORCE * strength * clampf(1.0 - absf(consist.v) / MAX_PUMP_SPEED, 0.08, 1.0)
	_pump_force = maxf(_pump_force, push)
	_pump_rate = strength
	if p and "stamina" in p:
		p.stamina = maxf(0.0, p.stamina - strength * 0.25)


func _physics_process(_dt: float) -> void:
	# holding W while on the pump handle pumps at a steady pace
	var pp := pumping_player as Player
	if pp and is_instance_valid(pp) and ((pp.net_peer == 0 and Input.is_action_pressed("move_forward") and pp.input_enabled) or (pp.net_peer != 0 and pp.remote_forward)):
		add_pump(pumping_player, 0.8)


func drive_force(_v: float, _dt: float) -> float:
	var f := _pump_force * direction
	_pump_force *= 0.9
	return f


func brake_amount() -> float:
	return brake.value


func visuals(dt: float, v: float, ds: float) -> void:
	super.visuals(dt, v, ds)
	var ph := _phase()
	var theta := BEAM_AMP * sin(ph)
	if _beam:
		_beam.basis = Basis(Vector3.RIGHT, theta)
	if _crank:
		_crank.basis = Basis(Vector3.RIGHT, -ph)
	if _rod and _beam:
		var top := _beam.position + Basis(Vector3.RIGHT, theta) * Vector3(0, 0, -0.30)
		var bottom := _crank.position + Basis(Vector3.RIGHT, -ph) * Vector3(0, 0.12, -0.0) if _crank else top - Vector3(0, 1, 0)
		var d := top - bottom
		var y := d.normalized()
		var x := Vector3.RIGHT
		var z := x.cross(y).normalized()
		_rod.transform = Transform3D(Basis(x, y, z).scaled(Vector3(1, d.length() / 1.0, 1)), top)
	var beam_dir := signf(cos(ph) * v)
	if beam_dir != _last_beam_dir and absf(v) > 0.3:
		_last_beam_dir = beam_dir
		Sfx.play_at("pump", _beam.global_position if _beam else global_position, -6.0 + clampf(absf(v), 0, 6), 0.12)
