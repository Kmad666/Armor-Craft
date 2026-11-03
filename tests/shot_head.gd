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
	main.wear_helmet = false; main._update_helmet_visibility()
	await snap(main, "h_bare", 0.6, 0.06, 0.8, 1.66)
	await snap(main, "h_bare_side", 1.5708, 0.02, 0.8, 1.66)
	main.wear_helmet = true; main.helmet_mode = 0; main._update_helmet_visibility()
	await snap(main, "h_spangen", 0.6, 0.06, 0.8, 1.66)
	await snap(main, "h_spangen_side", 1.5708, 0.02, 0.8, 1.66)
	main.helmet_mode = 1; main._update_helmet_visibility()
	main.modeled_helmet.set_visor_open(1.0)
	await snap(main, "h_bascinet_open", 0.7, 0.08, 0.9, 1.68)
	quit()
