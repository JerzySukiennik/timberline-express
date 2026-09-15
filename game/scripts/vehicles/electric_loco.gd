# Battery-electric loco: main breaker + notched controller draw battery power; a petrol generator recharges it.
class_name ElectricLoco
extends RailVehicle

const BATTERY_KWH := 40.0
const MAX_KW := 90.0
const F_MAX := 32000.0
const GEN_KW := 14.0
const FUEL_MAX := 20.0
const CAN_L := 10.0

var battery := 16.0
var breaker := false
var generator := false
var fuel := 0.0
var direction := 0          # -1, 0, 1
var power_kw := 0.0
var controller: Lever
var brake: Lever
var _breaker_node: Node3D
var _breaker_rest: Basis
var _rev_node: Node3D
var _rev_rest: Basis
var _needles := {}
var _motor: AudioStreamPlayer3D
var _gen_loop: AudioStreamPlayer3D
var _hum: AudioStreamPlayer3D
var _lights: Array[SpotLight3D] = []
var _lamp_mat: StandardMaterial3D
var _gen_lamp_mat: StandardMaterial3D
var _horn_cd := 0.0


func _init() -> void:
	mass = 16000.0
	bogie_half = 2.3
	display_name = "Electric Locomotive"
	surface = "metal"


func setup(network: TrackNetwork, _path := "") -> void:
	super.setup(network, "res://assets/models/vehicles/electric_loco.glb")
	add_box(Vector3(2.5, 0.1, 7.2), Vector3(0, 1.2, 0), "metal")
	add_box(Vector3(2.2, 0.8, 7.0), Vector3(0, 0.8, 0), "metal")
	add_box(Vector3(1.5, 1.1, 2.2), Vector3(0, 1.78, -2.15), "metal")
	add_box(Vector3(1.5, 0.7, 2.2), Vector3(0, 1.58, 2.15), "metal")
	add_box(Vector3(2.5, 0.1, 2.4), Vector3(0, 3.28, 0), "metal")
	add_box(Vector3(0.08, 2.0, 2.0), Vector3(-1.05, 2.23, 0), "metal")
	add_box(Vector3(0.9, 0.9, 1.0), Vector3(0, 2.35, 3.0), "metal")
	for x in [-1.2, 1.2]:
		add_box(Vector3(0.05, 1.0, 2.2), Vector3(x, 1.7, -2.3), "metal")
		add_box(Vector3(0.05, 1.0, 2.2), Vector3(x, 1.7, 2.3), "metal")
	controller = Lever.create(self, "Controller", "M_Controller", "Controller", 0.5, -0.6, Vector3.RIGHT, "y", 0.0035, 0.0, 1.0, 5)
	brake = Lever.create(self, "BrakeValve", "M_BrakeValve", "Brake", 0.0, 1.4, Vector3.UP, "x", 0.004)
	brake.set_value(0.6)
	_breaker_node = part("MainBreaker")
	if _breaker_node:
		_breaker_rest = _breaker_node.basis
	_rev_node = part("Reverser")
	if _rev_node:
		_rev_rest = _rev_node.basis
	for n in ["Battery", "Amps"]:
		var nd := part("Needle" + n)
		if nd:
			_needles[n] = [nd, nd.basis]
	_use_point("M_Breaker", 0.14, func(_p: Node) -> String: return "[E] Main breaker: %s" % ("ON" if breaker else "OFF"), func(_p: Node) -> void: _set_breaker(not breaker))
	_use_point("M_Reverser", 0.12, func(_p: Node) -> String: return "[E] Direction: %s" % ["Reverse", "Neutral", "Forward"][direction + 1], func(_p: Node) -> void: _cycle_direction())
	_use_point("M_Horn", 0.1, func(_p: Node) -> String: return "[E] Horn", func(_p: Node) -> void: _horn())
	_use_point("M_GenButton", 0.12, func(_p: Node) -> String: return "[E] %s generator  ·  fuel %.1f L  ·  battery %d%%" % ["Stop" if generator else "Start", fuel, int(battery / BATTERY_KWH * 100.0)], func(_p: Node) -> void: _toggle_generator())
	_use_point("M_FuelCap", 0.14, _fuel_prompt, _fuel_use)
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.93, 0.75)
	_lamp_mat.emission_energy_multiplier = 0.0
	for nm in ["HeadlightF", "HeadlightR"]:
		var mi := part(nm) as MeshInstance3D
		if mi:
			mi.material_override = _lamp_mat
			var sl := SpotLight3D.new()
			sl.light_color = Color(1.0, 0.93, 0.78)
			sl.spot_range = 45.0
			sl.spot_angle = 24.0
			sl.light_energy = 0.0
			sl.shadow_enabled = false
			add_child(sl)
			sl.global_position = mi.global_position
			if nm == "HeadlightR":
				sl.rotation.y = PI
			_lights.append(sl)
	var gl := part("GenLamp") as MeshInstance3D
	if gl:
		_gen_lamp_mat = StandardMaterial3D.new()
		_gen_lamp_mat.albedo_color = Color(0.1, 0.3, 0.1)
		_gen_lamp_mat.emission_enabled = true
		_gen_lamp_mat.emission = Color(0.3, 1.0, 0.35)
		gl.material_override = _gen_lamp_mat
	_motor = Sfx.loop("electric_motor_loop", self, -80.0, 5.0, 80.0)
	_gen_loop = Sfx.loop("generator_loop", self, -80.0, 4.0, 60.0)
	_gen_loop.position = Vector3(0, 2.3, 3.0)
	_hum = Sfx.loop("electric_hum_loop", self, -80.0, 2.0, 12.0)
	_hum.position = Vector3(0, 2.2, 0)


func _use_point(marker: String, radius: float, prompt: Callable, use: Callable) -> void:
	var m := part(marker)
	if m == null:
		return
	var it := Interactable.make(self, radius, to_local(m.global_position))
	it.prompt = prompt
	it.on_use = use


func _set_breaker(on: bool) -> void:
	breaker = on
	Sfx.play_at("breaker", _breaker_node.global_position if _breaker_node else global_position, -2.0)
	if _breaker_node:
		_breaker_node.basis = _breaker_rest * Basis(Vector3.RIGHT, -1.2 if on else 0.0)


func _cycle_direction() -> void:
	direction = direction + 1 if direction < 1 else -1
	Sfx.play_at("lever", part("M_Reverser").global_position, -6.0)
	if _rev_node:
		_rev_node.basis = _rev_rest * Basis(Vector3.UP, float(direction) * 0.7)


func _horn() -> void:
	if _horn_cd > 0.0:
		return
	_horn_cd = 1.0
	Sfx.play_at("horn", global_position + Vector3(0, 3, 0), 5.0, 0.01, 1.0, 400.0)


func _toggle_generator() -> void:
	if generator:
		generator = false
		Sfx.play_at("gen_stop", to_global(Vector3(0, 2.3, 3.0)), -2.0)
	elif fuel > 0.05:
		generator = true
		Sfx.play_at("gen_start", to_global(Vector3(0, 2.3, 3.0)), -2.0)
	else:
		Sfx.play_at("lever", to_global(Vector3(0, 2.3, 3.0)), -12.0)


func _fuel_prompt(p: Node) -> String:
	var s := "Generator fuel %.1f / %d L" % [fuel, int(FUEL_MAX)]
	if (p.inventory as Inventory).count("jerrycan_fuel") > 0:
		return "[E] Pour fuel  ·  " + s
	return s + "  ·  jerrycans are in the red crate"


func _fuel_use(p: Node) -> void:
	var inv: Inventory = p.inventory
	if inv.count("jerrycan_fuel") <= 0 or fuel > FUEL_MAX - 1.0:
		return
	inv.swap_item("jerrycan_fuel", "jerrycan", p.selected_slot)
	fuel = minf(FUEL_MAX, fuel + CAN_L)
	Sfx.play_at("fuel_pour", part("M_FuelCap").global_position, -2.0)


func sim(dt: float, v: float) -> void:
	_horn_cd = maxf(0.0, _horn_cd - dt)
	if generator:
		fuel -= dt / 90.0
		battery = minf(BATTERY_KWH, battery + GEN_KW * dt / 3600.0 * 20.0)
		if fuel <= 0.0:
			fuel = 0.0
			generator = false
			Sfx.play_at("gen_stop", to_global(Vector3(0, 2.3, 3.0)), -2.0)
	power_kw = 0.0
	if breaker and battery > 0.0 and direction != 0:
		power_kw = controller.stepped() * MAX_KW
		battery = maxf(0.0, battery - power_kw * dt / 3600.0 * 12.0)


func drive_force(v: float, _dt: float) -> float:
	if power_kw <= 0.0:
		return 0.0
	return minf(power_kw * 1000.0 / maxf(absf(v), 2.0), F_MAX) * float(direction)


func brake_amount() -> float:
	return brake.value


func visuals(dt: float, v: float, ds: float) -> void:
	super.visuals(dt, v, ds)
	if _needles.has("Battery"):
		_needles.Battery[0].basis = _needles.Battery[1] * Basis(Vector3.FORWARD, lerpf(2.2, -2.2, battery / BATTERY_KWH))
	if _needles.has("Amps"):
		_needles.Amps[0].basis = _needles.Amps[1] * Basis(Vector3.FORWARD, lerpf(2.2, -2.2, power_kw / MAX_KW))
	var lit := 1.0 if breaker and battery > 0.0 else 0.0
	_lamp_mat.emission_energy_multiplier = lerpf(_lamp_mat.emission_energy_multiplier, lit * 6.0, dt * 8.0)
	for sl in _lights:
		sl.light_energy = lit * 4.0
	if _gen_lamp_mat:
		_gen_lamp_mat.emission_energy_multiplier = 3.0 if generator else 0.0
	_motor.volume_db = linear_to_db(clampf(power_kw / MAX_KW + absf(v) / 20.0, 0.0, 1.0) * 0.9 + 0.0001)
	_motor.pitch_scale = clampf(0.55 + absf(v) / 9.0, 0.55, 2.0)
	_gen_loop.volume_db = -3.0 if generator else -80.0
	_hum.volume_db = -14.0 if breaker else -80.0
