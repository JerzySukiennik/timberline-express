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
var station: Station
var _craft_panel: PanelContainer
var _craft_list: VBoxContainer
var _craft_title: Label
var _craft_bar: ColorRect
var _craft_queue_label: Label
var _process_bar: ColorRect
var _process_row: Control
var _recipe_rows: Array = []


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
	var proc := HBoxContainer.new()
	proc.add_theme_constant_override("separation", 8)
	(_chest_panel.get_child(0) as VBoxContainer).add_child(proc)
	_process_row = proc
	var pbg := Panel.new()
	pbg.custom_minimum_size = Vector2(4 * SLOT + 18, 8)
	pbg.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.5), 3))
	proc.add_child(pbg)
	_process_bar = ColorRect.new()
	_process_bar.color = UI.LANTERN
	_process_bar.position = Vector2(1, 1)
	_process_bar.size = Vector2(0, 6)
	pbg.add_child(_process_bar)
	_craft_panel = _make_panel(row, "Crafting")
	var cv := _craft_panel.get_child(0) as VBoxContainer
	_craft_title = cv.get_child(0) as Label
	var qrow := HBoxContainer.new()
	cv.add_child(qrow)
	_craft_queue_label = UI.label("", 14, UI.DIM, "Medium")
	_craft_queue_label.custom_minimum_size = Vector2(170, 0)
	qrow.add_child(_craft_queue_label)
	var qbg := Panel.new()
	qbg.custom_minimum_size = Vector2(200, 8)
	qbg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qbg.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.5), 3))
	qrow.add_child(qbg)
	_craft_bar = ColorRect.new()
	_craft_bar.color = UI.MOSS
	_craft_bar.position = Vector2(1, 1)
	_craft_bar.size = Vector2(0, 6)
	qbg.add_child(_craft_bar)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(390, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cv.add_child(scroll)
	_craft_list = VBoxContainer.new()
	_craft_list.add_theme_constant_override("separation", 4)
	_craft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_craft_list)
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


func open(inv: Inventory = null, title := "", on_close := Callable(), at_station: Station = null) -> void:
	container = inv
	container_title = title
	_on_container_close = on_close
	station = at_station
	var processing := at_station != null and (at_station.kind == "campfire" or at_station.kind == "furnace")
	_process_row.visible = processing
	_chest_grid.columns = 3 if processing else 4
	_craft_panel.visible = inv == null or not processing and at_station == null
	_build_recipes()
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
	station = null
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


func _workbench_near() -> bool:
	if station and station.kind == "workbench":
		return true
	return player.main.nearby_station("workbench", player.global_position, 4.0) != null


func _build_recipes() -> void:
	for c in _craft_list.get_children():
		c.queue_free()
	_recipe_rows.clear()
	var bench := _workbench_near()
	_craft_title.text = "Crafting  ·  workbench" if bench else "Crafting  ·  by hand"
	var sorted := Recipes.CRAFT.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := 0 if a.at == "" or bench else 1
		var rb := 0 if b.at == "" or bench else 1
		return ra < rb)
	for r in sorted:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.035), 6, Color(1, 1, 1, 0.05), 1, 0, 6))
		_craft_list.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		row.add_child(h)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(icon)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		var name_l := UI.label(Items.display_name(r.out) + ("  x%d" % int(r.n) if int(r.n) > 1 else ""), 17, UI.PAPER, "SemiBold")
		v.add_child(name_l)
		var ing := RichTextLabel.new()
		ing.bbcode_enabled = true
		ing.fit_content = true
		ing.scroll_active = false
		ing.custom_minimum_size = Vector2(230, 0)
		ing.add_theme_font_override("normal_font", UI.font("Medium"))
		ing.add_theme_font_size_override("normal_font_size", 13)
		ing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ing)
		var btn := Button.new()
		btn.text = "Craft"
		btn.custom_minimum_size = Vector2(70, 34)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_override("font", UI.font("SemiBold"))
		btn.add_theme_stylebox_override("normal", UI.box(Color(1, 1, 1, 0.07), 5, Color(1, 1, 1, 0.1), 1))
		btn.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.12), 5, UI.LANTERN, 1))
		btn.add_theme_stylebox_override("disabled", UI.box(Color(0, 0, 0, 0.2), 5))
		btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.25))
		btn.pressed.connect(func() -> void:
			if player.queue_craft(r):
				refresh()
			else:
				Sfx.play("ui_error", -8.0))
		h.add_child(btn)
		_recipe_rows.append({"r": r, "icon": icon, "ing": ing, "btn": btn, "row": row})


func _refresh_recipes() -> void:
	var bench := _workbench_near()
	for rr in _recipe_rows:
		var r: Dictionary = rr.r
		(rr.icon as TextureRect).texture = icons.get_icon(str(r.out))
		var parts := PackedStringArray()
		for id in r.in:
			var have := player.inventory.count(id)
			var need := int(r.in[id])
			parts.append("[color=%s]%s %d/%d[/color]" % ["#cfd8c2" if have >= need else "#d98c6a", Items.display_name(id), have, need])
		var station_ok: bool = r.at == "" or bench
		if not station_ok:
			parts.append("[color=#9a9a90]needs workbench[/color]")
		(rr.ing as RichTextLabel).text = "  ·  ".join(parts)
		(rr.btn as Button).disabled = not station_ok or not Recipes.can_craft(r, player.inventory)
		(rr.row as Control).modulate.a = 1.0 if station_ok else 0.55


func refresh() -> void:
	if _craft_panel.visible:
		_refresh_recipes()
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
	_craft_bar.size.x = 198.0 * player.craft_progress()
	_craft_queue_label.text = ("Crafting %s  (%d queued)" % [Items.display_name(str(player.craft_queue[0].recipe.out)), player.craft_queue.size()]) if not player.craft_queue.is_empty() else "Nothing queued"
	if _process_row.visible and station:
		_process_bar.size.x = (4 * SLOT + 16) * station.process_ratio()
		if Engine.get_process_frames() % 10 == 0:
			refresh()
	var mp := _root.get_local_mouse_position()
	_held_icon.position = mp - Vector2(28, 28)
	_tooltip.position = mp + Vector2(18, 18)
