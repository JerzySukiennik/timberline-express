# Static interactive props: storage crates, water barrel, fuel drum, switch stands and buffer stops.
class_name Props
extends RefCounted


static func _glb(path: String) -> Node3D:
	return (load(path) as PackedScene).instantiate() as Node3D


static func crate(parent: Node3D, main: Node, xf: Transform3D, title: String, contents: Dictionary, tint := Color(1, 1, 1)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("surface", "wood")
	parent.add_child(body)
	body.global_transform = xf
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * 1.5
	body.add_child(holder)
	var box := _glb("res://assets/models/props/wooden_crate_01.glb")
	holder.add_child(box)
	var lid_pivot := Node3D.new()
	holder.add_child(lid_pivot)
	var lid := _glb("res://assets/models/props/wooden_crate_01_lid.glb")
	lid_pivot.add_child(lid)
	var aabb := _aabb(box)
	lid_pivot.position = Vector3(0, aabb.end.y, aabb.position.z)
	lid.position = Vector3(0, 0.0, -aabb.position.z)
	if tint != Color(1, 1, 1):
		for mi in holder.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh.surface_get_material(0)
			if m is StandardMaterial3D:
				var mm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				mm.albedo_color = tint
				(mi as MeshInstance3D).material_override = mm
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = aabb.size * 1.5
	cs.shape = bs
	cs.position = aabb.get_center() * 1.5
	body.add_child(cs)
	var inv := Inventory.new(12)
	for id in contents:
		inv.add(id, int(contents[id]))
	body.set_meta("inventory", inv)
	var it := Interactable.make(body, 0.8, Vector3(0, aabb.end.y * 0.9, 0))
	it.prompt = func(_p: Node) -> String: return "[E] Open %s" % title
	it.on_use = func(_p: Node) -> void:
		Sfx.play_at("crate_open", body.global_position, -3.0)
		var tw := body.create_tween()
		tw.tween_property(lid_pivot, "rotation:x", -1.9, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		main.open_container(inv, title, func() -> void:
			Sfx.play_at("crate_close", body.global_position, -3.0)
			body.create_tween().tween_property(lid_pivot, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT))
	return body


static func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var a := Terrain._rel(n, mi) * (mi as MeshInstance3D).get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


static func barrel(parent: Node3D, xf: Transform3D, fuel: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_meta("surface", "wood")
	parent.add_child(body)
	body.global_transform = xf
	var m := _glb("res://assets/models/props/water_barrel.glb")
	body.add_child(m)
	if fuel:
		var red := StandardMaterial3D.new()
		red.albedo_color = Color(0.55, 0.1, 0.07)
		red.metallic = 0.4
		red.roughness = 0.5
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = red
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.36
	cyl.height = 0.95
	cs.shape = cyl
	cs.position.y = 0.475
	body.add_child(cs)
	var it := Interactable.make(body, 0.62, Vector3(0, 0.55, 0))
	var from := "jerrycan" if fuel else "bucket"
	var to := "jerrycan_fuel" if fuel else "bucket_water"
	it.prompt = func(p: Node) -> String:
		if (p.inventory as Inventory).count(from) > 0:
			return "[E] Fill %s" % Items.display_name(from).to_lower()
		return "Fuel drum — bring an empty jerrycan" if fuel else "Water barrel — bring an empty bucket"
	it.on_use = func(p: Node) -> void:
		var inv: Inventory = p.inventory
		if inv.swap_item(from, to, p.selected_slot):
			Sfx.play_at("fuel_pour" if fuel else "bucket_fill", body.global_position + Vector3.UP, -2.0)
	return body


static func switch_stand(parent: Node3D, net: TrackNetwork, node: TrackNetwork.TrackNode, vehicles: VehicleSystem) -> Node3D:
	var seg: TrackNetwork.TrackSegment = node.links[1].seg
	var t := seg.tangent(0.0)
	var side := t.cross(Vector3.UP).normalized()
	var root := StaticBody3D.new()
	root.set_meta("surface", "metal")
	parent.add_child(root)
	root.global_transform = Transform3D(Basis(side, Vector3.UP, -t).orthonormalized().rotated(Vector3.UP, PI * 0.5), node.pos - side * 2.6 + Vector3.DOWN * 0.3)
	var m := _glb("res://assets/models/props/switch_stand.glb")
	root.add_child(m)
	var lever := m.find_child("Lever", true, false) as Node3D
	var target := m.find_child("Target", true, false) as Node3D
	var lever_rest := lever.basis if lever else Basis.IDENTITY
	var target_rest := target.basis if target else Basis.IDENTITY
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 1.6, 0.4)
	cs.shape = bs
	cs.position.y = 0.8
	root.add_child(cs)
	var refresh := func() -> void:
		if lever:
			root.create_tween().tween_property(lever, "basis", lever_rest * Basis(Vector3.RIGHT, 0.0 if node.state == 0 else PI * 0.85), 0.3).set_trans(Tween.TRANS_BACK)
		if target:
			target.basis = target_rest * Basis(Vector3.UP, 0.0 if node.state == 0 else PI * 0.5)
	net.switch_changed.connect(func(n: TrackNetwork.TrackNode) -> void:
		if n == node:
			refresh.call())
	var grip := m.find_child("M_Grip", true, false) as Node3D
	var it := Interactable.make(root, 0.35, root.to_local(grip.global_position) if grip else Vector3(0, 0.6, 0.5))
	it.prompt = func(_p: Node) -> String: return "[E] Throw switch  ·  set to %s" % ("main line" if node.state == 0 else "siding")
	it.on_use = func(_p: Node) -> void:
		for c in vehicles.consists:
			for v in c.vehicles:
				if v.global_position.distance_to(node.pos) < 7.0:
					Sfx.play_at("lever", root.global_position, -10.0)
					return
		node.state = 1 - node.state
		Sfx.play_at("switch", node.pos, 0.0)
		Sfx.play_at("lever", root.global_position, -3.0)
		refresh.call()
	refresh.call()
	return root


static func buffer_stop(parent: Node3D, dead_end: Dictionary) -> Node3D:
	var seg: TrackNetwork.TrackSegment = dead_end.seg
	var s := seg.length if int(dead_end.end) == 1 else 0.0
	var t := seg.tangent(s) * (1.0 if int(dead_end.end) == 1 else -1.0)
	var p := seg.point(s)
	var body := StaticBody3D.new()
	body.set_meta("surface", "metal")
	parent.add_child(body)
	# model faces +Blender Y (= -Z): buffers point toward incoming traffic
	body.global_transform = Transform3D(Basis.looking_at(-t, Vector3.UP), p + t * 0.3 + Vector3.DOWN * 0.2)
	body.add_child(_glb("res://assets/models/props/buffer_stop.glb"))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.2, 1.2, 0.5)
	cs.shape = bs
	cs.position = Vector3(0, 0.7, 0)
	body.add_child(cs)
	return body
