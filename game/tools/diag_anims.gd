extends SceneTree

func _init() -> void:
	for n in ["deer", "wolf", "fox"]:
		var ps: PackedScene = load("res://assets/models/animals/%s.glb" % n)
		if ps == null:
			print(n, " not imported")
			continue
		var inst := ps.instantiate()
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var aabb := AABB()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			aabb = aabb.merge((mi as MeshInstance3D).get_aabb()) if aabb.size != Vector3.ZERO else (mi as MeshInstance3D).get_aabb()
		print(n, " anims: ", ap.get_animation_list() if ap else [], " aabb ", aabb)
		inst.free()
	quit()
