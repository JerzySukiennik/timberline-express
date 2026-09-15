# Backpack screen (E / Tab): 20 backpack slots, 9 hotbar slots, optional container panel. Drag stacks with the cursor.
class_name InventoryUI
extends CanvasLayer

signal closed

const SLOT := 66

var player: Player
var icons: IconBaker
var is_open := false
var container: Inventory
var container_title := ""
var _on_container_close: Callable
var _held := {}
var _held_icon: TextureRect
var _held_count: Label
var _root: Control
var _panel: PanelContainer
var _chest_panel: PanelContainer
var _chest_title: Label
var _cells: Array[Dictionary] = []   # {inv, index, panel, icon, count, dur}
var _tooltip: Label
var _chest_grid: GridContainer


func _ready() -> void:
	layer = 8
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_background_input)
	_root.add_child(dim)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(row)
	_panel = _make_panel(row, "Backpack")
	var body: VBoxContainer = _panel.get_child(0)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for i in 20:
		_cells.append(_make_cell(grid, "player", 9 + i))
	body.add_child(_spacer(10))
	body.add_child(UI.label("HOTBAR", 13, UI.DIM, "Bold"))
	var hot := GridContainer.new()
	hot.columns = 9
	hot.add_theme_constant_override("h_separation", 6)
	body.add_child(hot)
	for i in 9:
		_cells.append(_make_cell(hot, "player", i))
	body.add_child(_spacer(6))
	var hint := UI.label("Click: pick up / place  ·  Right-click: half / one\nShift-click: quick move  ·  Click outside: drop", 13, UI.DIM, "Medium")
	body.add_child(hint)
	_chest_panel = _make_panel(row, "Crate")
	_chest_title = (_chest_panel.get_child(0) as VBoxContainer).get_child(0) as Label
	_chest_grid = GridContainer.new()
	_chest_grid.columns = 4
	_chest_grid.add_theme_constant_override("h_separation", 6)
	_chest_grid.add_theme_constant_override("v_separation", 6)
	(_chest_panel.get_child(0) as VBoxContainer).add_child(_chest_grid)
	_chest_panel.visible = false
	_held_icon = TextureRect.new()
	_held_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_icon.size = Vector2(56, 56)
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_held_icon)
	_held_count = UI.label("", 16, UI.PAPER, "Bold")
	_held_icon.add_child(_held_count)
	_held_count.position = Vector2(30, 36)
	_tooltip = UI.label("", 16, UI.PAPER, "SemiBold")
	_tooltip.add_theme_stylebox_override("normal", UI.box(Color(UI.INK, 0.92), 5, Color(1, 1, 1, 0.1), 1, 0, 6))
	_tooltip.visible = false
	_root.add_child(_tooltip)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _make_panel(parent: Control, title: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.075, 0.085, 0.08, 0.94), 10, Color(1, 1, 1, 0.07), 1, 12, 18))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UI.label(title, 24, UI.PAPER, "Bold"))
	return p


func _make_cell(parent: Control, which: String, index: int) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(SLOT, SLOT)
	panel.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.045), 6, Color(1, 1, 1, 0.07), 1))
	parent.add_child(panel)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(6, 6)
	icon.size = Vector2(SLOT - 12, SLOT - 12)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	var count := UI.label("", 15, UI.PAPER, "Bold")
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.position = Vector2(SLOT - 46, SLOT - 22)
	count.size = Vector2(40, 20)
	panel.add_child(count)
	var dur := ColorRect.new()
	dur.position = Vector2(8, SLOT - 6)
	dur.size = Vector2(SLOT - 16, 3)
	panel.add_child(dur)
	var cell := {"which": which, "index": index, "panel": panel, "icon": icon, "count": count, "dur": dur}
	panel.gui_input.connect(func(ev: InputEvent) -> void: _on_cell_input(cell, ev))
	panel.mouse_entered.connect(func() -> void: _hover(cell, true))
	panel.mouse_exited.connect(func() -> void: _hover(cell, false))
	return cell


func _inv(cell: Dictionary) -> Inventory:
	return player.inventory if cell.which == "player" else container


func open(inv: Inventory = null, title := "", on_close := Callable()) -> void:
	container = inv
	container_title = title
	_on_container_close = on_close
	for c in _chest_grid.get_children():
		c.queue_free()
	_cells = _cells.filter(func(c: Dictionary) -> bool: return c.which == "player")
	_chest_panel.visible = inv != null
	if inv:
		_chest_title.text = title
		for i in inv.size():
			_cells.append(_make_cell(_chest_grid, "container", i))
	is_open = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("backpack_open", -6.0)
	refresh()


func close() -> void:
	if not is_open:
		return
	if not _held.is_empty():
		var left := player.inventory.add(str(_held.id), int(_held.count))
		if left > 0:
			player.main.drop_item(str(_held.id), left)
		_held = {}
	is_open = false
	_root.visible = false
	_tooltip.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play("backpack_close", -6.0)
	if _on_container_close.is_valid():
		_on_container_close.call()
	_on_container_close = Callable()
	container = null
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_cell_input(cell: Dictionary, ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed):
		return
	var mb := ev as InputEventMouseButton
	var inv := _inv(cell)
	var i: int = cell.index
	var slot := inv.get_slot(i)
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.shift_pressed and _held.is_empty() and not slot.is_empty():
		_quick_move(cell)
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		if _held.is_empty():
			if not slot.is_empty():
				_held = slot.duplicate()
				inv.set_slot(i, {})
				Sfx.play("slot_pick", -10.0)
		elif slot.is_empty():
			inv.set_slot(i, _held)
			_held = {}
			Sfx.play("slot_drop", -10.0)
		elif slot.id == _held.id and not slot.has("dur"):
			var room := Items.stack_size(str(slot.id)) - int(slot.count)
			var put := mini(room, int(_held.count))
			slot.count = int(slot.count) + put
			_held.count = int(_held.count) - put
			inv.set_slot(i, slot)
			if int(_held.count) <= 0:
				_held = {}
			Sfx.play("slot_drop", -10.0)
		else:
			inv.set_slot(i, _held)
			_held = slot.duplicate()
			Sfx.play("slot_pick", -10.0)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if _held.is_empty() and not slot.is_empty():
			var half := int(ceil(int(slot.count) / 2.0))
			_held = slot.duplicate()
			_held.count = half
			slot.count = int(slot.count) - half
			inv.set_slot(i, slot)
			Sfx.play("slot_pick", -12.0)
		elif not _held.is_empty() and (slot.is_empty() or (slot.id == _held.id and int(slot.count) < Items.stack_size(str(slot.id)) and not slot.has("dur"))):
			if slot.is_empty():
				var one := _held.duplicate()
				one.count = 1
				inv.set_slot(i, one)
			else:
				slot.count = int(slot.count) + 1
				inv.set_slot(i, slot)
			_held.count = int(_held.count) - 1
			if int(_held.count) <= 0:
				_held = {}
			Sfx.play("slot_drop", -12.0)
	refresh()


func _quick_move(cell: Dictionary) -> void:
	var inv := _inv(cell)
	var slot := inv.get_slot(cell.index)
	var target: Inventory
	var prefer: Array = []
	if cell.which == "container":
		target = player.inventory
	elif container:
		target = container
	else:
		target = player.inventory
		prefer = range(9, 29) if int(cell.index) < 9 else range(0, 9)
	if target == inv:
		var left := 0
		inv.set_slot(cell.index, {})
		var order := prefer.duplicate()
		var placed := false
		for j in order:
			if inv.get_slot(j).is_empty():
				inv.set_slot(j, slot)
				placed = true
				break
		if not placed:
			inv.set_slot(cell.index, slot)
	else:
		if slot.has("dur"):
			for j in target.size():
				if target.get_slot(j).is_empty():
					target.set_slot(j, slot)
					inv.set_slot(cell.index, {})
					break
		else:
			var left2 := target.add(str(slot.id), int(slot.count))
			slot.count = left2
			inv.set_slot(cell.index, slot if left2 > 0 else {})
	Sfx.play("slot_drop", -10.0)


func _on_background_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and not _held.is_empty():
		player.main.drop_item(str(_held.id), int(_held.count), _held.get("dur", -1))
		_held = {}
		refresh()


func _hover(cell: Dictionary, on: bool) -> void:
	var s := _inv(cell).get_slot(cell.index) if _inv(cell) else {}
	if on and not s.is_empty():
		var t := Items.display_name(str(s.id))
		if s.has("dur"):
			t += "   %d / %d" % [int(s.dur), int(Items.def(str(s.id)).durability)]
		elif int(s.count) > 1:
			t += "   x%d" % int(s.count)
		_tooltip.text = t
		_tooltip.visible = true
	else:
		_tooltip.visible = false


func refresh() -> void:
	for c in _cells:
		var inv := _inv(c)
		if inv == null:
			continue
		var s := inv.get_slot(c.index)
		(c.icon as TextureRect).texture = null if s.is_empty() else icons.get_icon(str(s.id))
		(c.count as Label).text = "" if s.is_empty() or int(s.count) <= 1 else str(s.count)
		var d := c.dur as ColorRect
		d.visible = not s.is_empty() and s.has("dur") and int(s.dur) < int(Items.def(str(s.id)).durability)
		if d.visible:
			var f := float(s.dur) / float(Items.def(str(s.id)).durability)
			d.size.x = (SLOT - 16) * f
			d.color = UI.MOSS if f > 0.3 else UI.RUST
		var sel: bool = c.which == "player" and int(c.index) == player.selected_slot
		(c.panel as Panel).add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.045), 6, UI.LANTERN if sel else Color(1, 1, 1, 0.07), 2 if sel else 1))
	_held_icon.texture = null if _held.is_empty() else icons.get_icon(str(_held.id))
	_held_count.text = "" if _held.is_empty() or int(_held.count) <= 1 else str(_held.count)


func _process(_dt: float) -> void:
	if not is_open:
		return
	var mp := _root.get_local_mouse_position()
	_held_icon.position = mp - Vector2(28, 28)
	_tooltip.position = mp + Vector2(18, 18)
