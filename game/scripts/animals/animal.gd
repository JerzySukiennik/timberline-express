# Wild animal: grazes and wanders, notices the player, flees (prey) or hunts in a pack (wolves). Dies into a carcass
# that is butchered with a knife for meat and leather.
class_name Animal
extends CharacterBody3D

const SPECIES := {
	"deer": {"model": "deer", "length": 1.75, "hp": 70.0, "walk": 1.4, "run": 9.0, "sense": 26.0, "prey": true, "meat": 4, "leather": 2, "call": "deer_call", "run_sound": "deer_flee", "anim": {"idle": "Idle", "eat": "Eating", "walk": "Walk", "run": "Gallop", "attack": "Attack_Headbutt", "death": "Death", "hit": "Idle_HitReact_Left"}},
	"fox": {"model": "fox", "length": 0.95, "hp": 25.0, "walk": 1.1, "run": 7.5, "sense": 18.0, "prey": true, "meat": 1, "leather": 1, "call": "", "run_sound": "paws", "anim": {"idle": "Idle", "eat": "Eating", "walk": "Walk", "run": "Gallop", "attack": "Attack", "death": "Death", "hit": "Idle_HitReact_Left"}},
	"wolf": {"model": "wolf", "length": 1.45, "hp": 60.0, "walk": 1.5, "run": 7.8, "sense": 34.0, "prey": false, "damage": 13.0, "meat": 2, "leather": 2, "call": "wolf_howl", "run_sound": "paws", "anim": {"idle": "Idle", "eat": "Idle_Eating", "walk": "Walk", "run": "Run", "attack": "Headbutt", "death": "Death", "hit": "Idle"}},
}

var species := "deer"
var spec: Dictionary
var hp := 50.0
var state := "idle"      # idle, graze, wander, flee, chase, attack, dead
var target: Node3D
var main: Node
var pack: Array = []
var _model: Node3D
var _anim: AnimationPlayer
var _timer := 0.0
var _dir := Vector3.FORWARD
var _attack_cd := 0.0
var _call_cd := 0.0
var _butchered := false
var _cur_anim := ""


static func spawn(main_node: Node, kind: String, pos: Vector3) -> Animal:
	var a := Animal.new()
	a.species = kind
	a.main = main_node
	main_node.add_child(a)
	a.global_position = pos
	return a


func _ready() -> void:
	spec = SPECIES[species]
	hp = spec.hp
	collision_layer = 128
	collision_mask = 1 | 4
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(55)
	add_to_group("animals")
	_model = (load("res://assets/models/animals/%s.glb" % spec.model) as PackedScene).instantiate() as Node3D
	add_child(_model)
	_model.rotation.y = PI
	var size := _measure(_model)
	var s: float = spec.length / maxf(maxf(size.x, size.z), 0.01)
	_model.scale = Vector3.ONE * s
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25 * spec.length
	cap.height = spec.length
	cs.shape = cap
	cs.rotation.x = PI * 0.5
	cs.position.y = 0.32 * spec.length + 0.1
	add_child(cs)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	rotation.y = randf() * TAU
	_pick("graze")


func _measure(n: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a := m.global_transform * m.get_aabb() if m.is_inside_tree() else Terrain._rel(n, m) * m.get_aabb()
		box = a if first else box.merge(a)
		first = false
	# skinned meshes report bind-pose aabb in armature units; fall back to the skeleton's bone spread
	for skel in n.find_children("*", "Skeleton3D", true, false):
		var s3 := skel as Skeleton3D
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for b in s3.get_bone_count():
			var p := Terrain._rel(n, s3) * s3.get_bone_global_rest(b).origin
			lo = lo.min(p)
			hi = hi.max(p)
		if hi.x > lo.x:
			return (hi - lo) * 1.25
	return box.size


func _play(name: String, speed := 1.0) -> void:
	if _anim == null:
		return
	var key: String = spec.anim.get(name, "Idle")
	var full := ""
	for a in _anim.get_animation_list():
		if a == key or a.ends_with("|" + key):
			full = a
			break
	if full == "" or full == _cur_anim:
		_anim.speed_scale = speed
		return
	_cur_anim = full
	var anim := _anim.get_animation(full)
	if name != "death" and name != "attack" and name != "hit":
		anim.loop_mode = Animation.LOOP_LINEAR
	_anim.play(full, 0.25)
	_anim.speed_scale = speed


func _pick(s: String) -> void:
	state = s
	match s:
		"graze":
			_timer = randf_range(3.0, 9.0)
			_play("eat" if randf() < 0.6 else "idle")
		"wander":
			_timer = randf_range(3.0, 7.0)
			_dir = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
			_play("walk")


func _physics_process(dt: float) -> void:
	if state == "dead":
		velocity.x = move_toward(velocity.x, 0.0, dt * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, dt * 8.0)
		velocity.y -= 12.0 * dt
		move_and_slide()
		return
	var player: Node3D = main.player if main else null
	_attack_cd = maxf(0.0, _attack_cd - dt)
	_call_cd = maxf(0.0, _call_cd - dt)
	var want := Vector3.ZERO
	var speed := 0.0
	if player and not player.survival.dead:
		var d := global_position.distance_to(player.global_position)
		var noisy: bool = player.sprinting or (player.move_speed > 0.5 and not player.crouching)
		var sense: float = spec.sense * (1.0 if noisy else 0.55)
		if spec.prey:
			if d < sense and state != "flee":
				state = "flee"
				_timer = randf_range(5.0, 8.0)
				if spec.call != "" and _call_cd <= 0.0:
					Sfx.play_at(spec.call, global_position, -2.0)
					_call_cd = 6.0
				for other in pack:
					if is_instance_valid(other) and other.state != "flee" and other.state != "dead":
						other.state = "flee"
						other._timer = randf_range(5.0, 8.0)
		else:
			if d < sense and state != "chase" and state != "attack":
				state = "chase"
				target = player
				if _call_cd <= 0.0:
					Sfx.play_at("wolf_growl", global_position, 0.0)
					_call_cd = 8.0
			elif d > sense * 1.8 and (state == "chase" or state == "attack"):
				_pick("wander")
	match state:
		"graze":
			_timer -= dt
			if _timer <= 0.0:
				_pick("wander" if randf() < 0.6 else "graze")
		"wander":
			_timer -= dt
			want = _dir
			speed = spec.walk
			if _timer <= 0.0:
				_pick("graze")
		"flee":
			_timer -= dt
			if player:
				var away := global_position - player.global_position
				away.y = 0
				want = away.normalized() if away.length() > 0.1 else _dir
			speed = spec.run
			_play("run", 1.0)
			if _timer <= 0.0:
				_pick("wander")
		"chase", "attack":
			if target:
				var to := target.global_position - global_position
				to.y = 0
				var dist := to.length()
				want = to.normalized()
				speed = spec.run if dist > 2.2 else 0.0
				if dist < 2.0:
					state = "attack"
					if _attack_cd <= 0.0:
						_attack_cd = 1.3
						_play("attack", 1.3)
						Sfx.play_at("wolf_bark", global_position, 0.0)
						get_tree().create_timer(0.35).timeout.connect(func() -> void:
							if is_instance_valid(self) and state != "dead" and is_instance_valid(target) and global_position.distance_to(target.global_position) < 2.4:
								target.survival.damage(float(spec.get("damage", 10.0)), "a wolf"))
				else:
					state = "chase"
					_play("run", 1.0)
	# steer around obstacles and keep off very steep ground
	if want != Vector3.ZERO:
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, global_position + Vector3.UP * 0.6 + want * 2.2, 1 | 4)
		q.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			want = want.rotated(Vector3.UP, 1.2 if randf() < 0.5 else -1.2)
			_dir = want
		var yaw := atan2(want.x, want.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(dt * 5.0, 0.0, 1.0))
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var hv := fwd * speed
	velocity.x = move_toward(velocity.x, hv.x, dt * 14.0)
	velocity.z = move_toward(velocity.z, hv.z, dt * 14.0)
	if not is_on_floor():
		velocity.y -= 12.0 * dt
	move_and_slide()
	if global_position.y < -80.0:
		queue_free()


func tool_hit(tool_id: String, point: Vector3, normal: Vector3, player: Node) -> bool:
	if state == "dead":
		if Items.tool_type(tool_id) == "knife":
			butcher(player)
			return true
		return false
	var base := {"knife": 22.0, "axe": 30.0, "spear": 42.0, "pickaxe": 20.0, "hammer": 12.0}.get(Items.tool_type(tool_id), 5.0) as float
	damage(base * maxf(Items.tool_power(tool_id), 0.5), player)
	Sfx.play_at("flesh_hit", point, 0.0)
	Fx.burst(get_tree().current_scene, point, normal, "rock", 6)
	return true


func damage(amount: float, from: Node) -> void:
	if state == "dead":
		return
	hp -= amount
	if hp <= 0.0:
		die()
		return
	if spec.prey:
		state = "flee"
		_timer = 8.0
	else:
		state = "chase"
		target = from if from else target
	_play("hit")


func die() -> void:
	state = "dead"
	_play("death")
	Sfx.play_at("wolf_death" if species == "wolf" else "body_fall", global_position, 0.0)
	collision_layer = 32
	var it := Interactable.make(self, 0.6 * spec.length, Vector3(0, 0.4, 0))
	it.prompt = func(p: Node) -> String:
		return "[E] Butcher with a knife" if Items.tool_type((p as Player).equipped_id) == "knife" else "Hold a knife to butcher"
	it.on_use = func(p: Node) -> void:
		if Items.tool_type((p as Player).equipped_id) == "knife":
			butcher(p)


func butcher(player: Node) -> void:
	if _butchered:
		return
	_butchered = true
	var scene := get_tree().current_scene
	for i in int(spec.meat):
		Pickup.spawn(scene, "raw_meat", 1, global_position + Vector3(randf_range(-0.3, 0.3), 0.6 + i * 0.12, randf_range(-0.3, 0.3)))
	for i in int(spec.leather):
		Pickup.spawn(scene, "leather", 1, global_position + Vector3(randf_range(-0.3, 0.3), 0.7, randf_range(-0.3, 0.3)))
	Sfx.play_at("flesh_hit", global_position, 0.0)
	if player and player.has_method("shake"):
		player.shake(0.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(queue_free)
