extends SceneTree

func _init() -> void:
	for sd in [1, 7, 42]:
		var gen := WorldGen.new(sd)
		var total := 0
		var valid := 0
		var reasons := {"slope": 0, "height": 0}
		for i in range(-2, 3):
			for j in range(-2, 3):
				for pd in gen.ponds_near(i * 640.0, -j * 640.0):
					var pp := gen.pond(pd)
					total += 1
					if pp.valid:
						valid += 1
					else:
						if gen.slope(pp.c.x, pp.c.y) >= 0.09:
							reasons.slope += 1
						if gen.base_height(pp.c.x, pp.c.y) >= 60.0:
							reasons.height += 1
		print("seed ", sd, " ponds ", total, " valid ", valid, " ", reasons, " example slope ", gen.slope(100, 60))
	quit()
