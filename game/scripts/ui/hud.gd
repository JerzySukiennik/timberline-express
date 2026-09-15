# Minimal HUD: centre dot, context prompt, hotbar with baked icons and durability, fading stamina bar, toasts.
class_name Hud
extends CanvasLayer

var player: Player
var icons: IconBaker
var _dot: Control
var _prompt: Label
var _slots: Array[Dictionary] = []
var _stamina_bg: Panel
var _stamina_fill: ColorRect
var _stamina_alpha := 0.0
var _toasts: VBoxContainer
var _speed: Label
var _root: Control
var _bars := {}
var _flash: ColorRect
var _vignette: TextureRect
var _death: Control
var _death_label: Label


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dot = Control.new()
	_dot.set_anchors_preset(Control.PRESET_CENTER)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.draw.connect(func() -> void:
		_dot.draw_circle(Vector2.ZERO, 3.2, Color(0, 0, 0, 0.35))
		_dot.draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 1, 0.9)))
	_root.add_child(_dot)
	_prompt = UI.label("", 19, UI.PAPER, "SemiBold")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.place(_prompt, Control.PRESET_CENTER_BOTTOM, Vector2(-500, -150), Vector2(1000, 30))
	_root.add_child(_prompt)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.place(bar, Control.PRESET_CENTER_BOTTOM, Vector2(-330, -86), Vector2(660, 66))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	for i in 9:
		_slots.append(_make_slot(bar, i))
	_stamina_bg = Panel.new()
	_stamina_bg.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.45), 3))
	UI.place(_stamina_bg, Control.PRESET_CENTER_BOTTOM, Vector2(-120, -104), Vector2(240, 6))
	_stamina_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stamina_bg)
	_stamina_fill = ColorRect.new()
	_stamina_fill.color = Color(0.9, 0.88, 0.8)
	_stamina_fill.position = Vector2(1, 1)
	_stamina_fill.size = Vector2(238, 4)
	_stamina_bg.add_child(_stamina_fill)
	_toasts = VBoxContainer.new()
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	UI.place(_toasts, Control.PRESET_CENTER_TOP, Vector2(-300, 40), Vector2(600, 160))
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)
	_speed = UI.label("", 16, UI.DIM, "Medium")
	UI.place(_speed, Control.PRESET_BOTTOM_RIGHT, Vector2(-260, -40), Vector2(240, 24))
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_speed)
	if icons:
		icons.baked.connect(func(_id: String, _t: Texture2D) -> void: refresh())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	UI.place(col, Control.PRESET_CENTER_BOTTOM, Vector2(-520, -84), Vector2(170, 64))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)
	for spec in [["health", Color(0.9, 0.88, 0.82)], ["food", UI.LANTERN], ["water", Color(0.45, 0.7, 0.9)]]:
		_bars[spec[0]] = _make_bar(col, spec[0], spec[1])
	_flash = ColorRect.new()
	_flash.color = Color(0.6, 0.05, 0.02, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_vignette = TextureRect.new()
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.35, 0.0, 0.0, 0.0))
	gr.set_color(1, Color(0.35, 0.0, 0.0, 0.85))
	gr.set_offset(0, 0.55)
	g.gradient = gr
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 1.0)
	_vignette.texture = g
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	add_child(_vignette)
	_death = ColorRect.new()
	(_death as ColorRect).color = Color(0.03, 0.02, 0.02, 0.0)
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.visible = false
	add_child(_death)
	_death_label = UI.label("", 34, UI.PAPER, "Bold")
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.place(_death_label, Control.PRESET_CENTER, Vector2(-500, -40), Vector2(1000, 90))
	_death.add_child(_death_label)
	if player and player.survival:
		player.survival.damaged.connect(func(amount: float, _c: String) -> void:
			_flash.color.a = clampf(amount / 40.0, 0.15, 0.45)
			create_tween().tween_property(_flash, "color:a", 0.0, 0.5))


func _make_bar(parent: Control, kind: String, col: Color) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_icon.bind(icon, kind, col))
	row.add_child(icon)
	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(136, 7)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bg.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.45), 3))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	var fill := ColorRect.new()
	fill.color = col
	fill.position = Vector2(1, 1)
	fill.size = Vector2(134, 5)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	return {"fill": fill, "col": col, "row": row}


func _draw_icon(icon: Control, kind: String, col: Color) -> void:
	var c := Vector2(8, 8)
	if kind == "health":
		icon.draw_circle(c + Vector2(-3, -2), 3.6, col)
		icon.draw_circle(c + Vector2(3, -2), 3.6, col)
		icon.draw_colored_polygon(PackedVector2Array([c + Vector2(-6.6, -0.5), c + Vector2(6.6, -0.5), c + Vector2(0, 7)]), col)
	elif kind == "food":
		icon.draw_circle(c + Vector2(1.5, -1.5), 5.0, col)
		icon.draw_line(c + Vector2(-1, 1), c + Vector2(-6, 6), col, 2.4)
	else:
		icon.draw_circle(c + Vector2(0, 2.5), 4.6, col)
		icon.draw_colored_polygon(PackedVector2Array([c + Vector2(-4.2, 1.2), c + Vector2(4.2, 1.2), c + Vector2(0, -7)]), col)


func show_death(cause: String) -> void:
	_death.visible = true
	_death_label.text = "You died\n" + ("of " + cause if cause != "" else "")
	_death_label.add_theme_font_size_override("font_size", 34)
	(_death as ColorRect).color.a = 0.0
	create_tween().tween_property(_death, "color:a", 0.82, 1.4)


func hide_death() -> void:
	var tw := create_tween()
	tw.tween_property(_death, "color:a", 0.0, 0.8)
	tw.tween_callback(func() -> void: _death.visible = false)


func _make_slot(parent: Control, i: int) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(64, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(6, 6)
	icon.size = Vector2(52, 52)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	var num := UI.label(str(i + 1), 12, Color(1, 1, 1, 0.45), "Medium")
	num.position = Vector2(5, 1)
	panel.add_child(num)
	var count := UI.label("", 15, UI.PAPER, "Bold")
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.position = Vector2(20, 42)
	count.size = Vector2(40, 20)
	panel.add_child(count)
	var dur := ColorRect.new()
	dur.position = Vector2(8, 57)
	dur.size = Vector2(48, 3)
	dur.visible = false
	panel.add_child(dur)
	return {"panel": panel, "icon": icon, "count": count, "dur": dur}


func refresh() -> void:
	if player == null:
		return
	for i in 9:
		var s := player.inventory.get_slot(i)
		var ui: Dictionary = _slots[i]
		var sel := i == player.selected_slot
		(ui.panel as Panel).add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.07, 0.06, 0.62 if sel else 0.42), 7, UI.LANTERN if sel else Color(1, 1, 1, 0.08), 2 if sel else 1))
		if s.is_empty():
			(ui.icon as TextureRect).texture = null
			(ui.count as Label).text = ""
			(ui.dur as ColorRect).visible = false
			continue
		(ui.icon as TextureRect).texture = icons.get_icon(str(s.id)) if icons else null
		(ui.count as Label).text = str(s.count) if int(s.count) > 1 else ""
		if s.has("dur"):
			var f := float(s.dur) / float(Items.def(str(s.id)).durability)
			(ui.dur as ColorRect).visible = f < 0.999
			(ui.dur as ColorRect).size.x = 48.0 * f
			(ui.dur as ColorRect).color = UI.MOSS if f > 0.3 else UI.RUST
		else:
			(ui.dur as ColorRect).visible = false


func toast(text: String) -> void:
	var l := UI.label(text, 20, UI.PAPER, "SemiBold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toasts.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _process(dt: float) -> void:
	if player == null:
		return
	_prompt.text = player.aim_prompt
	_dot.modulate.a = 1.0 if player.aim_prompt == "" else 0.55
	var want := 1.0 if player.stamina < 99.0 else 0.0
	_stamina_alpha = move_toward(_stamina_alpha, want, dt * (4.0 if want > 0.0 else 1.2))
	_stamina_bg.modulate.a = _stamina_alpha
	_stamina_fill.size.x = 238.0 * player.stamina / 100.0
	_stamina_fill.color = Color(0.9, 0.88, 0.8) if not player.exhausted else UI.RUST
	if player.survival:
		var sv := player.survival
		for kind in ["health", "food", "water"]:
			var v: float = sv.health if kind == "health" else (sv.hunger if kind == "food" else sv.thirst)
			var b: Dictionary = _bars[kind]
			(b.fill as ColorRect).size.x = 134.0 * v / 100.0
			(b.fill as ColorRect).color = UI.RUST if v < 20.0 else b.col
		_vignette.modulate.a = lerpf(_vignette.modulate.a, clampf((30.0 - sv.health) / 30.0, 0.0, 1.0), dt * 3.0)
	if player.riding:
		var km: float = player.main.distance_km if player.main else 0.0
		_speed.text = "%s  ·  %d km/h  ·  %.1f km" % [player.riding.display_name, int(absf(player.riding.consist.v) * 3.6), km]
	else:
		_speed.text = ""
