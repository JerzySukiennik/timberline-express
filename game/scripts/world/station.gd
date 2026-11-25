# Placed station: campfire / furnace (process + fuel), workbench (enables recipes), chest (storage), bed (respawn).
# Lives on the ground or on a rail vehicle; on a vehicle its colliders become shapes of the vehicle so players ride it.
class_name Station
extends Node3D

const SIZES := {"campfire": Vector3(1.1, 0.4, 1.1), "workbench": Vector3(1.6, 0.9, 0.75), "furnace": Vector3(1.2, 1.6, 1.2), "chest": Vector3(0.9, 0.62, 0.55), "bed": Vector3(0.95, 0.55, 2.0)}

var kind := ""
var main: Node
var inventory: Inventory
var burn := 0.0          # seconds of fuel left
var progress := 0.0
var vehicle: RailVehicle
var _shapes: Array[CollisionShape3D] = []
var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D
var _light: OmniLight3D
var _fire: GPUParticles3D
var _loop: AudioStreamPlayer3D
var _lid: Node3D


static func place(main_node: Node, kind_id: String, xf: Transform3D, on: Node) -> Station:
	var s := Station.new()
	s.kind = kind_id
	s.main = main_node
	var parent: Node3D = on if on is RailVehicle else main_node
	parent.add_child(s)
	s.global_transform = xf
	if on is RailVehicle:
		s.vehicle = on
	s._build()
	if kind_id == "bed":
		main_node.beds.append(s)
	main_node.stations.append(s)
	if NetSync.hosting():
		NetSync.inst.register(s, "station")
	return s


func _build() -> void:
	var model := (load("res://assets/models/props/%s.glb" % kind) as PackedScene).instantiate() as Node3D
	add_child(model)
	var size: Vector3 = SIZES[kind]
	var body_owner: CollisionObject3D = vehicle
	if vehicle == null:
		var sb := StaticBody3D.new()
		sb.set_meta("surface", "wood")
		add_child(sb)
		body_owner = sb
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size if kind != "campfire" else Vector3(0.8, 0.25, 0.8)
	cs.shape = bs
	cs.set_meta("surface", "wood")
	body_owner.add_child(cs)
	cs.global_transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0, bs.size.y * 0.5, 0))
	_shapes.append(cs)
	var it := Interactable.make(self, maxf(size.x, size.z) * 0.55, Vector3(0, size.y * 0.55, 0))
	it.prompt = _prompt
	it.on_use = _use
	it.on_secondary = _pick_up
	match kind:
		"campfire", "furnace":
			inventory = Inventory.new(3)
			_glow = model.find_child("FurnaceGlow", true, false) as MeshInstance3D
			if _glow:
				_glow_mat = StandardMaterial3D.new()
				_glow_mat.albedo_color = Color(0.05, 0.02, 0.0)
				_glow_mat.emission_enabled = true
				_glow_mat.emission = Color(1.0, 0.45, 0.12)
				_glow.material_override = _glow_mat
			_light = OmniLight3D.new()
			_light.light_color = Color(1.0, 0.58, 0.25)
			_light.omni_range = 7.0 if kind == "campfire" else 5.0
			_light.light_energy = 0.0
			_light.shadow_enabled = kind == "campfire"
			add_child(_light)
			_light.position = Vector3(0, 0.6 if kind == "campfire" else 0.4, 0 if kind == "campfire" else -0.4)
			_fire = _flames(Vector3(0, 0.2, 0) if kind == "campfire" else Vector3(0, 1.75, 0), kind == "campfire")
			_loop = Sfx.loop("campfire_loop" if kind == "campfire" else "furnace_loop", self, -80.0, 4.0, 30.0)
		"chest":
			inventory = Inventory.new(20)
			_lid = model.find_child("Lid", true, false) as Node3D
		"bed":
			pass


func _flames(pos: Vector3, fire: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40 if fire else 30
	p.lifetime = 0.9 if fire else 2.5
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 0.6 if fire else 1.2
	pm.initial_velocity_max = 1.4 if fire else 2.0
	pm.gravity = Vector3(0, 0.8 if fire else 0.3, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var grad := Gradient.new()
	if fire:
		grad.set_color(0, Color(0.9, 0.42, 0.1, 0.55))
		grad.add_point(0.45, Color(0.75, 0.2, 0.03, 0.35))
		grad.set_color(1, Color(0.2, 0.08, 0.02, 0.0))
	else:
		grad.set_color(0, Color(0.3, 0.3, 0.3, 0.5))
		grad.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.32) if fire else Vector2(0.7, 0.7)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if fire else BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
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
	p.emitting = false
	add_child(p)
	p.position = pos
	return p


func _prompt(_p: Node) -> String:
	match kind:
		"campfire", "furnace":
			var st := "lit" if burn > 0.0 else "cold"
			return "[E] %s (%s)  ·  [RMB] Pick up" % [Items.display_name(kind), st]
		"workbench":
			return "[E] Craft at workbench  ·  [RMB] Pick up"
		"chest":
			return "[E] Open chest  ·  [RMB] Pick up"
		"bed":
			return "Your respawn point  ·  [E] Rest  ·  [RMB] Pick up"
	return ""


func _use(p: Node) -> void:
	match kind:
		"campfire", "furnace":
			main.open_container(inventory, "%s  —  input · fuel · output" % Items.display_name(kind), Callable(), self)
		"workbench":
			main.open_container(null, "", Callable(), self)
		"chest":
			Sfx.play_at("chest_open", global_position, -3.0)
			if _lid:
				create_tween().tween_property(_lid, "rotation:x", -1.7, 0.35).set_trans(Tween.TRANS_BACK)
			main.open_container(inventory, "Storage Chest", func() -> void:
				if _lid:
					create_tween().tween_property(_lid, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE)
				Sfx.play_at("crate_close", global_position, -3.0), self)
		"bed":
			Sfx.play_at("bed_creak", global_position, -4.0)
			main.beds.erase(self)
			main.beds.push_front(self)
			if main.has_method("toast"):
				main.toast("Respawn point set")
			(p as Player).stamina = 100.0


func _pick_up(p: Node) -> void:
	var inv: Inventory = (p as Player).inventory
	if inventory:
		for i in inventory.size():
			var s := inventory.get_slot(i)
			if not s.is_empty():
				if main.has_method("toast"):
					main.toast("Empty it first")
				return
	if inv.add(kind, 1) > 0:
		return
	Sfx.play_at("build_remove", global_position, -2.0)
	remove()


func remove() -> void:
	for cs in _shapes:
		if is_instance_valid(cs):
			cs.queue_free()
	main.beds.erase(self)
	main.stations.erase(self)
	queue_free()


func _process(dt: float) -> void:
	if inventory == null or not (kind == "campfire" or kind == "furnace"):
		return
	var input := inventory.get_slot(0)
	var fuel := inventory.get_slot(1)
	var out := inventory.get_slot(2)
	if Net.is_client_online():
		_visuals(dt, burn > 0.0)
		return
	var recipe: Array = []
	if not input.is_empty() and Recipes.PROCESS[kind].has(input.id):
		recipe = Recipes.PROCESS[kind][input.id]
	var out_ok: bool = not recipe.is_empty() and (out.is_empty() or (out.id == recipe[0] and int(out.count) < Items.stack_size(recipe[0])))
	# keep a campfire burning even without work (warmth, light); furnace only when smelting
	var wants_fuel: bool = out_ok
	if burn <= 0.0 and wants_fuel and not fuel.is_empty() and Recipes.FUEL_SECONDS.has(fuel.id):
		burn = Recipes.FUEL_SECONDS[fuel.id]
		inventory.remove_at(1, 1)
		Sfx.play_at("fire_ignite", global_position, -6.0)
	if burn > 0.0:
		burn -= dt
		if out_ok:
			progress += dt
			if progress >= float(recipe[1]):
				progress = 0.0
				inventory.remove_at(0, 1)
				if out.is_empty():
					inventory.set_slot(2, inventory.make(recipe[0], 1))
				else:
					out.count = int(out.count) + 1
					inventory.set_slot(2, out)
		else:
			progress = 0.0
	_visuals(dt, burn > 0.0)


func _visuals(dt: float, lit: bool) -> void:
	if _fire:
		_fire.emitting = lit
	if _light:
		_light.light_energy = lerpf(_light.light_energy, (1.8 + randf() * 0.4) if lit else 0.0, dt * 6.0)
	if _glow_mat:
		_glow_mat.emission_energy_multiplier = 3.0 if lit else 0.0
	if _loop:
		_loop.volume_db = lerpf(_loop.volume_db, -4.0 if lit else -80.0, dt * 3.0)


func process_ratio() -> float:
	var input := inventory.get_slot(0) if inventory else {}
	if input.is_empty() or not Recipes.PROCESS.get(kind, {}).has(input.id):
		return 0.0
	return progress / float(Recipes.PROCESS[kind][input.id][1])


func to_dict() -> Dictionary:
	var d := {"kind": kind, "burn": burn, "progress": progress}
	if inventory:
		d["inv"] = inventory.slots.duplicate(true)
	return d
