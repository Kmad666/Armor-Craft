extends SceneTree
func snap(main, name):
	for i in 30: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	# open the Helmet tab
	var tabs: TabContainer = main.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = 2
	await process_frame
	main.yaw = 0.55; main.pitch = 0.12
	main._set_helmet_selected(true)
	main.distance = 1.2; main.target_distance = 1.2
	main.focus = Vector3(0, 1.72, 0); main.target_focus = main.focus
	var h = main.spangenhelm
	await snap(main, "a_selected_dome")
	h.set_shape(0.0, 1.0)
	await snap(main, "b_pointed")
	h.set_shape(0.135, -1.0)
	main.focus = Vector3(0, 1.69, 0); main.target_focus = main.focus
	await snap(main, "c_bucket")
	h.set_shape(0.06, 0.35)
	await snap(main, "d_stretched")
	main._set_helmet_selected(false)
	h.set_shape(0.135, -1.0)
	main.yaw = 0.5; main.distance = 3.0; main.target_distance = 3.0
	main.focus = Vector3(0, 1.0, 0); main.target_focus = main.focus
	await snap(main, "e_full_bucket")
	quit()
