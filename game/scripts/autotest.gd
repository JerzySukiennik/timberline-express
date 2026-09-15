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
	if main.world != null:
		await _world_run()
		return
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


# ---------------------------------------------------------------- endless world

func _finish() -> void:
	var sum := 0.0
	for f in _fps:
		sum += f
	_ok("fps_avg", snappedf(sum / maxf(_fps.size(), 1), 0.1))
	var file := FileAccess.open(shots_dir.path_join("report.json") if shots_dir != "" else "user://report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
	print("[autotest] done")
	get_tree().quit()


func _world_run() -> void:
	var t0 := Time.get_ticks_msec()
	while main.loading and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
	_ok("load_seconds", snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1))
	_ok("loaded", not main.loading)
	await _seconds(2.0)
	_fps.clear()
	if _only.contains("graphics"):
		await _world_graphics()
		_finish()
		return
	var p := _p()
	for tool_id in ["pickaxe", "axe", "knife"]:
		p.inventory.add(tool_id, 1)
	var w: ChunkWorld = main.world
	_ok("chunks", w.chunks.size())
	_ok("segments", main.network.segments.size())
	_ok("player_on_flatcar", p.riding != null)
	await _shot("w01_spawn")
	for i in 3:
		p.rotation.y += PI * 0.5
		await _seconds(0.4)
		await _shot("w02_look_%d" % i)
	# harvest a chunk tree and a chunk boulder
	await _world_harvest()
	await _survival_test()
	# ride the handcar a while
	var h: Handcar = main.handcar
	await _tp(h.global_transform * Vector3(0.5, 1.1, 0.6), h.global_transform * Vector3(0, 1.6, -5))
	h.brake.set_value(0.0)
	var start := h.global_position
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 25000:
		await get_tree().physics_frame
		h._pump(p, Vector2(0, 20.0 * sin(Time.get_ticks_msec() * 0.01)), true)
		_fps.append(Engine.get_frames_per_second())
	_ok("handcar_ride_m", snappedf(h.global_position.distance_to(start), 0.1))
	# stand still on the flatcar while the consist keeps rolling: the player must not drift
	var fc: Flatcar = main.flatcar
	p.global_position = fc.global_transform * Vector3(0.4, 0.95, 0.5)
	p.velocity = Vector3.ZERO
	await _seconds(0.5)
	var local0: Vector3 = fc.to_local(p.global_position)
	h.consist.v = 7.0
	var t2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 12000:
		await get_tree().physics_frame
		h.add_pump(p, 1.0)
	var local1: Vector3 = fc.to_local(p.global_position)
	_ok("flatcar_speed_kmh", snappedf(absf(h.consist.v) * 3.6, 0.1))
	_ok("standing_drift_m", snappedf(Vector2(local1.x - local0.x, local1.z - local0.z).length(), 0.01))
	_ok("still_on_flatcar", p.riding == fc)
	# jump on the moving flatcar and land back on it
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _seconds(1.5)
	var local2: Vector3 = fc.to_local(p.global_position)
	_ok("jump_drift_m", snappedf(Vector2(local2.x - local1.x, local2.z - local1.z).length(), 0.01))
	_ok("on_flatcar_after_jump", p.riding == fc)
	_ok("handcar_ride_kmh", snappedf(absf(h.consist.v) * 3.6, 0.1))
	_ok("still_riding", p.riding == h)
	await _shot("w03_ride")
	h.brake.set_value(1.0)
	# fly along the rails to stress streaming
	p.fly = true
	var seg: TrackNetwork.TrackSegment = h.cursor_f.seg
	var ft := Time.get_ticks_msec()
	var min_fps := 999.0
	for k in 60:
		var s := clampf(float(k) / 59.0 * seg.length, 0.0, seg.length)
		var pos := seg.point(s) + Vector3(0, 18, 0)
		p.global_position = pos
		p.look_at_point(seg.point(minf(s + 60.0, seg.length)) + Vector3(0, 6, 0))
		await _seconds(0.25)
		min_fps = minf(min_fps, Engine.get_frames_per_second())
	_ok("flyover_seconds", snappedf((Time.get_ticks_msec() - ft) / 1000.0, 0.1))
	_ok("flyover_min_fps", min_fps)
	_ok("pending_after_fly", w.pending_count())
	await _seconds(3.0)
	await _shot("w04_flyover_end")
	var jn: TrackNetwork.TrackNode = seg.nodes[1]
	p.global_position = jn.pos + Vector3(-30, 25, 30)
	p.look_at_point(jn.pos)
	await _seconds(4.0)
	await _shot("w05_junction")
	p.global_position = jn.pos + Vector3(0, 220, 260)
	p.look_at_point(jn.pos + Vector3(0, 0, -300))
	await _seconds(5.0)
	await _shot("w06_valley_overview")
	_ok("segments_after", main.network.segments.size())
	_ok("switch_stands", main._stands.size())
	p.fly = false
	await _crafting_test()
	await _building_test()
	_finish()


func _world_harvest() -> void:
	var p := _p()
	var best: Dictionary = {}
	var bd := 1e9
	for ch in main.world.chunks.values():
		if ch.body == null:
			continue
		for oid in ch.body.owners:
			var info: Dictionary = ch.body.owners[oid]
			if info.kind != "tree":
				continue
			var pos: Vector3 = (info.data.xf as Transform3D).origin
			var d := pos.distance_to(p.global_position)
			if d < bd:
				bd = d
				best = info
	if best.is_empty():
		_ok("chunk_tree", "none")
		return
	var tp: Vector3 = (best.data.xf as Transform3D).origin
	p.select_slot(p.inventory.find("axe"))
	await _seconds(0.8)
	await _tp(tp + Vector3(1.2, 0.3, 0.9), tp + Vector3.UP * 1.1)
	var swings := 0
	var trees_before := main.find_children("*", "ChopTree", true, false).size()
	while swings < 25:
		p.look_at_point(tp + Vector3.UP * 1.1)
		p.viewmodel.request_swing()
		swings += 1
		await _seconds(0.85)
		p.stamina = 100.0
		var ct := main.find_children("*", "ChopTree", true, false)
		if ct.size() > trees_before and ct[0]._falling != null:
			break
	_ok("chunk_tree_swings", swings)
	await _seconds(4.5)
	_ok("chunk_logs", main.find_children("*", "Pickup", true, false).filter(func(x: Node) -> bool: return x.item_id == "log").size())
	_ok("removed_entries", main.world.removed.size())
	await _shot("w_tree_felled")


func _survival_test() -> void:
	var p := _p()
	var sv := p.survival
	# eat
	sv.hunger = 40.0
	p.inventory.set_slot(8, p.inventory.make("berries", 5))
	p.select_slot(8)
	await _seconds(0.6)
	Input.action_press("primary")
	await _seconds(1.4)
	Input.action_release("primary")
	_ok("ate_berries", sv.hunger > 40.0)
	# ponds, berry bushes, mushrooms present nearby?
	var ponds := 0
	var berry := 0
	var mush := 0
	for ch in main.world.chunks.values():
		if ch.root:
			ponds += ch.root.find_children("*", "WaterBody", true, false).size()
		if ch.body:
			for oid in ch.body.owners:
				var info: Dictionary = ch.body.owners[oid]
				if info.kind == "bush" and info.data.get("berry", false):
					berry += 1
				if info.kind == "mushroom":
					mush += 1
	_ok("ponds_near", ponds)
	var wbs: Array = main.world.find_children("*", "WaterBody", true, false)
	if not wbs.is_empty():
		var wb: WaterBody = wbs[0]
		var c := wb.global_position
		var shape_r: float = ((wb.get_child(0) as CollisionShape3D).shape as CylinderShape3D).radius
		var stand := c + Vector3(shape_r * 1.25, 0, 0)
		stand.y = main.world.height_at(stand.x, stand.z) + 0.2
		await _tp(stand, c + Vector3(0, -0.3, 0))
		await _seconds(1.5)
		await _shot("w_pond")
		sv.thirst = 50.0
		wb.use_shape(0, p)
		_ok("drank_pond", sv.thirst > 50.0)
		p.global_position = stand + Vector3(-shape_r * 1.0, 1.0, 0)
		await _seconds(1.0)
		_ok("in_water_detect", p.in_water)

	_ok("berry_bushes_near", berry)
	_ok("mushrooms_near", mush)
	# death and respawn with backpack
	var death_pos := p.global_position
	sv.damage(500.0, "autotest")
	await _seconds(1.0)
	await _shot("w_death")
	await _seconds(3.5)
	_ok("respawned", not sv.dead and sv.health >= 99.0)
	var bags := main.find_children("*", "DeathBag", true, false)
	_ok("death_bag", bags.size() == 1 and (bags[0] as Node3D).global_position.distance_to(death_pos) < 3.0)
	_ok("inventory_emptied", p.inventory.count("pickaxe") == 0)
	if bags.size() == 1:
		var bag: DeathBag = bags[0]
		for i in bag.inventory.size():
			var sl: Dictionary = bag.inventory.get_slot(i)
			if not sl.is_empty():
				p.inventory.set_slot(i, sl)
				bag.inventory.slots[i] = {}
	_ok("inventory_restored", p.inventory.count("pickaxe") == 1)


func _crafting_test() -> void:
	var p := _p()
	var inv := p.inventory
	for id in ["stick", "stone", "fiber", "log"]:
		inv.add(id, 20)
	var r_axe: Dictionary = Recipes.CRAFT.filter(func(r: Dictionary) -> bool: return r.out == "stone_axe")[0]
	var r_rope: Dictionary = Recipes.CRAFT.filter(func(r: Dictionary) -> bool: return r.out == "rope")[0]
	inv.add("rope", 2)
	p.queue_craft(r_axe)
	await _seconds(3.6)
	_ok("crafted_stone_axe", inv.count("stone_axe") == 1)
	# place a workbench and a campfire on the ground, cook meat
	var r_wb: Dictionary = Recipes.CRAFT.filter(func(r: Dictionary) -> bool: return r.out == "workbench")[0]
	var r_cf: Dictionary = Recipes.CRAFT.filter(func(r: Dictionary) -> bool: return r.out == "campfire")[0]
	inv.add("rope", 5)
	p.queue_craft(r_wb)
	p.queue_craft(r_cf)
	await _seconds(9.0)
	_ok("crafted_stations", inv.count("workbench") == 1 and inv.count("campfire") == 1)
	var ground := p.global_position + (-p.global_basis.z) * 3.0
	ground.y = main.world.height_at(ground.x, ground.z)
	var cf := Station.place(main, "campfire", Transform3D(Basis.IDENTITY, ground), main)
	cf.inventory.set_slot(0, cf.inventory.make("raw_meat", 1))
	cf.inventory.set_slot(1, cf.inventory.make("log", 1))
	await _seconds(0.5)
	_ok("campfire_lit", cf.burn > 0.0)
	cf.progress = 24.0
	await _seconds(1.5)
	_ok("meat_cooked", not cf.inventory.get_slot(2).is_empty() and cf.inventory.get_slot(2).id == "cooked_meat")
	p.look_at_point(cf.global_position)
	await _seconds(1.0)
	await _shot("w_campfire")
	# station on the moving flatcar
	var fc: Flatcar = main.flatcar
	var ws := Station.place(main, "workbench", fc.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.86, -1.5)), fc)
	_ok("workbench_on_flatcar", ws.get_parent() == fc)
	_ok("nearby_workbench", main.nearby_station("workbench", ws.global_position + Vector3(1, 0, 0), 4.0) != null)
	# kits
	inv.add("flatcar_kit", 1)
	var before: int = main.handcar.consist.vehicles.size()
	_ok("flatcar_attached", main.attach_flatcar(main.handcar.consist) and main.handcar.consist.vehicles.size() == before + 1)
	main.handcar.consist.v = 0.0
	var steam_ok: bool = main.upgrade_engine(main.handcar, "steam_kit")
	await _seconds(0.5)
	_ok("steam_upgrade", steam_ok and main.steam != null and main.steam.consist.vehicles.size() == before + 2)


func _view(label: String, pos: Vector3, look: Vector3) -> void:
	var p := _p()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.look_at_point(look)
	await _seconds(2.5)
	var n := 0
	var sum := 0.0
	var end := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() - end < 0:
		await get_tree().process_frame
		sum += Engine.get_frames_per_second()
		n += 1
	_ok("fps_" + label, snappedf(sum / maxf(n, 1), 0.1))
	await _shot("g_" + label)


func _world_graphics() -> void:
	var p := _p()
	p.fly = true
	p.inventory.add("axe", 1)
	p.select_slot(p.inventory.find("axe"))
	var w: ChunkWorld = main.world
	var base: Vector3 = main.handcar.global_position
	var fwd: Vector3 = main.handcar.forward()
	var side := fwd.cross(Vector3.UP).normalized()
	var eye := func(v: Vector3) -> Vector3: return Vector3(v.x, w.height_at(v.x, v.z) + 1.65, v.z)
	await _view("rails_forward", eye.call(base + side * 1.8), base + fwd * 60.0 + Vector3.UP * 1.0)
	await _view("toward_sun", eye.call(base - side * 14.0), base - side * 14.0 + Vector3(-60, 8, 50))
	await _view("into_forest", eye.call(base + side * 16.0), base + side * 60.0 + Vector3.UP * 2.0)
	await _view("meadow_low", eye.call(base - side * 9.0 + fwd * 20.0) - Vector3.UP * 0.9, base - side * 25.0 + fwd * 40.0)
	await _view("valley_high", base + Vector3(0, 60, 0) - fwd * 80.0, base + fwd * 200.0)
	var wbs: Array = w.find_children("*", "WaterBody", true, false)
	if not wbs.is_empty():
		var c: Vector3 = (wbs[0] as Node3D).global_position
		await _view("pond", eye.call(c + Vector3(14, 0, 8)), c)
	await _view("train_close", eye.call(base + side * 4.0 + fwd * 3.0), base + Vector3.UP * 0.8)
	for key in ["grass", "chunk_grass", "ferns", "trees", "tree_shadows_w", "ssao", "postfx", "glow"]:
		main.set_quality(key, false)
		await _view("rails_without_" + key, eye.call(base + side * 1.8), base + fwd * 60.0 + Vector3.UP * 1.0)
		main.set_quality(key, true)
	var vp := get_viewport()
	await _view("rails_again", eye.call(base + side * 1.8), base + fwd * 60.0 + Vector3.UP * 1.0)
	_ok("tris_rails", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	_ok("draws_rails", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	await _view("toward_sun_high", eye.call(base - side * 14.0), base - side * 14.0 + Vector3(-60, 8, 50))
	p.fly = false


func _building_test() -> void:
	var p := _p()
	var fc: Flatcar = null
	for v in main.steam.consist.vehicles:
		if v is Flatcar:
			fc = v
			break
	if fc == null:
		_ok("building", "no flatcar")
		return
	p.inventory.add("plank", 60)
	p.inventory.add("nails", 60)
	var built := 0
	for piece in ["floor", "wall", "window", "roof", "railing"]:
		var cell := Vector3i(0, 0, 1) if piece != "floor" else Vector3i(1, 1, 2)
		var edge := 1 if piece in ["wall", "window", "railing"] else 0
		if piece == "window":
			edge = 3
		var pc := Building.build(fc, piece, cell, edge)
		if pc:
			built += 1
	_ok("pieces_built", built)
	_ok("pieces_registered", (fc.get_meta("pieces", {}) as Dictionary).size())
	await _tp(fc.global_transform * Vector3(4.5, 2.2, 3.0), fc.global_position + Vector3.UP * 1.5)
	p.fly = true
	await _seconds(1.0)
	await _shot("w_building")
	p.fly = false
