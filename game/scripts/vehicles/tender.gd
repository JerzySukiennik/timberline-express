# Tender behind the steam loco: water tank (filled by bucket through the hatch) and a coal bunker to stand on.
class_name Tender
extends RailVehicle

const CAPACITY := 600.0
const BUCKET_L := 40.0

var water := 320.0
var _hatch: Node3D
var _hatch_rest: Basis


func _init() -> void:
	mass = 7000.0
	bogie_half = 0.9
	display_name = "Tender"
	surface = "metal"


func setup(network: TrackNetwork, _path := "") -> void:
	super.setup(network, "res://assets/models/vehicles/tender.glb")
	add_box(Vector3(2.1, 0.08, 3.3), Vector3(0, 1.04, 0), "metal")
	add_box(Vector3(2.0, 1.12, 1.9), Vector3(0, 1.63, 0.65), "metal")
	add_box(Vector3(2.2, 0.8, 3.4), Vector3(0, 0.65, 0), "metal")
	_hatch = part("WaterHatch")
	if _hatch:
		_hatch_rest = _hatch.basis
	var hm := part("M_WaterHatch")
	var it := Interactable.make(self, 0.3, to_local(hm.global_position))
	it.prompt = func(p: Node) -> String:
		var s := "Water %d / %d L" % [int(water), int(CAPACITY)]
		if (p.inventory as Inventory).count("bucket_water") > 0:
			return "[E] Pour water  ·  " + s
		return s + "  ·  fill a bucket at the water barrel"
	it.on_use = func(p: Node) -> void:
		var inv: Inventory = p.inventory
		if inv.count("bucket_water") <= 0 or water >= CAPACITY - 1.0:
			return
		inv.swap_item("bucket_water", "bucket", p.selected_slot)
		water = minf(CAPACITY, water + BUCKET_L)
		Sfx.play_at("water_pour", hm.global_position, -1.0)
		var tw := create_tween()
		tw.tween_property(_hatch, "basis", _hatch_rest * Basis(Vector3.FORWARD, 1.2), 0.25)
		tw.tween_interval(0.9)
		tw.tween_property(_hatch, "basis", _hatch_rest, 0.3)
