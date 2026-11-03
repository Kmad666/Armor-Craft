extends SceneTree
# Orthographic front/side/back renders with the UI hidden, for proportion checks.
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for c in main.get_children():
		if c is CanvasLayer: c.visible = false
	main.set_process(false)
	var cam: Camera3D = main.camera
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.05
	cam.h_offset = 0.0
	for v in [["o_front", 0.0], ["o_side", -PI / 2.0], ["o_back", PI]]:
		var yaw: float = v[1]
		cam.position = Vector3(sin(yaw) * 5.0, 0.95, cos(yaw) * 5.0)
		cam.look_at(Vector3(0, 0.95, 0), Vector3.UP)
		for i in 20: await process_frame
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + v[0] + ".png")
	quit()
