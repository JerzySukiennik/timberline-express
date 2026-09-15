# 20-minute day (14 day / 6 night) with sun and moon, colour-graded light and fog, and a simple weather machine:
# clear, cloudy, rain, storm (thunder + flashes) and snow high in the mountains. Drives ambience and wetness.
class_name DayNight
extends Node

const DAY_SECONDS := 1200.0

var main: Node
var time := 7.5              # hours
var speed := 24.0 / DAY_SECONDS
var weather := "clear"
var weather_amount := 0.0    # 0..1 blend toward the current weather
var _weather_timer := 240.0
var _target := "clear"
var moon: DirectionalLight3D
var rain: GPUParticles3D
var snow: GPUParticles3D
var _rain_loop: AudioStreamPlayer
var _wind_loop: AudioStreamPlayer
var _night_loop: AudioStreamPlayer
var _dawn_loop: AudioStreamPlayer
var _thunder_cd := 10.0
var _flash := 0.0
var _owl_cd := 30.0
var wetness := 0.0
var locked := false


func _ready() -> void:
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.66, 0.95)
	moon.light_energy = 0.0
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	main.add_child(moon)
	rain = _precip(false)
	snow = _precip(true)
	_rain_loop = Sfx.loop_2d("rain_loop", -80.0)
	_wind_loop = Sfx.loop_2d("wind_strong_loop", -80.0)
	_night_loop = Sfx.loop_2d("night_forest_loop", -80.0)
	_dawn_loop = Sfx.loop_2d("morning_birds_loop", -80.0)
	if not RenderingServer.global_shader_parameter_get_list().has("wetness"):
		RenderingServer.global_shader_parameter_add("wetness", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)


func _precip(is_snow: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 5000 if not is_snow else 3000
	p.lifetime = 1.2 if not is_snow else 6.0
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 0.5, 22)
	pm.direction = Vector3(0.1, -1, 0.05)
	pm.spread = 3.0 if not is_snow else 25.0
	pm.initial_velocity_min = 22.0 if not is_snow else 1.2
	pm.initial_velocity_max = 28.0 if not is_snow else 2.2
	pm.gravity = Vector3(0, -9.8, 0) if not is_snow else Vector3(0.6, -0.8, 0.3)
	pm.turbulence_enabled = is_snow
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.55) if not is_snow else Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.8, 0.88, 0.35) if not is_snow else Color(1, 1, 1, 0.9)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if not is_snow else BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	p.draw_pass_1 = q
	p.emitting = false
	main.add_child(p)
	return p


func is_night() -> bool:
	return time < 5.5 or time > 20.0


func _process(dt: float) -> void:
	if not locked:
		time = fposmod(time + dt * speed, 24.0)
	_update_weather(dt)
	var env: Environment = main.environment
	var sun: DirectionalLight3D = main.sun
	# sun path: rises 6:00 east, noon high, sets 20:00 west (compressed night)
	var day_t := clampf((time - 5.5) / 14.5, 0.0, 1.0)
	var elev := sin(day_t * PI) * 62.0 - 4.0
	var az := lerpf(100.0, 250.0, day_t)
	sun.rotation_degrees = Vector3(-elev, az, 0)
	var sun_up := smoothstep(-4.0, 10.0, elev)
	var golden := 1.0 - smoothstep(8.0, 30.0, elev)
	var cloud := _cloudiness()
	sun.light_energy = sun_up * lerpf(3.1, 0.7, cloud) * (0.75 + 0.25 * (1.0 - golden))
	sun.light_color = Color(1.0, 0.86, 0.66).lerp(Color(1.0, 0.58, 0.32), golden * 0.85)
	sun.shadow_enabled = sun_up > 0.05
	var night := 1.0 - smoothstep(-8.0, 6.0, elev)
	moon.light_energy = night * 0.32 * (1.0 - cloud * 0.7)
	moon.rotation_degrees = Vector3(-45.0, az + 180.0, 0)
	moon.visible = night > 0.02
	var sky := env.sky.sky_material as PanoramaSkyMaterial
	if sky:
		sky.energy_multiplier = lerpf(0.035, 1.15, sun_up) * lerpf(1.0, 0.55, cloud)
	env.ambient_light_energy = lerpf(0.18, 0.75, sun_up) * lerpf(1.0, 0.8, cloud)
	env.fog_light_color = Color(0.62, 0.74, 0.88).lerp(Color(0.95, 0.66, 0.45), golden * sun_up * 0.6).lerp(Color(0.06, 0.08, 0.13), night).lerp(Color(0.52, 0.55, 0.58), cloud * sun_up)
	env.fog_density = lerpf(0.00085, 0.0065, cloud * cloud) + night * 0.0008
	env.adjustment_saturation = lerpf(1.1, 0.75, maxf(cloud * 0.7, night * 0.6))
	env.tonemap_exposure = lerpf(0.9, 1.35, night)
	# thunder flashes
	_flash = move_toward(_flash, 0.0, dt * 4.0)
	if _flash > 0.0:
		env.ambient_light_energy += _flash * 2.5
	# ambience
	var dawn := clampf(1.0 - absf(time - 6.5) / 1.5, 0.0, 1.0)
	_vol(_night_loop, night * (1.0 - cloud * 0.8), -10.0)
	_vol(_dawn_loop, dawn * (1.0 - cloud), -9.0)
	_owl_cd -= dt
	if night > 0.6 and _owl_cd <= 0.0:
		_owl_cd = randf_range(25.0, 60.0)
		Sfx.play("owl", -14.0)
	if main.animals:
		main.animals.night = night > 0.5
	# precipitation follows the player
	var p: Node3D = main.player
	if p:
		var snowy := p.global_position.y > 140.0
		var raining := (weather == "rain" or weather == "storm") and weather_amount > 0.2
		rain.emitting = raining and not snowy
		snow.emitting = raining and snowy
		rain.global_position = p.global_position + Vector3(0, 14, 0)
		snow.global_position = p.global_position + Vector3(0, 12, 0)
		rain.amount_ratio = weather_amount
		snow.amount_ratio = weather_amount
		_vol(_rain_loop, weather_amount if raining and not snowy else 0.0, -6.0)
		_vol(_wind_loop, (weather_amount if weather == "storm" or snowy and raining else 0.0), -8.0)
		wetness = move_toward(wetness, 1.0 if raining and not snowy else 0.0, dt * (0.05 if raining else 0.012))
		RenderingServer.global_shader_parameter_set("wetness", wetness)


func _vol(pl: AudioStreamPlayer, amount: float, full_db: float) -> void:
	if pl == null or pl.stream == null:
		return
	var target := linear_to_db(maxf(amount, 0.0001)) + full_db
	pl.volume_db = lerpf(pl.volume_db, target, 0.05)


func _cloudiness() -> float:
	match weather:
		"cloudy":
			return 0.5 * weather_amount
		"rain":
			return 0.85 * weather_amount
		"storm":
			return 1.0 * weather_amount
	return 0.0


func _update_weather(dt: float) -> void:
	_weather_timer -= dt
	if _weather_timer <= 0.0 and not locked:
		_weather_timer = randf_range(180.0, 420.0)
		var roll := randf()
		_target = "clear" if roll < 0.45 else ("cloudy" if roll < 0.7 else ("rain" if roll < 0.92 else "storm"))
	if _target != weather:
		weather_amount = move_toward(weather_amount, 0.0, dt / 25.0)
		if weather_amount <= 0.0:
			weather = _target
	else:
		weather_amount = move_toward(weather_amount, 1.0 if weather != "clear" else 0.0, dt / 25.0)
	if weather == "storm" and weather_amount > 0.6:
		_thunder_cd -= dt
		if _thunder_cd <= 0.0:
			_thunder_cd = randf_range(8.0, 22.0)
			_flash = 1.0
			get_tree().create_timer(randf_range(0.4, 2.5)).timeout.connect(func() -> void: Sfx.play("thunder", randf_range(-4.0, 2.0)))


func set_weather(w: String) -> void:
	weather = w
	_target = w
	weather_amount = 1.0 if w != "clear" else 0.0
