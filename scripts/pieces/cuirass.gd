extends Node3D
## Cuirass traced from a front / side / back reference, fitted to the wooden
## mannequin (measurements.json).
##
##   Breastplate  mid section, front: round chest, wide shallow neckline,
##                armholes, shoulder tabs
##   Backplate    mid section, back
##   Fauld        bottom section: one flared band all round, below the waist
##   Shoulders    leather straps riveted to the front and back tabs, joining
##                them over each shoulder
##   Belt         front belt on the division with buckle and hanging tail,
##                plus buckled straps across each side seam
##
## The shell is a ring surface whose width (front and back views) and depth
## (side view) at every height come from the traced outlines (T_* tables).
## Neck and armholes are cut out along smooth curves with marching-triangle
## clipping, and every cut edge gets a rolled edge. Anywhere the traced shape
## would come too close to the mannequin, it is pushed out to clear it.
##
## Axes: +Y up, +Z toward the front. Angle a = 0 is the front centre,
## positive a turns toward +X (the figure's left).

const K := preload("res://scripts/mesh_kit.gd")

# ---- traced outlines (metres): height, half-width front/back, z front/back --
const T_Y := [1.512, 1.5017, 1.4929, 1.4840, 1.4752, 1.4663, 1.4575, 1.4487, 1.4398, 1.4310, 1.4221, 1.4133, 1.4044, 1.3956, 1.3867, 1.3779, 1.3690, 1.3602, 1.3513, 1.3425, 1.3337, 1.3248, 1.3160, 1.3071, 1.2983, 1.2894, 1.2810, 1.2731, 1.2651, 1.2572, 1.2493, 1.2413, 1.2334, 1.2254, 1.2175, 1.2096, 1.2016, 1.1937, 1.1857, 1.1778, 1.1699, 1.1619, 1.1540, 1.1463, 1.1389, 1.1314, 1.1240, 1.1166, 1.1091, 1.1017, 1.0943, 1.0869, 1.0794, 1.0720, 1.0646, 1.0571, 1.0497, 1.0423, 1.0]
const T_XF := [0.1336, 0.1336, 0.1334, 0.1286, 0.1282, 0.1274, 0.1270, 0.1265, 0.1267, 0.1267, 0.1272, 0.1280, 0.1290, 0.1305, 0.1321, 0.1340, 0.1363, 0.1386, 0.1415, 0.1448, 0.1482, 0.1527, 0.1577, 0.1629, 0.1629, 0.1605, 0.1586, 0.1563, 0.1540, 0.1521, 0.1502, 0.1473, 0.1451, 0.1432, 0.1413, 0.1392, 0.1374, 0.1359, 0.1344, 0.1330, 0.1330, 0.1340, 0.1336, 0.1325, 0.1334, 0.1346, 0.1363, 0.1392, 0.1423, 0.1450, 0.1478, 0.1507, 0.1560, 0.1600, 0.1630, 0.1640, 0.1648, 0.1648, 0.1648]
const T_XB := [0.1276, 0.1276, 0.1353, 0.1315, 0.1301, 0.1305, 0.1301, 0.1303, 0.1305, 0.1307, 0.1313, 0.1319, 0.1326, 0.1338, 0.1349, 0.1363, 0.1384, 0.1403, 0.1428, 0.1459, 0.1492, 0.1528, 0.1573, 0.1621, 0.1625, 0.1596, 0.1571, 0.1548, 0.1523, 0.1502, 0.1478, 0.1448, 0.1424, 0.1405, 0.1382, 0.1363, 0.1344, 0.1328, 0.1313, 0.1297, 0.1294, 0.1310, 0.1310, 0.1300, 0.1297, 0.1305, 0.1332, 0.1365, 0.1392, 0.1421, 0.1450, 0.1476, 0.1530, 0.1570, 0.1600, 0.1610, 0.1613, 0.1613, 0.1613]
const T_ZF := [-0.025, -0.0091, 0.0019, 0.0110, 0.0225, 0.0369, 0.0479, 0.0522, 0.0599, 0.0671, 0.0742, 0.0810, 0.0877, 0.0944, 0.1001, 0.1059, 0.1116, 0.1169, 0.1221, 0.1260, 0.1308, 0.1346, 0.1384, 0.1413, 0.1442, 0.1466, 0.1480, 0.1499, 0.1504, 0.1514, 0.1509, 0.1504, 0.1494, 0.1485, 0.1471, 0.1456, 0.1442, 0.1423, 0.1403, 0.1380, 0.1356, 0.1327, 0.1298, 0.1285, 0.1303, 0.1332, 0.1332, 0.1327, 0.1312, 0.1336, 0.1360, 0.1380, 0.1399, 0.1418, 0.1442, 0.1466, 0.1490, 0.1499, 0.1505]
const T_ZB := [-0.100, -0.1073, -0.1164, -0.1241, -0.1298, -0.1332, -0.1360, -0.1380, -0.1394, -0.1408, -0.1418, -0.1427, -0.1437, -0.1447, -0.1447, -0.1437, -0.1437, -0.1427, -0.1423, -0.1413, -0.1399, -0.1389, -0.1370, -0.1351, -0.1332, -0.1312, -0.1293, -0.1265, -0.1245, -0.1217, -0.1188, -0.1164, -0.1140, -0.1111, -0.1083, -0.1054, -0.1030, -0.1006, -0.0982, -0.0963, -0.0948, -0.0939, -0.0939, -0.0948, -0.0958, -0.0992, -0.1030, -0.1068, -0.1106, -0.1145, -0.1188, -0.1226, -0.1269, -0.1312, -0.1351, -0.1394, -0.1430, -0.1440, -0.1445]
# neckline (front and back views): |x| -> height of the cut
const NECK_F := [[0.0, 1.4645], [0.0389, 1.4699], [0.051, 1.4734], [0.0599, 1.477], [0.0672, 1.4805], [0.073, 1.484], [0.0785, 1.4876], [0.0828, 1.4911], [0.0868, 1.4947], [0.0901, 1.4982], [0.0928, 1.5017], [0.0965, 1.53], [0.11, 1.6]]
const NECK_B := [[0.0, 1.471], [0.0343, 1.4752], [0.051, 1.4787], [0.0622, 1.4823], [0.071, 1.4858], [0.078, 1.4893], [0.0835, 1.4929], [0.0882, 1.4964], [0.0916, 1.5], [0.0939, 1.5035], [0.097, 1.53], [0.11, 1.6]]

const TOP := 1.512
const ARM_BOTTOM := 1.30   # armholes close below this
const SEAM_Y := 1.128      # division between the mid and bottom sections
const SEAM_Z := -0.039     # side seam where breast and back plates meet
const BOTTOM_FRONT := 1.017
const BOTTOM_RISE := 0.022 # the lower edge rises this much over the hips
const CLEAR_SIDE := 0.008
const CLEAR_FB := 0.008

const EDGE_R := 0.0033     # rolled edge radius (cuts are pulled in by this)
const COLS := 144          # around the body
const ROW_STEP := 0.0036    # metres between rows

var metal: Material
var leather: Material
var brass: Material
var m: Dictionary = {}
var pieces := {}  # name -> Node3D

# dense per-height table, 1 mm spacing: see _row_at
var _tab := PackedFloat32Array()
const TAB_Y0 := 0.99
const TAB_N := 540
const STRIDE := 12
var _rivets: Array = []


func setup(mats: Dictionary, measurements: Dictionary, chest_joint: Node3D, pelvis_joint: Node3D) -> void:
	metal = mats["metal"]
	leather = mats["leather"]
	brass = mats["brass"]
	m = measurements
	_build_table()
	for n in ["Breastplate", "Backplate", "Shoulders", "Belt"]:
		pieces[n] = _piece(n, chest_joint)
	pieces["Fauld"] = _piece("Fauld", pelvis_joint)
	rebuild_all()


func _piece(piece_name: String, joint: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = piece_name
	joint.add_child(n)
	n.global_transform = Transform3D.IDENTITY  # modelled in mannequin space
	return n


func rebuild_all() -> void:
	_build_plate("Breastplate", 1)
	_build_plate("Backplate", -1)
	_build_fauld()
	_build_shoulder_straps()
	_build_belt()


# ==========================================================================
# Shape: tables, body model, surface
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


static func _lin(x: float, pts: Array) -> float:
	if x <= pts[0][0]:
		return pts[0][1]
	for i in pts.size() - 1:
		if x <= pts[i + 1][0]:
			var k: float = (x - pts[i][0]) / (pts[i + 1][0] - pts[i][0])
			return lerpf(pts[i][1], pts[i + 1][1], k)
	return 2.0


## Smooth maximum: exactly max(a, b) once they differ by more than k.
static func _smax(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return maxf(a, b) + h * h * k * 0.25


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
			_hermite(y, zs, [ww * 1.02, cw * 0.93, cw, cw * 0.93, 0.098, 0.062]),
			_hermite(y, zs, [wd, cd * 0.93, cd, cd * 0.72, 0.056, 0.05]),
			_hermite(y, zs, [0.0, 0.006, 0.012, 0.0, -0.012, -0.008]))
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


## Precomputes everything that depends only on height, at 1 mm spacing.
## Per row: ring half-width front/back, z front/back/middle, armhole cut
## half-width front/back, body half-width, body z front/back/centre, spare.
func _build_table() -> void:
	_tab.resize(TAB_N * STRIDE)
	var ty := T_Y.duplicate()
	# 1. sample the traced outlines densely
	var xf_a := PackedFloat32Array()
	var xb_a := PackedFloat32Array()
	var zf_a := PackedFloat32Array()
	var zb_a := PackedFloat32Array()
	var cs_a := PackedFloat32Array()
	var tf_a := PackedFloat32Array()  # armhole cut, straight from the trace
	var tb_a := PackedFloat32Array()
	var bodies := []
	for i in TAB_N:
		var y := TAB_Y0 + i * 0.001
		var b := body(y)
		bodies.append(b)
		# at the armpit the arm hangs close to the chest: tighten the plate there
		var pit := smoothstep(1.26, 1.29, y) * (1.0 - smoothstep(1.33, 1.37, y))
		var clear_side := CLEAR_SIDE - 0.002 * pit
		cs_a.append(clear_side)
		var xf := minf(_hermite(y, ty, T_XF), 0.1585 + 0.03 * (1.0 - pit))
		var xb := minf(_hermite(y, ty, T_XB), 0.1585 + 0.03 * (1.0 - pit))
		tf_a.append(xf)
		tb_a.append(xb)
		var zf := _hermite(y, ty, T_ZF)
		var zb := _hermite(y, ty, T_ZB)
		# 2. make room for the mannequin (it is fuller than the reference
		# wearer in places); fades out over the shoulders, where the neck
		# cut takes over
		var fade := 1.0 - smoothstep(1.44, 1.48, y)
		var margin := 0.001
		zf = lerpf(zf, _smax(zf, b.z + b.y + CLEAR_FB + margin, 0.02), fade)
		zb = lerpf(zb, -_smax(-zb, -(b.z - b.y) + CLEAR_FB + margin, 0.02), fade)
		if pit < 0.5:
			xf = lerpf(xf, _smax(xf, b.x + clear_side + margin, 0.015), fade)
			xb = lerpf(xb, _smax(xb, b.x + clear_side + margin, 0.015), fade)
		xf_a.append(xf)
		xb_a.append(xb)
		zf_a.append(zf)
		zb_a.append(zb)
	# 3. smooth so the steel reads as one fair curve
	xf_a = _smooth(xf_a, 14)
	xb_a = _smooth(xb_a, 14)
	zf_a = _smooth(zf_a, 18)
	zb_a = _smooth(zb_a, 18)
	tf_a = _smooth(tf_a, 14)
	tb_a = _smooth(tb_a, 14)
	for i in TAB_N:
		var y := TAB_Y0 + i * 0.001
		var b: Vector3 = bodies[i]
		var xf := xf_a[i]
		var xb := xb_a[i]
		var zf := zf_a[i]
		var zb := zb_a[i]
		# above the armholes the ring runs on past the cut so the side is open
		var up := _hermite(y, [1.25, 1.30, 1.32, 1.43, TOP], [0.0, 0.15, 0.163, 0.162, 0.142])
		var rxf := _smax(xf, up, 0.006)
		var rxb := _smax(xb, up, 0.006)
		var ramp := 0.5 * smoothstep(ARM_BOTTOM + 0.004, ARM_BOTTOM - 0.012, y)
		var d := zf - zb
		var zmid := clampf(b.z, zb + 0.3 * d, zf - 0.3 * d)
		var o := i * STRIDE
		_tab[o] = rxf
		_tab[o + 1] = rxb
		_tab[o + 2] = zf
		_tab[o + 3] = zb
		_tab[o + 4] = zmid
		_tab[o + 5] = tf_a[i] + ramp
		_tab[o + 6] = tb_a[i] + ramp
		_tab[o + 7] = b.x
		_tab[o + 8] = b.z + b.y
		_tab[o + 9] = b.z - b.y
		_tab[o + 10] = b.z
		_tab[o + 11] = cs_a[i]


## Gaussian smoothing (radius in samples), holding the ends.
static func _smooth(a: PackedFloat32Array, radius: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	var sigma := radius * 0.5
	for i in a.size():
		var sum := 0.0
		var wsum := 0.0
		for k in range(-radius, radius + 1):
			var j := clampi(i + k, 0, a.size() - 1)
			var w := exp(-0.5 * (k * k) / (sigma * sigma))
			sum += a[j] * w
			wsum += w
		out[i] = sum / wsum
	return out


func _row_at(y: float) -> PackedFloat32Array:
	var f := clampf((y - TAB_Y0) / 0.001, 0.0, TAB_N - 1.001)
	var i := int(f)
	var k := f - i
	var out := PackedFloat32Array()
	out.resize(STRIDE)
	for j in STRIDE:
		out[j] = lerpf(_tab[i * STRIDE + j], _tab[(i + 1) * STRIDE + j], k)
	return out


## Surface point at angle a, height y, pushed `push` metres outward, and
## guaranteed to clear the mannequin.
func surface(a: float, y: float, push: float = 0.0, row: PackedFloat32Array = PackedFloat32Array()) -> Vector3:
	if row.is_empty():
		row = _row_at(y)
	var c := cos(a)
	var s := sin(a)
	var w := (c + 1.0) * 0.5
	var rx := lerpf(row[1], row[0], w) + push
	var zmid := row[4]
	var x := s * rx
	var z: float
	if c >= 0.0:
		z = zmid + c * (row[2] - zmid + push)
	else:
		z = zmid + c * (zmid - row[3] + push)
	# clear the body: push outward if inside the padded body ellipse
	var bo := row[10]
	var ex := row[7] + row[11] + push
	var ez := (row[8] - bo if z >= bo else bo - row[9]) + CLEAR_FB + push
	var q := sqrt((x / ex) * (x / ex) + ((z - bo) / ez) * ((z - bo) / ez))
	if q < 1.15 and q > 1e-5:
		var scale := _smax(q, 1.0, 0.04) / q
		x *= scale
		z = bo + (z - bo) * scale
	return Vector3(x, y, z)


func normal_at(a: float, y: float, push: float = 0.0) -> Vector3:
	var e := 0.002
	var da := surface(a + e, y, push) - surface(a - e, y, push)
	var dy := surface(a, y + e, push) - surface(a, y - e, push)
	var n := da.cross(dy)
	if n.length_squared() < 1e-16:
		n = Vector3(sin(a), 0.0, cos(a))
	n = n.normalized()
	var p := surface(a, y, push)
	if n.dot(Vector3(p.x, 0.0, p.z - _row_at(y)[4])) < 0.0:
		n = -n
	return n


## Lower edge: lowest at the front and back centres, rising over the hips.
func bottom(a: float) -> float:
	var s := sin(a)
	return BOTTOM_FRONT + BOTTOM_RISE * s * s


## Angle of the side seam on side sx (+1 / -1).
func seam_angle(sx: float, y: float) -> float:
	var row := _row_at(y)
	var zmid := row[4]
	var c: float
	if SEAM_Z >= zmid:
		c = (SEAM_Z - zmid) / (row[2] - zmid)
	else:
		c = (SEAM_Z - zmid) / (zmid - row[3])
	return sx * acos(clampf(c, -1.0, 1.0))


# ==========================================================================
# Cut-out shell builder (marching triangles over the (angle, height) grid)
# ==========================================================================

## Cut function for the mid plates: > 0 means cut away.
func _cut_mid(p: Vector3, a: float, y: float, row: PackedFloat32Array, side: int) -> float:
	var c := cos(a)
	var ax := absf(p.x)
	var neck := y - (_lin(ax, NECK_F if c >= 0.0 else NECK_B) - EDGE_R)
	var w := (c + 1.0) * 0.5
	var arm := ax - (lerpf(row[6], row[5], w) - EDGE_R)
	var f := maxf(neck, arm)
	# split into breast (front of the seam) and back (behind, tucked under)
	if side > 0:
		f = maxf(f, (SEAM_Z - p.z) * 1.5)
	else:
		f = maxf(f, (p.z - SEAM_Z - 0.018) * 1.5)
	return f


func _cut_fauld(_p: Vector3, a: float, y: float, _row: PackedFloat32Array, _side: int) -> float:
	return bottom(a) + EDGE_R - y


## Builds a clipped surface; returns [mesh, boundary loops (arrays of [a, y])].
func _shell(y0: float, y1: float, push: float, cut: Callable, side: int) -> Array:
	var rows := int(ceil((y1 - y0) / ROW_STEP)) + 1
	var ys := PackedFloat32Array()
	for r in rows:
		ys.append(lerpf(y0, y1, float(r) / (rows - 1)))
	var da := TAU / COLS
	# grid values
	var gp := []        # positions
	var gf := PackedFloat32Array()
	for r in rows:
		var row := _row_at(ys[r])
		for c in COLS:
			var a := -PI + c * da
			var p := surface(a, ys[r], push, row)
			gp.append(p)
			gf.append(cut.call(p, a, ys[r], row, side))

	var params := []       # [a, y] per output vertex
	var vid := {}          # key -> output index
	var tris := PackedInt32Array()

	var grid_v := func(r: int, c: int) -> int:
		var key := "g%d_%d" % [r, c % COLS]
		if not vid.has(key):
			vid[key] = params.size()
			params.append([-PI + (c % COLS) * da, ys[r]])
		return vid[key]

	# vertex where the cut crosses the edge between two grid corners
	var edge_v := func(r0: int, c0: int, r1: int, c1: int) -> int:
		var ka := "%d_%d" % [r0, c0 % COLS]
		var kb := "%d_%d" % [r1, c1 % COLS]
		var key := ("e" + ka + "|" + kb) if ka < kb else ("e" + kb + "|" + ka)
		if vid.has(key):
			return vid[key]
		var a0 := -PI + c0 * da
		var a1 := -PI + c1 * da
		var yy0 := ys[r0]
		var yy1 := ys[r1]
		var f0 := gf[r0 * COLS + c0 % COLS]
		var lo := 0.0
		var hi := 1.0
		for _i in 14:
			var mid := (lo + hi) * 0.5
			var am := lerpf(a0, a1, mid)
			var ym := lerpf(yy0, yy1, mid)
			var rw := _row_at(ym)
			var fm: float = cut.call(surface(am, ym, push, rw), am, ym, rw, side)
			if (fm > 0.0) == (f0 > 0.0):
				lo = mid
			else:
				hi = mid
		var t := (lo + hi) * 0.5
		vid[key] = params.size()
		params.append([lerpf(a0, a1, t), lerpf(yy0, yy1, t)])
		return vid[key]

	for r in rows - 1:
		for c in COLS:
			var corners := [[r, c], [r, c + 1], [r + 1, c + 1], [r + 1, c]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var vs := []
				for k in 3:
					vs.append(corners[tri[k]])
				var fs := []
				for v in vs:
					fs.append(gf[v[0] * COLS + v[1] % COLS])
				if fs[0] > 0.0 and fs[1] > 0.0 and fs[2] > 0.0:
					continue
				var poly := PackedInt32Array()
				for k in 3:
					var va: Array = vs[k]
					var vb: Array = vs[(k + 1) % 3]
					var fa: float = fs[k]
					var fb: float = fs[(k + 1) % 3]
					if fa <= 0.0:
						poly.append(grid_v.call(va[0], va[1]))
					if (fa > 0.0) != (fb > 0.0):
						poly.append(edge_v.call(va[0], va[1], vb[0], vb[1]))
				for k in range(1, poly.size() - 1):
					tris.append_array([poly[0], poly[k], poly[k + 1]])

	# positions and normals
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for pr in params:
		verts.append(surface(pr[0], pr[1], push))
		norms.append(normal_at(pr[0], pr[1], push))
	# wind for Godot (clockwise front faces)
	var idx := PackedInt32Array()
	var edge_count := {}
	for i in range(0, tris.size(), 3):
		var i0 := tris[i]
		var i1 := tris[i + 1]
		var i2 := tris[i + 2]
		var g := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
		if g.length_squared() < 1e-14:
			continue
		if g.dot(norms[i0] + norms[i1] + norms[i2]) < 0.0:
			idx.append_array([i0, i1, i2])
		else:
			idx.append_array([i0, i2, i1])
		for e in [[i0, i1], [i1, i2], [i2, i0]]:
			var key := Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))
			edge_count[key] = edge_count.get(key, 0) + 1
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	# boundary edges -> chained loops of parameters
	var adj := {}
	for key in edge_count.keys():
		if edge_count[key] == 1:
			var k2: Vector2i = key
			adj[k2.x] = adj.get(k2.x, []) + [k2.y]
			adj[k2.y] = adj.get(k2.y, []) + [k2.x]
	var seen := {}
	var loops := []
	for start in adj.keys():
		if seen.has(start):
			continue
		var chain := [start]
		seen[start] = true
		var cur: int = start
		while true:
			var nxt := -1
			for nb in adj[cur]:
				if not seen.has(nb):
					nxt = nb
					break
			if nxt < 0:
				break
			seen[nxt] = true
			chain.append(nxt)
			cur = nxt
		var closed: bool = chain.size() > 2 and (adj[cur] as Array).has(start)
		var pts := []
		for v in chain:
			pts.append(params[v])
		if closed:
			pts.append(params[start])
		loops.append(pts)
	return [mesh, loops]


func _rolled_edges(root: Node3D, loops: Array, push: float, radius: float, skip: Callable) -> void:
	for lp in loops:
		var seg := PackedVector3Array()
		for pr in lp:
			if skip.call(pr[0], pr[1]):
				if seg.size() > 2:
					_add_mesh(root, K.tube(seg, radius, 6), metal)
				seg = PackedVector3Array()
				continue
			seg.append(surface(pr[0], pr[1], push) + normal_at(pr[0], pr[1], push) * radius * 0.4)
		if seg.size() > 2:
			_add_mesh(root, K.tube(seg, radius, 6), metal)


# ==========================================================================
# Pieces
# ==========================================================================

func _build_plate(piece_name: String, side: int) -> void:
	var root: Node3D = pieces[piece_name]
	_clear(root)
	var push := 0.0 if side > 0 else -0.0018  # back plate tucks under the breast
	var res: Array = _shell(SEAM_Y - 0.016, TOP, push, Callable(self, "_cut_mid"), side)
	_add_mesh(root, res[0], metal)
	# rolled edges everywhere except the hidden bottom row
	var skip := func(_a: float, y: float) -> bool: return y < SEAM_Y - 0.01
	_rolled_edges(root, res[1], push, EDGE_R, skip)


func _build_fauld() -> void:
	var root: Node3D = pieces["Fauld"]
	_clear(root)
	var push := 0.002
	var res: Array = _shell(BOTTOM_FRONT - 0.002, SEAM_Y + 0.004, push, Callable(self, "_cut_fauld"), 0)
	_add_mesh(root, res[0], metal)
	var hem := func(_a: float, y: float) -> bool: return y > SEAM_Y
	var top := func(_a: float, y: float) -> bool: return y < SEAM_Y
	_rolled_edges(root, res[1], push, EDGE_R, hem)   # hem
	_rolled_edges(root, res[1], push, 0.0022, top)   # top edge, under the belt
	# side seam lines on the flared band
	for sx in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		for i in 13:
			var y := lerpf(bottom(PI * 0.5) + 0.008, SEAM_Y, i / 12.0)
			var a := seam_angle(sx, y)
			pts.append(surface(a, y, push) + normal_at(a, y, push) * 0.0012)
		_add_mesh(root, K.tube(pts, 0.0016, 5), metal)


## Leather straps riveted to the front and back shoulder tabs, over the top.
func _build_shoulder_straps() -> void:
	var root: Node3D = pieces["Shoulders"]
	_clear(root)
	_rivets = []
	var y_low := 1.452
	for sx in [-1.0, 1.0]:
		var shape := func(u: float, t: float) -> Vector3:
			var x := 0.111 + (u - 0.5) * 0.036
			return _strap_path(sx, x, y_low, t)
		var c := Vector3(sx * 0.11, 1.44, -0.05)
		_add_mesh(root, K.surface(shape, 0.0, 1.0, 4, 0.0, 1.0, 40, c), leather)
		# rivets near each end
		for t in [0.06, 0.94]:
			var p := _strap_path(sx, 0.111, y_low, t)
			var n := (p - c).normalized()
			_rivets.append(K.rivet_xform(p, n, 0.0085))
	_flush_rivets(root, brass)


## Path over the shoulder at lateral position x (unsigned), t: 0 front .. 1 back.
func _strap_path(sx: float, x: float, y_low: float, t: float) -> Vector3:
	var lift := 0.0058
	var front := func(y: float) -> Vector3:
		var rx := lerpf(_row_at(y)[1], _row_at(y)[0], 1.0)
		var a := asin(clampf(x / rx, -1.0, 1.0))
		return surface(sx * a, y, lift)
	var back := func(y: float) -> Vector3:
		var rx := _row_at(y)[1]
		var a := PI - asin(clampf(x / rx, -1.0, 1.0))
		return surface(sx * a, y, lift)
	if t < 0.3:
		return front.call(lerpf(y_low, TOP, t / 0.3))
	if t > 0.7:
		return back.call(lerpf(TOP, y_low, (t - 0.7) / 0.3))
	var p0: Vector3 = front.call(TOP)
	var p3: Vector3 = back.call(TOP)
	var d0: Vector3 = (p0 - front.call(TOP - 0.01)).normalized()
	var d3: Vector3 = (p3 - back.call(TOP - 0.01)).normalized()
	var span := p0.distance_to(p3)
	var p1 := p0 + d0 * span * 0.45
	var p2 := p3 + d3 * span * 0.45
	var u := (t - 0.3) / 0.4
	var v := 1.0 - u
	return p0 * (v * v * v) + p1 * (3.0 * v * v * u) + p2 * (3.0 * v * u * u) + p3 * (u * u * u)


func _build_belt() -> void:
	var root: Node3D = pieces["Belt"]
	_clear(root)
	_rivets = []
	var by := SEAM_Y + 0.002
	var push := 0.006
	# belt across the front, from seam to seam
	var a_end := absf(seam_angle(1.0, by)) - 0.08
	var band := func(a: float, t: float) -> Vector3:
		return surface(a, by + lerpf(-0.008, 0.008, t), push)
	_add_mesh(root, K.surface(band, -a_end, a_end, 80, 0.0, 1.0, 2, Vector3(0, by, 0)), leather)
	for sx in [-1.0, 1.0]:
		_rivet_at(sx * a_end * 0.97, by, push + 0.001, 0.0065)
		_rivet_at(sx * (a_end - 0.06), by + 0.034, 0.0, 0.006)  # belt anchor on the plate
	# buckle and hanging tail
	var ab := 0.06
	_buckle(root, ab, by, push + 0.002, 0.024, 0.02)
	var tail := func(a: float, t: float) -> Vector3:
		var y := lerpf(by - 0.006, bottom(0.0) + 0.012, t)
		return surface(a, y, 0.002 + 0.0045)
	_add_mesh(root, K.surface(tail, ab - 0.05, ab + 0.05, 4, 0.0, 1.0, 16, Vector3(0, 1.08, 0)), leather)
	_rivet_at(ab, by - 0.016, 0.002 + 0.0055, 0.0055)
	# buckled straps across each side seam: one on the plates, one on the fauld
	for sx in [-1.0, 1.0]:
		for spec in [[1.237, 0.0035], [1.068, 0.002 + 0.0035]]:
			var y: float = spec[0]
			var pp: float = spec[1]
			var a0 := seam_angle(sx, y)
			var strap := func(a: float, t: float) -> Vector3:
				return surface(a, y + lerpf(-0.0085, 0.0085, t), pp)
			_add_mesh(root, K.surface(strap, a0 - 0.32, a0 + 0.32, 16, 0.0, 1.0, 2, Vector3(0, y, 0)), leather)
			_buckle(root, a0 + sx * 0.06 * signf(cos(a0) + 1.0), y, pp + 0.002, 0.021, 0.019)
			_rivet_at(a0 - 0.28, y, pp + 0.001, 0.006)
			_rivet_at(a0 + 0.28, y, pp + 0.001, 0.006)
	_flush_rivets(root, metal)


func _buckle(root: Node3D, a: float, y: float, push: float, w: float, h: float) -> void:
	var p := surface(a, y, push)
	var n := normal_at(a, y, push)
	var frame := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.5 - 0.12
	tm.outer_radius = 0.5
	tm.rings = 16
	tm.ring_segments = 6
	frame.mesh = tm
	frame.material_override = brass
	frame.transform = Transform3D(K.surface_basis(n, Vector3(w, 0.006 / 0.12, h)), p)
	root.add_child(frame)
	var tongue := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w * 0.9, 0.0025, 0.0025)
	tongue.mesh = bm
	tongue.material_override = brass
	tongue.transform = Transform3D(K.surface_basis(n, Vector3.ONE), p + n * 0.0015)
	root.add_child(tongue)


# ==========================================================================
# Helpers
# ==========================================================================

func _rivet_at(a: float, y: float, push: float, d: float) -> void:
	_rivets.append(K.rivet_xform(surface(a, y, push), normal_at(a, y, push), d))


func _clear(root: Node3D) -> void:
	for c in root.get_children():
		c.queue_free()


func _add_mesh(root: Node3D, mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	root.add_child(mi)


func _flush_rivets(root: Node3D, mat: Material) -> void:
	if _rivets.size() > 0:
		root.add_child(K.multimesh(_rivets, K.rivet_mesh(), mat))
	_rivets = []
