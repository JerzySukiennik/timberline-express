# Pond surface target: drink with E, fill buckets. Not solid for the player (layer 64 only).
class_name WaterBody
extends StaticBody3D

var level := 0.0


func prompt_shape(_shape_idx: int, player: Node) -> String:
	var inv: Inventory = player.inventory
	if inv.count("bucket") > 0:
		return "[E] Fill bucket"
	return "[E] Drink"


func use_shape(_shape_idx: int, player: Node) -> bool:
	var inv: Inventory = player.inventory
	if inv.count("bucket") > 0 and inv.swap_item("bucket", "bucket_water", player.selected_slot):
		Sfx.play("bucket_fill_pond", -3.0)
		return true
	player.survival.eat(0.0, 18.0, 0.0, 0.08)
	Sfx.play("drink_gulp", -4.0)
	Sfx.play_at("splash_water", player.global_position, -10.0)
	return true
