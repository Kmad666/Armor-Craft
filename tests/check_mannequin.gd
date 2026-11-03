extends SceneTree
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var mq = main.mannequin
	var meshes = mq.find_children("*", "MeshInstance3D", true, false)
	print("mannequin meshes: ", meshes.size())
	for j in ["Pelvis", "Chest", "Head", "Socket_Head", "Elbow_L", "Knee_R", "Ankle_L"]:
		var n = mq.node(j)
		print(j, ": ", n.global_position if n else "MISSING")
	print("helmet parent: ", main.modeled_helmet.get_parent().name, " at ", main.modeled_helmet.global_position)
	print("rows: ", mq.summary().size(), " chest cm: ", snappedf(mq.summary()[3][1] * 100.0, 0.1))
	# posing works: bend an elbow
	mq.node("Elbow_L").rotation.x = -0.6
	await process_frame
	print("OK")
	quit()
