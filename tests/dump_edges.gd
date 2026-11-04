extends SceneTree
# Writes every plate's cut edges (outer face and middle of the rolled edge,
# reference space) to EDGES_OUT as JSON: {piece: [[x, y, z], ...]} with loops separated
# by nulls.
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var c = main.cuirass
	var out := {}
	for piece in c.edge_loops.keys():
		var loops: Array = c.edge_loops[piece][0]
		var push: float = c.edge_loops[piece][1]
		var pts := []
		for lp in loops:
			for pr in lp:
				var p: Vector3 = c.surface(pr[0], pr[1], push)
				var n: Vector3 = c.normal_at(pr[0], pr[1], push)
				var q: Vector3 = p + n * c.EDGE_R * 1.4   # outer face of the rim
				var m: Vector3 = p + n * c.EDGE_R * 0.4   # middle of the rim
				pts.append([q.x, q.y, q.z, m.x, m.y, m.z])
			pts.append(null)
		out[piece] = pts
	var f := FileAccess.open(OS.get_environment("EDGES_OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	quit()
