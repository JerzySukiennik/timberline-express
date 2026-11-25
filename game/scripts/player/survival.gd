# Health, hunger and thirst. Starving or dehydrated drains health; fed and watered slowly heals. Death hands off to main.
class_name Survival
extends Node

signal died(cause: String)
signal damaged(amount: float, cause: String)

const HUNGER_PER_S := 100.0 / (45.0 * 60.0)
const THIRST_PER_S := 100.0 / (30.0 * 60.0)

var player: Player
var health := 100.0
var hunger := 100.0
var thirst := 100.0
var sick := 0.0            # seconds of food poisoning left
var dead := false
var god := false
var _growl_cd := 30.0
var _heart: AudioStreamPlayer
var _hurt_cd := 0.0


func _ready() -> void:
	_heart = Sfx.loop_2d("heartbeat_loop", -80.0)


func _process(dt: float) -> void:
	if dead or player == null or not player.is_physics_processing():
		return
	var exert := 1.6 if player.sprinting else 1.0
	hunger = maxf(0.0, hunger - HUNGER_PER_S * dt * exert)
	thirst = maxf(0.0, thirst - THIRST_PER_S * dt * exert)
	if sick > 0.0:
		sick -= dt
		hunger = maxf(0.0, hunger - dt * 0.15)
		damage(dt * 0.35, "food poisoning", false)
	if hunger <= 0.0:
		damage(dt * 0.6, "starvation", false)
	if thirst <= 0.0:
		damage(dt * 0.9, "dehydration", false)
	if hunger > 55.0 and thirst > 55.0 and sick <= 0.0:
		health = minf(100.0, health + dt * 0.25)
	_growl_cd -= dt
	if hunger < 25.0 and _growl_cd <= 0.0:
		_growl_cd = randf_range(25.0, 50.0)
		Sfx.play("stomach_growl", -10.0)
	_hurt_cd = maxf(0.0, _hurt_cd - dt)
	if _heart and _heart.stream:
		_heart.volume_db = lerpf(_heart.volume_db, -6.0 if health < 25.0 else -80.0, dt * 3.0)


func damage(amount: float, cause: String, feedback := true) -> void:
	if dead or god or amount <= 0.0:
		return
	if player and player.net_peer != 0:
		NetSync.inst.hurt_peer(player.net_peer, amount, cause)
		return
	health -= amount
	if feedback:
		damaged.emit(amount, cause)
		if _hurt_cd <= 0.0:
			Sfx.play("hurt", -3.0, 0.08)
			_hurt_cd = 0.35
		player.shake(clampf(amount / 25.0, 0.2, 1.0))
	if health <= 0.0:
		health = 0.0
		dead = true
		Sfx.play("death", 0.0)
		died.emit(cause)


func eat(food: float, water: float, heal: float, poison_chance := 0.0) -> void:
	hunger = clampf(hunger + food, 0.0, 100.0)
	thirst = clampf(thirst + water, 0.0, 100.0)
	if heal >= 0.0:
		health = clampf(health + heal, 0.0, 100.0)
	else:
		damage(-heal, "bad food", false)
	if randf() < poison_chance:
		sick = maxf(sick, 45.0)


func revive() -> void:
	dead = false
	health = 100.0
	hunger = maxf(hunger, 55.0)
	thirst = maxf(thirst, 55.0)
	sick = 0.0


func to_dict() -> Dictionary:
	return {"health": health, "hunger": hunger, "thirst": thirst, "sick": sick}


func from_dict(d: Dictionary) -> void:
	health = float(d.get("health", 100.0))
	hunger = float(d.get("hunger", 100.0))
	thirst = float(d.get("thirst", 100.0))
	sick = float(d.get("sick", 0.0))
