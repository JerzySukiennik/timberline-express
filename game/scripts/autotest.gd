# Scripted playtest: movement, tool poses, mining, chopping, inventory, all three vehicles, switches; screenshots + report.
extends Node

var main: Node3D
var shots_dir := ""
var report := {}
var _fps: Array[float] = []
var _only := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
		if a.begins_with("--only="):
			_only = a.substr(7)
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	main.infinite_stamina = false
	_run()


func _want(section: String) -> bool:
	return _only == "" or section in _only.split(",")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		_fps.append(Engine.get_frames_per_second())


func _seconds(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		_fps.append(Engine.get_frames_per_second())


func _shot(name: String) -> void:
	await _frames(3)
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))
	print("[autotest] shot ", name)


func _p() -> Player:
	return main.player


func _tp(pos: Vector3, look: Vector3) -> void:
	_p().riding = null
	_p().global_position = pos
	_p().velocity = Vector3.ZERO
	_p().look_at_point(look)
	await _frames(4)


func _ok(key: String, value: Variant) -> void:
	report[key] = value
	print("REPORT ", key, "=", value)


func _run() -> void:
	await _seconds(3.0)
	var p := _p()
	await _shot("01_spawn")
	if _want("move"):
		await _movement()
	if _want("tools"):
		await _tool_poses()
	if _want("world"):
		await _mining()
		await _chopping()
		await _inventory()
		await _mantle()
	if _want("vehicles"):
		await _handcar()
		await _steam()
		await _electric()
		await _switches()
	if _want("perf"):
		await _perf()
	await _overview()
	var sum := 0.0
	for f in _fps:
		sum += f
	_ok("fps_avg", snappedf(sum / maxf(_fps.size(), 1), 0.1))
	var mn := 9999.0
	for f in _fps.slice(60):
		mn = minf(mn, f)
	_ok("fps_min", mn)
	var file := FileAccess.open(shots_dir.path_join("report.json") if shots_dir != "" else "user://report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
	print("[autotest] done")
	get_tree().quit()


func _movement() -> void:
	var p := _p()
	await _tp(main.spawn_point, main.spawn_point + Vector3(-10, 1.6, 10))
	var start := p.global_position
	Input.action_press("move_forward")
	await _seconds(2.0)
	_ok("walk_speed", snappedf(p.move_speed, 0.01))
	Input.action_press("sprint")
	await _seconds(2.0)
	_ok("sprint_speed", snappedf(p.move_speed, 0.01))
	_ok("stamina_after_sprint", int(p.stamina))
	await _shot("02_sprint")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _seconds(0.6)
	_ok("moved", snappedf(p.global_position.distance_to(start), 0.1))
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var max_y := p.global_position.y
	var y0 := p.global_position.y
	for i in 60:
		await _frames(1)
		max_y = maxf(max_y, p.global_position.y)
	_ok("jump_height", snappedf(max_y - y0, 0.01))
	Input.action_press("crouch")
	await _seconds(0.6)
	_ok("crouch_height", snappedf(p.shape.height, 0.01))
	Input.action_release("crouch")
	await _seconds(0.6)


func _tool_poses() -> void:
	var p := _p()
	await _tp(main.spawn_point, main.spawn_point + Vector3(0, 1.5, -10))
	var vm := p.viewmodel
	await _shot("03_empty_hand")
	for tool in [["pickaxe", 0], ["axe", 1], ["knife", 2]]:
		p.select_slot(tool[1])
		await _frames(2)
		# wait for holster/switch, then freeze the draw halfway
		for i in 60:
			await _frames(1)
			if vm.state == "draw":
				break
		vm.freeze_t = 0.45
		await _shot("04_%s_draw" % tool[0])
		_ik_debug(tool[0] + "_draw")
		vm.freeze_t = -1.0
		await _seconds(0.8)
		await _shot("05_%s_idle" % tool[0])
		_ik_debug(tool[0] + "_idle")
		await _side_shots(tool[0])
		if tool[0] == "pickaxe":
			pass
		vm.request_swing()
		var cfg: Dictionary = ViewModel.TOOLS[tool[0]]
		vm.freeze_t = 0.3
		await _shot("06_%s_windup" % tool[0])
		vm.freeze_t = float(cfg.impact) + 0.01
		await _shot("07_%s_impact" % tool[0])
		_ik_debug(tool[0] + "_impact")
		vm.freeze_t = -1.0
		await _seconds(1.0)
	_ok("tool_state_after", vm.state)


func _nearest(group_class: String, from: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for n in main.find_children("*", group_class, true, false):
		var d := (n as Node3D).global_position.distance_to(from)
		if d < bd:
			bd = d
			best = n
	return best


func _mining() -> void:
	var p := _p()
	var rock := _nearest("MineRock", main.spawn_point)
	if rock == null:
		_ok("mining", "no rock")
		return
	p.select_slot(0)
	await _seconds(1.0)
	var rocks_before = main.find_children("*", "MineRock", true, false).size()
	var target := rock.global_position + Vector3.UP * 0.6
	var dir: Vector3 = (main.spawn_point - rock.global_position)
	dir.y = 0
	dir = dir.normalized()
	await _tp(rock.global_position + dir * 1.9, target)
	var swings := 0
	for i in 60:
		var r := _nearest("MineRock", p.global_position)
		if r == null or r.global_position.distance_to(p.global_position) > 4.0:
			break
		p.look_at_point(r.global_position + Vector3.UP * 0.25)
		p.viewmodel.request_swing()
		swings += 1
		await _seconds(1.05)
		if i == 9:
			await _shot("08_rock_chunks")
		p.stamina = 100.0
	await _seconds(1.0)
	_ok("rocks_after", main.find_children("*", "MineRock", true, false).size())
	_ok("mining_swings", swings)
	_ok("rocks_before", rocks_before)
	_ok("stones_on_ground", main.find_children("*", "Pickup", true, false).filter(func(x: Node) -> bool: return x.item_id == "stone").size())
	await _shot("09_rock_done")


func _chopping() -> void:
	var p := _p()
	var tree := _nearest("ChopTree", main.spawn_point)
	if tree == null:
		return
	p.select_slot(1)
	await _seconds(0.8)
	await _tp(tree.global_position + Vector3(1.3, 0.2, 0.9), tree.global_position + Vector3.UP * 1.1)
	var swings := 0
	while is_instance_valid(tree) and tree._falling == null and swings < 30:
		p.look_at_point(tree.global_position + Vector3.UP * 1.1)
		p.viewmodel.request_swing()
		swings += 1
		await _seconds(0.85)
		p.stamina = 100.0
	_ok("chop_swings", swings)
	await _seconds(1.2)
	await _shot("10_tree_falling")
	await _seconds(3.5)
	_ok("logs_on_ground", main.find_children("*", "Pickup", true, false).filter(func(x: Node) -> bool: return x.item_id == "log").size())
	await _shot("11_logs")


func _inventory() -> void:
	main.toggle_inventory()
	await _seconds(0.6)
	await _shot("12_inventory")
	main.inventory_ui.close()
	await _frames(5)
	var crate: StaticBody3D = null
	for c in main.get_children():
		if c is StaticBody3D and c.has_meta("inventory"):
			crate = c
			break
	if crate:
		main.open_container(crate.get_meta("inventory"), "Fuel Crate")
		await _seconds(0.6)
		await _shot("13_crate")
		main.inventory_ui.close()
	_ok("inventory_ok", not main.inventory_ui.is_open)
	await _frames(5)


func _mantle() -> void:
	var p := _p()
	var pos: Vector3 = main.spawn_point + Vector3(6, 0, 4)
	pos.y = main.terrain.height_at(pos.x, pos.z)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(2.0, 1.2, 2.0)
	cs.shape = b
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = b.size
	mi.mesh = bm
	body.add_child(mi)
	main.add_child(body)
	body.global_position = pos + Vector3(0, 0.6, -2.2)
	p.select_slot(5)
	await _tp(pos, pos + Vector3(0, 1.0, -3))
	Input.action_press("move_forward")
	await _seconds(0.3)
	Input.action_press("jump")
	for i in 90:
		await _frames(1)
		if p.mantling and i > 3:
			break
	await _shot("14_mantle")
	await _seconds(1.0)
	Input.action_release("jump")
	Input.action_release("move_forward")
	_ok("mantle_on_top", p.global_position.y > pos.y + 1.0)
	body.queue_free()


func _pump_frames(h: Handcar, seconds: float) -> void:
	var t := 0.0
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		# follow the beam rhythm like a player would
		var c := cos(h._phase())
		var rel := Vector2(0, -c * 26.0 * h.direction if absf(c) > 0.1 else -26.0)
		h._pump(_p(), rel, true)
		_fps.append(Engine.get_frames_per_second())


func _handcar() -> void:
	var p := _p()
	var h: Handcar = main.handcar
	h.brake.set_value(0.0)
	await _tp(h.global_transform * Vector3(0.5, 1.1, 0.6), h.global_transform * Vector3(0, 1.6, -3))
	await _seconds(0.5)
	_ok("rides_handcar", p.riding == h)
	var start := h.global_position
	h.direction = 1.0
	p.grabbing = null
	await _pump_frames(h, 8.0)
	_ok("handcar_speed_kmh", snappedf(absf(h.consist.v) * 3.6, 0.1))
	_ok("handcar_moved_m", snappedf(h.global_position.distance_to(start), 0.1))
	_ok("player_still_on_handcar", p.global_position.distance_to(h.global_position) < 3.0)
	await _shot("15_handcar_riding")
	h.brake.set_value(1.0)
	await _seconds(3.0)
	_ok("handcar_after_brake_kmh", snappedf(absf(h.consist.v) * 3.6, 0.1))


func _steam() -> void:
	var p := _p()
	var s: SteamLoco = main.steam
	await _tp(s.global_transform * Vector3(0.3, 1.2, 2.2), s.global_transform * Vector3(0, 1.7, 1.0))
	await _seconds(0.4)
	_ok("rides_steam", p.riding == s)
	s._set_door(true)
	await _seconds(0.5)
	p.inventory.add("coal", 10)
	for i in 8:
		s._door_use(p)
		await _frames(3)
	_ok("steam_energy", snappedf(s.energy, 0.1))
	await _shot("16_steam_cab_fire")
	s._set_door(false)
	s.pressure = 6.0
	s.brake.set_value(0.0)
	s.reverser.set_value(1.0)
	s.regulator.set_value(0.7)
	var start := s.global_position
	await _seconds(8.0)
	_ok("steam_speed_kmh", snappedf(absf(s.consist.v) * 3.6, 0.1))
	_ok("steam_pressure", snappedf(s.pressure, 0.1))
	_ok("steam_moved_m", snappedf(s.global_position.distance_to(start), 0.1))
	_ok("tender_water", int(main.tender.water))
	await _shot("17_steam_cab_running")
	s.regulator.set_value(0.0)
	s.brake.set_value(1.0)
	await _tp(s.global_transform * Vector3(-7, 1.0, -6), s.global_position + Vector3.UP * 2.0)
	p.riding = null
	await _seconds(0.4)
	await _shot("18_steam_outside")


func _electric() -> void:
	var p := _p()
	var e: ElectricLoco = main.electric
	await _tp(e.global_transform * Vector3(0.3, 1.35, -0.2), e.global_transform * Vector3(0, 2.3, -3))
	e._set_breaker(true)
	e.direction = 1
	e.brake.set_value(0.0)
	e.controller.set_value(0.8)
	e.fuel = 10.0
	e._toggle_generator()
	var start := e.global_position
	await _seconds(7.0)
	_ok("electric_speed_kmh", snappedf(absf(e.consist.v) * 3.6, 0.1))
	_ok("electric_moved_m", snappedf(e.global_position.distance_to(start), 0.1))
	_ok("electric_battery_kwh", snappedf(e.battery, 0.01))
	_ok("rides_electric", p.riding == e)
	await _shot("19_electric_cab")
	e.controller.set_value(0.0)
	e.brake.set_value(1.0)
	await _seconds(2.0)


func _switches() -> void:
	var net: TrackNetwork = main.network
	var sw: TrackNetwork.TrackNode = net.switches[0]
	var seg: TrackNetwork.TrackSegment = sw.links[0].seg
	var c := net.cursor_at(seg, seg.length - 5.0, false)
	sw.state = 1
	c.move(10.0)
	_ok("switch_to_siding", c.seg == net.sidings[0])
	sw.state = 0
	var c2 := net.cursor_at(seg, seg.length - 5.0, false)
	c2.move(10.0)
	_ok("switch_to_main", c2.seg != net.sidings[0])
	var loop := net.cursor_at(seg, 0.0, false)
	var left := loop.move(net.loop_length() + 5.0)
	_ok("loop_full_lap_blocked", left != 0.0)


func _overview() -> void:
	var p := _p()
	p.fly = true
	await _tp(Vector3(-50, 30, 75), Vector3(0, 0, 25))
	await _seconds(1.0)
	await _shot("20_overview")
	await _tp(Vector3(-18, main.terrain.height_at(-18, 44) + 0.1, 44), Vector3(-6, 1, 58))
	await _seconds(0.5)
	await _shot("21_samples")
	p.fly = false


func _measure(label: String) -> void:
	await _seconds(0.8)
	var n := 0
	var sum := 0.0
	var end := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		sum += Engine.get_frames_per_second()
		n += 1
	_ok("perf_" + label, snappedf(sum / maxf(n, 1), 0.1))


func _perf() -> void:
	var p := _p()
	p.fly = true
	await _tp(Vector3(-30, main.terrain.height_at(-30, 20) + 1.7, 20), Vector3(40, 2, -20))
	await _measure("all_on")
	for key in ["volumetric", "ssao", "glow", "msaa", "shadows", "tree_shadows", "plants", "trees"]:
		main.set_quality(key, false)
		await _measure("without_" + key)
	for key in ["volumetric", "ssao", "glow", "msaa", "shadows", "tree_shadows", "plants", "trees"]:
		main.set_quality(key, true)
	p.fly = false


func _ik_debug(label: String) -> void:
	var vm: ViewModel = _p().viewmodel
	for side in ["r", "l"]:
		var fr: Dictionary = vm._smooth_r if side == "r" else vm._smooth_l
		if fr.is_empty():
			continue
		var sh := ViewModel.SHOULDER_R if side == "r" else ViewModel.SHOULDER_L
		var w: Vector3 = fr.w
		print("IK %s %s wrist=%s reach=%.2f" % [label, side, str(w.snappedf(0.01)), w.distance_to(sh)])


## Close-up of the grip from outside the player camera (right side and from below/front).
func _side_shots(label: String) -> void:
	var p := _p()
	var vm: ViewModel = p.viewmodel
	if vm.tool_node == null:
		return
	var cfg: Dictionary = ViewModel.TOOLS[label]
	var grip: Vector3 = vm.tool_node.global_transform * (vm.tool_info.bottom + vm.tool_info.axis * vm.tool_info.length * float(cfg.u_r))
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.01
	main.add_child(cam)
	var views := {"side": p.camera.global_basis.x * 0.55 + p.camera.global_basis.y * 0.05, "front": -p.camera.global_basis.z * 0.6 + p.camera.global_basis.y * 0.1}
	for v in views:
		cam.global_position = grip + views[v]
		cam.look_at(grip)
		cam.make_current()
		vm.freeze_t = 0.99
		await _shot("05c_%s_grip_%s" % [label, v])
	vm.freeze_t = -1.0
	p.camera.make_current()
	cam.queue_free()
