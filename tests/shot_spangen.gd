extends SceneTree
func snap(main, name, yaw, pitch, dist, fy):
	main.yaw = yaw; main.pitch = pitch
	main.target_distance = dist; main.distance = dist
	main.target_focus = Vector3(0, fy, 0); main.focus = main.target_focus
	for i in 25: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for c in main.get_children():
		if c is CanvasLayer: c.visible = false
	await snap(main, "sp_three_quarter", 0.6, 0.12, 0.85, 1.66)
	await snap(main, "sp_front", 0.0, 0.05, 0.85, 1.66)
	await snap(main, "sp_side", 1.5708, 0.05, 0.85, 1.66)
	quit()
