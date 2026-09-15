# Registers input actions in code so bindings live in one readable place, plus shared mouse settings.
extends Node

var sensitivity := 0.0024
var fov := 80.0

const KEYS := {
	"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
	"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C],
	"interact": [KEY_E], "inventory": [KEY_TAB, KEY_I], "drop": [KEY_Q], "console": [KEY_SLASH],
	"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4], "slot_5": [KEY_5],
	"slot_6": [KEY_6], "slot_7": [KEY_7], "slot_8": [KEY_8], "slot_9": [KEY_9],
}
const MOUSE := {"primary": MOUSE_BUTTON_LEFT, "secondary": MOUSE_BUTTON_RIGHT}


func _ready() -> void:
	for action in KEYS:
		_ensure(action)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for action in MOUSE:
		_ensure(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE[action]
		InputMap.action_add_event(action, mb)
	_load()


func _ensure(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		sensitivity = cfg.get_value("input", "sensitivity", sensitivity)
		fov = cfg.get_value("video", "fov", fov)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "sensitivity", sensitivity)
	cfg.set_value("video", "fov", fov)
	cfg.save("user://settings.cfg")
