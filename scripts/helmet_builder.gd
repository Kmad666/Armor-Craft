extends RefCounted
## Procedural helmet generator for Armor Craft.
##
## The helmet shell is a parametric surface swept around the vertical axis.
## Angle a = 0 faces the front (+Z). t runs 0 (neck rim) -> 1 (crown).
## Visor slits are dark strips laid just above the shell surface so they
## follow its curve, which reads as a cut-out without real mesh boolean ops.

const RINGS := 36
const SEGMENTS := 48

const SLIT_STYLES := ["Horizontal", "Split Eyes", "T-Visor", "Grille"]


static func radius_factor(t: float, p: Dictionary) -> float:
	var r: float = lerp(1.0, float(p["taper"]), t)
	# Brim flare pushes the bottom edge outward (sallet / kettle hat feel).
	var flare: float = p["flare"]
	if t < 0.3:
		var f := (0.3 - t) / 0.3
		r *= 1.0 + flare * f * f
	# Dome rounds off the top portion of the helmet.
	var dome: float = clamp(float(p["dome"]), 0.05, 1.0)
	var d0 := 1.0 - dome
	if t > d0:
		var u := (t - d0) / dome
		r *= sqrt(max(0.0, 1.0 - u * u))
	return r


static func surface_point(a: float, t: float, p: Dictionary, push: float) -> Vector3:
	var r := radius_factor(t, p)
	var width: float = p["width"]
	var depth: float = p["depth"]
	var height: float = p["height"]
	var snout: float = p["snout"]
	var x := sin(a) * width * r
	var z := cos(a) * depth * r
	# Snout pulls the face forward, strongest at the centre-front.
	var front := pow(max(cos(a), 0.0), 3.0)
	z += snout * front * sin(PI * clamp(t, 0.0, 1.0))
	var v := Vector3(x, t * height, z)
	if push != 0.0:
		v += Vector3(sin(a), 0.0, cos(a)) * push
	return v


static func build(p: Dictionary, metal: Material, dark: Material, cloth: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Helmet"

	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = _shell_mesh(p)
	shell.material_override = metal
	root.add_child(shell)

	var slits := MeshInstance3D.new()
	slits.name = "Visor"
	slits.mesh = _slit_mesh(p)
	slits.material_override = dark
	root.add_child(slits)

	if p.get("rim", false):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_strip(st, p, 0.0, TAU, 0.0, 0.06, 0.004, SEGMENTS)
		st.generate_normals()
		var rim := MeshInstance3D.new()
		rim.name = "Rim"
		rim.mesh = st.commit()
		rim.material_override = metal
		root.add_child(rim)

	if p.get("plume", false):
		var plume_mesh := CylinderMesh.new()
		var h := 0.24
		plume_mesh.top_radius = 0.006
		plume_mesh.bottom_radius = 0.03
		plume_mesh.height = h
		var plume := MeshInstance3D.new()
		plume.name = "Plume"
		plume.mesh = plume_mesh
		plume.material_override = cloth
		var basis := Basis(Vector3.RIGHT, -0.9)  # lean back
		var top := surface_point(0.0, 0.97, p, 0.0)
		plume.transform = Transform3D(basis, top + basis.y * (h * 0.45))
		root.add_child(plume)

	return root


static func _shell_mesh(p: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in RINGS:
		var t := float(i) / RINGS
		for j in SEGMENTS:
			var a := TAU * j / SEGMENTS
			st.set_uv(Vector2(float(j) / SEGMENTS, t))
			st.add_vertex(surface_point(a, t, p, 0.0))
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(surface_point(0.0, 1.0, p, 0.0))
	var pole := RINGS * SEGMENTS

	for i in RINGS - 1:
		for j in SEGMENTS:
			var a0 := i * SEGMENTS + j
			var a1 := i * SEGMENTS + (j + 1) % SEGMENTS
			var b0 := a0 + SEGMENTS
			var b1 := a1 + SEGMENTS
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a1)
			st.add_index(a1)
			st.add_index(b0)
			st.add_index(b1)
	var last := (RINGS - 1) * SEGMENTS
	for j in SEGMENTS:
		st.add_index(last + j)
		st.add_index(pole)
		st.add_index(last + (j + 1) % SEGMENTS)
	st.generate_normals()
	return st.commit()


## Adds a curved strip that hugs the shell between angles a0..a1 and heights t0..t1.
static func _strip(st: SurfaceTool, p: Dictionary, a0: float, a1: float, t0: float, t1: float, push: float, steps: int = 10) -> void:
	# Subdivide vertically too so tall strips follow the shell's curve.
	var tsteps := maxi(1, ceili((t1 - t0) / 0.025))
	for m in tsteps:
		var ta := lerpf(t0, t1, float(m) / tsteps)
		var tb := lerpf(t0, t1, float(m + 1) / tsteps)
		for k in steps:
			var aa := lerpf(a0, a1, float(k) / steps)
			var ab := lerpf(a0, a1, float(k + 1) / steps)
			var v00 := surface_point(aa, ta, p, push)
			var v10 := surface_point(ab, ta, p, push)
			var v01 := surface_point(aa, tb, p, push)
			var v11 := surface_point(ab, tb, p, push)
			st.add_vertex(v00)
			st.add_vertex(v01)
			st.add_vertex(v10)
			st.add_vertex(v10)
			st.add_vertex(v01)
			st.add_vertex(v11)


static func _slit_mesh(p: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var style: int = p["slit_style"]
	var count: int = p["slit_count"]
	var w: float = p["slit_w"]
	var th: float = p["slit_thick"]
	var y: float = p["slit_y"]
	var push := 0.003
	var gap := th * 2.4

	match style:
		0:  # Horizontal - stacked eye slits across the face
			for k in count:
				var tc := y - k * gap
				_strip(st, p, -w, w, tc - th * 0.5, tc + th * 0.5, push, 16)
		1:  # Split eyes - two slits with a nose bar between them
			var bridge := 0.1
			for k in count:
				var tc := y - k * gap
				_strip(st, p, -w, -bridge, tc - th * 0.5, tc + th * 0.5, push, 10)
				_strip(st, p, bridge, w, tc - th * 0.5, tc + th * 0.5, push, 10)
		2:  # T-visor - eye bar plus a mouth channel
			_strip(st, p, -w, w, y - th * 0.5, y + th * 0.5, push, 16)
			_strip(st, p, -0.07, 0.07, 0.12, y - th * 0.5, push, 2)
		3:  # Grille - vertical bars across the face
			var half := (2.0 * w / count) * 0.28
			for k in count:
				var ac := lerpf(-w, w, (k + 0.5) / count)
				_strip(st, p, ac - half, ac + half, y - 0.28, y + th * 0.5, push, 2)

	st.generate_normals()
	return st.commit()
