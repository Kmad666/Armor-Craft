extends SceneTree
# Cuirass fit: no part of the steel or leather may come closer than a few
# millimetres to the wooden mannequin.
func _init():
	var t0 := Time.get_ticks_msec()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	print("scene ready in ", Time.get_ticks_msec() - t0, " ms")
	var c = main.cuirass
	var t1 := Time.get_ticks_msec()
	c.rebuild_all()
	print("cuirass rebuild ", Time.get_ticks_msec() - t1, " ms")
	await process_frame
	# mannequin points, bucketed into a 1 cm grid for fast lookup
	var grid := {}
	for mi in main.mannequin.find_children("*", "MeshInstance3D", true, false):
		var part: String = mi.name
		# only the carved wood (helmets and armour also hang off the joints)
		var wood := part.ends_with("Block") or part.contains("Ball") or part.begins_with("UpperArm") \
			or part.begins_with("Forearm") or part.begins_with("Thigh") or part.begins_with("Shin") or part == "NeckPost"
		if not wood or part == "HeadBlock":
			continue
		var xf: Transform3D = mi.global_transform
		var vv: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in vv:
			var p: Vector3 = xf * v
			var key := Vector3i(floori(p.x * 100.0), floori(p.y * 100.0), floori(p.z * 100.0))
			if not grid.has(key):
				grid[key] = []
			grid[key].append([part, p])
	var report := {}
	var tri_count := 0
	for piece in ["Breastplate", "Backplate", "Fauld", "Shoulders", "Belt"]:
		var best := 1.0
		var best_part := ""
		var best_p := Vector3.ZERO
		for mi in (c.pieces[piece] as Node3D).find_children("*", "MeshInstance3D", true, false):
			var vv: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			tri_count += mi.mesh.get_faces().size() / 3
			for v in vv:
				var p: Vector3 = mi.global_transform * v
				var k := Vector3i(floori(p.x * 100.0), floori(p.y * 100.0), floori(p.z * 100.0))
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						for dz in [-1, 0, 1]:
							var cell = grid.get(k + Vector3i(dx, dy, dz))
							if cell == null:
								continue
							for e in cell:
								var d: float = p.distance_to(e[1])
								if d < best:
									best = d
									best_part = e[0]
									best_p = p
		report[piece] = "%.1f mm (%s at %s)" % [best * 1000.0, best_part, best_p.snapped(Vector3.ONE * 0.001)] if best < 1.0 else "clear"
	print("closest wood per piece: ", report)
	print("cuirass triangles: ", tri_count)
	print("OK")
	quit()
