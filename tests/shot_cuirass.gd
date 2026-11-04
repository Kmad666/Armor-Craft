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
	await snap(main, "front", 0.0, 0.05, 1.5, 1.24)
	await snap(main, "three_quarter", 0.6, 0.1, 1.5, 1.24)
	await snap(main, "side", 1.5708, 0.03, 1.6, 1.24)
	await snap(main, "back", 3.3, 0.06, 1.6, 1.24)
	await snap(main, "close", 0.35, 0.12, 0.8, 1.3)
	quit()
