# Shared UI palette, fonts and stylebox helpers — a dark, woodsy field-gear look.
class_name UI
extends RefCounted

const INK := Color(0.07, 0.08, 0.075)
const INK_SOFT := Color(0.13, 0.145, 0.13)
const PAPER := Color(0.93, 0.91, 0.85)
const DIM := Color(0.66, 0.66, 0.6)
const LANTERN := Color(0.93, 0.66, 0.3)
const MOSS := Color(0.47, 0.6, 0.36)
const RUST := Color(0.78, 0.36, 0.24)
const HAY := LANTERN

static var _fonts := {}


static func font(weight := "SemiBold") -> Font:
	if not _fonts.has(weight):
		_fonts[weight] = load("res://assets/fonts/BarlowSemiCondensed-%s.ttf" % weight)
	return _fonts[weight]


static func mono() -> Font:
	if not _fonts.has("mono"):
		_fonts["mono"] = load("res://assets/fonts/JetBrainsMono-Variable.ttf")
	return _fonts["mono"]


static func box(bg: Color, radius := 6, border := Color(0, 0, 0, 0), border_w := 0, shadow := 0, margin := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.shadow_size = shadow
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.set_content_margin_all(margin)
	return s


static func label(text: String, size := 18, col := PAPER, weight := "SemiBold") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func place(c: Control, preset: Control.LayoutPreset, offset: Vector2, size: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y
