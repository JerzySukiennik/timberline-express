# Title screen: continue / new game / load / settings / test yard / quit.
extends Control

var _panel: VBoxContainer
var _sub: VBoxContainer


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args or "--world" in args or "--yard" in args:
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/title_bg.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var shade := TextureRect.new()
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.02, 0.03, 0.02, 0.92))
	gr.set_color(1, Color(0.02, 0.03, 0.02, 0.1))
	g.gradient = gr
	g.fill_from = Vector2(0, 0.5)
	g.fill_to = Vector2(0.75, 0.5)
	shade.texture = g
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	UI.place(col, Control.PRESET_CENTER_LEFT, Vector2(110, -300), Vector2(560, 640))
	add_child(col)
	col.add_child(UI.label("TIMBERLINE", 78, UI.PAPER, "Bold"))
	col.add_child(UI.label("EXPRESS", 78, UI.LANTERN, "Bold"))
	col.add_child(UI.label("Survive the mountains. Build the train.", 20, UI.DIM, "Medium"))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(spacer)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 8)
	col.add_child(_panel)
	_sub = VBoxContainer.new()
	_sub.add_theme_constant_override("separation", 8)
	col.add_child(_sub)
	var saves := SaveGame.list()
	if not saves.is_empty():
		var latest: Dictionary = saves[0]
		for sv in saves:
			if str(sv.time) > str(latest.time):
				latest = sv
		_panel.add_child(_button("Continue", func() -> void: _start({"mode": "world", "load": int(latest.slot)})))
	_panel.add_child(_button("New Game", _new_game))
	if not saves.is_empty():
		_panel.add_child(_button("Load", _load_menu))
	_panel.add_child(_button("Settings", _settings))
	_panel.add_child(_button("Test Yard", func() -> void: _start({"mode": "yard"})))
	_panel.add_child(_button("Quit", func() -> void: get_tree().quit()))
	var music := Sfx.loop_2d("music_calm_2", -16.0)
	if music.stream and "loop" in music.stream:
		music.stream.set("loop", true)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(340, 50)
	b.add_theme_font_override("font", UI.font("SemiBold"))
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0.25), 6, Color(1, 1, 1, 0.06), 1, 0, 14))
	b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.08), 6, UI.LANTERN, 1, 0, 14))
	b.add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.12), 6, UI.LANTERN, 2, 0, 14))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", UI.PAPER)
	b.add_theme_color_override("font_hover_color", UI.LANTERN)
	b.pressed.connect(func() -> void:
		Sfx.play("ui", -8.0)
		cb.call())
	return b


func _clear_sub() -> void:
	for c in _sub.get_children():
		c.queue_free()


func _new_game() -> void:
	_clear_sub()
	_sub.add_child(UI.label("Choose a save slot", 18, UI.DIM, "SemiBold"))
	var used := {}
	for sv in SaveGame.list():
		used[int(sv.slot)] = sv
	for slot in 3:
		var label := "Slot %d  ·  empty" % (slot + 1) if not used.has(slot) else "Slot %d  ·  overwrite (%s)" % [slot + 1, str(used[slot].time)]
		_sub.add_child(_button(label, func() -> void: _start({"mode": "world", "slot": slot, "seed": randi() % 1000000})))


func _load_menu() -> void:
	_clear_sub()
	for sv in SaveGame.list():
		var label := "Slot %d  ·  %s  ·  %.1f km" % [int(sv.slot) + 1, str(sv.time), float(sv.km)]
		_sub.add_child(_button(label, func() -> void: _start({"mode": "world", "load": int(sv.slot)})))


func _settings() -> void:
	_clear_sub()
	_sub.add_child(UI.label("Graphics quality", 18, UI.DIM, "SemiBold"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_sub.add_child(row)
	for preset in ["low", "medium", "high", "ultra"]:
		var b := _button(preset.capitalize() + ("  ✓" if Controls.quality == preset else ""), func() -> void:
			Controls.quality = preset
			Controls.save()
			_settings())
		b.custom_minimum_size = Vector2(120, 44)
		row.add_child(b)
	var s := HSlider.new()
	s.min_value = 0.0005
	s.max_value = 0.006
	s.step = 0.0001
	s.value = Controls.sensitivity
	s.custom_minimum_size = Vector2(340, 24)
	s.value_changed.connect(func(v: float) -> void:
		Controls.sensitivity = v
		Controls.save())
	_sub.add_child(UI.label("Mouse sensitivity", 18, UI.DIM, "SemiBold"))
	_sub.add_child(s)


func _start(cfg: Dictionary) -> void:
	Controls.start = cfg
	get_tree().change_scene_to_file("res://scenes/main.tscn")
