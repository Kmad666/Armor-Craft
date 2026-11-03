extends SceneTree
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var tabs: TabContainer = main.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = 2
	var h = main.spangenhelm
	main._set_hole_mode(true)
	main.yaw = 0.35; main.pitch = 0.12; main.distance = 0.8; main.target_distance = 0.8
	main.focus = Vector3(0, 1.72, 0); main.target_focus = main.focus
	h.set_shape(0.0, 0.4)
	h.add_hole_set([[0.5, 0.07, 2, 0.022, 0.006]], true)
	main._select_hole_shape(1)
	h.set_preview(Vector3(0.0, 0.08, 0.1), 1, main.hole_w, main.hole_h)
	for i in 25: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/preview_ui.png")
	quit()
