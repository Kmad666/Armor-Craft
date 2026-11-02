extends SceneTree
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var hb = load("res://scripts/helmet_builder.gd")
	for name in main.HELMET_PRESETS.keys():
		var p = main.HELMET_PRESETS[name]
		var mesh: ArrayMesh = hb._shell_mesh(p)
		var arr = mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var out := 0
		var bad := 0
		var center := Vector3(0, p.height * 0.5, 0)
		for i in verts.size():
			if is_nan(norms[i].x): bad += 1
			var radial = verts[i] - center
			if norms[i].dot(radial) > 0: out += 1
		print("%s: %d verts, outward %d, nan %d, slit tris %d" % [name, verts.size(), out, bad, hb._slit_mesh(p).surface_get_array_len(0) / 3])
	main._randomize_helmet()
	main._randomize_suit()
	main._on_preset(4)
	await process_frame
	print("OK")
	quit()
