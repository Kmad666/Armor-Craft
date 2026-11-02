extends RefCounted
## Procedural helmet generator for Armor Craft.
##
## The skull is a parametric surface swept around the vertical axis.
## Angle a = 0 faces the front (+Z). t runs 0 (lower rim) -> 1 (crown).
## `apex` turns the dome into a pointed ogive (bascinet). With `visor` on,
## a separate pig-faced (hounskull) visor is raised over the face, pivoting
## on rosette bosses at the temples, with an eye slit and breaths.
## Slits and breaths are dark inlays that follow the curve, which reads as
## a cut-out without boolean mesh operations.

const K := preload("res://scripts/mesh_kit.gd")

const SLIT_STYLES := ["Horizontal", "Split Eyes", "T-Visor", "Grille"]

# Visor footprint on the skull (in a / t space)
const VA := 1.28
const VT0 := -0.07
const VT1 := 0.76


static func radius_factor(t: float, p: Dictionary) -> float:
	var r: float = lerp(1.0, float(p["taper"]), clampf(t, 0.0, 1.0))
	var flare: float = p["flare"]
	if t < 0.3:
		var f := (0.3 - t) / 0.3
		r *= 1.0 + flare * f * f
	var dome: float = clamp(float(p["dome"]), 0.05, 1.0)
	var d0 := 1.0 - dome
	if t > d0:
		var u := clampf((t - d0) / dome, 0.0, 1.0)
		# Ogive: k = 1 is a hemisphere, larger k gives a pointed apex.
		var k := 1.0 + float(p.get("apex", 0.0)) * 1.6
		var rho := (1.0 + k * k) * 0.5
		r *= maxf(0.0, sqrt(maxf(0.0, rho * rho - k * k * u * u)) - (rho - 1.0))
	return r


static func surface_point(a: float, t: float, p: Dictionary, push: float) -> Vector3:
	var r := radius_factor(t, p)
	var width: float = p["width"]
	var depth: float = p["depth"]
	var height: float = p["height"]
	var x := sin(a) * width * r
	var z := cos(a) * depth * r
	if not p.get("visor", false):
		var snout: float = p["snout"]
		var front := pow(maxf(cos(a), 0.0), 3.0)
		z += snout * front * sin(PI * clampf(t, 0.0, 1.0))
	# Bascinet apex sits slightly behind centre.
	var dome: float = clamp(float(p["dome"]), 0.05, 1.0)
	var u := clampf((t - (1.0 - dome)) / dome, 0.0, 1.0)
	z -= float(p.get("apex", 0.0)) * 0.03 * u * u
	var v := Vector3(x, t * height, z)
	if push != 0.0:
		v += Vector3(sin(a), 0.0, cos(a)) * push
	return v


## How far the visor stands proud of the skull at (a, t): a cone to a point.
static func visor_push(a: float, t: float, p: Dictionary) -> float:
	var snout: float = p["snout"]
	var d := sqrt(pow(a / 1.3, 2.0) + pow((t - 0.34) / 0.56, 2.0))
	var cone := maxf(0.0, 1.0 - d)
	var fall := smoothstep(VT1, VT1 - 0.2, t) * smoothstep(VA, VA - 0.32, absf(a))
	return 0.0065 + snout * cone * fall


static func in_visor(a: float, t: float) -> bool:
	return absf(a) <= VA + 0.0001 and t >= VT0 - 0.0001 and t <= VT1 + 0.0001


static func face_point(a: float, t: float, p: Dictionary, push: float) -> Vector3:
	if p.get("visor", false) and in_visor(a, t):
		return surface_point(a, t, p, push + visor_push(a, t, p))
	return surface_point(a, t, p, push)


static func build(p: Dictionary, metal: Material, dark: Material, cloth: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Helmet"
	var height: float = p["height"]
	var center := Vector3(0, height * 0.35, 0)
	var rivets: Array = []

	var skull := func(a: float, t: float) -> Vector3:
		return surface_point(a, t, p, 0.0)
	_add(root, K.surface(skull, 0.0, TAU, 64, 0.0, 1.0, 44, center), metal)

	# Lower rim: rolled edge plus the vervelles that hold the aventail.
	if p.get("rim", false):
		_add(root, _edge_tube(skull, 0.0, TAU, 0.0, 64, center, 0.004), metal)
	for k in 30:
		var a := TAU * (k + 0.5) / 30.0
		if p.get("visor", false) and absf(wrapf(a, -PI, PI)) < VA:
			continue
		var pn := K.point_normal(skull, a, 0.07, center)
		rivets.append(K.rivet_xform(pn[0], pn[1], 0.0075))

	if p.get("visor", false):
		var vshape := func(a: float, t: float) -> Vector3:
			return face_point(a, t, p, 0.0)
		var vc := Vector3(0, height * 0.35, -0.03)
		_add(root, K.surface(vshape, -VA, VA, 36, VT0, VT1, 34, vc), metal)
		# Rolled rim round the whole visor
		var rim := PackedVector3Array()
		var n := 24
		for k in n + 1:
			rim.append(_off(vshape, lerpf(-VA, VA, float(k) / n), VT0, vc))
		for k in range(1, n + 1):
			rim.append(_off(vshape, VA, lerpf(VT0, VT1, float(k) / n), vc))
		for k in range(1, n + 1):
			rim.append(_off(vshape, lerpf(VA, -VA, float(k) / n), VT1, vc))
		for k in range(1, n + 1):
			rim.append(_off(vshape, -VA, lerpf(VT1, VT0, float(k) / n), vc))
		_add(root, K.tube(rim, 0.0036, 7), metal)
		# Hinge arms and rosette pivots at the temples
		for s in [-1.0, 1.0]:
			var arm := func(a: float, t: float) -> Vector3:
				return surface_point(a, t, p, 0.005)
			_add(root, K.surface(arm, s * (VA - 0.05), s * 1.6, 6, 0.6, 0.665, 2, center), metal)
			var pv := K.point_normal(skull, s * 1.6, 0.632, center)
			var boss := MeshInstance3D.new()
			boss.mesh = K.rivet_mesh()
			boss.material_override = metal
			boss.transform = K.rivet_xform(pv[0] + pv[1] * 0.004, pv[1], 0.026)
			root.add_child(boss)
			rivets.append(K.rivet_xform(pv[0] + pv[1] * 0.009, pv[1], 0.009))
			for r in 6:
				var ang := TAU * r / 6.0
				var off: Vector3 = K.surface_basis(pv[1], Vector3.ONE) * Vector3(cos(ang), 0.0, sin(ang)) * 0.0105
				rivets.append(K.rivet_xform(pv[0] + pv[1] * 0.006 + off, pv[1], 0.004))
		# Breaths: rows of small holes on both cheeks of the snout
		if p.get("breaths", false):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for s in [-1.0, 1.0]:
				for row in 4:
					for col in 5 - row:
						var a: float = s * (0.16 + col * 0.12 + row * 0.05)
						var t := 0.4 - row * 0.068
						_hole(st, p, a, t, 0.024, 0.012)
			st.generate_normals()
			_add(root, st.commit(), dark)

	_add(root, _slit_mesh(p), dark)

	if p.get("plume", false):
		var plume_mesh := CylinderMesh.new()
		var h := 0.24
		plume_mesh.top_radius = 0.006
		plume_mesh.bottom_radius = 0.03
		plume_mesh.height = h
		var plume := MeshInstance3D.new()
		plume.mesh = plume_mesh
		plume.material_override = cloth
		var basis := Basis(Vector3.RIGHT, -0.9)
		var top := surface_point(0.0, 0.97, p, 0.0)
		plume.transform = Transform3D(basis, top + basis.y * (h * 0.45))
		root.add_child(plume)

	if rivets.size() > 0:
		root.add_child(K.multimesh(rivets, K.rivet_mesh(), metal))
	return root


static func _add(root: Node3D, mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	root.add_child(mi)


static func _off(shape: Callable, a: float, t: float, center: Vector3) -> Vector3:
	var pn := K.point_normal(shape, a, t, center)
	return pn[0] + pn[1] * 0.0012


static func _edge_tube(shape: Callable, a0: float, a1: float, t: float, n: int, center: Vector3, r: float) -> ArrayMesh:
	var pts := PackedVector3Array()
	for k in n + 1:
		var pn := K.point_normal(shape, lerpf(a0, a1, float(k) / n), t, center)
		pts.append(pn[0] + pn[1] * r * 0.3)
	return K.tube(pts, r, 7)


static func _hole(st: SurfaceTool, p: Dictionary, a: float, t: float, ha: float, ht: float) -> void:
	# Small rounded hole: a fan of 10 triangles hugging the face surface.
	var push := 0.0022
	var c := face_point(a, t, p, push)
	var segs := 10
	for k in segs:
		var q0 := TAU * k / segs
		var q1 := TAU * (k + 1) / segs
		var v0 := face_point(a + cos(q0) * ha * 0.5, t + sin(q0) * ht * 0.5, p, push)
		var v1 := face_point(a + cos(q1) * ha * 0.5, t + sin(q1) * ht * 0.5, p, push)
		st.add_vertex(c)
		st.add_vertex(v0)
		st.add_vertex(v1)


## Curved strip hugging the face between angles a0..a1 and heights t0..t1.
static func _strip(st: SurfaceTool, p: Dictionary, a0: float, a1: float, t0: float, t1: float, push: float, steps: int = 10) -> void:
	var tsteps := maxi(1, ceili((t1 - t0) / 0.025))
	for m in tsteps:
		var ta := lerpf(t0, t1, float(m) / tsteps)
		var tb := lerpf(t0, t1, float(m + 1) / tsteps)
		for k in steps:
			var aa := lerpf(a0, a1, float(k) / steps)
			var ab := lerpf(a0, a1, float(k + 1) / steps)
			var v00 := face_point(aa, ta, p, push)
			var v10 := face_point(ab, ta, p, push)
			var v01 := face_point(aa, tb, p, push)
			var v11 := face_point(ab, tb, p, push)
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
	var push := 0.0025
	var gap := th * 2.4

	match style:
		0:
			for k in count:
				var tc := y - k * gap
				_strip(st, p, -w, w, tc - th * 0.5, tc + th * 0.5, push, 18)
		1:
			var bridge := 0.07
			for k in count:
				var tc := y - k * gap
				_strip(st, p, -w, -bridge, tc - th * 0.5, tc + th * 0.5, push, 12)
				_strip(st, p, bridge, w, tc - th * 0.5, tc + th * 0.5, push, 12)
		2:
			_strip(st, p, -w, w, y - th * 0.5, y + th * 0.5, push, 18)
			_strip(st, p, -0.07, 0.07, 0.12, y - th * 0.5, push, 2)
		3:
			var half := (2.0 * w / count) * 0.28
			for k in count:
				var ac := lerpf(-w, w, (k + 0.5) / count)
				_strip(st, p, ac - half, ac + half, y - 0.28, y + th * 0.5, push, 2)

	st.generate_normals()
	return st.commit()
