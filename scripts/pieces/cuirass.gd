extends Node3D
## Munitions-style cuirass (plain breast and back), fitted to the wooden
## mannequin (measurements.json). Two sections, kept as separate pieces:
##
##   mid section    Breastplate: plain, sharp medial crease, shallow neck,
##                  deep armholes with riveted gusset plates, lower edge
##                  pointed at the centre front; side clasp and hinges.
##                  Backplate: V-shaped yoke line across the shoulders,
##                  spine ridge, armhole gussets, higher shoulders.
##   bottom section Fauld: flared lame(s) all the way round below the plates.
##   Belt           leather strap on the seam between the two, side buckle;
##                  shoulder straps join breast and back.
##
## Barrel-shaped: straight sides from chest to hip, no waist nip.
## Axes: +Y up, +Z toward the front. Angle a = 0 is the front centre;
## positive a turns toward +X (the figure's left).

const K := preload("res://scripts/mesh_kit.gd")

const BREAST_BOTTOM := 1.045  # lower edge at the sides
const POINT_DROP := 0.036     # how far the centre front point dips below that
const SIDE_CLEAR := 0.014     # padding over the arming doublet at the sides
const FRONT_CLEAR := 0.022    # and at the front / back
const BREAST_ARC := 1.65      # breastplate wraps this far round each side (radians)
const BACK_ARC := 1.6         # backplate, measured from the back centre (overlaps the breast)
const GUSSET_W := 0.026
const LAME_H := 0.05
const LAME_STEP := 0.036

var lames := 1
var gussets := true

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
	for n in ["Breastplate", "Backplate", "Shoulders", "Belt"]:
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
	_build_shoulders()
	_build_fauld()
	_build_belt()


func set_lames(n: int) -> void:
	lames = clampi(n, 0, 4)
	_build_fauld()
	_build_belt()


func set_gussets(on: bool) -> void:
	gussets = on
	_build_breastplate()
	_build_backplate()
	_build_shoulders()


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
		var k := smoothstep(pel_top, chest_base, y)
		p = p.lerp(Vector3(ww * 1.02, wd, 0.0), k)
	return p


static func _smax(a: float, b: float, k: float = 0.012) -> float:
	return 0.5 * (a + b + sqrt((a - b) * (a - b) + k * k))


## Plate cross-section at height y: (half-width, front depth, back depth).
## A barrel that never nips in at the waist, but always clears the body.
func plate(y: float, extra: float = 0.0) -> Vector3:
	var b := body(y)
	var hw: float = m["hip_width"] * 0.5
	var cw: float = m["chest_width"] * 0.5
	var cd: float = m["chest_depth"] * 0.5
	var arm: float = m["armpit_height"]
	var ys := [0.98, 1.08, 1.2, arm, arm + 0.12]
	var bx := _hermite(y, ys, [hw + 0.012, hw * 0.98 + 0.006, cw + 0.008, cw + SIDE_CLEAR, cw * 0.86])
	var bf := _hermite(y, ys, [0.14, 0.138, 0.142, cd + 0.03, cd * 0.9])
	var bb := _hermite(y, ys, [0.124, 0.118, 0.12, 0.127, 0.12])
	var rx := _smax(b.x + SIDE_CLEAR, bx)
	var rf := _smax(b.y + b.z + FRONT_CLEAR, bf)
	var rb := _smax(b.y - b.z + FRONT_CLEAR * 0.8, bb)
	return Vector3(rx + extra, rf + extra, rb + extra)


func ring_point(a: float, y: float, r: Vector3) -> Vector3:
	var c := cos(a)
	return Vector3(sin(a) * r.x, y, c * (r.y if c >= 0.0 else r.z))


func ring_normal(a: float, r: Vector3) -> Vector3:
	var c := cos(a)
	var d := r.y if c >= 0.0 else r.z
	return Vector3(sin(a) / r.x, 0.0, c / d).normalized()


## Lower edge of the plates (pointed at the centre front).
func bottom(a: float) -> float:
	var w := absf(wrapf(a, -PI, PI))
	return BREAST_BOTTOM - POINT_DROP * maxf(0.0, 1.0 - w / 0.75) * (1.0 - 0.35 * smoothstep(0.0, 0.08, 0.08 - w))


# ==========================================================================
# Breastplate
# ==========================================================================

## Top outline: shallow neck, narrow shoulder points, deep armholes.
func breast_top(a: float) -> float:
	var top: float = m["neck_base_height"]
	var arm: float = m["armpit_height"]
	return _hermite(absf(a), [0.0, 0.3, 0.5, 0.68, 0.9, 1.15, 1.4, BREAST_ARC],
		[top - 0.032, top - 0.022, top - 0.004, top - 0.006, top - 0.06, arm + 0.03, arm - 0.004, arm - 0.022])


## Sharp medial crease running down the centre of the breastplate.
func crease(x: float, y: float) -> float:
	var fade := 1.0 - smoothstep(m["neck_base_height"] - 0.085, m["neck_base_height"] - 0.045, y)
	return 0.0058 * exp(-absf(x) / 0.019) * fade


func breast_surface(a: float, y: float, push: float = 0.0) -> Vector3:
	var r := plate(y)
	var p := ring_point(a, y, r)
	return p + ring_normal(a, r) * (crease(p.x, y) + push)


func _breast_shape(a: float, t: float) -> Vector3:
	return breast_surface(a, lerpf(bottom(a), breast_top(a), t))


func _build_breastplate() -> void:
	var root: Node3D = pieces["Breastplate"]
	_clear(root)
	_rivets = []
	var shape := Callable(self, "_breast_shape")
	var centre := Vector3(0, 1.25, -0.12)
	_add_mesh(root, K.surface(shape, -BREAST_ARC, BREAST_ARC, 120, 0.0, 1.0, 70, centre), metal)
	# rolled edges: neck (and the armholes too when there are no gussets)
	var a_edge := 0.66 if gussets else BREAST_ARC
	_edge(root, shape, -a_edge, a_edge, 1.0, 70, centre, 0.0036)
	_edge(root, shape, -BREAST_ARC, BREAST_ARC, 0.0, 80, centre, 0.0028)
	for s in [-1.0, 1.0]:
		_edge_a(root, shape, s * BREAST_ARC, 0.0, 1.0, 16, centre, 0.0026)
		_rivet(shape, s * 0.5, 0.95, centre, 0.008)  # shoulder strap rivets
	if gussets:
		for s in [-1.0, 1.0]:
			_gusset(root, s, Callable(self, "breast_top"), 0.0, 0.62, 1.6, centre)
	_side_fittings(root)
	_flush_rivets(root)


## Riveted plate along an armhole. top_fn(a) is the outline; a_off turns the
## angles (0 for the breast, PI for the back).
func _gusset(root: Node3D, side: float, top_fn: Callable, a_off: float, a0: float, a1: float, centre: Vector3) -> void:
	var surf := func(a: float, y: float, push: float) -> Vector3:
		var r := plate(y)
		return ring_point(a, y, r) + ring_normal(a, r) * push
	var edge_at := func(u: float) -> Vector3:
		var a: float = side * u
		return surf.call(a + a_off, top_fn.call(a), 0.0)
	var shape := func(u: float, t: float) -> Vector3:
		var e: Vector3 = edge_at.call(u)
		var tan: Vector3 = edge_at.call(u + 0.004) - edge_at.call(u - 0.004)
		var n := ring_normal(atan2(e.x, e.z), plate(e.y))
		var inward := n.cross(tan).normalized()
		# pick the direction that heads into the plate (below the outline)
		var probe := e + inward * 0.01
		var pa := atan2(probe.x, probe.z) - a_off
		if probe.y > top_fn.call(wrapf(pa, -PI, PI)):
			inward = -inward
		var q := e + inward * (GUSSET_W * t)
		# taper the band at both ends
		var w := smoothstep(a0, a0 + 0.08, u) * (1.0 - smoothstep(a1 - 0.08, a1, u))
		q = e + inward * (GUSSET_W * t * (0.35 + 0.65 * w))
		var qa := atan2(q.x, q.z)
		return surf.call(qa, q.y, 0.0034)
	_add_mesh(root, K.surface(shape, a0, a1, 40, 0.0, 1.0, 4, centre), metal)
	_edge(root, shape, a0, a1, 0.0, 40, centre, 0.0034)
	_edge(root, shape, a0, a1, 1.0, 40, centre, 0.0018)
	for i in 5:
		_rivet(shape, lerpf(a0 + 0.08, a1 - 0.08, i / 4.0), 0.62, centre, 0.0062)


## Clasp on the right side (-X), hinges on the left (+X).
func _side_fittings(root: Node3D) -> void:
	# clasp: a small plate with a stud and a swivel hook
	var a := -BREAST_ARC + 0.08
	var y := 1.2
	var p := breast_surface(a, y, 0.003)
	var n := ring_normal(a, plate(y))
	var plate_mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.024, 0.003, 0.05)
	plate_mi.mesh = bm
	plate_mi.material_override = metal
	plate_mi.transform = Transform3D(K.surface_basis(n, Vector3.ONE).rotated(n, PI * 0.5), p)
	root.add_child(plate_mi)
	_rivets.append(K.rivet_xform(p + Vector3(0, 0.017, 0), n, 0.006))
	_rivets.append(K.rivet_xform(p - Vector3(0, 0.017, 0), n, 0.006))
	var hook := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.006
	tm.outer_radius = 0.0095
	hook.mesh = tm
	hook.material_override = metal
	hook.transform = Transform3D(K.surface_basis(n, Vector3(1.0, 1.0, 1.6)), p + n * 0.004)
	root.add_child(hook)
	# hinges
	for hy in [1.13, 1.27]:
		var ha := BREAST_ARC - 0.06
		var hp := breast_surface(ha, hy, 0.003)
		var hn := ring_normal(ha, plate(hy))
		var leaf := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.03, 0.003, 0.022)
		leaf.mesh = lm
		leaf.material_override = metal
		leaf.transform = Transform3D(K.surface_basis(hn, Vector3.ONE), hp)
		root.add_child(leaf)
		var pin := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0035
		cm.bottom_radius = 0.0035
		cm.height = 0.026
		pin.mesh = cm
		pin.material_override = metal
		pin.position = ring_point(BREAST_ARC + 0.02, hy, plate(hy, 0.004))
		root.add_child(pin)
		_rivets.append(K.rivet_xform(hp, hn, 0.0055))


# ==========================================================================
# Backplate
# ==========================================================================

## Top outline, a measured from the back centre: neck, high shoulders,
## armholes cut deep toward the spine.
func back_top(a: float) -> float:
	var top: float = m["neck_base_height"]
	var arm: float = m["armpit_height"]
	return _hermite(absf(a), [0.0, 0.25, 0.5, 0.68, 0.95, 1.25, BACK_ARC],
		[top - 0.012, top - 0.004, top + 0.014, top + 0.002, top - 0.075, arm - 0.008, arm - 0.03])


## V-shaped yoke line: the upper plate overlaps the lower one along it.
func yoke_y(a: float) -> float:
	return m["neck_base_height"] - 0.018 - 0.05 * maxf(0.0, 1.0 - absf(a) / 0.82)


func _back_shape(a: float, t: float) -> Vector3:
	var y := lerpf(bottom(PI + a), back_top(a), t)
	var r := plate(y, -0.002)
	var p := ring_point(PI + a, y, r)
	var raise := 0.0028 * exp(-absf(p.x) / 0.012)  # spine ridge
	if absf(a) < 0.82:
		raise += 0.0036 * smoothstep(-0.0015, 0.0015, y - yoke_y(a))
	return p + ring_normal(PI + a, r) * raise


func _build_backplate() -> void:
	var root: Node3D = pieces["Backplate"]
	_clear(root)
	_rivets = []
	var shape := Callable(self, "_back_shape")
	var centre := Vector3(0, 1.25, 0.12)
	_add_mesh(root, K.surface(shape, -BACK_ARC, BACK_ARC, 110, 0.0, 1.0, 80, centre), metal)
	var a_edge := 0.7 if gussets else BACK_ARC
	_edge(root, shape, -a_edge, a_edge, 1.0, 60, centre, 0.0036)
	_edge(root, shape, -BACK_ARC, BACK_ARC, 0.0, 70, centre, 0.0028)
	for s in [-1.0, 1.0]:
		_edge_a(root, shape, s * BACK_ARC, 0.0, 1.0, 14, centre, 0.0026)
		_rivet(shape, s * 0.5, 0.96, centre, 0.008)
	# rolled edge along the V of the yoke
	var vpts := PackedVector3Array()
	for i in 41:
		var a := lerpf(-0.8, 0.8, i / 40.0)
		var y := yoke_y(a) + 0.0008
		var r := plate(y, -0.002)
		var p := ring_point(PI + a, y, r)
		vpts.append(p + ring_normal(PI + a, r) * (0.0042 + 0.0028 * exp(-absf(p.x) / 0.012)))
	_add_mesh(root, K.tube(vpts, 0.0028, 6), metal)
	if gussets:
		for s in [-1.0, 1.0]:
			_gusset(root, s, Callable(self, "back_top"), PI, 0.72, 1.56, centre)
	_flush_rivets(root)


# ==========================================================================
# Shoulder plates: steel straps joining breast and back over the shoulders
# ==========================================================================

const SH_FRONT := [0.34, 0.64]   # span on the breastplate's shoulder (angle from front)
const SH_BACK := [0.36, 0.68]    # span on the backplate's shoulder (angle from back)
const SH_OVERLAP := 0.07         # how far down each plate the strap starts (fraction)
const SH_PUSH := 0.0075          # sits this far outside the plates
const NECK_CLEAR := 0.012


## Neck column of the mannequin at height y: (centre z, radius).
func _neck(y: float) -> Vector2:
	var nr: float = m["neck_girth"] / TAU
	var y0: float = m["neck_base_height"] - 0.035
	var y1: float = m["chin_height"] + 0.055
	var k := clampf((y - y0) / (y1 - y0), 0.0, 1.0)
	return Vector2(lerpf(-0.024, -0.004, k), nr * lerpf(1.12, 1.02, k))


func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)


## Point on the strap. side: +1 = figure's left (+X). u: 0 neck side .. 1 arm side.
## t: 0 on the breastplate .. 1 on the backplate.
func shoulder_point(side: float, u: float, t: float) -> Vector3:
	var p := _strap_path(side, u, t)
	# keep the whole strap clear of the neck: shift it outward as one piece,
	# judged by its neck-side edge so it keeps its width
	var inner := _strap_path(side, 0.0, t)
	var nk := _neck(inner.y)
	var d := Vector2(inner.x, inner.z - nk.x)
	var need := nk.y + NECK_CLEAR
	var have := d.length()
	var grow := _smax(have, need, 0.012) - have
	if grow > 0.0 and have > 1e-5:
		var dir := d / have
		p += Vector3(dir.x, 0.0, dir.y) * grow
	return p


func _strap_path(side: float, u: float, t: float) -> Vector3:
	var af := side * lerpf(SH_FRONT[0], SH_FRONT[1], u)
	var ab := -side * lerpf(SH_BACK[0], SH_BACK[1], u)
	var t0 := 1.0 - SH_OVERLAP
	var f0 := _breast_shape(af, t0)
	var f1 := _breast_shape(af, 1.0)
	var b0 := _back_shape(ab, t0)
	var b1 := _back_shape(ab, 1.0)
	var nf := ring_normal(af, plate(f0.y))
	var nb := ring_normal(PI + ab, plate(b0.y))
	var p0 := f0 + nf * SH_PUSH
	var p3 := b0 + nb * SH_PUSH
	var span := p0.distance_to(p3)
	var p1 := p0 + (f1 - f0).normalized() * span * 0.3
	var p2 := p3 + (b1 - b0).normalized() * span * 0.3
	return _bezier(p0, p1, p2, p3, t)


func _build_shoulders() -> void:
	var root: Node3D = pieces["Shoulders"]
	_clear(root)
	_rivets = []
	for side in [-1.0, 1.0]:
		var shape := func(u: float, t: float) -> Vector3: return shoulder_point(side, u, t)
		var centre := Vector3(side * 0.05, 1.38, -0.01)
		_add_mesh(root, K.surface(shape, 0.0, 1.0, 10, 0.0, 1.0, 48, centre), metal)
		_edge_a(root, shape, 0.0, 0.0, 1.0, 48, centre, 0.003)
		_edge_a(root, shape, 1.0, 0.0, 1.0, 48, centre, 0.003)
		_edge(root, shape, 0.0, 1.0, 0.0, 10, centre, 0.0026)
		_edge(root, shape, 0.0, 1.0, 1.0, 10, centre, 0.0026)
		for t in [0.05, 0.95]:
			_rivet(shape, 0.3, t, centre, 0.0065)
			_rivet(shape, 0.7, t, centre, 0.0065)
	_flush_rivets(root)


# ==========================================================================
# Fauld (bottom section): flared lame(s) all the way round
# ==========================================================================

func _lame_shape(k: int, a: float, t: float) -> Vector3:
	var y0 := bottom(a) + 0.012 - k * LAME_STEP
	var y1 := y0 - LAME_H
	var y := lerpf(y0, y1, t)
	var r := plate(y, -0.001 + 0.005 * k + 0.32 * (y0 - y))
	return ring_point(a, y, r)


func _build_fauld() -> void:
	var root: Node3D = pieces["Fauld"]
	_clear(root)
	_rivets = []
	var centre := Vector3(0, 1.0, 0.0)
	for k in lames:
		var shape := func(a: float, t: float) -> Vector3: return _lame_shape(k, a, t)
		_add_mesh(root, K.surface(shape, -PI, PI, 120, 0.0, 1.0, 8, centre), metal)
		_edge(root, shape, -PI, PI, 1.0, 120, centre, 0.0028)
		for i in 8:
			_rivet(shape, -PI + TAU * (i + 0.5) / 8.0, 0.3, centre, 0.0062)
	_flush_rivets(root)


# ==========================================================================
# Belt (on the seam) and shoulder straps
# ==========================================================================

func _build_belt() -> void:
	var root: Node3D = pieces["Belt"]
	_clear(root)
	var off := 0.009 + (0.004 if lames > 0 else 0.0)
	var band := func(a: float, t: float) -> Vector3:
		var y := bottom(a) - 0.002 + lerpf(-0.012, 0.012, t)
		return ring_point(a, y, plate(y, off))
	_add_mesh(root, K.surface(band, -PI, PI, 120, 0.0, 1.0, 2, Vector3(0, 1.04, 0)), leather)
	# buckle on the right side of the front (-X)
	var ab := -1.05
	var yb := bottom(ab) - 0.002
	var rb := plate(yb, off + 0.003)
	var pb := ring_point(ab, yb, rb)
	var nb := ring_normal(ab, rb)
	var buckle := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.01
	tm.outer_radius = 0.0145
	buckle.mesh = tm
	buckle.material_override = brass
	buckle.transform = Transform3D(K.surface_basis(nb, Vector3(1.0, 1.0, 1.3)), pb)
	root.add_child(buckle)
	var tongue := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.024, 0.003, 0.003)
	tongue.mesh = bm
	tongue.material_override = brass
	tongue.transform = Transform3D(K.surface_basis(nb, Vector3.ONE), pb + nb * 0.002)
	root.add_child(tongue)
	# loose tail of the strap
	var tail := func(a: float, t: float) -> Vector3:
		var y := bottom(a) - 0.002 - 0.004 * t + lerpf(-0.011, 0.011, t)
		return ring_point(a, y, plate(y, off + 0.0035))
	_add_mesh(root, K.surface(tail, ab - 0.02, ab + 0.32, 10, 0.0, 1.0, 2, Vector3(0, 1.04, 0)), leather)


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
