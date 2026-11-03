extends Node3D
## On-model handles for a ShapedHelmet:
##   "stretch"  down arrow on the front edge: drag down to lengthen the walls
##   "crown"    double arrow on top: drag up = pointed, drag down = flat top
## Handles draw on top of everything and are picked in screen space.

const PICK_RADIUS_PX := 26.0
const CROWN_DRAG_METRES := 0.08  # this much drag goes from round to fully pointed/flat

var helmet: Node3D
var hovered := ""

var _stretch: Node3D
var _crown: Node3D
var _mat: StandardMaterial3D
var _mat_hot: StandardMaterial3D


func _init(target: Node3D) -> void:
	helmet = target


func _ready() -> void:
	_mat = _make_mat(Color(1.0, 0.76, 0.3))
	_mat_hot = _make_mat(Color(1.0, 0.95, 0.75))
	_stretch = _arrow_handle(false, "Stretch")
	_crown = _arrow_handle(true, "Skew: pointed / flat")
	add_child(_stretch)
	add_child(_crown)
	visible = false


func _make_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.no_depth_test = true
	m.render_priority = 10
	return m


func _arrow_handle(double: bool, label: String) -> Node3D:
	var root := Node3D.new()
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0028
	cyl.bottom_radius = 0.0028
	cyl.height = 0.04 if double else 0.035
	shaft.mesh = cyl
	root.add_child(shaft)
	var tips := [-1.0, 1.0] if double else [-1.0]
	for s in tips:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0 if s > 0.0 else 0.011
		cm.bottom_radius = 0.011 if s > 0.0 else 0.0
		cm.height = 0.018
		cone.mesh = cm
		cone.position.y = s * (cyl.height * 0.5 + 0.009)
		root.add_child(cone)
	if not double:
		shaft.position.y = 0.0
	var tag := Label3D.new()
	tag.text = label
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0011
	tag.font_size = 22
	tag.outline_size = 6
	tag.modulate = Color(1.0, 0.9, 0.65)
	tag.render_priority = 11
	tag.outline_render_priority = 10
	tag.position = Vector3(0.0, 0.0, 0.0)
	tag.offset = Vector2(0, 58) if double else Vector2(0, -58)
	root.add_child(tag)
	return root


func _process(_delta: float) -> void:
	if not visible or helmet == null:
		return
	var h = helmet
	var g: float = h.grow()
	var xf: Transform3D = helmet.global_transform
	_stretch.global_position = xf * Vector3(0.0, h.bottom_y() - 0.03, h.RZ * g + 0.012)
	_crown.global_position = xf * Vector3(0.0, h.top_y() + 0.04, 0.0)
	_stretch.global_basis = xf.basis
	_crown.global_basis = xf.basis
	_tint(_stretch, hovered == "stretch")
	_tint(_crown, hovered == "crown")


func _tint(node: Node3D, hot: bool) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = _mat_hot if hot else _mat


## Which handle is under the mouse ("" for none).
func handle_at(cam: Camera3D, pos: Vector2) -> String:
	if not visible:
		return ""
	var best := ""
	var best_d := PICK_RADIUS_PX
	for pair in [["stretch", _stretch], ["crown", _crown]]:
		var n: Node3D = pair[1]
		if cam.is_position_behind(n.global_position):
			continue
		var d := cam.unproject_position(n.global_position).distance_to(pos)
		if d < best_d:
			best_d = d
			best = pair[0]
	return best


## Apply a mouse drag of `rel` pixels to a handle.
func drag(cam: Camera3D, handle: String, rel: Vector2) -> void:
	var h = helmet
	var node := _stretch if handle == "stretch" else _crown
	var up := helmet.global_basis.y.normalized()
	var axis := -up if handle == "stretch" else up
	var p0 := node.global_position
	var s0 := cam.unproject_position(p0)
	var s1 := cam.unproject_position(p0 + axis * 0.1)
	var dir := s1 - s0
	if dir.length_squared() < 1.0:
		return
	var metres := 0.1 * rel.dot(dir) / dir.length_squared()
	if handle == "stretch":
		h.set_shape(h.stretch + metres, h.crown)
	else:
		h.set_shape(h.stretch, h.crown + metres / CROWN_DRAG_METRES)
