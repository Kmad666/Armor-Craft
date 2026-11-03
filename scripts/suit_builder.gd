extends RefCounted
## Builds a full early-15th-century harness (Italian style, c. 1400-1420):
## mail aventail cape, globose breastplate, fauld lames, mail skirt over a
## linen arming skirt, rerebraces, winged couters, vambraces, hourglass
## gauntlets with articulated fingers, cuisses strapped over mail, winged
## poleyns, greaves and pointed laminated sabatons. Straps, buckles and
## rivets throughout.
##
## Proportions come from the ANATOMY landmarks below (metres, ground = 0),
## measured off a museum-style reference: ~1.86 m to the bascinet apex.
## Each named group becomes a Node3D so the UI can toggle it.

const K := preload("res://scripts/mesh_kit.gd")

# --- Anatomy landmarks -----------------------------------------------------
const SHOULDER_Y := 1.452
const ELBOW_Y := 1.2
const WRIST_Y := 0.97
const KNUCKLE_Y := 0.848
const WAIST_Y := 1.125     # narrowest point of the breastplate / sword belt
const BREAST_Y0 := 1.13    # lower edge of the breastplate
const HEM_Y := 0.818       # mail skirt hem
const HIP_Y := 0.91        # top of the legs
const KNEE_Y := 0.55
const NECK_Y := 1.665      # top of the aventail, inside the helmet
const CAPE_HEM_Y := 1.395  # lower edge of the mail cape

## Arm centre-line: shoulders sit close in, arms angle outward to the hands,
## elbows slightly behind the body line and forearms reaching forward.
const ARM_X := [[1.5, 0.21], [1.2, 0.245], [0.97, 0.268], [0.75, 0.28]]
const ARM_Z := [[1.5, 0.0], [1.2, -0.015], [0.97, 0.038], [0.75, 0.056]]
## Leg centre-line: slightly wider at the hip than at the ankle.
const LEG_XS := [[0.92, 0.118], [0.55, 0.11], [0.0, 0.105]]
const LEG_X := 0.105
const ARM_SCALE := 0.9   # arm plate girth

const SIDES := [-1.0, 1.0]

const PLATE_GROUPS := ["Breastplate", "Backplate", "Fauld", "Rerebraces", "Couters", "Vambraces",
	"Gauntlets", "Cuisses", "Poleyns", "Greaves", "Sabatons"]
const MAIL_GROUPS := ["Aventail", "Mail Sleeves", "Mail Skirt", "Mail Chausses"]
const SOFT_GROUPS := ["Belts", "Arming Skirt", "Surcoat", "Cape"]
const OFF_BY_DEFAULT := ["Surcoat", "Cape"]

var metal: Material
var mail: Material
var leather: Material
var linen: Material
var cloth: Material
var brass: Material

var groups := {}
var _root: Node3D
var _node: Node3D
var _rivets: Array = []

static var _torus: TorusMesh


func _init(root: Node3D, mats: Dictionary) -> void:
	_root = root
	metal = mats["metal"]
	mail = mats["mail"]
	leather = mats["leather"]
	linen = mats["linen"]
	cloth = mats["cloth"]
	brass = mats["brass"]


func build() -> Dictionary:
	_aventail()
	_breastplate()
	_backplate()
	_fauld()
	_belts()
	_mail_skirt()
	_arming_skirt()
	_mail_sleeves()
	_rerebraces()
	_couters()
	_vambraces()
	_gauntlets()
	_mail_chausses()
	_cuisses()
	_poleyns()
	_greaves()
	_sabatons()
	_surcoat()
	_cape()
	return groups


# ==========================================================================
# Shape factories
# ==========================================================================

## Piecewise-linear lookup in [[y, value], ...] sorted by descending y.
static func pw(y: float, pts: Array) -> float:
	if y >= float(pts[0][0]):
		return pts[0][1]
	for i in range(1, pts.size()):
		var y1: float = pts[i][0]
		if y >= y1:
			var y0: float = pts[i - 1][0]
			return lerpf(float(pts[i - 1][1]), float(pts[i][1]), (y0 - y) / (y0 - y1))
	return pts[pts.size() - 1][1]


static func arm_center(sx: float, y: float) -> Vector3:
	return Vector3(sx * pw(y, ARM_X), y, pw(y, ARM_Z))


static func leg_center(sx: float, y: float) -> Vector3:
	return Vector3(sx * pw(y, LEG_XS), y, 0.0)


## Torso cross-section radii at height y: (rx, rz_front, rz_back).
## Narrow waist, deep pigeon-breasted (globose) chest, flatter back.
static func torso(y: float) -> Vector3:
	var u := (y - 1.04) / 0.56
	var rx := K.catmull(u, [0.148, 0.133, 0.138, 0.15, 0.16, 0.158, 0.152, 0.138])
	var rzf := K.catmull(u, [0.128, 0.124, 0.136, 0.156, 0.163, 0.152, 0.13, 0.108])
	var rzb := K.catmull(u, [0.118, 0.11, 0.112, 0.12, 0.128, 0.132, 0.128, 0.116])
	return Vector3(rx, rzf, rzb)


static func torso_point(a: float, y: float, push: float) -> Vector3:
	var r := torso(y)
	var rz := r.y if cos(a) >= 0.0 else r.z
	return Vector3(sin(a) * (r.x + push), y, cos(a) * (rz + push))


## Mail skirt radii at height y (the waist down to the hem).
static func skirt(y: float) -> Vector2:
	var u := (1.1 - y) / (1.1 - HEM_Y)
	return Vector2(K.catmull(u, [0.152, 0.165, 0.182, 0.198, 0.21]),
		K.catmull(u, [0.13, 0.14, 0.154, 0.167, 0.177]))


static func skirt_point(a: float, y: float, push: float) -> Vector3:
	var r := skirt(y)
	return Vector3(sin(a) * (r.x + push), y, cos(a) * (r.y + push))


## Tube around a straight vertical axis. t runs y0 -> y1; keys sampled along t.
static func limb(cx: float, cz: Array, y0: float, y1: float, rx: Array, rz: Array, push: float = 0.0) -> Callable:
	return func(a: float, t: float) -> Vector3:
		var x := K.catmull(t, rx) + push
		var z := K.catmull(t, rz) + push
		return Vector3(cx + x * sin(a), lerpf(y0, y1, t), K.catmull(t, cz) + z * cos(a))


## Tube that follows the arm centre-line.
static func arm_tube(sx: float, y0: float, y1: float, rx: Array, rz: Array, push: float = 0.0) -> Callable:
	return func(a: float, t: float) -> Vector3:
		var y := lerpf(y0, y1, t)
		var c := arm_center(sx, y)
		return c + Vector3((K.catmull(t, rx) * ARM_SCALE + push) * sin(a), 0.0, (K.catmull(t, rz) * ARM_SCALE + push) * cos(a))


## Tube that follows the leg centre-line (cz keys add a calf/knee offset).
static func leg_tube(sx: float, y0: float, y1: float, rx: Array, rz: Array, cz: Array = [0.0], push: float = 0.0) -> Callable:
	return func(a: float, t: float) -> Vector3:
		var y := lerpf(y0, y1, t)
		var c := leg_center(sx, y)
		return c + Vector3((K.catmull(t, rx) + push) * sin(a), 0.0, K.catmull(t, cz) + (K.catmull(t, rz) + push) * cos(a))


## Spherical cap around direction d (t = polar angle, a = around).
static func cap(c: Vector3, d: Vector3, r: float, s: Vector3 = Vector3.ONE) -> Callable:
	d = d.normalized()
	var e1 := d.cross(Vector3.UP).normalized() if absf(d.y) < 0.9 else d.cross(Vector3.RIGHT).normalized()
	var e2 := d.cross(e1)
	return func(a: float, t: float) -> Vector3:
		var v := d * cos(t) + (e1 * cos(a) + e2 * sin(a)) * sin(t)
		return c + v * r * s


## Shallow dish (fan wing) facing n; edges curl back toward -n.
static func dish(c: Vector3, n: Vector3, r: float, depth: float) -> Callable:
	n = n.normalized()
	var e1 := n.cross(Vector3.UP).normalized()
	var e2 := n.cross(e1)
	return func(a: float, t: float) -> Vector3:
		return c + (e1 * cos(a) + e2 * sin(a)) * (t * r) - n * depth * t * t


# ==========================================================================
# Builder helpers
# ==========================================================================

func _begin(group: String) -> void:
	_node = Node3D.new()
	_node.name = group.replace(" ", "")
	_root.add_child(_node)
	groups[group] = _node
	_rivets = []


func _end() -> void:
	if _rivets.size() > 0:
		_node.add_child(K.multimesh(_rivets, K.rivet_mesh(), metal))
	_rivets = []


func _surf(shape: Callable, a0: float, a1: float, na: int, t0: float, t1: float, nt: int,
		orient, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = K.surface(shape, a0, a1, na, t0, t1, nt, orient)
	mi.material_override = mat
	_node.add_child(mi)


func _tube(pts: PackedVector3Array, radius: float, mat: Material, sides: int = 7) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = K.tube(pts, radius, sides)
	mi.material_override = mat
	_node.add_child(mi)


## Rolled edge along t = const.
func _edge(shape: Callable, a0: float, a1: float, t: float, n: int, center: Vector3, radius: float = 0.0032) -> void:
	var pts := PackedVector3Array()
	for k in n + 1:
		var pn := K.point_normal(shape, lerpf(a0, a1, float(k) / n), t, center)
		pts.append(pn[0] + pn[1] * radius * 0.35)
	_tube(pts, radius, metal)


## Rolled edge along a = const.
func _edge_a(shape: Callable, a: float, t0: float, t1: float, n: int, center: Vector3, radius: float = 0.0032) -> void:
	var pts := PackedVector3Array()
	for k in n + 1:
		var pn := K.point_normal(shape, a, lerpf(t0, t1, float(k) / n), center)
		pts.append(pn[0] + pn[1] * radius * 0.35)
	_tube(pts, radius, metal)


func _rivet(shape: Callable, a: float, t: float, center: Vector3, d: float = 0.0075) -> void:
	var pn := K.point_normal(shape, a, t, center)
	_rivets.append(K.rivet_xform(pn[0], pn[1], d))


func _rivet_row(shape: Callable, a0: float, a1: float, t: float, count: int, center: Vector3, d: float = 0.0075) -> void:
	for k in count:
		_rivet(shape, lerpf(a0, a1, (k + 0.5) / count), t, center, d)


func _rivet_col(shape: Callable, a: float, t0: float, t1: float, count: int, center: Vector3, d: float = 0.0075) -> void:
	for k in count:
		_rivet(shape, a, lerpf(t0, t1, (k + 0.5) / count), center, d)


## Small brass buckle lying on the surface, long axis along `along`.
func _buckle(p: Vector3, n: Vector3, along: Vector3) -> void:
	if _torus == null:
		_torus = TorusMesh.new()
		_torus.inner_radius = 0.0055
		_torus.outer_radius = 0.0095
		_torus.rings = 12
		_torus.ring_segments = 6
	var y := n.normalized()
	var x := (along - y * along.dot(y)).normalized()
	var z := x.cross(y)
	var mi := MeshInstance3D.new()
	mi.mesh = _torus
	mi.material_override = brass
	mi.transform = Transform3D(Basis(x * 1.25, y * 0.45, z * 0.95), p + y * 0.002)
	_node.add_child(mi)
	# Tongue
	var tongue := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.013, 0.0025, 0.002)
	tongue.mesh = bm
	tongue.material_override = brass
	tongue.transform = Transform3D(Basis(x, y, z), p + y * 0.003)
	_node.add_child(tongue)


## Leather strap: a band offset from a shape, plus a buckle at a_buckle.
func _strap(shape: Callable, a0: float, a1: float, t0: float, t1: float, center: Vector3, a_buckle: float) -> void:
	_surf(shape, a0, a1, maxi(4, int(absf(a1 - a0) * 10.0)), t0, t1, 1, center, leather)
	var pn := K.point_normal(shape, a_buckle, (t0 + t1) * 0.5, center)
	var pa := K.point_normal(shape, a_buckle + 0.05, (t0 + t1) * 0.5, center)
	_buckle(pn[0], pn[1], pa[0] - pn[0])


# ==========================================================================
# Torso
# ==========================================================================

func _aventail() -> void:
	_begin("Aventail")
	var av := func(a: float, t: float) -> Vector3:
		var yb := CAPE_HEM_Y - 0.01 * pow(sin(a), 2.0) + 0.004 * sin(a * 31.0)
		var y := lerpf(NECK_Y, yb, t)
		var rx := K.catmull(t, [0.104, 0.112, 0.152, 0.248, 0.286, 0.296])
		var rz := K.catmull(t, [0.117, 0.122, 0.136, 0.156, 0.168, 0.175])
		return Vector3(rx * sin(a), y, rz * cos(a))
	_surf(av, 0.0, TAU, 80, 0.0, 1.0, 26, Vector3(0, NECK_Y + 0.06, 0), mail)
	_end()


func _breast_shape(push: float) -> Callable:
	return func(a: float, t: float) -> Vector3:
		var top := 1.548 - 0.032 * exp(-pow(a / 0.5, 2.0)) - 0.1 * smoothstep(1.05, 1.75, absf(a))
		var y := lerpf(BREAST_Y0, top, t)
		var p := torso_point(a, y, push)
		p.z += 0.006 * exp(-pow(a / 0.32, 2.0)) * smoothstep(BREAST_Y0, BREAST_Y0 + 0.25, y)
		return p


func _breastplate() -> void:
	_begin("Breastplate")
	var c := Vector3(0, 1.34, -0.05)
	var s := _breast_shape(0.0)
	_surf(s, -1.85, 1.85, 64, 0.0, 1.0, 34, c, metal)
	_edge(s, -1.85, 1.85, 1.0, 64, c, 0.0042)
	_edge(s, -1.85, 1.85, 0.0, 48, c)
	_edge_a(s, -1.85, 0.0, 1.0, 16, c)
	_edge_a(s, 1.85, 0.0, 1.0, 16, c)
	_rivet_row(s, -1.6, 1.6, 0.05, 13, c)
	_rivet_row(s, -0.35, 0.35, 0.93, 3, c, 0.008)
	for sx in SIDES:
		for y in [1.25, 1.385]:
			var band := func(a: float, t: float) -> Vector3:
				return torso_point(a, lerpf(y - 0.011, y + 0.011, t), 0.0045)
			_strap(band, sx * 1.66, sx * 2.04, 0.0, 1.0, Vector3(0, y, 0), sx * 1.7)
	_end()


func _backplate() -> void:
	_begin("Backplate")
	var c := Vector3(0, 1.34, 0.05)
	var s := func(a: float, t: float) -> Vector3:
		var top := 1.57 - 0.1 * smoothstep(0.85, 1.29, absf(a - PI))
		return torso_point(a, lerpf(BREAST_Y0, top, t), 0.002)
	_surf(s, 1.85, TAU - 1.85, 56, 0.0, 1.0, 34, c, metal)
	_edge(s, 1.85, TAU - 1.85, 1.0, 56, c, 0.0042)
	_edge(s, 1.85, TAU - 1.85, 0.0, 40, c)
	_rivet_row(s, 2.1, TAU - 2.1, 0.05, 9, c)
	_end()


func _fauld() -> void:
	_begin("Fauld")
	var c := Vector3(0, 1.1, 0)
	var lames := [[1.088, 1.15, 0.006], [1.042, 1.098, 0.013]]
	for l in lames:
		var y0: float = l[0]
		var y1: float = l[1]
		var push: float = l[2]
		var s := func(a: float, t: float) -> Vector3:
			return torso_point(a, lerpf(y0, y1, t), push)
		_surf(s, 0.0, TAU, 72, 0.0, 1.0, 6, c, metal)
		_edge(s, 0.0, TAU, 0.0, 72, c, 0.0035)
		_rivet_row(s, 0.0, TAU, 0.78, 22, c, 0.0065)
	_end()


func _belts() -> void:
	_begin("Belts")
	var c := Vector3(0, 1.1, 0)
	var waist := func(a: float, t: float) -> Vector3:
		return torso_point(a, lerpf(WAIST_Y - 0.014, WAIST_Y + 0.014, t), 0.017)
	_strap(waist, 0.0, TAU, 0.0, 1.0, c, 0.16)
	# Hip belt, slung lower on the left
	var hip := func(a: float, t: float) -> Vector3:
		var y := 1.062 + 0.028 * sin(a + 0.5) + lerpf(-0.012, 0.012, t)
		return skirt_point(a, y, 0.02)
	_strap(hip, 0.0, TAU, 0.0, 1.0, c, -0.3)
	# Hanging strap / frog on the left hip
	var hang := func(a: float, t: float) -> Vector3:
		return skirt_point(a, lerpf(1.07, 0.93, t), 0.012)
	_surf(hang, -0.55, -0.45, 2, 0.0, 1.0, 8, c, leather)
	var tip := K.point_normal(hang, -0.5, 1.0, c)
	_buckle(tip[0], tip[1], Vector3.UP)
	_end()


func _mail_skirt() -> void:
	_begin("Mail Skirt")
	var s := func(a: float, t: float) -> Vector3:
		var y := lerpf(1.1, HEM_Y + 0.005 * sin(a * 23.0), t)
		return skirt_point(a, y, 0.0)
	_surf(s, 0.0, TAU, 80, 0.0, 1.0, 22, Vector3(0, 1.05, 0), mail)
	_end()


func _arming_skirt() -> void:
	_begin("Arming Skirt")
	var s := func(a: float, t: float) -> Vector3:
		var y := lerpf(HEM_Y + 0.035, HEM_Y - 0.05 + 0.009 * sin(a * 11.0) + 0.005 * sin(a * 29.0), t)
		var r := skirt(HEM_Y + 0.004)
		var fold := 0.007 * sin(a * 17.0) + 0.004 * sin(a * 7.0 + 1.3)
		var fl := 0.004 + 0.026 * t + fold * t
		return Vector3(sin(a) * (r.x + fl), y, cos(a) * (r.y + fl))
	_surf(s, 0.0, TAU, 120, 0.0, 1.0, 8, Vector3(0, HEM_Y + 0.05, 0), linen)
	_end()


# ==========================================================================
# Arms
# ==========================================================================

func _mail_sleeves() -> void:
	_begin("Mail Sleeves")
	for sx in SIDES:
		var s := arm_tube(sx, SHOULDER_Y - 0.005, ELBOW_Y - 0.06, [0.056, 0.055, 0.052], [0.054, 0.053, 0.05])
		_surf(s, 0.0, TAU, 32, 0.0, 1.0, 16, arm_center(sx, 1.3), mail)
	_end()


func _rerebraces() -> void:
	_begin("Rerebraces")
	for sx in SIDES:
		var c := arm_center(sx, 1.36)
		var out: float = sx * PI * 0.5
		var lame := arm_tube(sx, SHOULDER_Y, SHOULDER_Y - 0.05, [0.068, 0.066], [0.065, 0.063])
		_surf(lame, 0.0, TAU, 36, 0.0, 1.0, 4, c, metal)
		_edge(lame, 0.0, TAU, 0.0, 36, c)
		_edge(lame, 0.0, TAU, 1.0, 36, c, 0.0025)
		var main := arm_tube(sx, SHOULDER_Y - 0.043, ELBOW_Y + 0.055, [0.064, 0.062, 0.059], [0.061, 0.059, 0.056])
		_surf(main, 0.0, TAU, 36, 0.0, 1.0, 14, c, metal)
		_edge(main, 0.0, TAU, 1.0, 36, c)
		_rivet_row(lame, out - 0.7, out + 0.7, 0.5, 3, c)
		_rivet_col(main, out + sx * 2.6, 0.1, 0.9, 3, c, 0.006)
	_end()


func _couters() -> void:
	_begin("Couters")
	for sx in SIDES:
		var c := arm_center(sx, ELBOW_Y)
		var out: float = sx * PI * 0.5
		var up := arm_tube(sx, ELBOW_Y + 0.078, ELBOW_Y + 0.035, [0.066, 0.064], [0.063, 0.061])
		_surf(up, 0.0, TAU, 36, 0.0, 1.0, 4, c, metal)
		_edge(up, 0.0, TAU, 1.0, 36, c)
		var lo := arm_tube(sx, ELBOW_Y - 0.032, ELBOW_Y - 0.072, [0.062, 0.06], [0.059, 0.057])
		_surf(lo, 0.0, TAU, 36, 0.0, 1.0, 4, c, metal)
		_edge(lo, 0.0, TAU, 0.0, 36, c)
		_rivet(up, out, 0.5, c)
		_rivet(lo, out, 0.5, c)
		# The cop over the point of the elbow
		var cup_c := c + Vector3(0, 0.002, -0.004)
		var cup := cap(cup_c, Vector3(sx * 0.25, -0.05, -1.0), 0.062, Vector3(1.0, 1.05, 1.0))
		_surf(cup, 0.0, TAU, 32, 0.0, 1.35, 12, cup_c, metal)
		_edge(cup, 0.0, TAU, 1.35, 32, cup_c)
		# Fan-shaped side wing
		var wn := Vector3(sx, 0.0, 0.18)
		var wc := c + Vector3(sx * 0.066, 0.0, 0.006)
		var wing := dish(wc, wn, 0.06, 0.016)
		_surf(wing, 0.0, TAU, 36, 0.0, 1.0, 8, func(_a: float, _t: float) -> Vector3: return wn, metal)
		_edge(wing, 0.0, TAU, 1.0, 36, wc - wn.normalized() * 0.1, 0.0036)
		var ring := PackedVector3Array()
		var wing_shape := dish(wc + wn.normalized() * 0.0015, wn, 0.06, 0.016)
		for k in 33:
			ring.append(wing_shape.call(TAU * k / 32.0, 0.55))
		_tube(ring, 0.0016, metal, 5)
		_rivets.append(K.rivet_xform(wc, wn.normalized(), 0.014))
	_end()


func _vambraces() -> void:
	_begin("Vambraces")
	for sx in SIDES:
		var c := arm_center(sx, 1.06)
		var out: float = sx * PI * 0.5
		var s := arm_tube(sx, ELBOW_Y - 0.058, WRIST_Y + 0.008, [0.056, 0.052, 0.046], [0.053, 0.049, 0.044])
		_surf(s, 0.0, TAU, 36, 0.0, 1.0, 16, c, metal)
		_edge(s, 0.0, TAU, 0.0, 36, c)
		_edge(s, 0.0, TAU, 1.0, 36, c)
		# Hinge line on the outside, closure rivets on the inside
		_edge_a(s, out, 0.04, 0.96, 10, c, 0.0018)
		_rivet_col(s, out, 0.05, 0.95, 3, c, 0.008)
		_rivet_col(s, -out, 0.1, 0.9, 2, c, 0.006)
	_end()


func _gauntlets() -> void:
	_begin("Gauntlets")
	for sx in SIDES:
		var c := arm_center(sx, 0.92)
		# Hourglass cuff flowing into the metacarpal plate
		var cuff := arm_tube(sx, WRIST_Y + 0.025, KNUCKLE_Y + 0.014,
			[0.065, 0.054, 0.045, 0.039, 0.033, 0.03],
			[0.06, 0.051, 0.044, 0.048, 0.052, 0.05])
		_surf(cuff, 0.0, TAU, 40, 0.0, 1.0, 22, c, metal)
		_edge(cuff, 0.0, TAU, 0.0, 40, c, 0.0035)
		_edge(cuff, 0.0, TAU, 1.0, 40, c, 0.003)
		# Beaded decorative band round the cuff
		_rivet_row(cuff, 0.0, TAU, 0.09, 26, c, 0.0055)
		var bead := PackedVector3Array()
		for k in 41:
			var pn := K.point_normal(cuff, TAU * k / 40.0, 0.16, c)
			bead.append(pn[0] + pn[1] * 0.001)
		_tube(bead, 0.0018, metal, 5)
		# Knuckle line
		var knuckle := arm_tube(sx, KNUCKLE_Y + 0.018, KNUCKLE_Y, [0.031, 0.03], [0.051, 0.049], 0.002)
		_surf(knuckle, 0.0, TAU, 32, 0.0, 1.0, 2, c, metal)
		_edge(knuckle, 0.0, TAU, 1.0, 32, c, 0.0028)

		var hc := arm_center(sx, KNUCKLE_Y)
		# Fingers: three lames each, gently curled toward the palm (inward)
		for f in 4:
			var fz := -0.027 + f * 0.018
			var p := hc + Vector3(sx * 0.004, 0.0, fz)
			var lengths := [0.036, 0.03, 0.025]
			var bends := [0.08, 0.28, 0.55]
			var r := 0.0118 - absf(f - 1.5) * 0.0006
			_rivets.append(K.rivet_xform(hc + Vector3(sx * 0.034, 0.008, fz), Vector3(sx, 0, 0), 0.006))
			for seg in 3:
				var b: float = bends[seg]
				var dir := Vector3(-sx * sin(b), -cos(b), 0.0)
				var l: float = lengths[seg] * (1.0 - absf(f - 1.5) * 0.08)
				var q: Vector3 = p + dir * l
				var pts := PackedVector3Array([p - dir * 0.002, p + dir * l * 0.5, q])
				_tube(pts, r * (1.0 - seg * 0.08), metal, 8)
				# Lame ridge
				var rr := PackedVector3Array()
				var nrm := Vector3(sx * cos(b), -sin(b), 0.0)
				for k in 7:
					var ang := lerpf(-1.4, 1.4, k / 6.0)
					var side := Vector3(0, 0, 1)
					rr.append(p + dir * 0.002 + (nrm * cos(ang) + side * sin(ang)) * r * (1.12 - seg * 0.08))
				_tube(rr, 0.0014, metal, 4)
				p = q
			var tip := MeshInstance3D.new()
			tip.mesh = K.rivet_mesh()
			tip.material_override = metal
			tip.transform = Transform3D(Basis.from_scale(Vector3.ONE * r * 1.7), p)
			_node.add_child(tip)
		# Thumb on the front of the hand
		var tp := hc + Vector3(-sx * 0.012, 0.044, 0.04)
		var tdirs := [Vector3(-sx * 0.2, -0.95, 0.22).normalized(), Vector3(-sx * 0.45, -0.88, 0.05).normalized()]
		var tl := [0.03, 0.025]
		for seg in 2:
			var d: Vector3 = tdirs[seg]
			var q: Vector3 = tp + d * float(tl[seg])
			_tube(PackedVector3Array([tp - d * 0.003, tp + d * float(tl[seg]) * 0.5, q]), 0.0112 - seg * 0.001, metal, 8)
			tp = q
		var ttip := MeshInstance3D.new()
		ttip.mesh = K.rivet_mesh()
		ttip.material_override = metal
		ttip.transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.018), tp)
		_node.add_child(ttip)
		# Leather palm and glove under the plates
		var palm := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.026, 0.05, 0.078)
		palm.mesh = pm
		palm.material_override = leather
		palm.position = hc + Vector3(-sx * 0.004, 0.042, 0.0)
		_node.add_child(palm)
		var glove := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = 0.034
		gm.bottom_radius = 0.031
		gm.height = 0.1
		glove.mesh = gm
		glove.material_override = leather
		glove.position = arm_center(sx, WRIST_Y - 0.03)
		_node.add_child(glove)
	_end()


# ==========================================================================
# Legs
# ==========================================================================

func _mail_chausses() -> void:
	_begin("Mail Chausses")
	for sx in SIDES:
		var s := leg_tube(sx, HIP_Y, KNEE_Y - 0.09, [0.084, 0.077, 0.064, 0.057], [0.083, 0.077, 0.068, 0.062], [0.0, 0.0, -0.004])
		_surf(s, 0.0, TAU, 32, 0.0, 1.0, 20, leg_center(sx, 0.7), mail)
	_end()


func _cuisses() -> void:
	_begin("Cuisses")
	for sx in SIDES:
		var c := leg_center(sx, 0.76)
		var y_top := HIP_Y
		var y_bot := KNEE_Y + 0.055
		var s := leg_tube(sx, y_top, y_bot, [0.088, 0.083, 0.077, 0.071], [0.09, 0.085, 0.079, 0.072], [0.004, 0.004, 0.006])
		_surf(s, -2.15, 2.15, 44, 0.0, 1.0, 22, c, metal)
		_edge(s, -2.15, 2.15, 0.0, 44, c, 0.0042)
		_edge(s, -2.15, 2.15, 1.0, 44, c)
		_edge_a(s, -2.15, 0.0, 1.0, 14, c)
		_edge_a(s, 2.15, 0.0, 1.0, 14, c)
		# Straps round the back of the thigh, over the mail
		var a_b: float = 2.04 if sx > 0 else TAU - 2.04
		for yr in [[0.85, 0.082], [0.705, 0.075]]:
			var y: float = yr[0]
			var r: float = yr[1] + 0.007
			var band := leg_tube(sx, y + 0.012, y - 0.012, [r], [r], [0.004])
			_strap(band, 1.98, TAU - 1.98, 0.0, 1.0, leg_center(sx, y), a_b)
			var tt := (y_top - y) / (y_top - y_bot)
			_rivet(s, sx * 2.0, tt, c)
			_rivet(s, -sx * 2.0, tt, c)
	_end()


func _poleyns() -> void:
	_begin("Poleyns")
	for sx in SIDES:
		var c := leg_center(sx, KNEE_Y)
		var up := leg_tube(sx, KNEE_Y + 0.09, KNEE_Y + 0.05, [0.078, 0.076], [0.079, 0.077], [0.004])
		_surf(up, -1.9, 1.9, 30, 0.0, 1.0, 4, c, metal)
		_edge(up, -1.9, 1.9, 1.0, 30, c)
		var lo := leg_tube(sx, KNEE_Y - 0.042, KNEE_Y - 0.077, [0.069, 0.067], [0.071, 0.069], [0.006])
		_surf(lo, -1.9, 1.9, 30, 0.0, 1.0, 4, c, metal)
		_edge(lo, -1.9, 1.9, 0.0, 30, c)
		_rivet(up, sx * 1.75, 0.5, c)
		_rivet(up, -sx * 1.75, 0.5, c)
		_rivet(lo, sx * 1.75, 0.5, c)
		_rivet(lo, -sx * 1.75, 0.5, c)
		var cup_c := c + Vector3(0, 0.003, 0.024)
		var cup := cap(cup_c, Vector3(0, 0, 1), 0.069, Vector3(1.0, 1.08, 0.95))
		_surf(cup, 0.0, TAU, 32, 0.0, 1.3, 12, cup_c, metal)
		_edge(cup, 0.0, TAU, 1.3, 32, cup_c)
		var wn := Vector3(sx, 0.0, 0.3)
		var wc := c + Vector3(sx * 0.064, 0.0, 0.01)
		var wing := dish(wc, wn, 0.048, 0.013)
		_surf(wing, 0.0, TAU, 32, 0.0, 1.0, 7, func(_a: float, _t: float) -> Vector3: return wn, metal)
		_edge(wing, 0.0, TAU, 1.0, 32, wc - wn.normalized() * 0.1, 0.0033)
		_rivets.append(K.rivet_xform(wc, wn.normalized(), 0.012))
	_end()


func _greaves() -> void:
	_begin("Greaves")
	for sx in SIDES:
		var c := leg_center(sx, 0.29) + Vector3(0, 0, -0.006)
		var out: float = sx * PI * 0.5
		var y0 := KNEE_Y - 0.053
		var s := leg_tube(sx, y0, 0.085,
			[0.064, 0.061, 0.055, 0.046, 0.039, 0.035, 0.04],
			[0.064, 0.069, 0.066, 0.053, 0.042, 0.037, 0.042],
			[0.0, -0.008, -0.012, -0.008, -0.002, 0.0, 0.0])
		_surf(s, 0.0, TAU, 40, 0.0, 1.0, 30, c, metal)
		_edge(s, 0.0, TAU, 0.0, 40, c, 0.004)
		_edge(s, 0.0, TAU, 1.0, 40, c, 0.0035)
		_edge_a(s, out, 0.03, 0.97, 14, c, 0.0018)
		_edge_a(s, -out, 0.03, 0.97, 14, c, 0.0018)
		_rivet_col(s, out, 0.05, 0.95, 4, c, 0.0075)
		var band := leg_tube(sx, 0.342, 0.318, [0.055], [0.066], [-0.011])
		_strap(band, 0.0, TAU, 0.0, 1.0, leg_center(sx, 0.33), -out)
	_end()


func _sabatons() -> void:
	_begin("Sabatons")
	var yc := 0.024
	for sx in SIDES:
		var cx: float = LEG_X * sx
		var c := Vector3(cx, 0.0, 0.08)
		var wk := [0.057, 0.058, 0.055, 0.049, 0.042, 0.035, 0.028]
		var hk := [0.086, 0.075, 0.06, 0.048, 0.04, 0.033, 0.027]
		# Laminated foot
		for k in 7:
			var z0 := -0.035 + k * 0.034
			var z1 := z0 + 0.04
			var lame := func(a: float, t: float) -> Vector3:
				var z := lerpf(z0, z1, t)
				var u := (z + 0.035) / 0.24
				var sc := lerpf(1.05, 0.97, t)
				var w := K.catmull(u, wk) * sc
				var h := K.catmull(u, hk) * sc
				return Vector3(cx + w * sin(a), yc + h * cos(a), z)
			_surf(lame, -1.8, 1.8, 24, 0.0, 1.0, 4, Vector3(cx, yc - 0.02, (z0 + z1) * 0.5), metal)
			_edge(lame, -1.8, 1.8, 0.0, 24, Vector3(cx, yc - 0.02, z0), 0.0028)
			_rivet(lame, 1.45, 0.45, Vector3(cx, yc - 0.02, z0), 0.0055)
			_rivet(lame, -1.45, 0.45, Vector3(cx, yc - 0.02, z0), 0.0055)
		# Pointed toe (poulaine)
		var w0 := K.catmull(1.0, wk) * 1.04
		var h0 := K.catmull(1.0, hk) * 1.04
		var toe := func(a: float, t: float) -> Vector3:
			var f := pow(1.0 - t, 0.85)
			var w := lerpf(0.0015, w0, f)
			var h := lerpf(0.0015, h0, f)
			return Vector3(cx + w * sin(a), lerpf(yc, yc + 0.012, t) + h * cos(a), lerpf(0.203, 0.3, t))
		_surf(toe, -1.8, 1.8, 24, 0.0, 1.0, 12, Vector3(cx, yc - 0.02, 0.22), metal)
		_edge(toe, -1.8, 1.8, 0.0, 24, Vector3(cx, yc - 0.02, 0.2), 0.0028)
		# Heel cup
		var heel := func(a: float, t: float) -> Vector3:
			return Vector3(cx + 0.056 * sin(a), lerpf(0.112, 0.012, t), -0.03 + 0.058 * cos(a))
		var hc := Vector3(cx, 0.06, -0.03)
		_surf(heel, PI - 1.7, PI + 1.7, 24, 0.0, 1.0, 8, hc, metal)
		_edge(heel, PI - 1.7, PI + 1.7, 0.0, 24, hc)
		_rivet(heel, PI + 1.4, 0.5, hc, 0.006)
		_rivet(heel, PI - 1.4, 0.5, hc, 0.006)
		# Leather sole
		var sole := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.08, 0.012, 0.27)
		sole.mesh = sm
		sole.material_override = leather
		sole.position = Vector3(cx, 0.006, 0.085)
		_node.add_child(sole)
	_end()


# ==========================================================================
# Cloth over the harness (off by default)
# ==========================================================================

func _surcoat() -> void:
	_begin("Surcoat")
	var s := func(a: float, t: float) -> Vector3:
		var y := lerpf(1.53, HEM_Y - 0.03 + 0.008 * sin(a * 9.0), t)
		var rx: float
		var rz: float
		if y > 1.1:
			var r := torso(y)
			rx = r.x
			rz = r.y if cos(a) >= 0.0 else r.z
		else:
			var r2 := skirt(maxf(y, HEM_Y))
			rx = r2.x + (HEM_Y - minf(y, HEM_Y)) * 0.4
			rz = r2.y + (HEM_Y - minf(y, HEM_Y)) * 0.4
		var push := 0.03 + 0.006 * sin(a * 14.0) * t
		return Vector3(sin(a) * (rx + push), y, cos(a) * (rz + push))
	_surf(s, 0.0, TAU, 80, 0.0, 1.0, 36, Vector3(0, 1.2, 0), cloth)
	_end()


func _cape() -> void:
	_begin("Cape")
	var s := func(a: float, t: float) -> Vector3:
		var y := lerpf(1.47, 0.35, t)
		var rx := lerpf(0.31, 0.44, t)
		var rz := lerpf(0.2, 0.33, t) + 0.012 * sin(a * 9.0) * t
		return Vector3(rx * sin(a), y, rz * cos(a))
	_surf(s, 2.2, TAU - 2.2, 48, 0.0, 1.0, 30, Vector3(0, 0.95, 0), cloth)
	_end()
