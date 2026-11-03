extends SceneTree
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var h = main.spangenhelm
	var cam: Camera3D = main.camera
	# aim the camera at the head and click the helmet
	main.target_focus = Vector3(0, 1.74, 0); main.focus = main.target_focus
	main.target_distance = 1.1; main.distance = 1.1; main.yaw = 0.4; main.pitch = 0.1
	main._update_camera()
	await process_frame
	var hp: Vector2 = cam.unproject_position(h.global_position + Vector3(0, 0.08, 0))
	main._click(hp)
	print("selected after click on helmet: ", main.helmet_selected)
	main._click(Vector2(30, 600))
	print("selected after click on empty space: ", main.helmet_selected)
	main._click(hp)
	await process_frame
	# drag the stretch handle down by 120 px
	var sp: Vector2 = cam.unproject_position(main.gizmo._stretch.global_position)
	print("handle under stretch arrow: ", main.gizmo.handle_at(cam, sp))
	main.gizmo.drag(cam, "stretch", Vector2(0, 120))
	print("stretch after drag: ", snappedf(h.stretch, 0.001))
	main.gizmo.drag(cam, "crown", Vector2(0, -80))
	print("crown after drag up: ", snappedf(h.crown, 0.01))
	main.gizmo.drag(cam, "crown", Vector2(0, 400))
	print("crown after big drag down: ", snappedf(h.crown, 0.01))
	print("slider label: ", main.shape_sliders["crown"][1].text, " | ", main.shape_sliders["stretch"][1].text)
	print("OK")
	quit()
