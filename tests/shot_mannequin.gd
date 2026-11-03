extends SceneTree
func snap(main, name, yaw, pitch, dist, fy, fx := 0.0):
	main.yaw = yaw; main.pitch = pitch
	main.target_distance = dist; main.distance = dist
	main.target_focus = Vector3(fx, fy, 0); main.focus = main.target_focus
	for i in 25: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var mode = OS.get_environment("MODE")
	if mode == "bare":
		main.wear_helmet = false
		main._update_helmet_visibility()
	await snap(main, "m_hero", 0.5, 0.1, 3.2, 0.95)
	await snap(main, "m_back", 2.6, 0.08, 3.2, 0.95)
	await snap(main, "m_head", 0.7, 0.05, 1.0, 1.62)
	await snap(main, "m_hand", 1.2, 0.0, 0.7, 0.9, 0.2)
	await snap(main, "m_feet", 0.6, 0.35, 1.0, 0.15)
	quit()
