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
	var h = main.modeled_helmet
	await snap(main, "g_helm", 0.6, 0.06, 0.95, 1.73)
	await snap(main, "g_side", 1.5708, 0.02, 0.95, 1.73)
	h.set_visor_open(1.0)
	await snap(main, "g_open", 0.7, 0.12, 0.95, 1.73)
	h.set_visor_open(0.0)
	h.set_morph("Apex", 1.0); h.set_morph("Snout", 1.0); h.set_morph("Width", -0.4)
	await snap(main, "g_morph", 1.2, 0.05, 0.95, 1.75)
	h.set_morph("Apex", 0.0); h.set_morph("Snout", 0.0); h.set_morph("Width", 0.0)
	await snap(main, "g_full", 0.55, 0.12, 2.7, 1.0)
	quit()
