extends RefCounted
## Procedural mesh toolkit for Armor Craft.
##
## Almost every armour piece is a parametric surface: a Callable shape(a, t)
## returning a point, where `a` usually runs around a limb and `t` along it.
## surface() turns that into a lit, tangent-space mesh with UVs in metres
## (so the mail shader keeps a constant ring size on every piece).


## Smooth Catmull-Rom interpolation through evenly spaced keys over t in 0..1.
static func catmull(t: float, keys: Array) -> float:
	var n := keys.size()
	if n == 1:
		return keys[0]
	var x := clampf(t, 0.0, 1.0) * (n - 1)
	var i := mini(int(floor(x)), n - 2)
	var f := x - i
	var p0: float = keys[maxi(i - 1, 0)]
	var p1: float = keys[i]
	var p2: float = keys[i + 1]
	var p3: float = keys[mini(i + 2, n - 1)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * f
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f)


## Builds a mesh from shape(a, t) over a grid.
## `orient` is either a Vector3 (normals face away from that point) or a
## Callable(a, t) -> Vector3 giving the rough outward direction.
static func surface(shape: Callable, a0: float, a1: float, na: int,
		t0: float, t1: float, nt: int, orient) -> ArrayMesh:
	var cols := na + 1
	var rows := nt + 1
	var wrap := absf(absf(a1 - a0) - TAU) < 0.001
	var pts := PackedVector3Array()
	pts.resize(cols * rows)
	for i in rows:
		var t := lerpf(t0, t1, float(i) / nt)
		for j in cols:
			pts[i * cols + j] = shape.call(lerpf(a0, a1, float(j) / na), t)

	var nrm := PackedVector3Array()
	nrm.resize(pts.size())
	var tan := PackedFloat32Array()
	tan.resize(pts.size() * 4)
	var vote := 0.0
	for i in rows:
		var t := lerpf(t0, t1, float(i) / nt)
		for j in cols:
			var k := i * cols + j
			var jl := j - 1
			var jr := j + 1
			if wrap:
				if jl < 0:
					jl = cols - 2
				if jr >= cols:
					jr = 1
			else:
				jl = maxi(jl, 0)
				jr = mini(jr, cols - 1)
			var ib := maxi(i - 1, 0)
			var it := mini(i + 1, rows - 1)
			var da := pts[i * cols + jr] - pts[i * cols + jl]
			var dt := pts[it * cols + j] - pts[ib * cols + j]
			if da.length_squared() < 1e-12:
				# Collapsed row (pole / tip): borrow the neighbouring row's direction.
				var nr := i + 1 if i == 0 else i - 1
				da = pts[nr * cols + jr] - pts[nr * cols + jl]
			var n := da.cross(dt)
			if n.length_squared() < 1e-20:
				n = Vector3.UP
			n = n.normalized()
			nrm[k] = n
			var tg := da.normalized() if da.length_squared() > 1e-12 else dt.normalized()
			tan[k * 4] = tg.x
			tan[k * 4 + 1] = tg.y
			tan[k * 4 + 2] = tg.z
			tan[k * 4 + 3] = 1.0
			var ref: Vector3
			if orient is Callable:
				ref = orient.call(lerpf(a0, a1, float(j) / na), t)
			else:
				ref = pts[k] - (orient as Vector3)
			vote += n.dot(ref)
	if vote < 0.0:
		for k in nrm.size():
			nrm[k] = -nrm[k]

	# UVs in metres, measured along the middle row / column.
	var us := PackedFloat32Array()
	us.resize(cols)
	var vs := PackedFloat32Array()
	vs.resize(rows)
	var mr := rows / 2
	var mc := cols / 2
	for j in range(1, cols):
		us[j] = us[j - 1] + pts[mr * cols + j].distance_to(pts[mr * cols + j - 1])
	for i in range(1, rows):
		vs[i] = vs[i - 1] + pts[i * cols + mc].distance_to(pts[(i - 1) * cols + mc])
	var uv := PackedVector2Array()
	uv.resize(pts.size())
	for i in rows:
		for j in cols:
			uv[i * cols + j] = Vector2(us[j], vs[i])

	# Triangles, wound so Godot's front face matches our normals.
	var idx := PackedInt32Array()
	for i in nt:
		for j in na:
			var v00 := i * cols + j
			var v10 := v00 + 1
			var v01 := v00 + cols
			var v11 := v01 + 1
			var want := nrm[v00] + nrm[v11] + nrm[v10] + nrm[v01]
			var g := (pts[v10] - pts[v00]).cross(pts[v01] - pts[v00]) \
				+ (pts[v11] - pts[v10]).cross(pts[v01] - pts[v10])
			if g.dot(want) >= 0.0:
				idx.append_array([v00, v01, v10, v10, v01, v11])
			else:
				idx.append_array([v00, v10, v01, v10, v11, v01])

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TANGENT] = tan
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## A round tube following a polyline (rolled edges, finger lames, straps).
static func tube(points: PackedVector3Array, radius: float, sides: int = 7) -> ArrayMesh:
	var n := points.size()
	var tans := PackedVector3Array()
	tans.resize(n)
	for i in n:
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, n - 1)]
		tans[i] = (b - a).normalized()
	var ns := PackedVector3Array()
	ns.resize(n)
	var bs := PackedVector3Array()
	bs.resize(n)
	var ref := Vector3.UP if absf(tans[0].y) < 0.9 else Vector3.RIGHT
	ns[0] = tans[0].cross(ref).normalized()
	bs[0] = tans[0].cross(ns[0])
	for i in range(1, n):
		var nn := ns[i - 1] - tans[i] * ns[i - 1].dot(tans[i])
		if nn.length_squared() < 1e-10:
			nn = ns[i - 1]
		ns[i] = nn.normalized()
		bs[i] = tans[i].cross(ns[i])
	var shape := func(a: float, t: float) -> Vector3:
		var i := clampi(int(round(t)), 0, n - 1)
		return points[i] + (ns[i] * cos(a) + bs[i] * sin(a)) * radius
	var orient := func(a: float, t: float) -> Vector3:
		var i := clampi(int(round(t)), 0, n - 1)
		return ns[i] * cos(a) + bs[i] * sin(a)
	return surface(shape, 0.0, TAU, sides, 0.0, float(n - 1), n - 1, orient)


## Position and outward normal of shape at (a, t).
static func point_normal(shape: Callable, a: float, t: float, center: Vector3) -> Array:
	var e := 0.003
	var p: Vector3 = shape.call(a, t)
	var da: Vector3 = shape.call(a + e, t) - shape.call(a - e, t)
	var dt: Vector3 = shape.call(a, t + e) - shape.call(a, t - e)
	var n := da.cross(dt)
	if n.length_squared() < 1e-20:
		n = p - center
	n = n.normalized()
	if n.dot(p - center) < 0.0:
		n = -n
	return [p, n]


## Basis whose Y axis is `n`, scaled by s.
static func surface_basis(n: Vector3, s: Vector3) -> Basis:
	var y := n.normalized()
	var x := y.cross(Vector3.UP) if absf(y.y) < 0.95 else y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	return Basis(x * s.x, y * s.y, z * s.z)


static func multimesh(xforms: Array, mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi


static var _rivet_mesh: SphereMesh

static func rivet_mesh() -> SphereMesh:
	if _rivet_mesh == null:
		_rivet_mesh = SphereMesh.new()
		_rivet_mesh.radius = 0.5
		_rivet_mesh.height = 1.0
		_rivet_mesh.radial_segments = 8
		_rivet_mesh.rings = 4
	return _rivet_mesh


## Transform for a domed rivet head of diameter d sitting on the surface.
static func rivet_xform(p: Vector3, n: Vector3, d: float) -> Transform3D:
	return Transform3D(surface_basis(n, Vector3(d, d * 0.55, d)), p + n * d * 0.08)
