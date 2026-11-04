extends SceneTree
func _init():
	var t0 := Time.get_ticks_msec()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	print("scene ready in ", Time.get_ticks_msec() - t0, " ms")
	var c = main.cuirass
	var t1 := Time.get_ticks_msec()
	c._build_breastplate()
	print("breastplate rebuild ", Time.get_ticks_msec() - t1, " ms")
	t1 = Time.get_ticks_msec()
	c.set_lames(5)
	print("fauld rebuild ", Time.get_ticks_msec() - t1, " ms")
	c.set_lames(4)
	# clearance: mannequin torso and arm vertices must be inside the plates
	var worst := {}
	for part in ["ChestBlock", "PelvisBlock", "WaistBall", "UpperArm_L", "UpperArm_R", "ShoulderBall_L", "Thigh_L", "HipBall_L"]:
		var mi: MeshInstance3D = main.mannequin.node(part)
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var xf: Transform3D = mi.global_transform
		var bad := 0
		for v in verts:
			var p: Vector3 = xf * v
			if p.y > c.BREAST_BOTTOM and p.y < c.breast_top(atan2(p.x, p.z)) - 0.01 and absf(atan2(p.x, p.z)) < c.BREAST_ARC:
				var r: Vector3 = c.plate(p.y)
				var d: float = r.y if p.z >= 0.0 else r.z
				var q: float = (p.x / r.x) * (p.x / r.x) + (p.z / d) * (p.z / d)
				# body parts must be inside the plate; arms must stay outside it
				if (q > 1.0) != part.begins_with("Upper"):
					bad += 1
		worst[part] = bad
	print("mannequin points on the wrong side of the breastplate: ", worst)
	# shoulder plates: closest distance to the wooden body, and continuity with the plates
	var sh_pts := []
	for side in [-1.0, 1.0]:
		for i in 11:
			for j in 49:
				sh_pts.append(c.shoulder_point(side, i / 10.0, j / 48.0))
	var body_v := []
	for part in ["NeckPost", "NeckBall", "ChestBlock", "HeadBlock", "ShoulderBall_L", "ShoulderBall_R", "UpperArm_L", "UpperArm_R"]:
		var mi: MeshInstance3D = main.mannequin.node(part)
		var xf: Transform3D = mi.global_transform
		var vv: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for k in range(0, vv.size(), 3):
			body_v.append([part, xf * vv[k]])
	var best := 1.0
	var best_part := ""
	for p in sh_pts:
		for bv in body_v:
			var dd: float = (p as Vector3).distance_to(bv[1])
			if dd < best:
				best = dd
				best_part = bv[0]
	print("shoulder plates: closest wood %.1f mm (%s)" % [best * 1000.0, best_part])
	var gap_f: float = c.shoulder_point(1.0, 0.5, 0.0).distance_to(c._breast_shape(0.49, 1.0 - c.SH_OVERLAP))
	var gap_b: float = c.shoulder_point(1.0, 0.5, 1.0).distance_to(c._back_shape(-0.52, 1.0 - c.SH_OVERLAP))
	print("strap ends sit %.1f mm / %.1f mm off the breast / back plates" % [gap_f * 1000.0, gap_b * 1000.0])
	var apex := -1.0
	for p in sh_pts:
		apex = maxf(apex, (p as Vector3).y)
	print("strap apex height %.3f m (shoulder %.3f, neck base %.3f)" % [apex, c.m["shoulder_height"], c.m["neck_base_height"]])
	print("OK")
	quit()
