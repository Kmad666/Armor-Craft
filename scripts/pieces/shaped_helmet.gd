extends Node3D
## A helmet generated live from two shape controls, so the player can
## stretch and skew it directly:
##
##   stretch  0 .. MAX_STRETCH metres: walls extend down from the brow rim
##            (the whole shell widens a little once it passes the eyes so it
##            clears the face)
##   crown   -1 .. 1: -1 = flat bucket-helm top, 0 = round dome, 1 = pointed
##
## Base size is the spangenhelm fitted to the mannequin's head (>= 3 mm
## clearance). Origin = Socket_Head (centre of the head at eye level).
## Axes: +Y up, +Z toward the face.

signal shape_changed

const RIM := 0.028          # rim height above eye level
const RX := 0.091           # half-width
const RZ := 0.109           # half-depth (front to back)
const HEIGHT := 0.112       # dome height
const THICK := 0.002        # plate thickness
const MAX_STRETCH := 0.15   # down to the chin
const SEG := 72             # around
const DOME_RINGS := 40
const WALL_RINGS := 10

var stretch := 0.0
var crown := 0.0

## Holes punched through the shell. Each is pinned to the surface by its
## angle around the helmet and its height, so it rides along when the shape
## is stretched or skewed: {a, y, shape (0 round, 1 slot, 2 cross), w, h, group}
var holes: Array = []
const MAX_HOLES := 64
var _group := 0
var _mat: ShaderMaterial

var _mi: MeshInstance3D
var _overlay: ShaderMaterial


func setup(mat: ShaderMaterial) -> void:
	_mat = mat
	_mi = MeshInstance3D.new()
	_mi.name = "Shell"
	_mi.material_override = mat
	add_child(_mi)
	_overlay = ShaderMaterial.new()
	_overlay.shader = preload("res://shaders/select_glow.gdshader")
	rebuild()


func set_shape(new_stretch: float, new_crown: float) -> void:
	new_stretch = clampf(new_stretch, 0.0, MAX_STRETCH)
	new_crown = clampf(new_crown, -1.0, 1.0)
	if is_equal_approx(new_stretch, stretch) and is_equal_approx(new_crown, crown):
		return
	stretch = new_stretch
	crown = new_crown
	rebuild()
	shape_changed.emit()


func set_selected(on: bool) -> void:
	if _mi:
		_mi.material_overlay = _overlay if on else null


# --------------------------------------------------------------------------
# Shape maths
# --------------------------------------------------------------------------

## Extra width once the walls pass the eyes, so the face fits inside.
func grow() -> float:
	return 1.0 + 0.2 * smoothstep(0.01, 0.05, stretch)


func dome_height() -> float:
	return HEIGHT * (1.0 + 0.45 * maxf(crown, 0.0))


func bottom_y() -> float:
	return RIM - stretch


func top_y() -> float:
	return RIM + dome_height()


## Profile at angle theta (0 = rim, PI/2 = top): (radius factor, height factor).
func _profile(theta: float) -> Vector2:
	var c := cos(theta)
	var s := sin(theta)
	if crown <= 0.0:
		# superellipse: n = 2 is a circle, large n is a flat top with straight sides
		var n := 2.0 + (-crown) * 10.0
		return Vector2(pow(maxf(c, 0.0), 2.0 / n), pow(maxf(s, 0.0), 2.0 / n))
	# ogive (gothic arch): k = 1 is a circle, larger k is more pointed
	var k := 1.0 + 2.0 * crown
	var rho := (1.0 + k * k) * 0.5
	return Vector2(maxf(0.0, sqrt(maxf(0.0, rho * rho - k * k * s * s)) - (rho - 1.0)), s)


## Radius factor at height fraction v (0 = rim, 1 = top), for hit testing.
func _radius_at(v: float) -> float:
	v = clampf(v, 0.0, 1.0)
	if crown <= 0.0:
		var n := 2.0 + (-crown) * 10.0
		return pow(maxf(0.0, 1.0 - pow(v, n)), 1.0 / n)
	var k := 1.0 + 2.0 * crown
	var rho := (1.0 + k * k) * 0.5
	return maxf(0.0, sqrt(maxf(0.0, rho * rho - k * k * v * v)) - (rho - 1.0))


## Is a point (helmet-local) inside the outer shell?
func contains(p: Vector3) -> bool:
	if p.y < bottom_y() or p.y > top_y():
		return false
	var g := grow()
	var f := 1.0 if p.y < RIM else _radius_at((p.y - RIM) / dome_height())
	var a := RX * g * f
	var b := RZ * g * f
	if a < 1e-5:
		return false
	return (p.x / a) * (p.x / a) + (p.z / b) * (p.z / b) <= 1.0


## Ray in global space -> hit?
func ray_hits(origin: Vector3, dir: Vector3) -> bool:
	return hit_local(origin, dir) != null


## First point (helmet-local) where a global ray enters the shell, or null.
func hit_local(origin: Vector3, dir: Vector3):
	var inv := global_transform.affine_inverse()
	var o := inv * origin
	var d := (inv.basis * dir).normalized()
	# start just before the helmet's bounding sphere
	var t := maxf(0.0, -o.dot(d) - 0.35)
	var t_end := t + 0.8
	while t < t_end:
		var p := o + d * t
		if contains(p):
			# refine to the surface
			var lo := t - 0.002
			var hi := t
			for i in 10:
				var m := (lo + hi) * 0.5
				if contains(o + d * m):
					hi = m
				else:
					lo = m
			return o + d * hi
		t += 0.002
	return null


# --------------------------------------------------------------------------
# Holes
# --------------------------------------------------------------------------

## Surface point and outward normal at angle a (0 = front) and height y.
func surface_at(a: float, y: float) -> Array:
	var p := _surf(a, y)
	var e := 0.002
	var n := (_surf(a + e, y) - _surf(a - e, y)).cross(_surf(a, y + e) - _surf(a, y - e))
	if n.length_squared() < 1e-14:
		n = Vector3.UP
	n = n.normalized()
	if n.dot(Vector3(p.x, maxf(p.y - RIM, 0.0) * 0.5, p.z)) < 0.0:
		n = -n
	return [p, n]


func _surf(a: float, y: float) -> Vector3:
	var g := grow()
	var f := 1.0 if y < RIM else _radius_at((y - RIM) / dome_height())
	return Vector3(sin(a) * RX * g * f, y, cos(a) * RZ * g * f)


static func angle_of(p: Vector3) -> float:
	return atan2(p.x, p.z)


## Adds a hole at helmet-local point p (and its mirror twin across the centre).
func add_hole(p: Vector3, shape: int, w: float, h: float, mirror: bool) -> void:
	_group += 1
	_add_pair(angle_of(p), p.y, shape, w, h, mirror)
	_push_holes()


## Adds a set of holes as one undo step: entries are [a, y, shape, w, h].
func add_hole_set(entries: Array, mirror: bool) -> void:
	_group += 1
	for e in entries:
		_add_pair(e[0], e[1], e[2], e[3], e[4], mirror)
	_push_holes()


func _add_pair(a: float, y: float, shape: int, w: float, h: float, mirror: bool) -> void:
	_append_hole(a, y, shape, w, h)
	if mirror and absf(a) * RX > w * 0.55:
		_append_hole(-a, y, shape, w, h)


func _append_hole(a: float, y: float, shape: int, w: float, h: float) -> void:
	if holes.size() >= MAX_HOLES:
		return
	holes.append({"a": a, "y": y, "shape": shape, "w": w, "h": h, "group": _group})


## Removes the hole (and its mirror twin) under helmet-local point p.
func remove_hole_at(p: Vector3) -> bool:
	var a := angle_of(p)
	for i in range(holes.size() - 1, -1, -1):
		var ho: Dictionary = holes[i]
		var sp: Vector3 = surface_at(ho["a"], ho["y"])[0]
		var reach := maxf(float(ho["w"]), float(ho["h"])) * 0.5 + 0.004
		if sp.distance_to(p) < reach:
			var grp: int = ho["group"]
			holes = holes.filter(func(x): return x["group"] != grp)
			_push_holes()
			return true
	return false


func undo_hole() -> void:
	if holes.is_empty():
		return
	var grp: int = holes[-1]["group"]
	holes = holes.filter(func(x): return x["group"] != grp)
	_push_holes()


func clear_holes() -> void:
	holes.clear()
	_push_holes()


func _hole_uniforms(a: float, y: float, shape: int, w: float, h: float) -> Array:
	var sn := surface_at(a, y)
	var p: Vector3 = sn[0]
	var n: Vector3 = sn[1]
	return [Vector4(p.x, p.y, p.z, shape), Vector4(n.x, n.y, n.z, 0.0), Vector4(w, h, 0.0, 0.0)]


func _push_holes() -> void:
	if _mat == null:
		return
	var pos := []
	var nrm := []
	var size := []
	for ho in holes:
		var y: float = ho["y"]
		if y < bottom_y() - 0.004 or y > top_y():
			continue  # not on the shell at the current stretch
		var u := _hole_uniforms(ho["a"], y, ho["shape"], ho["w"], ho["h"])
		pos.append(u[0])
		nrm.append(u[1])
		size.append(u[2])
	var count := pos.size()
	while pos.size() < MAX_HOLES:
		pos.append(Vector4.ZERO)
		nrm.append(Vector4(0, 1, 0, 0))
		size.append(Vector4.ZERO)
	_mat.set_shader_parameter("hole_count", count)
	_mat.set_shader_parameter("hole_pos", pos)
	_mat.set_shader_parameter("hole_nrm", nrm)
	_mat.set_shader_parameter("hole_size", size)


## Outline where the next hole would go (p = null hides it).
func set_preview(p, shape: int, w: float, h: float) -> void:
	if _mat == null:
		return
	if p == null:
		_mat.set_shader_parameter("preview_on", false)
		return
	var u := _hole_uniforms(angle_of(p), p.y, shape, w, h)
	_mat.set_shader_parameter("preview_on", true)
	_mat.set_shader_parameter("preview_pos", u[0])
	_mat.set_shader_parameter("preview_nrm", u[1])
	_mat.set_shader_parameter("preview_size", u[2])


# --------------------------------------------------------------------------
# Mesh
# --------------------------------------------------------------------------

## Rings bottom -> top as [y, radius factor]; the top ring collapses to a point.
func _rings(inset: float) -> Array:
	var rings := []
	var g := grow()
	var h := dome_height() - inset
	if stretch > 0.0005:
		for i in WALL_RINGS:
			rings.append([RIM - stretch * (1.0 - float(i) / WALL_RINGS), 1.0])
	for i in DOME_RINGS + 1:
		var pr := _profile(PI * 0.5 * float(i) / DOME_RINGS)
		rings.append([RIM + pr.y * h, pr.x])
	return [rings, g]


func _ring_points(rings: Array, g: float, inset: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for r in rings:
		var y: float = r[0]
		var f: float = r[1]
		var a := maxf(0.0, (RX * g - inset) * f)
		var b := maxf(0.0, (RZ * g - inset) * f)
		for j in SEG:
			var ang := TAU * j / SEG
			pts.append(Vector3(sin(ang) * a, y, cos(ang) * b))
	return pts


func rebuild() -> void:
	var outer := _rings(0.0)
	var inner := _rings(THICK)
	var po := _ring_points(outer[0], outer[1], 0.0)
	var pi := _ring_points(inner[0], inner[1], THICK)
	var n_o: int = outer[0].size()
	var n_i: int = inner[0].size()

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var mid := Vector3(0.0, RIM + dome_height() * 0.3, 0.0)

	_add_surface(po, n_o, verts, norms, idx, mid, true)
	_add_surface(pi, n_i, verts, norms, idx, mid, false)

	# Bottom edge: band joining the outer and inner rims
	var base := verts.size()
	for j in SEG:
		verts.append(po[j])
		norms.append(Vector3.DOWN)
	for j in SEG:
		verts.append(pi[j])
		norms.append(Vector3.DOWN)
	for j in SEG:
		var j2 := (j + 1) % SEG
		_quad(idx, verts, base + j, base + j2, base + SEG + j2, base + SEG + j, Vector3.DOWN)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mi.mesh = mesh
	_push_holes()


func _add_surface(pts: PackedVector3Array, rows: int, verts: PackedVector3Array,
		norms: PackedVector3Array, idx: PackedInt32Array, mid: Vector3, outward: bool) -> void:
	var base := verts.size()
	for i in rows:
		for j in SEG:
			var p := pts[i * SEG + j]
			var jl := (j - 1 + SEG) % SEG
			var jr := (j + 1) % SEG
			var ib := maxi(i - 1, 0)
			var it := mini(i + 1, rows - 1)
			var da := pts[i * SEG + jr] - pts[i * SEG + jl]
			var dv := pts[it * SEG + j] - pts[ib * SEG + j]
			var n := da.cross(dv)
			if n.length_squared() < 1e-14:
				n = Vector3.UP
			n = n.normalized()
			var away := p - mid
			if (n.dot(away) < 0.0) == outward:
				n = -n
			verts.append(p)
			norms.append(n)
	for i in rows - 1:
		for j in SEG:
			var j2 := (j + 1) % SEG
			var a := base + i * SEG + j
			var b := base + i * SEG + j2
			var c := base + (i + 1) * SEG + j2
			var d := base + (i + 1) * SEG + j
			_quad(idx, verts, a, b, c, d, norms[a] + norms[c])


## Adds a quad wound so its face matches `want`.
func _quad(idx: PackedInt32Array, verts: PackedVector3Array, a: int, b: int, c: int, d: int, want: Vector3) -> void:
	var g := (verts[b] - verts[a]).cross(verts[d] - verts[a]) + (verts[c] - verts[b]).cross(verts[d] - verts[b])
	# Godot treats clockwise (seen from the front) as front-facing
	if g.dot(want) < 0.0:
		idx.append_array([a, b, c, a, c, d])
	else:
		idx.append_array([a, c, b, a, d, c])
