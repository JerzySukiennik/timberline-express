# Test yard: builds the loop, terrain and decor, the three vehicles, crates and samples, player, UI and pause menu.
extends Node3D

var network: TrackNetwork
var terrain: Node3D
var vehicles: VehicleSystem
var player: Player
var hud: Hud
var inventory_ui: InventoryUI
var console: GameConsole
var icons: IconBaker
var handcar: Handcar
var flatcar: Flatcar
var steam: SteamLoco
var tender: Tender
var electric: ElectricLoco
var spawn_point := Vector3(-30, 0, 39)
var yard_mode := true
var world: ChunkWorld
var gen: WorldGen
var world_seed := 0
var infinite_stamina := false
var menu_open := false
var sun: DirectionalLight3D
var _menu: CanvasLayer
var _music_timer := 40.0


func _ready() -> void:
	randomize()
	yard_mode = "--yard" in OS.get_cmdline_user_args() or "--autotest" in OS.get_cmdline_user_args() and not "--world" in OS.get_cmdline_user_args()
	_environment()
	network = TrackNetwork.new()
	network.name = "Track"
	add_child(network)
	vehicles = VehicleSystem.new()
	vehicles.name = "Vehicles"
	vehicles.net = network
	add_child(vehicles)
	icons = IconBaker.new()
	add_child(icons)
	Items.icons = icons
	if yard_mode:
		_build_yard()
	else:
		_build_world()
	_player()
	_ui()
	_ambience()
	grass_field = GrassField.new()
	grass_field.world = terrain
	grass_field.focus = player
	add_child(grass_field)
	apply_quality(Controls.quality)
	if world:
		world.focus = player
		world.extra_focus = [handcar]
		_begin_loading()
	if "--autotest" in OS.get_cmdline_user_args():
		var at: Node = load("res://scripts/autotest.gd").new()
		at.set("main", self)
		add_child(at)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_yard() -> void:
	network.build_layout()
	network.build_meshes()
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(network)
	spawn_point.y = terrain.height_at(spawn_point.x, spawn_point.z) + 0.1
	_vehicles()
	for n in network.switches:
		Props.switch_stand(self, network, n, vehicles)
	for d in network.dead_ends:
		Props.buffer_stop(self, d)
	_props()
	_samples()
	terrain.scatter([Vector3(-12, 40, 34), Vector3(-2, 20, 30), Vector3(0, 0, 14)])


func _build_world() -> void:
	world_seed = randi() % 1000000 if not "--seed" in str(OS.get_cmdline_user_args()) else 424242
	gen = WorldGen.new(world_seed)
	world = ChunkWorld.new()
	world.name = "World"
	add_child(world)
	world.setup(gen, network)
	terrain = world
	var start := world.tracks.start_segment()
	network.switch_changed.connect(_on_switch_changed)
	handcar = Handcar.new()
	add_child(handcar)
	handcar.setup(network)
	flatcar = Flatcar.new()
	add_child(flatcar)
	flatcar.setup(network)
	handcar.place(network.cursor_at(start, 60.0, false))
	vehicles.add([handcar, flatcar])
	handcar.brake.set_value(1.0)
	spawn_point = flatcar.global_transform * Vector3(0.6, 1.0, 1.2)
	_stands_timer = 0.0


var _stands := {}
var _stands_timer := 0.0


func _update_switch_stands() -> void:
	for n in world.tracks.branch_nodes:
		if _stands.has(n.id):
			continue
		if n.links.size() < 3 or (n.links[0] as Dictionary).is_empty() or (n.links[1] as Dictionary).is_empty() or (n.links[2] as Dictionary).is_empty():
			continue
		if Vector2(n.pos.x - player.global_position.x, n.pos.z - player.global_position.z).length() > 450.0:
			continue
		_stands[n.id] = Props.switch_stand(self, network, n, vehicles)


## Couples a fresh flatcar behind the consist's tail.
func attach_flatcar(c: Consist) -> bool:
	var tail := c.tail()
	var probe := tail.center_cursor()
	if probe.move(-(tail.coupler_rear + 3.3 + 0.05), false) != 0.0:
		toast("No room behind the train")
		return false
	var f := Flatcar.new()
	add_child(f)
	f.setup(network)
	c.vehicles.append(f)
	f.consist = c
	f.place(probe)
	Sfx.play_at("coupling", f.global_position, 0.0)
	toast("Flatcar coupled")
	return true


## Swaps the lead engine of a consist for a steam loco (+tender) or an electric loco, keeping the rest of the train.
func upgrade_engine(old: RailVehicle, kit: String) -> bool:
	var c := old.consist
	if absf(c.v) > 0.5:
		toast("Stop the train first")
		return false
	var center := old.center_cursor()
	var new_list: Array = []
	if kit == "steam_kit":
		var s := SteamLoco.new()
		add_child(s)
		s.setup(network)
		var t := Tender.new()
		add_child(t)
		t.setup(network)
		t.water = 0.0
		s.tender = t
		new_list = [s, t]
		steam = s
		tender = t
	else:
		var e := ElectricLoco.new()
		add_child(e)
		e.setup(network)
		e.battery = 6.0
		new_list = [e]
		electric = e
	var rest: Array = []
	for v in c.vehicles:
		if v != old and not (old is SteamLoco and v == (old as SteamLoco).tender):
			rest.append(v)
	for rider in [player]:
		if rider.riding == old:
			rider.riding = null
	if old is SteamLoco and (old as SteamLoco).tender:
		(old as SteamLoco).tender.queue_free()
	old.queue_free()
	vehicles.consists.erase(c)
	(new_list[0] as RailVehicle).place(center)
	var nc := vehicles.add(new_list + rest)
	if handcar == old:
		handcar = null
	if world:
		world.extra_focus = [new_list[0]]
	Sfx.play_at("craft_metal", center.position(), 2.0)
	toast("Engine installed")
	return true


func _on_switch_changed(_n: TrackNetwork.TrackNode) -> void:
	pass


var _loading_layer: CanvasLayer
var loading := false


func _begin_loading() -> void:
	loading = true
	player.input_enabled = false
	player.set_physics_process(false)
	vehicles.set_physics_process(false)
	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 20
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.055)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_layer.add_child(bg)
	var l := UI.label("Laying track through the forest…", 30, UI.PAPER, "SemiBold")
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.place(l, Control.PRESET_CENTER, Vector2(-400, -20), Vector2(800, 40))
	_loading_layer.add_child(l)
	add_child(_loading_layer)


func _check_loaded() -> void:
	var c := world.cell(player.global_position)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var ch = world.chunks.get(c + Vector2i(dx, dz))
			if ch == null or ch.lod != 0:
				return
	loading = false
	_loading_layer.queue_free()
	player.set_physics_process(true)
	vehicles.set_physics_process(true)
	player.input_enabled = not menu_open
	player.global_position = spawn_point
	player.velocity = Vector3.ZERO


var environment: Environment
var _post_mat: ShaderMaterial
var grass_field: GrassField

const QUALITY := {
	"low": {"ssao": false, "ssao_q": 0, "volumetric": false, "glow": false, "rays": false, "splits": 2, "shadow_dist": 60.0, "grass": 0.0, "scale": 0.7, "taa": false},
	"medium": {"ssao": false, "ssao_q": 0, "volumetric": false, "glow": true, "rays": true, "splits": 2, "shadow_dist": 80.0, "grass": 0.6, "scale": 0.85, "taa": true},
	"high": {"ssao": false, "ssao_q": 0, "volumetric": false, "glow": true, "rays": true, "splits": 4, "shadow_dist": 100.0, "grass": 1.0, "scale": 1.0, "taa": true},
	"ultra": {"ssao": true, "ssao_q": 2, "volumetric": true, "glow": true, "rays": true, "splits": 4, "shadow_dist": 130.0, "grass": 1.3, "scale": 1.0, "taa": true},
}


func apply_quality(preset: String) -> void:
	var q: Dictionary = QUALITY.get(preset, QUALITY.high)
	environment.ssao_enabled = q.ssao
	RenderingServer.environment_set_ssao_quality(q.ssao_q, true, 0.5, 2, 50.0, 300.0)
	environment.volumetric_fog_enabled = q.volumetric
	environment.glow_enabled = q.glow
	if _post_mat:
		_post_mat.set_shader_parameter("rays_on", q.rays)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q.splits == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = q.shadow_dist
	var vp := get_viewport()
	vp.scaling_3d_scale = q.scale
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if q.scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.use_taa = q.taa and q.scale >= 1.0
	if grass_field:
		grass_field.visible = q.grass > 0.0
		grass_field.spacing = 0.42 / sqrt(maxf(q.grass, 0.1))
		grass_field._center = Vector2(INF, INF)
	Controls.quality = preset


## Runtime quality switches (used by the perf autotest to find what costs frames).
func set_quality(key: String, on: bool) -> void:
	match key:
		"volumetric":
			environment.volumetric_fog_enabled = on
		"ssao":
			environment.ssao_enabled = on
		"postfx":
			($PostFX as CanvasLayer).visible = on
		"grass":
			if grass_field:
				grass_field.visible = on
		"glow":
			environment.glow_enabled = on
		"shadows":
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if on else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 120.0 if on else 60.0
		"trees", "plants", "chunk_grass", "ferns", "tree_shadows_w":
			if world:
				var tag: String = {"trees": "trees", "plants": "ferns", "chunk_grass": "chunk_grass", "ferns": "ferns", "tree_shadows_w": "tree_shadows"}[key]
				for mmi in world.find_children("*", "MultiMeshInstance3D", true, false):
					if mmi.get_meta("kind", "") == tag:
						mmi.visible = on
				return
			for c in terrain.get_children():
				if c is MultiMeshInstance3D:
					var is_tree := (c as MultiMeshInstance3D).visibility_range_end > 100.0
					if (key == "trees") == is_tree:
						c.visible = on
		"tree_shadows":
			if world:
				return
			for c in terrain.get_children():
				if c is MultiMeshInstance3D and (c as MultiMeshInstance3D).visibility_range_end > 100.0:
					(c as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"msaa":
			get_viewport().use_taa = on


func _environment() -> void:
	var env := Environment.new()
	environment = env
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/textures/sky/qwantani_morning_puresky_2k.hdr")
	pano.energy_multiplier = 1.15
	sky.sky_material = pano
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.8
	env.ssao_light_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 1.05
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.6)
	env.set_glow_level(5, 0.35)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.62, 0.74, 0.88)
	env.fog_sun_scatter = 0.12
	env.fog_density = 0.00085
	env.fog_sky_affect = 0.12
	env.fog_aerial_perspective = 0.85
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0028
	env.volumetric_fog_albedo = Color(0.95, 0.93, 0.88)
	env.volumetric_fog_anisotropy = 0.82
	env.volumetric_fog_length = 110.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-30, 140, 0)
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 3.1
	sun.light_angular_distance = 0.6
	sun.light_volumetric_fog_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 0.8
	add_child(sun)
	_post_mat = null
	var post := CanvasLayer.new()
	post.name = "PostFX"
	post.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/postfx.gdshader")
	rect.material = pm
	_post_mat = pm
	post.add_child(rect)
	add_child(post)


func _siding_cursor(i: int, from_end: float) -> TrackNetwork.Cursor:
	var seg: TrackNetwork.TrackSegment = network.sidings[i]
	return network.cursor_at(seg, seg.length - from_end, true)


func _vehicles() -> void:
	handcar = Handcar.new()
	add_child(handcar)
	handcar.setup(network)
	flatcar = Flatcar.new()
	add_child(flatcar)
	flatcar.setup(network)
	handcar.place(_siding_cursor(0, 9.0))
	vehicles.add([handcar, flatcar])
	steam = SteamLoco.new()
	add_child(steam)
	steam.setup(network)
	tender = Tender.new()
	add_child(tender)
	tender.setup(network)
	steam.tender = tender
	steam.place(_siding_cursor(1, 10.0))
	vehicles.add([steam, tender])
	electric = ElectricLoco.new()
	add_child(electric)
	electric.setup(network)
	electric.place(_siding_cursor(2, 5.5))
	vehicles.add([electric])


func _ground_xf(x: float, z: float, yaw := 0.0, sink := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(x, terrain.height_at(x, z) - sink, z))


func _props() -> void:
	var z := TrackNetwork.LOOP_R + TrackNetwork.SIDING_OFFSET + 4.2
	Props.crate(self, self, _ground_xf(-26.0, z + 0.5, 0.2), "Supply Crate", {"bucket": 2, "jerrycan": 1, "log": 6, "stone": 4})
	Props.crate(self, self, _ground_xf(-3.0, z, -0.1), "Fuel Crate", {"coal": 40, "log": 24})
	Props.barrel(self, _ground_xf(1.2, z + 0.3), false)
	Props.barrel(self, _ground_xf(-6.2, z + 0.4), false)
	Props.crate(self, self, _ground_xf(30.0, z, 0.15), "Jerrycan Crate", {"jerrycan_fuel": 4, "jerrycan": 2}, Color(1.0, 0.55, 0.45))
	Props.barrel(self, _ground_xf(33.5, z + 0.3), true)


func _samples() -> void:
	var base := Vector3(-34, 0, 50)
	MineRock.create(self, _ground_xf(base.x, base.z, 0.3, 0.15))
	MineRock.create(self, _ground_xf(base.x + 5.0, base.z + 3.5, 1.9, 0.15))
	MineRock.create(self, _ground_xf(base.x - 4.5, base.z + 4.0, 4.1, 0.15))
	ChopTree.create(self, _ground_xf(-20, 53).origin - Vector3.UP * 0.1, "fir_b", 0.85)
	ChopTree.create(self, _ground_xf(-14, 56).origin - Vector3.UP * 0.1, "fir_a", 0.7)
	ChopTree.create(self, _ground_xf(-24, 58).origin - Vector3.UP * 0.1, "fir_b", 0.75)
	for p in [Vector2(-42, 45), Vector2(-45, 50), Vector2(-9, 49), Vector2(-28, 45)]:
		Bush.create(self, _ground_xf(p.x, p.y).origin, randf_range(0.8, 1.1))
	_static_model("res://assets/models/animals/deer.glb", _ground_xf(-6, 58, 2.4), 1.0)
	_static_model("res://assets/models/animals/wolf.glb", _ground_xf(-1, 55, -2.2), 1.0)


func _static_model(path: String, xf: Transform3D, scale: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var n := (load(path) as PackedScene).instantiate() as Node3D
	add_child(n)
	n.global_transform = xf
	n.scale = Vector3.ONE * scale
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		for a in ap.get_animation_list():
			if a.to_lower().contains("idle"):
				ap.play(a)
				break


func _player() -> void:
	player = Player.new()
	player.name = "Player"
	player.main = self
	add_child(player)
	player.global_position = spawn_point
	player.look_at_point(handcar.global_position + Vector3.UP * 1.0 if yard_mode else handcar.global_transform * Vector3(0, 1.4, -6.0))
	if yard_mode:
		for id in ["pickaxe", "axe", "knife", "bucket", "jerrycan"]:
			player.inventory.add(id, 1)
		player.inventory.add("coal", 6)
		player.select_slot(6)
	else:
		player.inventory.add("berries", 5)
		player.select_slot(8)


func _on_player_died(cause: String) -> void:
	player.input_enabled = false
	player._end_grab()
	player.set_physics_process(false)
	hud.show_death(cause)
	var head := player.head
	var tw := create_tween()
	tw.tween_property(head, "position:y", 0.25, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(head, "rotation:z", 1.3, 1.2)
	tw.tween_interval(2.4)
	tw.tween_callback(_respawn)


func respawn_point() -> Vector3:
	if not beds.is_empty():
		for b in beds:
			if is_instance_valid(b):
				return (b as Node3D).global_transform * Vector3(0.9, 0.2, 0)
	if world and handcar:
		return handcar.global_transform * Vector3(0.5, 1.0, 0.6)
	return spawn_point


var beds: Array = []


func _respawn() -> void:
	if not player.inventory.slots.all(func(x: Dictionary) -> bool: return x.is_empty()):
		DeathBag.spawn(self, player.global_position + Vector3(0, 0.05, 0), player.inventory)
	player.head.rotation.z = 0.0
	player.head.position.y = Player.EYE
	player.global_position = respawn_point()
	player.velocity = Vector3.ZERO
	player.riding = null
	player.survival.revive()
	player.stamina = 100.0
	player.set_physics_process(true)
	player.input_enabled = not menu_open
	hud.hide_death()


func _ui() -> void:
	player.survival.died.connect(_on_player_died)
	hud = Hud.new()
	hud.player = player
	hud.icons = icons
	add_child(hud)
	player.slot_changed.connect(func(_i: int) -> void: hud.refresh())
	player.crafted.connect(func(id: String) -> void:
		hud.toast("Crafted " + Items.display_name(id))
		if inventory_ui.is_open:
			inventory_ui.refresh())
	player.inventory.changed.connect(func() -> void:
		hud.refresh()
		if inventory_ui and inventory_ui.is_open:
			inventory_ui.refresh())
	hud.refresh()
	inventory_ui = InventoryUI.new()
	inventory_ui.player = player
	inventory_ui.icons = icons
	add_child(inventory_ui)
	icons.baked.connect(func(_id: String, _t: Texture2D) -> void:
		if inventory_ui.is_open:
			inventory_ui.refresh())
	inventory_ui.closed.connect(func() -> void: player.input_enabled = not menu_open)
	console = GameConsole.new()
	console.main = self
	add_child(console)
	console.opened_changed.connect(func(open: bool) -> void:
		player.input_enabled = not open and not inventory_ui.is_open and not menu_open
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED)
	for id in Items.ids():
		icons.get_icon(id)
	_build_menu()


var build_menu: BuildMenu


func open_build_menu() -> void:
	if build_menu == null:
		build_menu = BuildMenu.new()
		build_menu.player = player
		add_child(build_menu)
		build_menu.closed.connect(func() -> void: player.input_enabled = not menu_open)
	player.input_enabled = false
	build_menu.open()


func toggle_inventory() -> void:
	if inventory_ui.is_open:
		inventory_ui.close()
	else:
		open_container(null, "")


var stations: Array = []


func nearby_station(kind: String, pos: Vector3, radius: float) -> Station:
	for s in stations:
		if is_instance_valid(s) and (s as Station).kind == kind and (s as Station).global_position.distance_to(pos) < radius:
			return s
	return null


func open_container(inv: Inventory, title: String, on_close := Callable(), station: Station = null) -> void:
	player.input_enabled = false
	player._end_grab()
	inventory_ui.open(inv, title, on_close, station)


func toast(text: String) -> void:
	hud.toast(text)


func drop_item(id: String, n: int, dur := -1) -> void:
	var p := Pickup.spawn(self, id, n, player.camera.global_position - player.camera.global_basis.z * 0.8)
	p.dur = dur
	p.linear_velocity = -player.camera.global_basis.z * 2.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("console") and not console.is_open and not inventory_ui.is_open and not menu_open:
		console.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and not console.is_open and not inventory_ui.is_open:
		_set_menu(not menu_open)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not console.is_open and not menu_open and not inventory_ui.is_open:
		toggle_inventory()
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if _post_mat and player:
		var cam := player.camera
		var sun_dir := sun.global_basis.z
		var sun_pos := cam.global_position + sun_dir * 1000.0
		var vis := 0.0
		if not cam.is_position_behind(sun_pos):
			var sp := cam.unproject_position(sun_pos)
			var vs := get_viewport().get_visible_rect().size
			_post_mat.set_shader_parameter("sun_uv", sp / vs)
			vis = clampf(1.0 - (sp / vs - Vector2(0.5, 0.5)).length() * 1.1, 0.0, 1.0) * clampf(sun_dir.dot(-cam.global_basis.z) * 2.0, 0.0, 1.0)
		_post_mat.set_shader_parameter("sun_visible", vis)
	if world:
		if loading:
			_check_loaded()
		_stands_timer -= dt
		if _stands_timer <= 0.0:
			_stands_timer = 1.0
			_update_switch_stands()
	if infinite_stamina:
		player.stamina = 100.0
		player.exhausted = false
	_music_timer -= dt
	if _music_timer <= 0.0:
		_music_timer = randf_range(240.0, 420.0)
		var p := Sfx.loop_2d("music_calm_%d" % randi_range(1, 2), -20.0)
		if p.stream and "loop" in p.stream:
			p.stream.set("loop", false)
		p.finished.connect(p.queue_free)


func _ambience() -> void:
	Sfx.loop_2d("amb_forest_day_loop", -13.0)
	Sfx.loop_2d("amb_wind_pines_loop", -19.0)


# ---------------------------------------------------------------- pause menu

func _build_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 12
	_menu.visible = false
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.025, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	UI.place(col, Control.PRESET_CENTER_LEFT, Vector2(90, -300), Vector2(520, 600))
	_menu.add_child(col)
	col.add_child(UI.label("TIMBERLINE EXPRESS", 46, UI.PAPER, "Bold"))
	col.add_child(UI.label("v1 — test yard", 18, UI.LANTERN, "SemiBold"))
	var resume := _menu_button("Resume")
	resume.pressed.connect(func() -> void: _set_menu(false))
	col.add_child(resume)
	col.add_child(_slider("Mouse sensitivity", 0.0005, 0.006, Controls.sensitivity, func(v: float) -> void:
		Controls.sensitivity = v
		Controls.save()))
	col.add_child(_slider("Field of view", 60.0, 110.0, Controls.fov, func(v: float) -> void:
		Controls.fov = v
		Controls.save()))
	col.add_child(_slider("Volume", 0.0, 1.0, db_to_linear(AudioServer.get_bus_volume_db(0)), func(v: float) -> void:
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 6)
	col.add_child(UI.label("Graphics quality", 16, UI.DIM, "SemiBold"))
	col.add_child(qrow)
	for preset in ["low", "medium", "high", "ultra"]:
		var b := _menu_button(preset.capitalize())
		b.custom_minimum_size = Vector2(90, 40)
		b.pressed.connect(func() -> void:
			apply_quality(preset)
			Controls.save())
		qrow.add_child(b)
	var quit := _menu_button("Quit to desktop")
	quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quit)
	var credits := UI.label(_credits_text(), 13, UI.DIM, "Medium")
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.place(credits, Control.PRESET_BOTTOM_RIGHT, Vector2(-620, -250), Vector2(580, 230))
	credits.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_menu.add_child(credits)
	var keys := UI.label("WASD move · Shift sprint · Ctrl crouch · Space jump / climb · LMB use tool / hold+drag controls · E interact / backpack · 1-9 tools · Q drop · / console", 15, UI.DIM, "Medium")
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.place(keys, Control.PRESET_BOTTOM_LEFT, Vector2(90, -90), Vector2(760, 60))
	_menu.add_child(keys)


func _credits_text() -> String:
	return "Models & textures: Poly Haven (CC0), Quaternius (CC0). Sounds: BigSoundBank, Kenney, OpenGameArt (CC0).\n" + \
		"\"Hand lever rail trolley\", \"Air pump steam locomotive\" by Work With Sounds / Konrad Gutkowski; " + \
		"\"Battery locomotive moving\", \"Steam locomotive S06-018 steam release\" by Work With Sounds / Technical Museum of Slovenia — CC BY 4.0 (edited), via Wikimedia Commons.\n" + \
		"Music: Jim Greeninger, Kimiko Ishizaka (CC0, Musopen)."


func _menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(320, 48)
	b.add_theme_font_override("font", UI.font("SemiBold"))
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_stylebox_override("normal", UI.box(Color(1, 1, 1, 0.05), 6, Color(1, 1, 1, 0.08), 1, 0, 12))
	b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.1), 6, UI.LANTERN, 1, 0, 12))
	b.add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.14), 6, UI.LANTERN, 2, 0, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", UI.PAPER)
	b.add_theme_color_override("font_hover_color", UI.LANTERN)
	b.pressed.connect(func() -> void: Sfx.play("ui", -8.0))
	return b


func _slider(title: String, lo: float, hi: float, value: float, on_change: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_child(UI.label(title, 16, UI.DIM, "SemiBold"))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 200.0
	s.value = value
	s.custom_minimum_size = Vector2(320, 24)
	s.value_changed.connect(func(x: float) -> void: on_change.call(x))
	v.add_child(s)
	return v


func _set_menu(open: bool) -> void:
	menu_open = open
	_menu.visible = open
	player.input_enabled = not open
	player._end_grab()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
