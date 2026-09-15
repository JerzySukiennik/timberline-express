# Slot-based container: each slot is {} or {id, count, dur}. Used for the player (hotbar + backpack) and crates.
class_name Inventory
extends RefCounted

signal changed

var slots: Array[Dictionary] = []


func _init(size: int) -> void:
	slots.resize(size)
	for i in size:
		slots[i] = {}


func size() -> int:
	return slots.size()


func get_slot(i: int) -> Dictionary:
	return slots[i] if i >= 0 and i < slots.size() else {}


func set_slot(i: int, data: Dictionary) -> void:
	slots[i] = data.duplicate() if not data.is_empty() and int(data.get("count", 0)) > 0 else {}
	changed.emit()


func make(id: String, count := 1) -> Dictionary:
	var d := {"id": id, "count": count}
	var dur := int(Items.def(id).get("durability", 0))
	if dur > 0:
		d["dur"] = dur
	return d


## Adds items, filling existing stacks first. Returns how many did not fit.
func add(id: String, count := 1, prefer: Array = []) -> int:
	var left := count
	var max_stack := Items.stack_size(id)
	var order := prefer.duplicate()
	for i in slots.size():
		if not i in order:
			order.append(i)
	for i in order:
		if left <= 0:
			break
		var s := slots[i]
		if not s.is_empty() and s.id == id and int(s.count) < max_stack:
			var put := mini(left, max_stack - int(s.count))
			s.count = int(s.count) + put
			left -= put
	for i in order:
		if left <= 0:
			break
		if slots[i].is_empty():
			var put := mini(left, max_stack)
			slots[i] = make(id, put)
			left -= put
	changed.emit()
	return left


func count(id: String) -> int:
	var n := 0
	for s in slots:
		if not s.is_empty() and s.id == id:
			n += int(s.count)
	return n


func remove(id: String, count := 1) -> bool:
	if count(id) < count:
		return false
	var left := count
	for i in range(slots.size() - 1, -1, -1):
		var s := slots[i]
		if left > 0 and not s.is_empty() and s.id == id:
			var take := mini(left, int(s.count))
			s.count = int(s.count) - take
			left -= take
			if int(s.count) <= 0:
				slots[i] = {}
	changed.emit()
	return true


func remove_at(i: int, n := 1) -> void:
	var s := get_slot(i)
	if s.is_empty():
		return
	s.count = int(s.count) - n
	if int(s.count) <= 0:
		slots[i] = {}
	changed.emit()


func find(id: String) -> int:
	for i in slots.size():
		if not slots[i].is_empty() and slots[i].id == id:
			return i
	return -1


## Replace one item of `from_id` with `to_id` (e.g. bucket -> bucket_water), preferring slot `prefer`.
func swap_item(from_id: String, to_id: String, prefer := -1) -> bool:
	var i := prefer if prefer >= 0 and not get_slot(prefer).is_empty() and get_slot(prefer).id == from_id else find(from_id)
	if i < 0:
		return false
	slots[i] = make(to_id, 1)
	changed.emit()
	return true
