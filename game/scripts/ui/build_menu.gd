# Piece picker for the hammer: a row of cards with cost; click to select, Esc/RMB to close.
class_name BuildMenu
extends CanvasLayer

signal closed

var player: Player
var is_open := false
var _root: Control
var _row: HBoxContainer


func _ready() -> void:
	layer = 9
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			close())
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.075, 0.085, 0.08, 0.94), 10, Color(1, 1, 1, 0.07), 1, 12, 16))
	UI.place(panel, Control.PRESET_CENTER_BOTTOM, Vector2(-560, -330), Vector2(1120, 170))
	_root.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UI.label("Build", 22, UI.PAPER, "Bold"))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	v.add_child(_row)


func open() -> void:
	for c in _row.get_children():
		c.queue_free()
	var none := _card("Repair / take apart", "no piece selected", "")
	_row.add_child(none)
	for id in Building.ORDER:
		_row.add_child(_card(Building.PIECES[id].name, Building.cost_text(id, player.inventory), id))
	is_open = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("ui", -8.0)


func _card(title: String, sub: String, id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(130, 96)
	b.text = title + "\n" + sub.replace("  ·  ", "\n")
	b.add_theme_font_override("font", UI.font("SemiBold"))
	b.add_theme_font_size_override("font_size", 14)
	var ok := id == "" or Building.can_afford(id, player.inventory)
	b.add_theme_stylebox_override("normal", UI.box(Color(1, 1, 1, 0.05), 6, UI.LANTERN if player.builder.selected == id else Color(1, 1, 1, 0.08), 2 if player.builder.selected == id else 1))
	b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.1), 6, UI.LANTERN, 1))
	b.add_theme_color_override("font_color", UI.PAPER if ok else Color(0.85, 0.55, 0.45))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(func() -> void:
		player.builder.select(id)
		Sfx.play("ui", -8.0)
		close())
	return b


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("secondary")):
		get_viewport().set_input_as_handled()
		close()
