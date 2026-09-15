# Sound autoload: cue names map to file-name prefixes in assets/audio; random variant and pitch per play.
extends Node

const AUDIO_DIR := "res://assets/audio"
const CUES := {
	"step_grass": ["footstep_grass_"], "step_gravel": ["footstep_gravel_"], "step_wood": ["footstep_wood_"], "step_metal": ["footstep_metal_"],
	"land_soft": ["land_soft_"], "land_hard": ["land_hard_"], "jump": ["jump_cloth_"], "crouch": ["crouch_cloth_"], "breath": ["breath_exhausted_"],
	"equip_pickaxe": ["equip_pickaxe_"], "equip_axe": ["equip_axe_"], "equip_knife": ["equip_knife_"], "equip_hand": ["equip_hand_"],
	"swing_heavy": ["swing_heavy_"], "swing_light": ["swing_light_"],
	"hit_rock": ["pickaxe_hit_rock_"], "rock_crack": ["rock_crack_"], "rock_debris": ["rock_debris_"],
	"chop": ["axe_chop_wood_"], "tree_creak": ["tree_creak_"], "tree_fall": ["tree_fall_"], "cut_foliage": ["knife_cut_foliage_"],
	"pickup": ["pickup_item_"], "hit_miss": ["tool_hit_miss_"],
	"backpack_open": ["backpack_open_"], "backpack_close": ["backpack_close_"], "slot_pick": ["slot_pick_"], "slot_drop": ["slot_drop_"],
	"ui": ["ui_click_"], "crate_open": ["crate_open_"], "crate_close": ["crate_close_"],
	"pump": ["handcar_pump_"], "rail_clack": ["rail_clack_"], "lever": ["lever_clunk_"], "buffer_hit": ["buffer_hit_"], "switch": ["switch_throw_"],
	"chuff": ["steam_chuff_"], "whistle": ["steam_whistle_"], "firedoor_open": ["firebox_door_open_"], "firedoor_close": ["firebox_door_close_"],
	"coal": ["coal_shovel_"], "wood_fire": ["wood_toss_fire_"], "water_pour": ["water_pour_tank_"], "bucket_fill": ["bucket_fill_"], "steam_release": ["pressure_release_"],
	"breaker": ["breaker_switch_"], "gen_start": ["generator_start_"], "gen_stop": ["generator_stop_"], "horn": ["electric_horn_"], "fuel_pour": ["fuel_pour_"],
}

var _files: Array[String] = []
var _streams := {}
var master_volume := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_walk(AUDIO_DIR, _files)
	_files.sort()
	for cue in CUES:
		var list: Array[AudioStream] = []
		for prefix in CUES[cue]:
			for f in _files:
				if f.get_file().begins_with(prefix):
					var s := load(f) as AudioStream
					if s:
						list.append(s)
		_streams[cue] = list


func _walk(dir: String, out: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for entry in ResourceLoader.list_directory(dir):
		var path := dir.path_join(entry)
		if entry.ends_with("/"):
			_walk(path.trim_suffix("/"), out)
		elif entry.get_extension() in ["ogg", "wav", "mp3"]:
			out.append(path)


func has(cue: String) -> bool:
	return not (_streams.get(cue, []) as Array).is_empty()


func stream(base: String) -> AudioStream:
	for f in _files:
		if f.get_file().get_basename() == base:
			return load(f) as AudioStream
	return null


func play(cue: String, volume_db := 0.0, pitch_spread := 0.05, pitch := 1.0) -> void:
	var list: Array = _streams.get(cue, [])
	if list.is_empty():
		return
	var p := AudioStreamPlayer.new()
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(1.0 - pitch_spread, 1.0 + pitch_spread)
	p.bus = "Master"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func play_at(cue: String, pos: Vector3, volume_db := 0.0, pitch_spread := 0.1, pitch := 1.0, max_dist := 60.0) -> void:
	var list: Array = _streams.get(cue, [])
	var scene := get_tree().current_scene
	if list.is_empty() or scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(1.0 - pitch_spread, 1.0 + pitch_spread)
	p.unit_size = 5.0
	p.max_distance = max_dist
	p.attenuation_filter_cutoff_hz = 12000.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## Looping positional sound attached to a node; control volume/pitch through the returned player.
func loop(base: String, parent: Node3D, volume_db := -80.0, unit_size := 5.0, max_dist := 60.0) -> AudioStreamPlayer3D:
	var s := stream(base)
	var p := AudioStreamPlayer3D.new()
	if s:
		s = s.duplicate()
		if "loop" in s:
			s.set("loop", true)
		elif "loop_mode" in s:
			s.set("loop_mode", 1)
		p.stream = s
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = max_dist
	parent.add_child(p)
	if s:
		p.play()
	return p


func loop_2d(base: String, volume_db := -12.0) -> AudioStreamPlayer:
	var s := stream(base)
	var p := AudioStreamPlayer.new()
	if s:
		s = s.duplicate()
		if "loop" in s:
			s.set("loop", true)
		p.stream = s
	p.volume_db = volume_db
	add_child(p)
	if s:
		p.play()
	return p
