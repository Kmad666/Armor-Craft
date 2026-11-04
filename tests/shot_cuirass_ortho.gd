extends SceneTree
# Orthographic front / side / back of the cuirass, mannequin hidden, to
# compare against the reference sheet.
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for c in main.get_children():
		if c is CanvasLayer: c.visible = false
	var hide_body := OS.get_environment("BODY") != "1"
	if hide_body:
		var keep := []
		for piece in main.cuirass.pieces.values():
			keep.append_array((piece as Node).find_children("*", "MeshInstance3D", true, false))
		for mi in main.mannequin.find_children("*", "MeshInstance3D", true, false):
			if not keep.has(mi):
				mi.visible = false
	main.wear_helmet = false; main._update_helmet_visibility()
	# compare in reference space: undo the size / placement on the mannequin
	for piece in main.cuirass.pieces.values():
		(piece as Node3D).global_transform = Transform3D.IDENTITY
	main.set_process(false)
	var cam: Camera3D = main.camera
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.62
	cam.h_offset = 0.0
	for v in [["o_front", 0.0], ["o_side", PI / 2.0], ["o_back", PI]]:
		var yaw: float = v[1]
		cam.position = Vector3(sin(yaw) * 3.0, 1.265, cos(yaw) * 3.0)
		cam.look_at(Vector3(0, 1.265, 0), Vector3.UP)
		for i in 25: await process_frame
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + v[0] + ".png")
	quit()
