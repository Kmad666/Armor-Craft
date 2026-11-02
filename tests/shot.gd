extends SceneTree
var main
func snap(path):
	for i in 25: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + path)
func _init():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var views = OS.get_environment("VIEWS").split(",")
	for v in views:
		var parts = v.split(":")
		# name:yaw:pitch:dist:focusY
		main.yaw = float(parts[1]); main.pitch = float(parts[2])
		main.target_distance = float(parts[3]); main.distance = float(parts[3])
		main.target_focus = Vector3(0, float(parts[4]), 0); main.focus = main.target_focus
		await snap(parts[0] + ".png")
	quit()
