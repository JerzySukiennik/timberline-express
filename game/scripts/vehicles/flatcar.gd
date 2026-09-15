# Unpowered wooden flatcar — the first buildable deck.
class_name Flatcar
extends RailVehicle


func _init() -> void:
	mass = 520.0
	bogie_half = 2.2
	display_name = "Flatcar"
	surface = "wood"


func setup(network: TrackNetwork, _path := "") -> void:
	super.setup(network, "res://assets/models/vehicles/flatcar.glb")
	add_box(Vector3(3.0, 0.14, 6.1), Vector3(0, 0.8, 0), "wood")
