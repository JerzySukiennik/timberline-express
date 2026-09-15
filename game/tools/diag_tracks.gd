extends SceneTree

func _init() -> void:
	for sd in [1, 7, 42, 424242, 999]:
		var gen := WorldGen.new(sd)
		var net := TrackNetwork.new()
		var it := InfiniteTracks.new(gen, net)
		it.ensure(Vector3.ZERO, 2)
		var worst := 0.0
		var worst_info := ""
		for seg in net.segments:
			var n := int(seg.length / 8.0)
			for i in n + 1:
				var p := seg.point(seg.length * i / n)
				var b := gen.base_height(p.x, p.z)
				var d := p.y - b
				if absf(d) > absf(worst):
					worst = d
					worst_info = "seg %d len %d at %s node heights %.1f -> %.1f" % [seg.id, int(seg.length), str(p.snappedf(1)), seg.nodes[0].pos.y, seg.nodes[1].pos.y]
		print("seed ", sd, " segs ", net.segments.size(), " worst track-base ", snappedf(worst, 0.1), " ", worst_info)
	quit()
