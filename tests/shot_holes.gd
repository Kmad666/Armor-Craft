extends SceneTree
func snap(main, name):
	for i in 30: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")
func view(main, yaw, pitch, dist, fy):
	main.yaw = yaw; main.pitch = pitch
	main.distance = dist; main.target_distance = dist
	main.focus = Vector3(0, fy, 0); main.target_focus = main.focus
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var tabs: TabContainer = main.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = 2
	var h = main.spangenhelm
	var cam: Camera3D = main.camera
	# bucket helm with eye slits and breaths
	h.set_shape(0.135, -1.0)
	main._add_eye_slits()
	main._add_breaths()
	view(main, 0.45, 0.06, 0.95, 1.67)
	await snap(main, "a_great_helm")
	view(main, 0.0, 0.0, 0.85, 1.67)
	await snap(main, "b_great_helm_front")
	# dome with crosses and a hover preview
	h.clear_holes()
	h.set_shape(0.0, 0.6)
	main._set_hole_mode(true)
	main._select_hole_shape(2)
	h.add_hole(Vector3(0.035, 0.07, 0.09), 2, 0.022, 0.006, true)
	main._select_hole_shape(0)
	h.add_hole_set([[0.0, 0.11, 0, 0.012, 0.012], [1.2, 0.05, 0, 0.009, 0.009], [1.5, 0.05, 0, 0.009, 0.009]], true)
	view(main, 0.5, 0.15, 0.95, 1.72)
	main._update_camera()
	await process_frame
	var hover: Vector2 = cam.unproject_position(h.global_transform * Vector3(-0.045, 0.06, 0.085))
	main._update_hole_preview(hover)
	await snap(main, "c_dome_holes_preview")
	quit()
