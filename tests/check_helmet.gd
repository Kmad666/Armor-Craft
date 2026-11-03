extends SceneTree
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var h = main.modeled_helmet
	var names := []
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		names.append("%s(%d shapes)" % [mi.name, mi.mesh.get_blend_shape_count()])
	print("parts: ", names)
	h.set_morph("Width", -0.5)
	print("width -0.5 reads back: ", h.get_morph("Width"))
	h.set_visor_open(1.0)
	print("visor: ", h.has_visor())
	main._randomize_suit()
	print("OK")
	quit()
