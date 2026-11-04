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
	print("OK")
	quit()
