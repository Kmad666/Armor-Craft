extends SceneTree
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var h = main.spangenhelm
	var cam: Camera3D = main.camera
	main.target_focus = Vector3(0, 1.72, 0); main.focus = main.target_focus
	main.target_distance = 1.0; main.distance = 1.0; main.yaw = 0.3; main.pitch = 0.1
	main._update_camera()
	await process_frame
	main._set_hole_mode(true)
	print("hole mode on, helmet selected: ", main.helmet_selected)
	var target: Vector3 = h.global_transform * Vector3(0.03, 0.07, 0.1)
	var sp: Vector2 = cam.unproject_position(target)
	main._click(sp)
	print("holes after click (mirrored): ", h.holes.size())
	main._click(sp)
	print("holes after clicking the same hole: ", h.holes.size())
	main._add_eye_slits()
	print("eye slits: ", h.holes.size(), " stretch now ", snappedf(h.stretch, 0.001))
	main._add_breaths()
	print("with breaths: ", h.holes.size(), " stretch now ", snappedf(h.stretch, 0.001))
	print("shader hole_count: ", main.helm_mat.get_shader_parameter("hole_count"))
	h.set_shape(0.0, h.crown)
	print("shader hole_count after un-stretching: ", main.helm_mat.get_shader_parameter("hole_count"))
	h.set_shape(0.135, -1.0)
	print("bucket hole_count: ", main.helm_mat.get_shader_parameter("hole_count"))
	main.helm_mat.get_shader_parameter("hole_count")
	h.undo_hole()
	print("after undo: ", h.holes.size())
	main._set_hole_mode(false)
	print("OK")
	quit()
