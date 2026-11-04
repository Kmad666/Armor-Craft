extends SceneTree
func snap(main, name, yaw, pitch, dist, fy):
	main.yaw = yaw; main.pitch = pitch
	main.distance = dist; main.target_distance = dist
	main.focus = Vector3(0, fy, 0); main.target_focus = main.focus
	for i in 30: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for c in main.get_children():
		if c is CanvasLayer: c.visible = false
	main.wear_helmet = false; main._update_helmet_visibility()
	await snap(main, "s_side", 1.5708, 0.12, 0.85, 1.42)
	await snap(main, "s_high", 0.8, 0.75, 0.9, 1.45)
	await snap(main, "s_front", 0.35, 0.15, 1.0, 1.38)
	await snap(main, "s_back", 2.7, 0.2, 1.0, 1.4)
	await snap(main, "s_full", 0.6, 0.1, 1.6, 1.25)
	quit()
