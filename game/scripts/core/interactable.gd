# Aim target for the player's interaction ray. Owners fill in callables; a grab target also exposes a hand point.
class_name Interactable
extends Area3D

var prompt: Callable            # func(player) -> String   ("" hides the prompt)
var on_use: Callable            # func(player)             (E pressed)
var on_hold: Callable           # func(player, delta)      (E held)
var on_release: Callable        # func(player)             (E released)
var on_secondary: Callable      # func(player)             (RMB pressed)
var grab_drag: Callable         # func(player, rel: Vector2) — makes this a LMB-drag grab target
var grab_start: Callable
var grab_end: Callable
var hand_point: Node3D          # where the right hand goes while grabbing / using


static func make(parent: Node3D, radius := 0.18, local_pos := Vector3.ZERO) -> Interactable:
	var it := Interactable.new()
	it.collision_layer = 8
	it.collision_mask = 0
	it.monitoring = false
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = radius
	cs.shape = sp
	it.add_child(cs)
	parent.add_child(it)
	it.position = local_pos
	it.hand_point = it
	return it


func is_grab() -> bool:
	return grab_drag.is_valid()


func get_prompt(player: Node) -> String:
	return prompt.call(player) if prompt.is_valid() else ""
