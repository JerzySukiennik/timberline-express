# First-person arms and held tool: two-bone IK onto grip points, procedural draw/holster/swing/gesture animation.
class_name ViewModel
extends Node3D

const SHOULDER_R := Vector3(0.17, -0.28, -0.02)
const SHOULDER_L := Vector3(-0.17, -0.28, -0.02)
const POLE_R := Vector3(0.8, -1.0, 0.4)
const POLE_L := Vector3(-0.8, -1.0, 0.4)

# Tool rigs. Poses are camera-space {b: handle bottom, d: handle direction, h: head/edge facing, lean: shoulder shift}.
# Right hand grips high on the handle (u_r), left hand low (u_l) — fractions of the tool length from the bottom.
const TOOLS := {
	"pickaxe": {
		"scale": 0.82, "u_r": 0.46, "u_l": 0.17, "two_hand": true, "alpha_r": 0.25, "alpha_l": -0.2,
		"idle": {"b": Vector3(0.1, -0.35, -0.2), "d": Vector3(0.15, 0.62, -0.77), "h": Vector3(-0.2, 0.2, -1.0)},
		"draw_from": {"b": Vector3(0.38, -0.85, 0.02), "d": Vector3(0.6, 0.45, 0.65), "h": Vector3(0, -1, 0)},
		"draw_time": 0.6, "swing_time": 1.0, "impact": 0.46, "swing_sound": "swing_heavy", "stamina": 7.0,
		"swing": [
			[0.0, "idle"],
			[0.34, {"b": Vector3(0.24, -0.27, -0.42), "d": Vector3(0.1, 0.88, 0.46), "h": Vector3(0.0, 0.46, -0.88), "lean": Vector3(0.01, 0.02, 0.0)}],
			[0.46, {"b": Vector3(0.05, -0.13, -0.3), "d": Vector3(0.0, -0.25, -0.97), "h": Vector3(0, -1, 0.25), "lean": Vector3(0, -0.02, -0.2)}],
			[0.62, {"b": Vector3(0.06, -0.22, -0.28), "d": Vector3(0.0, -0.45, -0.89), "h": Vector3(0, -0.9, 0.45), "lean": Vector3(0, -0.03, -0.14)}],
			[1.0, "idle"],
		],
	},
	"axe": {
		"scale": 1.0, "u_r": 0.45, "u_l": 0.12, "two_hand": true, "alpha_r": 0.25, "alpha_l": -0.2,
		"idle": {"b": Vector3(0.13, -0.31, -0.3), "d": Vector3(0.1, 0.65, -0.75), "h": Vector3(1.0, 0.0, 0.2)},
		"draw_from": {"b": Vector3(0.6, -0.55, -0.1), "d": Vector3(0.3, -0.4, 0.86), "h": Vector3(0, 1, 0)},
		"draw_time": 0.45, "swing_time": 0.82, "impact": 0.45, "swing_sound": "swing_heavy", "stamina": 6.0,
		"swing": [
			[0.0, "idle"],
			[0.32, {"b": Vector3(0.27, -0.22, -0.38), "d": Vector3(0.35, 0.85, 0.4), "h": Vector3(-0.3, 0.2, -1.0), "lean": Vector3(0.03, 0.02, 0.0)}],
			[0.45, {"b": Vector3(0.12, -0.2, -0.34), "d": Vector3(-0.7, -0.2, -0.68), "h": Vector3(-0.5, -0.8, 0.3), "lean": Vector3(-0.03, -0.03, -0.15)}],
			[0.6, {"b": Vector3(0.04, -0.26, -0.3), "d": Vector3(-0.75, -0.35, -0.55), "h": Vector3(-0.4, -0.85, 0.35), "lean": Vector3(-0.04, -0.03, -0.1)}],
			[1.0, "idle"],
		],
	},
	"knife": {
		"scale": 1.0, "u_r": 0.28, "u_l": -1.0, "two_hand": false, "alpha_r": 0.0,
		"idle": {"b": Vector3(0.2, -0.28, -0.36), "d": Vector3(-0.2, 0.35, -0.92), "h": Vector3(0, -1, 0)},
		"draw_from": {"b": Vector3(0.25, -0.62, -0.3), "d": Vector3(0, 1, 0), "h": Vector3(0, 0, 1)},
		"draw_time": 0.65, "spin": true, "swing_time": 0.5, "impact": 0.42, "swing_sound": "swing_light", "stamina": 3.0,
		"swing": [
			[0.0, "idle"],
			[0.28, {"b": Vector3(0.32, -0.14, -0.3), "d": Vector3(0.35, 0.55, -0.76), "h": Vector3(-1, 0, 0), "lean": Vector3(0.02, 0.01, 0.03)}],
			[0.42, {"b": Vector3(0.02, -0.26, -0.46), "d": Vector3(-0.75, 0.05, -0.66), "h": Vector3(-0.66, -0.1, 0.75), "lean": Vector3(-0.03, -0.02, -0.08)}],
			[0.58, {"b": Vector3(-0.1, -0.32, -0.4), "d": Vector3(-0.8, -0.1, -0.55), "h": Vector3(-0.6, -0.3, 0.7), "lean": Vector3(-0.03, -0.02, -0.05)}],
			[1.0, "idle"],
		],
	},
}

var player: Player
var current_id := ""
var state := "empty"
var t := 0.0
var arms: Node3D
var skel_r: Skeleton3D
var skel_l: Skeleton3D
var tool_node: Node3D
var tool_info := {}
var pending_id := ""
var swing_queued := false
var mantle_pts := []
var _hit_done := false
var _gesture := ""
var _gesture_t := 0.0
var _impulse := Vector3.ZERO
var _impulse_v := Vector3.ZERO
var _sway := Vector3.ZERO
var _smooth_r := {}
var _smooth_l := {}
var _rest := {}
var _grip_r := 0.3
var _grip_l := 0.3
var _hidden_r := 1.0
var _hidden_l := 1.0
var _bob := 0.0
var curl_sign := -1.0
var hand_flip := true
var grip_f := 0.1
var grip_p := 0.028
var freeze_t := -1.0          # autotest: hold the current animation at a fixed fraction


func _ready() -> void:
	arms = (load("res://assets/models/arms.glb") as PackedScene).instantiate() as Node3D
	add_child(arms)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/arms.gdshader")
	for mi in arms.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.extra_cull_margin = 2.0
	for sk in arms.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D
		var chain := str(s.get_path())
		var hand := s.find_bone("hand")
		if hand < 0:
			continue
		var gp := s.get_bone_global_rest(hand).origin
		if gp.x > 0.0 or chain.contains("RigR"):
			skel_r = s
		else:
			skel_l = s
	for s in [skel_r, skel_l]:
		if s:
			_rest[s] = _capture_rest(s)


func _capture_rest(s: Skeleton3D) -> Dictionary:
	var d := {}
	for n in ["upper", "fore", "hand"]:
		d[n] = s.get_bone_global_rest(s.find_bone(n))
	d["a"] = d.upper.origin.distance_to(d.fore.origin)
	d["b"] = d.fore.origin.distance_to(d.hand.origin)
	d["sign"] = 1.0 if d.hand.origin.x >= d.upper.origin.x - 0.001 and s == skel_r else -1.0
	return d


# ---------------------------------------------------------------- public API

func equip(id: String) -> void:
	if id == current_id and state != "holster":
		return
	pending_id = id
	if tool_node and state != "holster":
		state = "holster"
		t = 0.0
	elif not tool_node:
		_switch_to_pending()


func request_swing() -> void:
	if state == "idle" and TOOLS.has(current_id) and player.stamina > 2.0 and player.grabbing == null:
		state = "swing"
		t = 0.0
		_hit_done = false
		player.use_stamina(float(TOOLS[current_id].stamina))
		Sfx.play(TOOLS[current_id].swing_sound, -7.0, 0.1)


func gesture(kind: String) -> void:
	_gesture = kind
	_gesture_t = 0.0


func impulse(v: Vector3) -> void:
	_impulse_v += v * 20.0


func mantle(world_ledge: Vector3, fwd: Vector3, _height: float) -> void:
	var side := fwd.cross(Vector3.UP).normalized()
	mantle_pts = [world_ledge + side * 0.25, world_ledge - side * 0.25, 0.0]
	state = "mantle" if state != "swing" else state
	t = 0.0


# ---------------------------------------------------------------- tool setup

func _switch_to_pending() -> void:
	if tool_node:
		tool_node.queue_free()
		tool_node = null
	current_id = pending_id
	tool_info = {}
	if TOOLS.has(current_id) or Items.def(current_id).has("model"):
		tool_node = Items.instance(current_id)
		add_child(tool_node)
		for mi in tool_node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(mi as MeshInstance3D).extra_cull_margin = 2.0
		if tool_node is MeshInstance3D:
			(tool_node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tool_info = _analyse(tool_node, current_id)
	state = "draw" if current_id != "" else "empty"
	t = 0.0
	var sound := str(Items.def(current_id).get("equip", "equip_hand"))
	Sfx.play(sound, -6.0, 0.06)


func _analyse(node: Node3D, id: String) -> Dictionary:
	var pts := PackedVector3Array()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := Terrain._rel(node, m)
		for si in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(si)
			for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				pts.append(xf * v)
	if node is MeshInstance3D:
		for v in ((node as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			pts.append(v)
	var info := {"bottom": Vector3.ZERO, "axis": Vector3.UP, "head": Vector3.FORWARD, "length": 0.5}
	if pts.is_empty():
		return info
	var grip := node.find_child("M_Grip", true, false) as Node3D
	var tip := node.find_child("M_Tip", true, false) as Node3D
	if grip and tip:
		var a := (tip.position - grip.position).normalized()
		info.axis = a
		info.bottom = grip.position - a * 0.065
		info.length = (tip.position - info.bottom).length()
		info.head = Vector3.DOWN
		return info
	var mn := pts[0]
	var mx := pts[0]
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	var size := mx - mn
	var ax := 0
	for i in 3:
		if size[i] > size[ax]:
			ax = i
	var axis := Vector3.ZERO
	axis[ax] = 1.0
	var lo := mn[ax]
	var hi := mx[ax]
	var len := hi - lo
	var top_spread := 0.0
	var bot_spread := 0.0
	var top_centroid := Vector3.ZERO
	var top_n := 0
	var center := (mn + mx) * 0.5
	for p in pts:
		var f := (p[ax] - lo) / len
		var off := p - center
		off[ax] = 0.0
		if f > 0.82:
			top_spread = maxf(top_spread, off.length())
			top_centroid += off
			top_n += 1
		elif f < 0.18:
			bot_spread = maxf(bot_spread, off.length())
	var head_hi := top_spread >= bot_spread
	if not head_hi:
		axis = -axis
		top_centroid = Vector3.ZERO
		top_n = 0
		for p in pts:
			var f2 := (p[ax] - lo) / len
			if f2 < 0.18:
				var off2 := p - center
				off2[ax] = 0.0
				top_centroid += off2
				top_n += 1
	# handle axis passes through the handle, not the head: use the centroid of the lower half
	var hc := Vector3.ZERO
	var hn := 0
	for p in pts:
		var f3 := (p[ax] - lo) / len
		if (f3 < 0.5 and head_hi) or (f3 > 0.5 and not head_hi):
			hc += p
			hn += 1
	hc /= maxf(hn, 1)
	var bottom := hc
	bottom[ax] = lo if head_hi else hi
	var head := Vector3.ZERO
	if top_n > 0:
		head = top_centroid / top_n
	if head.length() < 0.02:
		var perp := size
		perp[ax] = 0.0
		var pi := 0 if ax != 0 else 1
		for i in 3:
			if i != ax and perp[i] > perp[pi]:
				pi = i
		head = Vector3.ZERO
		head[pi] = 1.0
	info.axis = axis
	info.bottom = bottom
	info.length = len
	info.head = head.normalized()
	return info


# ---------------------------------------------------------------- per frame

func _process(dt: float) -> void:
	if player == null or skel_r == null or skel_l == null:
		return
	var cfg: Dictionary = TOOLS.get(current_id, {})
	var dur := 0.3
	match state:
		"holster":
			dur = 0.22
		"draw":
			dur = float(cfg.get("draw_time", 0.35))
		"swing":
			dur = float(cfg.get("swing_time", 0.6))
		"mantle":
			dur = 0.55
	if freeze_t >= 0.0:
		t = freeze_t
	else:
		t += dt / dur
	var pose := _tool_pose(cfg)
	# state transitions
	if state == "swing" and not _hit_done and t >= float(cfg.get("impact", 0.5)):
		_hit_done = true
		_on_impact()
	if t >= 1.0 and freeze_t < 0.0:
		match state:
			"holster":
				_switch_to_pending()
			"draw", "swing", "mantle":
				state = "idle" if current_id != "" else "empty"
				t = 0.0
	_gesture_t += dt / 0.35
	_update_offsets(dt)
	var cam := player.camera
	var sprint_k := clampf((player.move_speed - Player.WALK) / (Player.SPRINT - Player.WALK), 0.0, 1.0) if player.sprinting else 0.0
	var off := _sway + Vector3(0, -0.06, 0.04) * sprint_k + _impulse
	var lean: Vector3 = pose.get("lean", Vector3.ZERO)
	var target_r := {}
	var target_l := {}
	var grip_r := 0.3
	var grip_l := 0.3
	var hide_tool := false
	if tool_node and not cfg.is_empty():
		var b: Vector3 = pose.b + off
		var d: Vector3 = (pose.d as Vector3).normalized()
		var h: Vector3 = pose.h
		# near-wall retract
		var wall := _wall_distance(cam)
		if wall < 0.9:
			b += Vector3(0.05, -0.12, 0.35) * (0.9 - wall) / 0.9
		var xf := _tool_transform(b, d, h, float(cfg.scale))
		# keep both grips within arm's reach: slide the whole tool toward the shoulders if needed
		var max_reach := 0.5
		var fix := Vector3.ZERO
		var gr: Vector3 = xf * (tool_info.bottom + tool_info.axis * tool_info.length * float(cfg.u_r))
		var sr: Vector3 = SHOULDER_R + lean
		if gr.distance_to(sr) > max_reach:
			fix = (sr - gr).normalized() * (gr.distance_to(sr) - max_reach)
		if cfg.two_hand:
			var glp: Vector3 = xf * (tool_info.bottom + tool_info.axis * tool_info.length * float(cfg.u_l))
			var sl: Vector3 = SHOULDER_L + lean
			if (glp + fix).distance_to(sl) > max_reach:
				fix += (sl - (glp + fix)).normalized() * ((glp + fix).distance_to(sl) - max_reach)
		if fix != Vector3.ZERO:
			xf.origin += fix
		if cfg.get("spin", false) and state == "draw":
			var e := 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 2.0)
			var grip_pt: Vector3 = xf * (tool_info.bottom + tool_info.axis * tool_info.length * float(cfg.u_r))
			var spin := Basis(Vector3.RIGHT, (1.0 - e) * TAU * 1.0)
			xf = Transform3D(spin, grip_pt) * Transform3D(Basis.IDENTITY, -grip_pt) * xf
		tool_node.transform = xf
		var axis_cam: Vector3 = (xf.basis * (tool_info.axis as Vector3)).normalized()
		var grip_world: Vector3 = xf * (tool_info.bottom + tool_info.axis * tool_info.length * float(cfg.u_r))
		target_r = _grip_target(grip_world, axis_cam, SHOULDER_R + lean, true, float(cfg.get("alpha_r", 0.3)))
		grip_r = 1.0
		if cfg.two_hand:
			var gl: Vector3 = xf * (tool_info.bottom + tool_info.axis * tool_info.length * float(cfg.u_l))
			target_l = _grip_target(gl, axis_cam, SHOULDER_L + lean, false, float(cfg.get("alpha_l", -0.3)))
			grip_l = 1.0
	elif tool_node:
		# carried item (resource, bucket...): hold it in the right hand in front
		var hold := Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.22, -0.3, -0.42) + off)
		var aabb_c := _node_center(tool_node)
		tool_node.transform = hold * Transform3D(Basis.IDENTITY, -aabb_c)
		target_r = _hand_frame(hold.origin + Vector3(0.04, -0.06, 0.1), Vector3(-0.2, 0.3, -1.0), Vector3(-0.3, 1.0, 0.0), true)
		grip_r = 0.75
	if tool_node and state == "holster" or state == "draw" and not cfg.is_empty():
		pass
	if target_r.is_empty():
		target_r = _hand_frame(Vector3(0.19, -0.27, -0.4) + off, Vector3(-0.15, 0.3, -1.0), Vector3(-0.45, 1.0, 0.0), true)
		grip_r = 0.35
	# grab: right hand goes to the control
	if player.grabbing and is_instance_valid(player.grabbing):
		var hp := cam.global_transform.affine_inverse() * player.grabbing.hand_point.global_position
		target_r = _grip_target(hp, (cam.global_transform.affine_inverse().basis * player.grabbing.hand_point.global_basis.x).normalized(), SHOULDER_R, true, 0.6)
		grip_r = 1.0
		hide_tool = true
	# gestures on the free hand
	if _gesture != "" and _gesture_t < 1.0:
		var g := sin(clampf(_gesture_t, 0.0, 1.0) * PI)
		var reach := Vector3(-0.02, 0.06, -0.22) * g
		if target_l.is_empty() and not (tool_node and cfg.get("two_hand", false)):
			target_l = _hand_frame(Vector3(-0.08, -0.3, -0.34) + reach, Vector3(0.15, 0.25, -1.0), Vector3(0.4, 1.0, 0.0), false)
			grip_l = 0.2 + g * 0.6
			_hidden_l = 0.0
	if state == "mantle" and mantle_pts.size() >= 2:
		var inv := cam.global_transform.affine_inverse()
		var push := smoothstep(0.35, 0.9, t) * 0.25
		target_r = _hand_frame(inv * (mantle_pts[0] as Vector3) + Vector3(0, -push, 0), Vector3(0, -0.3, -1), Vector3(-1, 0, 0), true)
		target_l = _hand_frame(inv * (mantle_pts[1] as Vector3) + Vector3(0, -push, 0), Vector3(0, -0.3, -1), Vector3(1, 0, 0), false)
		grip_r = 0.15
		grip_l = 0.15
		hide_tool = true
	if target_l.is_empty():
		target_l = _hand_frame(Vector3(-0.3, -0.85, -0.05), Vector3(0.1, 0.3, -1), Vector3(0.4, 1, 0), false)
		grip_l = 0.3
	if tool_node:
		tool_node.visible = not hide_tool or state == "swing"
		if hide_tool:
			tool_node.position += Vector3(0.2, -0.7, 0.2)
	# holster / draw blends
	var blend := 1.0
	if state == "holster":
		blend = 1.0 - smoothstep(0.0, 1.0, t)
	var k := clampf(dt * 22.0, 0.0, 1.0)
	_smooth_r = _lerp_frame(_smooth_r, target_r, 1.0 if _smooth_r.is_empty() else k)
	_smooth_l = _lerp_frame(_smooth_l, target_l, 1.0 if _smooth_l.is_empty() else clampf(dt * 14.0, 0.0, 1.0))
	_grip_r = lerpf(_grip_r, grip_r, clampf(dt * 12.0, 0.0, 1.0))
	_grip_l = lerpf(_grip_l, grip_l, clampf(dt * 12.0, 0.0, 1.0))
	_solve(skel_r, SHOULDER_R + lean + off * 0.3, _smooth_r, POLE_R, _grip_r)
	_solve(skel_l, SHOULDER_L + lean + off * 0.3, _smooth_l, POLE_L, _grip_l)


func _tool_pose(cfg: Dictionary) -> Dictionary:
	if cfg.is_empty():
		return {}
	var idle: Dictionary = cfg.idle
	match state:
		"draw":
			var e := _ease_out_back(clampf(t, 0.0, 1.0))
			return _mix_pose(cfg.draw_from, idle, e)
		"holster":
			var e2 := smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))
			return _mix_pose(idle, cfg.draw_from, e2)
		"swing":
			var keys: Array = cfg.swing
			var tt := clampf(t, 0.0, 1.0)
			for i in range(keys.size() - 1):
				var k0: Array = keys[i]
				var k1: Array = keys[i + 1]
				if tt >= float(k0[0]) and tt <= float(k1[0]):
					var f := (tt - float(k0[0])) / maxf(float(k1[0]) - float(k0[0]), 0.0001)
					var p0: Dictionary = idle if str(k0[1]) == "idle" else k0[1]
					var p1: Dictionary = idle if str(k1[1]) == "idle" else k1[1]
					return _mix_pose(p0, p1, f * f * (3.0 - 2.0 * f))
			return idle
	return idle


func _mix_pose(a: Dictionary, b: Dictionary, f: float) -> Dictionary:
	return {
		"b": (a.b as Vector3).lerp(b.b, f),
		"d": (a.d as Vector3).normalized().slerp((b.d as Vector3).normalized(), clampf(f, -0.3, 1.3)) if absf((a.d as Vector3).normalized().dot((b.d as Vector3).normalized())) < 0.9999 else (b.d as Vector3).normalized(),
		"h": (a.h as Vector3).normalized().lerp((b.h as Vector3).normalized(), f),
		"lean": (a.get("lean", Vector3.ZERO) as Vector3).lerp(b.get("lean", Vector3.ZERO), f),
	}


func _ease_out_back(x: float) -> float:
	var c1 := 1.4
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _tool_transform(b: Vector3, d: Vector3, h: Vector3, scl: float) -> Transform3D:
	var a_l: Vector3 = tool_info.axis
	var h_l: Vector3 = (tool_info.head - a_l * a_l.dot(tool_info.head)).normalized()
	var c_l := a_l.cross(h_l)
	var hh := (h - d * d.dot(h))
	hh = hh.normalized() if hh.length() > 0.001 else d.cross(Vector3.RIGHT).normalized()
	var c := d.cross(hh)
	var local_b := Basis(a_l, h_l, c_l)
	var cam_b := Basis(d, hh, c)
	var basis := (cam_b * local_b.inverse()).scaled(Vector3.ONE * scl)
	var origin := b - basis * (tool_info.bottom as Vector3)
	return Transform3D(basis, origin)


func _node_center(n: Node3D) -> Vector3:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		return Terrain._rel(n, mi) * (mi as MeshInstance3D).get_aabb().get_center()
	return Vector3.ZERO


func _wall_distance(cam: Camera3D) -> float:
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 0.9, 1 | 4)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return 0.9 if hit.is_empty() else cam.global_position.distance_to(hit.position)


func _update_offsets(dt: float) -> void:
	var md := player.mouse_delta
	var target := Vector3(-md.x * 0.00035, md.y * 0.00035, 0).limit_length(0.05)
	_sway = _sway.lerp(target, clampf(dt * 8.0, 0.0, 1.0))
	if player.is_on_floor() and player.move_speed > 0.3:
		_bob += dt * player.move_speed * (1.9 if player.sprinting else 2.3)
		var amp := 0.012 if not player.sprinting else 0.03
		_sway += Vector3(sin(_bob * PI) * amp, -absf(cos(_bob * PI)) * amp, 0) * dt * 10.0
	# spring for impulses
	_impulse_v += (-_impulse * 90.0 - _impulse_v * 12.0) * dt
	_impulse += _impulse_v * dt


# ---------------------------------------------------------------- hands & IK

## Hand frame for a grip on a handle: thumb along the axis, fingers wrap from the shoulder side.
func _grip_target(g: Vector3, axis: Vector3, shoulder: Vector3, right: bool, alpha: float) -> Dictionary:
	var A := axis.normalized()
	var s := shoulder - g
	var sp := s - A * A.dot(s)
	sp = sp.normalized() if sp.length() > 0.001 else Vector3.BACK
	var F := (-sp).rotated(A, alpha if right else -alpha)
	F = (F - A * A.dot(F)).normalized()
	var T := A
	var P := T.cross(F) if right else -T.cross(F)
	var wrist := g - P * grip_p - F * grip_f
	return {"w": wrist, "t": T, "f": F, "p": P}


func _hand_frame(wrist: Vector3, fingers: Vector3, thumb: Vector3, right: bool) -> Dictionary:
	var F := fingers.normalized()
	var T := (thumb - F * F.dot(thumb)).normalized()
	var P := T.cross(F) if right else -T.cross(F)
	return {"w": wrist, "t": T, "f": F, "p": P}


func _lerp_frame(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	if a.is_empty() or k >= 1.0:
		return b.duplicate()
	var f := (a.f as Vector3).lerp(b.f, k).normalized()
	var th := (a.t as Vector3).lerp(b.t, k)
	th = (th - f * f.dot(th)).normalized()
	var right: bool = (b.p as Vector3).dot((b.t as Vector3).cross(b.f)) > 0.0
	return {"w": (a.w as Vector3).lerp(b.w, k), "f": f, "t": th, "p": th.cross(f) if right else -th.cross(f)}


func _solve(s: Skeleton3D, shoulder_cam: Vector3, frame: Dictionary, pole_cam: Vector3, grip: float) -> void:
	var r: Dictionary = _rest[s]
	var to_skel := s.global_transform.affine_inverse() * global_transform
	var S := to_skel * shoulder_cam
	var W := to_skel * (frame.w as Vector3)
	var Fv := (to_skel.basis * (frame.f as Vector3)).normalized()
	var Tv := (to_skel.basis * (frame.t as Vector3)).normalized()
	var Pv := (to_skel.basis * (frame.p as Vector3)).normalized()
	var pole := (to_skel.basis * pole_cam).normalized()
	var a: float = r.a
	var b: float = r.b
	var dvec := W - S
	var d := clampf(dvec.length(), 0.05, a + b - 0.002)
	var dir := dvec.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var along := a * cos_a
	var hgt := sqrt(maxf(a * a - along * along, 0.0))
	var pp := (pole - dir * dir.dot(pole))
	pp = pp.normalized() if pp.length() > 0.001 else Vector3.DOWN
	var E := S + dir * along + pp * hgt
	W = S + dir * d
	var rest_up: Transform3D = r.upper
	var rest_fore: Transform3D = r.fore
	var rest_hand: Transform3D = r.hand
	var q0 := Vector3.DOWN
	var up_basis := _frame_basis(E - S, pp) * _frame_basis(rest_fore.origin - rest_up.origin, q0).inverse() * rest_up.basis
	var fore_q := (pp + (Pv - (W - E).normalized() * (W - E).normalized().dot(Pv)).normalized()).normalized()
	var fore_basis := _frame_basis(W - E, fore_q) * _frame_basis(rest_hand.origin - rest_fore.origin, q0).inverse() * rest_fore.basis
	var sgn := 1.0 if s == skel_r else -1.0
	var sem_rest := Basis(Vector3(-sgn, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0))
	# measured on screen: the imported hand's palm/thumb are flipped about the finger axis vs. the Blender layout
	var sem_target := Basis(-Tv, Fv, -Pv) if hand_flip else Basis(Tv, Fv, Pv)
	var hand_basis := sem_target * sem_rest.inverse() * rest_hand.basis
	var g_up := Transform3D(up_basis.orthonormalized(), S)
	var g_fore := Transform3D(fore_basis.orthonormalized(), E)
	var g_hand := Transform3D(hand_basis.orthonormalized(), W)
	var iu := s.find_bone("upper")
	var i_f := s.find_bone("fore")
	var ih := s.find_bone("hand")
	var pu := s.get_bone_parent(iu)
	var parent_g := s.get_bone_global_pose(pu) if pu >= 0 else Transform3D.IDENTITY
	s.set_bone_pose(iu, parent_g.affine_inverse() * g_up)
	s.set_bone_pose(i_f, g_up.affine_inverse() * g_fore)
	s.set_bone_pose(ih, g_fore.affine_inverse() * g_hand)
	_curl(s, grip)


func _frame_basis(dir: Vector3, q: Vector3) -> Basis:
	var y := dir.normalized()
	var qq := (q - y * y.dot(q))
	qq = qq.normalized() if qq.length() > 0.001 else y.cross(Vector3.RIGHT).normalized()
	var x := qq.cross(y).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


func _curl(s: Skeleton3D, g: float) -> void:
	for n in ["index", "middle", "ring", "pinky"]:
		for i in 3:
			var bi := s.find_bone("%s%d" % [n, i + 1])
			if bi < 0:
				continue
			var ang: float = [1.25, 1.45, 1.0][i] * g + 0.12
			var rest := s.get_bone_rest(bi)
			s.set_bone_pose(bi, Transform3D(rest.basis * Basis(Vector3.RIGHT, -ang * curl_sign), rest.origin))
	for i in 3:
		var bt := s.find_bone("thumb%d" % (i + 1))
		if bt < 0:
			continue
		var rest_t := s.get_bone_rest(bt)
		var sgn := 1.0 if s == skel_r else -1.0
		s.set_bone_pose(bt, Transform3D(rest_t.basis * Basis(Vector3.RIGHT, -0.5 * g * curl_sign) * Basis(Vector3.FORWARD, 0.35 * g * sgn), rest_t.origin))


func _on_impact() -> void:
	if player and player.has_method("tool_hit"):
		player.tool_hit(current_id)
