# Small tank-style steam loco: firebox energy -> boiler pressure (needs water from the tender) -> tractive force.
class_name SteamLoco
extends RailVehicle

const MAX_P := 12.0
const VALVE_P := 11.0
const F_MAX := 30000.0

var tender: Tender
var energy := 0.0          # MJ of fuel in the firebox
var fire := 0.0            # 0..1 visual/thermal fire intensity
var pressure := 0.0        # bar
var door_open := false
var valve := 100.0          # safety valve condition; a worn valve sticks and the boiler can explode
var regulator: Lever
var reverser: Lever
var brake: Lever
var _door: Node3D
var _door_rest: Basis
var _needle: Node3D
var _needle_rest: Basis
var _water: Node3D
var _glow_mat: StandardMaterial3D
var _fire_light: OmniLight3D
var _smoke: GPUParticles3D
var _steam: GPUParticles3D
var _fire_loop: AudioStreamPlayer3D
var _idle_loop: AudioStreamPlayer3D
var _valve_loop: AudioStreamPlayer3D
var _chuff_acc := 0.0
var _whistle_cd := 0.0


func _init() -> void:
	mass = 14000.0
	bogie_half = 0.75
	display_name = "Steam Locomotive"
	surface = "metal"


func setup(network: TrackNetwork, _path := "") -> void:
	super.setup(network, "res://assets/models/vehicles/steam_loco.glb")
	add_box(Vector3(2.1, 0.1, 1.9), Vector3(0, 1.11, 2.0), "planks")
	add_box(Vector3(0.42, 0.06, 3.6), Vector3(-0.98, 1.1, -0.9), "metal")
	add_box(Vector3(0.42, 0.06, 3.6), Vector3(0.98, 1.1, -0.9), "metal")
	add_box(Vector3(1.4, 1.4, 4.3), Vector3(0, 1.8, -0.6), "metal")
	add_box(Vector3(2.2, 0.9, 5.8), Vector3(0, 0.75, -0.15), "metal")
	add_box(Vector3(2.4, 0.08, 2.2), Vector3(0, 3.12, 1.95), "metal")
	add_box(Vector3(0.08, 1.0, 1.9), Vector3(-1.08, 1.66, 2.0), "metal")
	add_box(Vector3(0.08, 1.0, 1.9), Vector3(1.08, 1.66, 2.0), "metal")
	add_box(Vector3(2.2, 1.95, 0.1), Vector3(0, 2.12, 0.98), "metal")
	_door = part("FireboxDoor")
	if _door:
		_door_rest = _door.basis
	_needle = part("NeedlePressure")
	if _needle:
		_needle_rest = _needle.basis
	_water = part("WaterLevel")
	var glow := part("FireGlow") as MeshInstance3D
	if glow:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.albedo_color = Color(0.05, 0.02, 0.0)
		_glow_mat.emission_enabled = true
		_glow_mat.emission = Color(1.0, 0.42, 0.1)
		glow.material_override = _glow_mat
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.55, 0.22)
	_fire_light.omni_range = 3.2
	_fire_light.light_energy = 0.0
	_fire_light.shadow_enabled = false
	add_child(_fire_light)
	_fire_light.position = to_local(part("M_FireDoor").global_position) + Vector3(0, 0.1, 0.4)
	regulator = Lever.create(self, "Regulator", "M_Regulator", "Regulator", 0.0, -1.1, Vector3.FORWARD, "x", 0.003)
	reverser = Lever.create(self, "Reverser", "M_Reverser", "Reverser", -0.45, 0.45, Vector3.RIGHT, "y", 0.004, -1.0, 1.0, 8)
	brake = Lever.create(self, "BrakeHandle", "M_Brake", "Brake", 0.0, 0.7, Vector3.RIGHT, "y", -0.004)
	brake.set_value(0.6)
	var fd := part("M_FireDoor")
	var door_it := Interactable.make(self, 0.22, to_local(fd.global_position))
	door_it.prompt = _door_prompt
	door_it.on_use = _door_use
	door_it.on_secondary = func(_p: Node) -> void: _set_door(false)
	var wm := part("M_Whistle")
	var wh := Interactable.make(self, 0.12, to_local(wm.global_position))
	wh.prompt = func(_p: Node) -> String: return "[E] Whistle"
	wh.on_use = func(_p: Node) -> void: _whistle()
	_smoke = _make_particles(part("M_Smoke").global_position, Color(0.18, 0.17, 0.16, 0.7), 1.2, Vector3(0, 3.0, 0), 5.0)
	_steam = _make_particles(part("M_SafetyValve").global_position, Color(0.95, 0.95, 0.95, 0.55), 0.35, Vector3(0, 4.5, 0), 1.6)
	_steam.emitting = false
	_fire_loop = Sfx.loop("fire_roar_loop", self, -80.0, 3.0, 25.0)
	_fire_loop.position = _fire_light.position
	_idle_loop = Sfx.loop("steam_idle_loop", self, -80.0, 4.0, 40.0)
	_valve_loop = Sfx.loop("safety_valve_loop", self, -80.0, 8.0, 120.0)
	_valve_loop.position = to_local(part("M_SafetyValve").global_position)


func _make_particles(world_pos: Vector3, col: Color, size: float, vel: Vector3, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = life
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = vel.normalized()
	pm.spread = 12.0
	pm.initial_velocity_min = vel.length() * 0.7
	pm.initial_velocity_max = vel.length()
	pm.gravity = Vector3(0.4, 0.6, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 3.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, col)
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	var tex := GradientTexture2D.new()
	var rg := Gradient.new()
	rg.set_color(0, Color(1, 1, 1, 1))
	rg.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = rg
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	m.albedo_texture = tex
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	p.global_position = world_pos
	return p


func _door_prompt(p: Node) -> String:
	if not door_open:
		return "[E] Open firebox  ·  %.1f bar" % pressure
	var inv: Inventory = p.inventory
	var coal := inv.count("coal")
	var logs := inv.count("log")
	if coal > 0:
		return "[E] Shovel coal (%d)  ·  [RMB] Close" % coal
	if logs > 0:
		return "[E] Add log (%d)  ·  [RMB] Close" % logs
	return "No fuel — grab coal or logs from the crates  ·  [E] Close"


func _door_use(p: Node) -> void:
	if not door_open:
		_set_door(true)
		return
	var inv: Inventory = p.inventory
	for id in ["coal", "log"]:
		if inv.count(id) > 0:
			inv.remove(id, 1)
			var mj := float(Items.def(id).fuel_kg) * (30.0 if id == "coal" else 15.0)
			energy = minf(energy + mj, 600.0)
			Sfx.play_at("coal" if id == "coal" else "wood_fire", _door.global_position, -2.0)
			if p.has_method("play_hand_gesture"):
				p.play_hand_gesture("toss")
			return
	_set_door(false)


func _set_door(open: bool) -> void:
	if open == door_open:
		return
	door_open = open
	Sfx.play_at("firedoor_open" if open else "firedoor_close", _door.global_position, -3.0)
	var tw := create_tween()
	tw.tween_property(_door, "basis", _door_rest * Basis(Vector3.UP, -1.9 if open else 0.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _whistle() -> void:
	if _whistle_cd > 0.0:
		return
	_whistle_cd = 1.2
	Sfx.play_at("whistle", part("M_Whistle").global_position + Vector3(0, 0.8, 0), 4.0, 0.02, 1.0, 400.0)
	_steam.restart()
	_steam.emitting = true


func water() -> float:
	return tender.water if tender else 0.0


func sim(dt: float, v: float) -> void:
	_whistle_cd = maxf(0.0, _whistle_cd - dt)
	var draft := clampf(regulator.value * absf(v) / 6.0, 0.0, 1.0) + (0.15 if not door_open else 0.05)
	var burn := minf(energy, (0.45 + 1.2 * draft) * dt) if energy > 0.0 else 0.0
	energy -= burn
	fire = lerpf(fire, clampf(energy / 60.0, 0.0, 1.0), dt * 0.8)
	var heat := burn / dt * fire * (0.75 if door_open else 1.0)
	var steam_use := regulator.value * (0.03 + 0.035 * absf(v)) * (0.35 + 0.65 * absf(reverser.stepped()))
	if water() > 15.0:
		pressure += (heat * 0.2 - 0.004 * pressure - steam_use) * dt
		if tender:
			tender.water = maxf(0.0, tender.water - (heat * 0.25 + steam_use * 6.0) * dt)
	else:
		pressure -= (0.05 + steam_use) * dt
	pressure = clampf(pressure, 0.0, MAX_P if valve > 0.0 else MAX_P + 2.0)
	var venting := pressure > VALVE_P and valve > 0.0
	if pressure > VALVE_P:
		valve = maxf(0.0, valve - dt * 1.2)
	if venting:
		pressure = VALVE_P
	if pressure >= MAX_P - 0.05 and valve <= 0.0:
		_explode()
	_valve_loop.volume_db = lerpf(_valve_loop.volume_db, 2.0 if venting else -80.0, dt * 6.0)
	if venting and not _steam.emitting:
		_steam.emitting = true
	elif not venting and _whistle_cd <= 0.0:
		_steam.emitting = false


func _explode() -> void:
	pressure = 0.0
	energy = 0.0
	fire = 0.0
	valve = 60.0
	Sfx.play_at("boiler_explosion", global_position + Vector3.UP * 1.8, 8.0, 0.02, 1.0, 400.0)
	Sfx.play_at("steam_burst", global_position + Vector3.UP * 1.8, 4.0)
	Fx.burst(get_tree().current_scene, global_position + Vector3.UP * 2.0, Vector3.UP, "dust", 30)
	damage(70.0)
	for c in [consist.vehicles]:
		for veh in c:
			if veh != self and veh.global_position.distance_to(global_position) < 10.0:
				veh.damage(25.0)
	var pl = get_tree().get_first_node_in_group("player")
	if pl:
		var d := (pl as Node3D).global_position.distance_to(global_position)
		if d < 14.0:
			pl.survival.damage(lerpf(85.0, 5.0, d / 14.0), "a boiler explosion")
			pl.velocity += ((pl as Node3D).global_position - global_position).normalized() * 9.0 + Vector3.UP * 5.0


func drive_force(v: float, _dt: float) -> float:
	var r := reverser.stepped()
	if absf(r) < 0.05 or pressure < 0.5 or broken():
		return 0.0
	var falloff := clampf(1.0 - absf(v) / 16.0, 0.05, 1.0)
	return regulator.value * r * (pressure / 10.0) * F_MAX * falloff


func brake_amount() -> float:
	return brake.value


func visuals(dt: float, v: float, ds: float) -> void:
	super.visuals(dt, v, ds)
	for side in ["L", "R"]:
		var rod := part("CouplingRod_" + side)
		if rod:
			var a: float = travel / 0.55
			var off := 0.0 if side == "L" else PI * 0.5
			rod.position = Vector3(rod.position.x, 0.55 + cos(a + off) * 0.22 - 0.0, rod.position.z)
			rod.set_meta("phase", a)
			var zc := -0.2
			rod.position.z = zc + sin(a + off) * 0.22
		var pr := part("PistonRod_" + side)
		if pr:
			var a2: float = travel / 0.55 + (0.0 if side == "L" else PI * 0.5)
			pr.position.z = -1.3 + sin(a2) * 0.22
	if _needle:
		_needle.basis = _needle_rest * Basis(Vector3.FORWARD, lerpf(2.2, -2.2, pressure / 14.0))
	if _water and tender:
		_water.scale = Vector3(1, clampf(tender.water / tender.CAPACITY, 0.02, 1.0), 1)
	if _glow_mat:
		_glow_mat.emission_energy_multiplier = fire * (3.0 + sin(Time.get_ticks_msec() * 0.013) * 0.4)
	_fire_light.light_energy = fire * (2.2 if door_open else 0.5) * (0.9 + randf() * 0.2)
	_fire_loop.volume_db = linear_to_db(fire * (1.0 if door_open else 0.35) + 0.0001)
	_idle_loop.volume_db = linear_to_db(clampf(pressure / 10.0, 0.0, 1.0) * 0.5 + 0.0001)
	_smoke.amount_ratio = clampf(0.15 + fire * 0.4 + regulator.value * 0.5, 0.0, 1.0) if fire > 0.02 else 0.0
	_smoke.emitting = fire > 0.02
	# chuffs: four per wheel revolution while steam is admitted
	if regulator.value > 0.05 and pressure > 0.5 and absf(reverser.stepped()) > 0.05:
		_chuff_acc += absf(ds)
		var quarter := TAU * 0.55 / 4.0
		if _chuff_acc >= quarter:
			_chuff_acc = fmod(_chuff_acc, quarter)
			var vol := linear_to_db(clampf(regulator.value * pressure / 8.0, 0.15, 1.0)) + 2.0
			Sfx.play_at("chuff", part("M_Smoke").global_position, vol, 0.08, 1.0, 150.0)
			_smoke.amount_ratio = 1.0
