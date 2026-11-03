extends SceneTree
# Checks the head stays inside the shaped helmet's inner surface for a grid of shapes.
func _init():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var h = main.spangenhelm
	var head: MeshInstance3D = main.mannequin.node("HeadBlock")
	var verts: PackedVector3Array = head.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var to_h: Transform3D = h.global_transform.affine_inverse() * head.global_transform
	var worst_all := 0.0
	for st in [0.0, 0.02, 0.04, 0.06, 0.09, 0.12, 0.15]:
		for cr in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			h.set_shape(st, cr)
			var worst := -1.0
			var g: float = h.grow()
			for v in verts:
				var p: Vector3 = to_h * v
				if p.y < h.bottom_y() or p.y > h.top_y():
					continue
				var f: float = 1.0 if p.y < h.RIM else h._radius_at((p.y - h.RIM) / (h.dome_height() - h.THICK))
				var a: float = (h.RX * g - h.THICK) * f
				var b: float = (h.RZ * g - h.THICK) * f
				if a < 1e-4:
					worst = maxf(worst, 9.0)
					continue
				# how far out along the horizontal ellipse, as a fraction (1 = touching)
				var q: float = sqrt((p.x / a) * (p.x / a) + (p.z / b) * (p.z / b))
				worst = maxf(worst, q)
			worst_all = maxf(worst_all, worst)
			if worst > 0.97:
				print("TIGHT stretch=%.2f crown=%.1f -> %.3f" % [st, cr, worst])
	print("worst ratio over all shapes: %.3f (below 1.0 = no poke-through)" % worst_all)
	quit()
