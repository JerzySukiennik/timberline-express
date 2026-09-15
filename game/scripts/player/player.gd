# First-person survivor: weighty movement, stamina, crouch, mantle, riding moving vehicles, aim/interact/grab, hotbar.
class_name Player
extends CharacterBody3D

signal slot_changed(index: int)

const WALK := 3.0
const SPRINT := 5.6
const CROUCH := 1.5
const ACCEL := 11.0
const DECEL := 13.0
const AIR_ACCEL := 2.2
const JUMP_V := 4.0
const GRAVITY := 11.5
const STAND_H := 1.8
const CROUCH_H := 1.15
const EYE := 1.64
const EYE_CROUCH := 1.02
const REACH := 2.5

var main: Node
var head: Node3D
var camera: Camera3D
var viewmodel: ViewModel
var shape: CapsuleShape3D
var inventory := Inventory.new(29)
var survival: Survival
var placer: Placer
var builder: Builder
var shape_target: Object = null
var shape_idx := -1
var eat_progress := 0.0
var in_water := false
var selected_slot := 0
var equipped_id := ""

var stamina := 100.0
var exhausted := false
var input_enabled := true
var speed_mult := 1.0
var fly := false
var sprinting := false
var crouch := 0.0
var crouching := false
var riding: RailVehicle = null
var aim: Interactable = null
var aim_prompt := ""
var grabbing: Interactable = null
var mantling := false
var mouse_delta := Vector2.ZERO
var move_speed := 0.0

var _pitch := 0.0
var _bob := 0.0
var _step_phase := 0.0
var _land_dip := 0.0
var _tilt := 0.0
var _fov_kick := 0.0
var _shake := 0.0
var _stamina_delay := 0.0
var _was_floor := true
var _fall_speed := 0.0
var _breath_cd := 0.0
var _e_held := false
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_t := 0.0
var _last_ride_vel := Vector3.ZERO
var _swing_held := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	platform_floor_layers = 0
	platform_wall_layers = 0
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	var cs := CollisionShape3D.new()
	shape = CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = STAND_H
	cs.shape = shape
	cs.position.y = STAND_H * 0.5
	cs.name = "Shape"
	add_child(cs)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.fov = Controls.fov
	camera.near = 0.04
	camera.far = 2200.0
	head.add_child(camera)
	viewmodel = ViewModel.new()
	viewmodel.player = self
	camera.add_child(viewmodel)
	inventory.changed.connect(_on_inventory_changed)
	builder = Builder.new()
	builder.player = self
	add_child(builder)
	placer = Placer.new()
	placer.player = self
	add_child(placer)
	survival = Survival.new()
	survival.player = self
	add_child(survival)


func set_look(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	_pitch = pitch
	head.rotation.x = pitch


func look_at_point(p: Vector3) -> void:
	var d := p - camera.global_position
	rotation.y = atan2(-d.x, -d.z)
	_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.5, 1.5)
	head.rotation.x = _pitch


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel := (event as InputEventMouseMotion).relative
		if grabbing:
			grabbing.grab_drag.call(self, rel)
			mouse_delta += rel * 0.15
			return
		rotation.y -= rel.x * Controls.sensitivity
		_pitch = clampf(_pitch - rel.y * Controls.sensitivity, deg_to_rad(-88), deg_to_rad(88))
		head.rotation.x = _pitch
		mouse_delta += rel
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_slot(posmod(selected_slot - 1, 9))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_slot(posmod(selected_slot + 1, 9))
	for i in 9:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			select_slot(i)
	if event.is_action_pressed("primary"):
		_primary_pressed()
	if event.is_action_released("primary"):
		_swing_held = false
		_end_grab()
		_release_bow()
	if event.is_action_pressed("secondary") and aim and aim.on_secondary.is_valid():
		aim.on_secondary.call(self)
	elif event.is_action_pressed("secondary") and equipped_id == "hammer" and main and main.has_method("open_build_menu"):
		main.open_build_menu()
	if event.is_action_pressed("rotate_build") and equipped_id == "hammer":
		builder.rotate_piece()
	if event.is_action_pressed("interact"):
		_e_held = true
		if aim and aim.on_use.is_valid():
			aim.on_use.call(self)
			viewmodel.gesture("press")
		elif shape_target and is_instance_valid(shape_target) and shape_target.use_shape(shape_idx, self):
			viewmodel.gesture("grab")
		elif _pickup_target():
			pass
		elif main and main.has_method("toggle_inventory"):
			main.toggle_inventory()
	if event.is_action_released("interact"):
		_e_held = false
		if aim and aim.on_release.is_valid():
			aim.on_release.call(self)
	if event.is_action_pressed("drop") and equipped_id != "hammer":
		drop_selected()


func _primary_pressed() -> void:
	if aim and aim.is_grab():
		grabbing = aim
		if grabbing.grab_start.is_valid():
			grabbing.grab_start.call(self)
		return
	if Items.def(equipped_id).get("kind", "") == "placeable":
		placer.try_place()
		return
	if equipped_id == "hammer" and builder.primary():
		return
	if Items.tool_type(equipped_id) == "bow":
		if inventory.count("arrow") > 0:
			bow_draw = 0.001
			Sfx.play("bow_draw", -4.0)
		else:
			if main:
				main.toast("No arrows")
		return
	if Items.is_tool(equipped_id):
		_swing_held = true
		viewmodel.request_swing()
	elif equipped_id == "":
		_pickup_target()


func _end_grab() -> void:
	if grabbing:
		if grabbing.grab_end.is_valid():
			grabbing.grab_end.call(self)
		grabbing = null


func select_slot(i: int) -> void:
	if i == selected_slot and viewmodel.current_id == _slot_id(i):
		return
	selected_slot = i
	_refresh_equipped()
	slot_changed.emit(i)


func _slot_id(i: int) -> String:
	var s := inventory.get_slot(i)
	return "" if s.is_empty() else str(s.id)


func _refresh_equipped() -> void:
	var id := _slot_id(selected_slot)
	if id != equipped_id or viewmodel.current_id != id:
		equipped_id = id
		viewmodel.equip(id)
	if placer:
		placer.set_item(id)


func _on_inventory_changed() -> void:
	var id := _slot_id(selected_slot)
	if id != equipped_id and id == "":
		# the held item just left the slot: remove it from the hand immediately
		equipped_id = ""
		viewmodel.equip("", true)
		if placer:
			placer.set_item("")
		return
	_refresh_equipped()


func use_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	_stamina_delay = 0.9
	if stamina <= 0.0:
		exhausted = true


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


# ---------------------------------------------------------------- physics

func _physics_process(dt: float) -> void:
	_apply_ride()
	if mantling:
		_mantle_step(dt)
		_camera_fx(dt, Vector2.ZERO)
		return
	var input := Vector2.ZERO
	if input_enabled and not grabbing:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var want_crouch := input_enabled and Input.is_action_pressed("crouch")
	if not want_crouch and crouching and not _can_stand():
		want_crouch = true
	if want_crouch != crouching:
		crouching = want_crouch
		Sfx.play("crouch", -10.0)
	crouch = move_toward(crouch, 1.0 if crouching else 0.0, dt * 6.0)
	shape.height = lerpf(STAND_H, CROUCH_H, crouch)
	($Shape as CollisionShape3D).position.y = shape.height * 0.5
	var moving := input.length() > 0.1
	sprinting = input_enabled and Input.is_action_pressed("sprint") and moving and input.y < 0.3 and not crouching and not exhausted and is_on_floor()
	var target_speed := (SPRINT if sprinting else (CROUCH if crouching else WALK)) * speed_mult
	var wish := (global_basis * Vector3(input.x, 0, input.y))
	wish.y = 0
	wish = wish.normalized() * target_speed * minf(input.length(), 1.0)
	if fly:
		var up := 0.0
		if Input.is_action_pressed("jump"):
			up += 1.0
		if Input.is_action_pressed("crouch"):
			up -= 1.0
		velocity = (camera.global_basis * Vector3(input.x, 0, input.y)).normalized() * 14.0 * speed_mult + Vector3.UP * up * 10.0
		move_and_slide()
		_camera_fx(dt, input)
		return
	var horiz := Vector3(velocity.x, 0, velocity.z)
	var accel := (ACCEL if moving else DECEL) if is_on_floor() else AIR_ACCEL
	horiz = horiz.move_toward(wish, accel * dt * (1.0 if is_on_floor() else target_speed))
	velocity.x = horiz.x
	velocity.z = horiz.z
	if not is_on_floor():
		velocity.y -= GRAVITY * dt
		_fall_speed = maxf(_fall_speed, -velocity.y)
	if input_enabled and Input.is_action_pressed("jump") and (not is_on_floor() or input.y < -0.3 or Input.is_action_just_pressed("jump")):
		if _try_mantle():
			return
	if input_enabled and Input.is_action_just_pressed("jump") and is_on_floor() and not crouching and stamina > 8.0:
		velocity.y = JUMP_V
		use_stamina(10.0)
		Sfx.play("jump", -12.0)
		_step_phase = 0.0
	# stamina
	if sprinting:
		use_stamina(13.0 * dt)
	_stamina_delay -= dt
	if _stamina_delay <= 0.0:
		stamina = minf(100.0, stamina + (22.0 if not moving else 14.0) * dt)
	if exhausted and stamina > 30.0:
		exhausted = false
	_breath_cd -= dt
	if stamina < 20.0 and _breath_cd <= 0.0:
		Sfx.play("breath", -14.0, 0.05)
		_breath_cd = 2.6
	var was_air := not is_on_floor()
	move_and_slide()
	_vehicle_hits()
	_detect_ride()
	if is_on_floor() and was_air:
		_landed()
	move_speed = Vector2(velocity.x, velocity.z).length()
	_footsteps(dt)
	_camera_fx(dt, input)
	_update_aim()
	if grabbing and (not is_instance_valid(grabbing) or grabbing.hand_point.global_position.distance_to(camera.global_position) > REACH + 0.8):
		_end_grab()
	if _swing_held and Items.is_tool(equipped_id):
		viewmodel.request_swing()
	_eating(dt)
	_water_check(dt)
	if bow_draw > 0.0:
		bow_draw = minf(1.0, bow_draw + dt / 0.9)
		if not Input.is_action_pressed("primary") and not "--autotest" in OS.get_cmdline_user_args():
			_release_bow()
	if _e_held and aim and aim.on_hold.is_valid():
		aim.on_hold.call(self, dt)
	mouse_delta = mouse_delta.lerp(Vector2.ZERO, clampf(dt * 12.0, 0.0, 1.0))


func _apply_ride() -> void:
	if riding and is_instance_valid(riding):
		var d := riding.last_delta
		var dt := get_physics_process_delta_time()
		var np := d * global_position
		_last_ride_vel = (np - global_position) / maxf(dt, 0.0001)
		global_position = np
		if mantling:
			_mantle_from = d * _mantle_from
			_mantle_to = d * _mantle_to
		var yaw := d.basis.get_euler().y
		rotation.y += yaw


func _detect_ride() -> void:
	# Ray down instead of slide collisions: standing still produces no collision some frames, which used to drop
	# the ride for a frame and let the vehicle slide out from under the player. While airborne above the same
	# vehicle (a jump on a moving train) the ride is kept so the player lands where they jumped.
	var space := get_world_3d().direct_space_state
	var reach := 0.45 if is_on_floor() else 4.0
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position - Vector3.UP * reach, 4)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var found: RailVehicle = null
	if not hit.is_empty() and hit.collider is RailVehicle:
		found = hit.collider
	if found == null and riding != null and is_instance_valid(riding) and not is_on_floor():
		# stepped off the edge: keep the vehicle's momentum once
		velocity += Vector3(_last_ride_vel.x, 0.0, _last_ride_vel.z)
	riding = found


func _can_stand() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = STAND_H - 0.05
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, STAND_H * 0.5 + 0.03, 0))
	q.collision_mask = 1 | 4
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _landed() -> void:
	var f := _fall_speed
	_fall_speed = 0.0
	if f > 11.5 and not fly:
		survival.damage((f - 11.5) * 9.0, "a fall")
	if f > 2.0:
		_land_dip = clampf(f * 0.018, 0.02, 0.16)
		Sfx.play("land_hard" if f > 6.0 else "land_soft", linear_to_db(clampf(f / 8.0, 0.2, 1.0)) - 6.0)
		viewmodel.impulse(Vector3(0, -f * 0.006, 0))


func surface_under() -> String:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position - Vector3.UP * 0.4, 1 | 4)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "grass"
	var col: Object = hit.collider
	if col is RailVehicle:
		var shape_i: int = hit.shape
		var owner_id := (col as CollisionObject3D).shape_find_owner(shape_i)
		var sh := (col as CollisionObject3D).shape_owner_get_owner(owner_id) as Node
		var s := str(sh.get_meta("surface", "")) if sh else ""
		return "metal" if s == "metal" else "wood"
	var surf := str((col as Node).get_meta("surface", "ground")) if col is Node else "ground"
	match surf:
		"ground":
			if main and main.terrain and main.terrain.dist_to_track(global_position.x, global_position.z) < 2.7:
				return "gravel"
			return "grass"
		"rock":
			return "gravel"
		"planks", "wood":
			return "wood"
		"metal":
			return "metal"
	return "grass"


func _footsteps(dt: float) -> void:
	if not is_on_floor() or move_speed < 0.4:
		_step_phase = 0.0
		return
	var stride := 1.05 if sprinting else (0.55 if crouching else 0.78)
	_step_phase += move_speed * dt / stride
	if _step_phase >= 1.0:
		_step_phase -= 1.0
		var vol := -6.0 if sprinting else (-17.0 if crouching else -11.0)
		if not in_water:
			Sfx.play("step_" + surface_under(), vol, 0.1)


func _camera_fx(dt: float, input: Vector2) -> void:
	var grounded := is_on_floor() or mantling
	var amp := 0.0
	if grounded and move_speed > 0.3:
		amp = (0.05 if sprinting else (0.018 if crouching else 0.03)) * clampf(move_speed / WALK, 0.3, 1.4)
	_bob += dt * move_speed * (1.9 if sprinting else 2.3)
	var bob_y := -absf(sin(_bob * PI)) * amp * 1.4 + amp * 0.7
	var bob_x := sin(_bob * PI) * amp * 0.6
	_land_dip = move_toward(_land_dip, 0.0, dt * 0.5)
	var eye := lerpf(EYE, EYE_CROUCH, crouch)
	head.position = Vector3(bob_x, eye + bob_y - _land_dip, 0)
	_tilt = lerpf(_tilt, -input.x * (0.022 if sprinting else 0.012), dt * 6.0)
	_shake = move_toward(_shake, 0.0, dt * 2.5)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.02
	camera.rotation = Vector3(sh.x, sh.y, _tilt)
	_fov_kick = lerpf(_fov_kick, 7.0 if sprinting and move_speed > WALK + 0.5 else 0.0, dt * 4.0)
	camera.fov = Controls.fov + _fov_kick


# ---------------------------------------------------------------- aim / interact

func _update_aim() -> void:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var dir := -camera.global_basis.z
	var wq := PhysicsRayQueryParameters3D.create(from, from + dir * REACH, 1 | 4 | 16)
	wq.exclude = [get_rid()]
	var whit := space.intersect_ray(wq)
	var limit := REACH if whit.is_empty() else from.distance_to(whit.position) + 0.6
	var aq := PhysicsRayQueryParameters3D.create(from, from + dir * minf(limit, REACH), 8)
	aq.collide_with_areas = true
	aq.collide_with_bodies = false
	var ahit := space.intersect_ray(aq)
	var new_aim: Interactable = null
	if not ahit.is_empty() and ahit.collider is Interactable:
		new_aim = ahit.collider
	if grabbing:
		new_aim = grabbing
	aim = new_aim
	aim_prompt = aim.get_prompt(self) if aim else ""
	shape_target = null
	shape_idx = -1
	if aim_prompt == "":
		var sq := PhysicsRayQueryParameters3D.create(from, from + dir * minf(limit, REACH), 32 | 64 | 1)
		sq.exclude = [get_rid()]
		var shit := space.intersect_ray(sq)
		if shit.is_empty():
			var sq2 := PhysicsRayQueryParameters3D.create(from, from + dir * REACH, 64)
			shit = space.intersect_ray(sq2)
		if not shit.is_empty() and (shit.collider as Object).has_method("prompt_shape"):
			var pr: String = shit.collider.prompt_shape(int(shit.shape), self)
			if pr != "":
				shape_target = shit.collider
				shape_idx = int(shit.shape)
				aim_prompt = pr
	if aim_prompt == "" and builder and builder.active() and builder.prompt != "":
		aim_prompt = builder.prompt
	if aim_prompt == "":
		var pk := _aimed_pickup()
		if pk:
			aim_prompt = "[E] Pick up %s" % pk.label()


func _aimed_pickup() -> Pickup:
	var from := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * REACH, 1 | 16)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider is Pickup:
		return hit.collider
	return null


func _pickup_target() -> bool:
	var pk := _aimed_pickup()
	if pk == null:
		return false
	var left := pk.count
	if pk.dur >= 0:
		var idx := selected_slot if inventory.get_slot(selected_slot).is_empty() else inventory.find("")
		for j in inventory.size():
			if idx < 0 and inventory.get_slot(j).is_empty():
				idx = j
		if idx >= 0:
			var d := inventory.make(pk.item_id, 1)
			d["dur"] = pk.dur
			inventory.set_slot(idx, d)
			left = 0
	else:
		left = inventory.add(pk.item_id, pk.count, [selected_slot] if inventory.get_slot(selected_slot).is_empty() else [])
	if left < pk.count:
		Sfx.play("pickup", -6.0)
		viewmodel.gesture("grab")
		if left <= 0:
			pk.queue_free()
		else:
			pk.count = left
		return true
	return false


func drop_selected() -> void:
	var s := inventory.get_slot(selected_slot)
	if s.is_empty() or main == null:
		return
	var n := int(s.count) if Input.is_key_pressed(KEY_CTRL) else 1
	inventory.remove_at(selected_slot, n)
	var p := Pickup.spawn(main, str(s.id), n, camera.global_position - camera.global_basis.z * 0.7 + Vector3.DOWN * 0.3)
	p.dur = int(s.get("dur", -1))
	p.linear_velocity = -camera.global_basis.z * 3.0 + velocity
	Sfx.play("slot_drop", -8.0)


# ---------------------------------------------------------------- mantle

func _try_mantle() -> bool:
	var space := get_world_3d().direct_space_state
	var fwd := -global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var chest := global_position + Vector3.UP * 0.9
	var wq := PhysicsRayQueryParameters3D.create(chest, chest + fwd * 0.75, 1 | 4)
	wq.exclude = [get_rid()]
	var wall := space.intersect_ray(wq)
	var knee := global_position + Vector3.UP * 0.45
	var kq := PhysicsRayQueryParameters3D.create(knee, knee + fwd * 0.75, 1 | 4)
	kq.exclude = [get_rid()]
	if wall.is_empty():
		wall = space.intersect_ray(kq)
	if wall.is_empty():
		return false
	var probe := Vector3(wall.position.x, global_position.y, wall.position.z) + fwd * 0.3
	var dq := PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 2.0, probe + Vector3.UP * 0.3, 1 | 4)
	dq.exclude = [get_rid()]
	var top := space.intersect_ray(dq)
	if top.is_empty() or (top.normal as Vector3).y < 0.7:
		return false
	var h: float = top.position.y - global_position.y
	if h < 0.45 or h > 1.75:
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = CROUCH_H
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, top.position + Vector3.UP * (CROUCH_H * 0.5 + 0.05) + fwd * 0.1)
	q.collision_mask = 1 | 4
	q.exclude = [get_rid()]
	if not space.intersect_shape(q, 1).is_empty():
		return false
	if stamina < 12.0:
		return false
	use_stamina(12.0)
	mantling = true
	_mantle_t = 0.0
	_mantle_from = global_position
	_mantle_to = top.position + fwd * 0.12 + Vector3.UP * 0.02
	velocity = Vector3.ZERO
	var hand_y: float = top.position.y
	viewmodel.mantle(Vector3(wall.position.x, hand_y, wall.position.z) - fwd * 0.05, fwd, h)
	Sfx.play("jump", -8.0)
	if riding == null and top.collider is RailVehicle:
		riding = top.collider
	return true


func _mantle_step(dt: float) -> void:
	var dur := 0.55
	_mantle_t += dt / dur
	var t := clampf(_mantle_t, 0.0, 1.0)
	var up := smoothstep(0.0, 0.7, t)
	var fwd := smoothstep(0.45, 1.0, t)
	var p := Vector3(lerpf(_mantle_from.x, _mantle_to.x, fwd), lerpf(_mantle_from.y, _mantle_to.y + 0.08, up), lerpf(_mantle_from.z, _mantle_to.z, fwd))
	if t >= 1.0:
		p = _mantle_to
	global_position = p
	crouch = move_toward(crouch, 0.6 if t < 0.8 else 0.0, dt * 4.0)
	if t >= 1.0:
		mantling = false
		Sfx.play("land_soft", -12.0)
		_detect_ride_after_mantle()


func _detect_ride_after_mantle() -> void:
	velocity = Vector3.ZERO
	move_and_slide()
	_detect_ride()


func play_hand_gesture(kind: String) -> void:
	viewmodel.gesture(kind)


# ---------------------------------------------------------------- tools

func tool_hit(id: String) -> void:
	var from := camera.global_position
	var dir := -camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 2.3, 1 | 4 | 16 | 32)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col: Object = hit.collider
	var valid := false
	if OS.is_debug_build() or "--autotest" in OS.get_cmdline_user_args():
		print("[hit] ", id, " -> ", (col as Node).name, " ", col.get_class())
	if col.has_method("tool_hit_shape"):
		valid = col.tool_hit_shape(id, hit.position, hit.normal, self, int(hit.shape))
	elif col.has_method("tool_hit"):
		valid = col.tool_hit(id, hit.position, hit.normal, self)
	else:
		var surf := str((col as Node).get_meta("surface", "ground")) if col is Node else "ground"
		if surf == "rock":
			Sfx.play_at("hit_rock", hit.position, -5.0)
			Fx.burst(get_tree().current_scene, hit.position, hit.normal, "rock", 5)
		elif surf == "metal":
			Sfx.play_at("lever", hit.position, -8.0, 0.2, 1.4)
		else:
			Sfx.play_at("hit_miss", hit.position, -4.0)
			Fx.burst(get_tree().current_scene, hit.position, hit.normal, "dust", 3)
	viewmodel.impulse(Vector3(0, 0.01, 0.04))
	shake(0.15)
	if valid:
		var s := inventory.get_slot(selected_slot)
		if not s.is_empty() and s.has("dur"):
			s.dur = int(s.dur) - 1
			if int(s.dur) <= 0:
				inventory.set_slot(selected_slot, {})
				Sfx.play("hit_miss", 0.0)
				if main and main.has_method("toast"):
					main.toast("%s broke" % Items.display_name(id))
			else:
				inventory.changed.emit()


# ---------------------------------------------------------------- survival helpers

var _eat_armed := true


func _eating(dt: float) -> void:
	if not Input.is_action_pressed("primary"):
		_eat_armed = true
	if eat_progress <= 0.0:
		if _eat_armed and input_enabled and Input.is_action_pressed("primary") and Items.is_consumable(equipped_id) and grabbing == null:
			eat_progress = 0.001
			_eat_armed = false
		return
	if not Input.is_action_pressed("primary") or not Items.is_consumable(equipped_id) or not input_enabled:
		eat_progress = 0.0
		return
	eat_progress += dt / 1.1
	if eat_progress >= 1.0:
		eat_progress = 0.0
		var d := Items.def(equipped_id)
		survival.eat(float(d.get("food", 0.0)), float(d.get("water", 0.0)), float(d.get("heal", 0.0)), float(d.get("poison", 0.0)))
		Sfx.play(str(d.get("eat", "eat_crunch")), -3.0)
		var leaves := str(d.get("leaves", ""))
		if leaves != "":
			inventory.swap_item(equipped_id, leaves, selected_slot)
		else:
			inventory.remove_at(selected_slot, 1)


var _hit_cd := 0.0


func _vehicle_hits() -> void:
	_hit_cd = maxf(0.0, _hit_cd - get_physics_process_delta_time())
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col is RailVehicle and absf(c.get_normal().y) < 0.5 and _hit_cd <= 0.0:
			var v: float = absf((col as RailVehicle).consist.v)
			if v > 2.5 and col != riding:
				_hit_cd = 1.0
				survival.damage(v * 5.0, "a train")
				velocity += c.get_normal() * v * 1.2 + Vector3.UP * 2.0


var _splash_cd := 0.0


func _water_check(dt: float) -> void:
	in_water = false
	if main == null or main.world == null:
		return
	var lvl: float = main.world.water_level_at(global_position.x, global_position.z)
	in_water = lvl > global_position.y + 0.05
	if in_water:
		velocity.x *= 1.0 - dt * 3.0
		velocity.z *= 1.0 - dt * 3.0
		_splash_cd -= dt
		if move_speed > 0.8 and _splash_cd <= 0.0:
			_splash_cd = 0.5
			Sfx.play("footstep_water", -8.0, 0.1)


# ---------------------------------------------------------------- crafting queue

signal crafted(id: String)

var craft_queue: Array = []   # [{recipe, t}]


func queue_craft(r: Dictionary) -> bool:
	if craft_queue.size() >= 8 or not Recipes.take(r, inventory):
		return false
	craft_queue.append({"recipe": r, "t": 0.0})
	Sfx.play(str(r.get("sound", "craft_wood")), -6.0, 0.1)
	return true


func _process(dt: float) -> void:
	if craft_queue.is_empty():
		return
	var job: Dictionary = craft_queue[0]
	job.t = float(job.t) + dt
	var r: Dictionary = job.recipe
	if float(job.t) >= float(r.time):
		craft_queue.pop_front()
		var left := inventory.add(str(r.out), int(r.n))
		if left > 0 and main:
			main.drop_item(str(r.out), left)
		Sfx.play("craft_complete", -6.0)
		crafted.emit(str(r.out))
		if not craft_queue.is_empty():
			Sfx.play(str((craft_queue[0].recipe as Dictionary).get("sound", "craft_wood")), -6.0, 0.1)


func craft_progress() -> float:
	if craft_queue.is_empty():
		return 0.0
	return float(craft_queue[0].t) / float((craft_queue[0].recipe as Dictionary).time)


var bow_draw := 0.0


func _release_bow() -> void:
	if bow_draw <= 0.0:
		return
	var pwr := bow_draw
	bow_draw = 0.0
	if pwr < 0.2 or Items.tool_type(equipped_id) != "bow" or not inventory.remove("arrow", 1):
		return
	var dir := -camera.global_basis.z
	Arrow.fire(get_tree().current_scene, camera.global_position + dir * 0.6 + camera.global_basis.y * -0.05, dir, lerpf(18.0, 62.0, pwr), self, pwr)
	Sfx.play("bow_release", -2.0)
	Sfx.play("arrow_whoosh", -8.0)
	viewmodel.impulse(Vector3(0, 0, 0.05))
