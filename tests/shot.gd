extends SceneTree
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var out = OS.get_environment("SHOT_DIR")
	for i in 40: await process_frame
	root.get_texture().get_image().save_png(out + "/suit.png")
	main._on_tab_changed(1)
	main.yaw = 0.6
	for i in 60: await process_frame
	root.get_texture().get_image().save_png(out + "/helm_great.png")
	main._on_preset(1)
	for i in 10: await process_frame
	root.get_texture().get_image().save_png(out + "/helm_hounskull.png")
	main._on_preset(4)
	for i in 10: await process_frame
	root.get_texture().get_image().save_png(out + "/helm_grille.png")
	quit()
