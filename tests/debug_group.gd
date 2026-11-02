extends SceneTree
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var keep = OS.get_environment("KEEP").split(",")
	for g in main.groups.keys():
		main.groups[g].visible = keep.has(g)
	for c in main.get_children():
		if c is MeshInstance3D: c.visible = false
	main.helmet_node.visible = false
	var views = OS.get_environment("VIEWS").split(",")
	for v in views:
		var parts = v.split(":")
		main.yaw = float(parts[1]); main.pitch = float(parts[2])
		main.target_distance = float(parts[3]); main.distance = float(parts[3])
		main.target_focus = Vector3(float(parts[5]), float(parts[4]), 0); main.focus = main.target_focus
		for i in 20: await process_frame
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + parts[0] + ".png")
	quit()
