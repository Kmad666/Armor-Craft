extends SceneTree
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._randomize_helmet()
	main._randomize_suit()
	for i in main.HELMET_PRESETS.size():
		main._on_preset(i)
	await process_frame
	var tris := 0
	for n in main.find_children("*", "MeshInstance3D", true, false):
		if n.mesh: 
			for s in n.mesh.get_surface_count():
				var a = n.mesh.surface_get_arrays(s)
				tris += (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] else a[Mesh.ARRAY_VERTEX].size()) / 3
	print("triangles (excluding multimesh/primitive): ", tris)
	print("OK")
	quit()
