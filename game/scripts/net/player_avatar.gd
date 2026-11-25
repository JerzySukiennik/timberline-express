# Another player's body: a flannel-shirted survivor with swinging limbs, the held item in the right hand and a name
# tag, interpolated from network state.
class_name PlayerAvatar
extends Node3D

const SHIRTS := [Color(0.55, 0.12, 0.1), Color(0.14, 0.3, 0.55), Color(0.2, 0.42, 0.22), Color(0.5, 0.36, 0.12)]

var peer_id := 0
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _pitch := 0.0
var _speed := 0.0
var _crouch := 0.0
var _phase := 0.0
var _has := false
var _dead := false
var _body: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _hand: Node3D
var _item: Node3D
var _item_id := "-"
var _label: Label3D


func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 12
	c.rings = 4
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _ready() -> void:
	var shirt := _mat(SHIRTS[peer_id % SHIRTS.size()])
	var jeans := _mat(Color(0.16, 0.2, 0.3))
	var skin := _mat(Color(0.86, 0.66, 0.52), 0.7)
	var boots := _mat(Color(0.18, 0.12, 0.08))
	var hat := _mat(Color(0.22, 0.2, 0.17))
	_body = Node3D.new()
	add_child(_body)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.11 * side, 0.9, 0)
		_body.add_child(hip)
		_capsule(hip, 0.085, 0.86, Vector3(0, -0.43, 0), jeans)
		_box(hip, Vector3(0.14, 0.1, 0.28), Vector3(0, -0.86, -0.05), boots)
		_legs.append(hip)
	var torso := _capsule(_body, 0.21, 0.72, Vector3(0, 1.22, 0), shirt)
	torso.scale = Vector3(1.0, 1.0, 0.7)
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.28 * side, 1.46, 0)
		_body.add_child(shoulder)
		_capsule(shoulder, 0.065, 0.62, Vector3(0, -0.3, 0), shirt)
		_box(shoulder, Vector3(0.09, 0.1, 0.1), Vector3(0, -0.64, 0), skin)
		_arms.append(shoulder)
	_hand = Node3D.new()
	_hand.position = Vector3(0, -0.66, -0.04)
	_arms[1].add_child(_hand)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.68, 0)
	_body.add_child(_head)
	var h := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.12
	sph.height = 0.27
	h.mesh = sph
	h.material_override = skin
	h.position.y = 0.06
	_head.add_child(h)
	var brim := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = 0.02
	brim.mesh = cyl
	brim.material_override = hat
	brim.position.y = 0.15
	_head.add_child(brim)
	var crown := MeshInstance3D.new()
	var cyl2 := CylinderMesh.new()
	cyl2.top_radius = 0.1
	cyl2.bottom_radius = 0.125
	cyl2.height = 0.12
	crown.mesh = cyl2
	crown.material_override = hat
	crown.position.y = 0.21
	_head.add_child(crown)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.2
	_label.font_size = 56
	_label.pixel_size = 0.004
	_label.outline_size = 12
	_label.modulate = UI.PAPER
	_label.outline_modulate = Color(0.05, 0.05, 0.04)
	_label.font = UI.font("SemiBold")
	add_child(_label)


func set_display_name(n: String) -> void:
	if _label:
		_label.text = n


func set_state(pos: Vector3, yaw: float, pitch: float, item: String, speed: float, crouching: bool, dead: bool) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_pitch = pitch
	_speed = speed
	_crouch = 1.0 if crouching else 0.0
	_dead = dead
	if not _has:
		global_position = pos
		rotation.y = yaw
		_has = true
	if item != _item_id:
		_item_id = item
		if _item:
			_item.queue_free()
			_item = null
		if item != "":
			_item = Items.instance(item)
			if _item:
				_hand.add_child(_item)
				_item.rotation = Vector3(-PI * 0.5, 0, 0)


func _process(dt: float) -> void:
	if not _has:
		return
	var k := 1.0 - exp(-dt * 14.0)
	if global_position.distance_to(_target_pos) > 8.0:
		global_position = _target_pos
	global_position = global_position.lerp(_target_pos, k)
	rotation.y = lerp_angle(rotation.y, _target_yaw, k)
	_head.rotation.x = lerpf(_head.rotation.x, clampf(_pitch, -0.9, 0.9), k)
	_phase += dt * clampf(_speed, 0.0, 6.0) * 2.6
	var swing := sin(_phase) * clampf(_speed / 3.0, 0.0, 1.0) * 0.6
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_arms[0].rotation.x = -swing * 0.8
	_arms[1].rotation.x = swing * 0.5 + (-0.6 if _item_id != "" else 0.0) + clampf(_pitch, -0.8, 0.8) * 0.5
	_body.position.y = lerpf(_body.position.y, -0.35 * _crouch, k)
	_body.rotation.x = lerpf(_body.rotation.x, 0.25 * _crouch, k)
	rotation.z = lerpf(rotation.z, PI * 0.5 if _dead else 0.0, k * 0.5)
