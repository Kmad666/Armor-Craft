extends Node3D
## Gothic cuirass, built to fit the wooden mannequin (measurements.json).
##
## Two sections, kept as separate pieces:
##   mid section    Breastplate (fluted, central ridge, scooped neck, deep
##                  armholes) + plain Backplate, rolled edges, shoulder straps
##   bottom section Fauld: overlapping lames hanging from the waist, each
##                  stepping out a little further, the last one notched
## A leather Belt with a brass buckle marks the division between them.
##
## Axes: +Y up, +Z toward the front. Angle a = 0 is the front centre.

const K := preload("res://scripts/mesh_kit.gd")

const BREAST_BOTTOM := 1.125
const SIDE_CLEAR := 0.014    # padding over the arming doublet at the sides
const FRONT_CLEAR := 0.022   # and at the front / back
const BREAST_ARC := 1.75     # breastplate wraps this far round each side (radians)
const FAULD_ARC := 1.95
const LAME_DROP := 0.045     # vertical step between lames
const LAME_HEIGHT := 0.058

var lames := 4
var fluting := true

var metal: Material
var leather: Material
var brass: Material
var m: Dictionary = {}
var pieces := {}  # name -> Node3D

var _rivets: Array = []


func setup(mats: Dictionary, measurements: Dictionary, chest_joint: Node3D, pelvis_joint: Node3D) -> void:
	metal = mats["metal"]
	leather = mats["leather"]
	brass = mats["brass"]
	m = measurements
	for n in ["Breastplate", "Backplate", "Belt"]:
		pieces[n] = _piece(n, chest_joint)
	pieces["Fauld"] = _piece("Fauld", pelvis_joint)
	rebuild_all()


func _piece(piece_name: String, joint: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = piece_name
	joint.add_child(n)
	# pieces are modelled in mannequin space; cancel the joint's offset
	n.global_transform = Transform3D.IDENTITY
	return n


func rebuild_all() -> void:
	_build_breastplate()
	_build_backplate()
	_build_fauld()
	_build_belt()


func set_lames(n: int) -> void:
	lames = clampi(n, 1, 7)
	_build_fauld()


func set_fluting(on: bool) -> void:
	fluting = on
	_build_breastplate()


# ==========================================================================
# Body shape (mirrors art/blender/build_mannequin.py) and plate radii
# ==========================================================================

static func _hermite(z: float, zs: Array, vs: Array) -> float:
	if zs[0] > zs[-1]:
		zs = zs.duplicate()
		vs = vs.duplicate()
		zs.reverse()
		vs.reverse()
	var n := zs.size()
	if z <= zs[0]:
		return vs[0]
	if z >= zs[n - 1]:
		return vs[n - 1]
	for i in n - 1:
		var z0: float = zs[i]
		var z1: float = zs[i + 1]
		if z <= z1:
			var t0: float = (vs[mini(i + 1, n - 1)] - vs[maxi(i - 1, 0)]) / (zs[mini(i + 1, n - 1)] - zs[maxi(i - 1, 0)])
			var t1: float = (vs[mini(i + 2, n - 1)] - vs[i]) / (zs[mini(i + 2, n - 1)] - zs[i])
			var h := z1 - z0
			var t := (z - z0) / h
			var t2 := t * t
			var t3 := t2 * t
			return (2 * t3 - 3 * t2 + 1) * vs[i] + (t3 - 2 * t2 + t) * h * t0 \
				+ (-2 * t3 + 3 * t2) * vs[i + 1] + (t3 - t2) * h * t1
	return vs[n - 1]


## Mannequin torso at height y: (half-width, half-depth, forward offset).
func body(y: float) -> Vector3:
	var cw: float = m["chest_width"] * 0.5
	var cd: float = m["chest_depth"] * 0.5
	var ww: float = m["waist_width"] * 0.5
	var wd: float = m["waist_depth"] * 0.5
	var hw: float = m["hip_width"] * 0.5
	var hd: float = m["hip_depth"] * 0.5
	var chest_base: float = m["waist_height"] + 0.025
	var top: float = m["neck_base_height"] + 0.005
	var arm: float = m["armpit_height"]
	if y >= chest_base:
		var zs := [chest_base, arm - 0.07, arm, m["shoulder_height"] - 0.02, top - 0.04, top]
		return Vector3(
			_hermite(y, zs, [ww * 1.02, cw * 0.97, cw, cw * 0.93, 0.105, 0.062]),
			_hermite(y, zs, [wd, cd * 0.96, cd, cd * 0.88, 0.075, 0.058]),
			_hermite(y, zs, [0.0, 0.008, 0.012, 0.004, -0.01, -0.006]))
	var pel_top: float = m["waist_height"] - 0.03
	var crotch: float = m["crotch_height"]
	var hip: float = m["hip_height"]
	var zs2 := [pel_top, hip + 0.06, hip, crotch + 0.03, crotch]
	var p := Vector3(
		_hermite(y, zs2, [ww * 1.02, hw * 0.94, hw, hw * 0.93, hw * 0.62]),
		_hermite(y, zs2, [wd, hd * 0.95, hd, hd * 0.86, hd * 0.55]),
		_hermite(y, zs2, [0.0, 0.004, 0.0, -0.004, 0.0]))
	if y > pel_top:
		# waist ball between pelvis and chest
		var k := smoothstep(pel_top, chest_base, y)
		p = p.lerp(Vector3(ww * 1.02, wd, 0.0), k)
	return p


## Plate cross-section at height y: (half-width, front depth, back depth).
func plate(y: float, extra: float = 0.0) -> Vector3:
	var b := body(y)
	var rx := b.x + SIDE_CLEAR + extra
	var rf := b.y + b.z + FRONT_CLEAR + extra
	var rb := b.y - b.z + FRONT_CLEAR * 0.8 + extra
	return Vector3(rx, rf, rb)


func ring_point(a: float, y: float, r: Vector3) -> Vector3:
	var c := cos(a)
	return Vector3(sin(a) * r.x, y, c * (r.y if c >= 0.0 else r.z))


func ring_normal(a: float, r: Vector3) -> Vector3:
	var c := cos(a)
	var d := r.y if c >= 0.0 else r.z
	return Vector3(sin(a) / r.x, 0.0, c / d).normalized()


# ==========================================================================
# Breastplate (mid section)
# ==========================================================================

## Top outline of the breastplate: scooped neck, shoulder points, armholes.
func breast_top(a: float) -> float:
	var top: float = m["neck_base_height"]
	var arm: float = m["armpit_height"]
	return _hermite(absf(a), [0.0, 0.3, 0.55, 0.78, 1.05, 1.35, BREAST_ARC],
		[top - 0.037, top - 0.027, top + 0.0, top - 0.01, top - 0.1, arm + 0.005, arm - 0.03])


## Raised flutes: a central ridge plus two sets of chevron flutes sweeping
## down from the armholes to the centre.
func flute(x: float, y: float) -> float:
	if not fluting:
		return 0.0
	var ax := absf(x)
	var h := 0.0
	# medial ridge
	h += 0.0042 * exp(-pow(x / 0.0085, 2.0)) * smoothstep(1.14, 1.22, y) * (1.0 - smoothstep(1.43, 1.47, y))
	# chevron flutes
	var fade := smoothstep(0.006, 0.02, ax) * (1.0 - smoothstep(0.115, 0.14, ax))
	if fade > 0.0:
		var arm: float = m["armpit_height"]
		for c in [arm - 0.008, arm + 0.006, arm + 0.02, arm - 0.088, arm - 0.074, arm - 0.06]:
			var yc: float = c + 0.62 * ax - 1.3 * ax * ax
			h += 0.0021 * exp(-pow((y - yc) / 0.0032, 2.0)) * fade
	return h


func _breast_shape(a: float, t: float) -> Vector3:
	var y := lerpf(BREAST_BOTTOM, breast_top(a), t)
	var r := plate(y)
	var p := ring_point(a, y, r)
	return p + ring_normal(a, r) * flute(p.x, y)


func _build_breastplate() -> void:
	var root: Node3D = pieces["Breastplate"]
	_clear(root)
	_rivets = []
	var shape := Callable(self, "_breast_shape")
	var centre := Vector3(0, 1.3, -0.12)
	var res := 150 if fluting else 60
	_add_mesh(root, K.surface(shape, -BREAST_ARC, BREAST_ARC, res, 0.0, 1.0, int(res * 1.2), centre), metal)
	_edge(root, shape, -BREAST_ARC, BREAST_ARC, 1.0, 90, centre, 0.0034)
	_edge(root, shape, -BREAST_ARC, BREAST_ARC, 0.0, 70, centre, 0.0028)
	for s in [-1.0, 1.0]:
		_edge_a(root, shape, s * BREAST_ARC, 0.0, 1.0, 20, centre, 0.0028)
		# strap rivets at the shoulder points and side hinge rivets
		_rivet(shape, s * 0.55, 0.93, centre, 0.008)
		_rivet(shape, s * 1.6, 0.25, centre, 0.007)
		_rivet(shape, s * 1.6, 0.6, centre, 0.007)
	_rivet(shape, 0.0, 0.06, centre, 0.008)
	_flush_rivets(root)


# ==========================================================================
# Backplate
# ==========================================================================

func back_top(a: float) -> float:
	# a measured from the back centre
	var top: float = m["neck_base_height"]
	var arm: float = m["armpit_height"]
	return _hermite(absf(a), [0.0, 0.45, 0.7, 1.05, 1.5],
		[top - 0.012, top + 0.008, top - 0.004, top - 0.09, arm - 0.03])


func _back_shape(a: float, t: float) -> Vector3:
	var y := lerpf(BREAST_BOTTOM, back_top(a), t)
	return ring_point(PI + a, y, plate(y, -0.003))


func _build_backplate() -> void:
	var root: Node3D = pieces["Backplate"]
	_clear(root)
	_rivets = []
	var shape := Callable(self, "_back_shape")
	var centre := Vector3(0, 1.3, 0.12)
	var arc := PI - BREAST_ARC + 0.18
	_add_mesh(root, K.surface(shape, -arc, arc, 56, 0.0, 1.0, 50, centre), metal)
	_edge(root, shape, -arc, arc, 1.0, 70, centre, 0.0034)
	_edge(root, shape, -arc, arc, 0.0, 50, centre, 0.0028)
	for s in [-1.0, 1.0]:
		_edge_a(root, shape, s * arc, 0.0, 1.0, 16, centre, 0.0026)
		_rivet(shape, s * 0.5, 0.93, centre, 0.008)
	_flush_rivets(root)


# ==========================================================================
# Fauld (bottom section)
# ==========================================================================

func _lame_top(k: int) -> float:
	return BREAST_BOTTOM + 0.01 - k * LAME_DROP


## Lame k: starts tucked under the piece above and flares outward as it drops,
## so each lame overlaps the next one down.
func _lame_shape(k: int, a: float, t: float) -> Vector3:
	# lames curve up toward the hips so the legs can move
	var rise := 0.028 * (1.0 - cos(a)) * (0.4 + 0.2 * k)
	var y0 := _lame_top(k) + rise
	var y1 := y0 - LAME_HEIGHT
	if k == lames - 1:
		# notch in the bottom lame at the centre front
		y1 += 0.02 * exp(-pow(a / 0.22, 2.0))
	var y := lerpf(y0, y1, t)
	var r := plate(y, -0.004 + 0.003 * k + 0.25 * (y0 - y))
	return ring_point(a, y, r)


func _build_fauld() -> void:
	var root: Node3D = pieces["Fauld"]
	_clear(root)
	_rivets = []
	var centre := Vector3(0, 1.0, -0.12)
	for k in lames:
		var shape := func(a: float, t: float) -> Vector3: return _lame_shape(k, a, t)
		_add_mesh(root, K.surface(shape, -FAULD_ARC, FAULD_ARC, 90, 0.0, 1.0, 10, centre), metal)
		_edge(root, shape, -FAULD_ARC, FAULD_ARC, 1.0, 90, centre, 0.0026)
		for s in [-1.0, 1.0]:
			_edge_a(root, shape, s * FAULD_ARC, 0.0, 1.0, 6, centre, 0.0022)
			_rivet(shape, s * 1.75, 0.3, centre, 0.0065)
		_rivet(shape, 0.0, 0.3, centre, 0.0065)
	_flush_rivets(root)


# ==========================================================================
# Belt and shoulder straps (leather + brass)
# ==========================================================================

func _build_belt() -> void:
	var root: Node3D = pieces["Belt"]
	_clear(root)
	var yb := BREAST_BOTTOM - 0.004
	var band := func(a: float, t: float) -> Vector3:
		var y := lerpf(yb - 0.013, yb + 0.013, t)
		return ring_point(a, y, plate(y, 0.0045))
	_add_mesh(root, K.surface(band, -PI, PI, 96, 0.0, 1.0, 2, Vector3(0, yb, 0)), leather)
	# buckle at the front
	var pf := ring_point(0.0, yb, plate(yb, 0.008))
	var buckle := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.011
	tm.outer_radius = 0.016
	buckle.mesh = tm
	buckle.material_override = brass
	buckle.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.25, 1.0, 1.0)), pf)
	root.add_child(buckle)
	var tongue := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.026, 0.003, 0.003)
	tongue.mesh = bm
	tongue.material_override = brass
	tongue.position = pf + Vector3(0, 0, 0.002)
	root.add_child(tongue)
	# hanging tail of the belt
	var tail := func(a: float, t: float) -> Vector3:
		var y := lerpf(yb, yb - 0.075, t)
		return ring_point(a, y, plate(y, 0.006 + 0.25 * (yb - y)))
	_add_mesh(root, K.surface(tail, 0.05, 0.16, 3, 0.0, 1.0, 6, Vector3(0, yb, 0)), leather)

	# shoulder straps from the breastplate's shoulder points over to the back
	for s in [-1.0, 1.0]:
		var f := _breast_shape(s * 0.55, 1.0)
		var b := _back_shape(s * 0.5, 1.0)
		var over := Vector3((f.x + b.x) * 0.5 * 1.05, maxf(f.y, b.y) + 0.022, (f.z + b.z) * 0.5)
		var pts := PackedVector3Array()
		for i in 13:
			var t := i / 12.0
			var q := f.lerp(over, t).lerp(over.lerp(b, t), t)  # quadratic curve
			pts.append(q)
		_add_mesh(root, _ribbon(pts, 0.022, 0.003), leather)


## Flat strap following a polyline.
func _ribbon(pts: PackedVector3Array, width: float, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in n:
		var tan := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var outward := Vector3(pts[i].x, 0.0, 0.0).normalized() if absf(pts[i].x) > 1e-4 else Vector3.RIGHT
		var side := tan.cross(outward).normalized()
		var up := side.cross(tan).normalized()
		var l := pts[i] - side * width * 0.5 + up * thick
		var r := pts[i] + side * width * 0.5 + up * thick
		if i > 0:
			st.add_vertex(prev_l)
			st.add_vertex(l)
			st.add_vertex(prev_r)
			st.add_vertex(prev_r)
			st.add_vertex(l)
			st.add_vertex(r)
		prev_l = l
		prev_r = r
	st.generate_normals()
	return st.commit()


# ==========================================================================
# Helpers
# ==========================================================================

func _clear(root: Node3D) -> void:
	for c in root.get_children():
		c.queue_free()


func _add_mesh(root: Node3D, mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	root.add_child(mi)


func _edge(root: Node3D, shape: Callable, a0: float, a1: float, t: float, n: int, centre: Vector3, r: float) -> void:
	var pts := PackedVector3Array()
	for k in n + 1:
		var pn := K.point_normal(shape, lerpf(a0, a1, float(k) / n), t, centre)
		pts.append(pn[0] + pn[1] * r * 0.35)
	_add_mesh(root, K.tube(pts, r, 7), metal)


func _edge_a(root: Node3D, shape: Callable, a: float, t0: float, t1: float, n: int, centre: Vector3, r: float) -> void:
	var pts := PackedVector3Array()
	for k in n + 1:
		var pn := K.point_normal(shape, a, lerpf(t0, t1, float(k) / n), centre)
		pts.append(pn[0] + pn[1] * r * 0.35)
	_add_mesh(root, K.tube(pts, r, 7), metal)


func _rivet(shape: Callable, a: float, t: float, centre: Vector3, d: float) -> void:
	var pn := K.point_normal(shape, a, t, centre)
	_rivets.append(K.rivet_xform(pn[0], pn[1], d))


func _flush_rivets(root: Node3D) -> void:
	if _rivets.size() > 0:
		root.add_child(K.multimesh(_rivets, K.rivet_mesh(), metal))
	_rivets = []
