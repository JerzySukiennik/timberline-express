# Renders item models into small transparent icons once, in an offscreen viewport with its own world.
class_name IconBaker
extends Node

signal baked(id: String, texture: Texture2D)

var _cache := {}
var _queue: Array[String] = []
var _busy := false
var _viewport: SubViewport
var _holder: Node3D
var _camera: Camera3D


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(128, 128)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.72)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.6
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 28.0
	_viewport.add_child(_camera)
	_holder = Node3D.new()
	_viewport.add_child(_holder)


func get_icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	if DisplayServer.get_name() == "headless":
		return null
	if not id in _queue:
		_queue.append(id)
		_run.call_deferred()
	return null


func _run() -> void:
	if _busy:
		return
	_busy = true
	while not _queue.is_empty():
		var id: String = _queue.pop_front()
		for c in _holder.get_children():
			c.free()
		var inst := Items.instance(id)
		_holder.add_child(inst)
		var aabb := Props._aabb(inst)
		if inst is MeshInstance3D:
			aabb = (inst as MeshInstance3D).get_aabb()
		inst.position = -aabb.get_center()
		var longest := aabb.get_longest_axis_index()
		_holder.basis = Basis.IDENTITY
		if longest == 1:
			_holder.basis = Basis(Vector3.FORWARD, deg_to_rad(-45))
		elif longest == 2:
			_holder.basis = Basis(Vector3.UP, deg_to_rad(90)) * Basis(Vector3.FORWARD, deg_to_rad(-45))
		_holder.rotate_y(0.5)
		var radius := maxf(aabb.size.length() * 0.5, 0.05)
		_camera.position = Vector3(0, radius * 0.6, radius * 4.2)
		_camera.look_at(Vector3.ZERO)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var tex := ImageTexture.create_from_image(_viewport.get_texture().get_image())
		_cache[id] = tex
		baked.emit(id, tex)
	_busy = false
