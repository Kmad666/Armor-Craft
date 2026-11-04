extends Node3D
## Armor Craft - armour stand + helmet designer.
## Everything is built in code so the project stays tiny and easy to iterate on.

const HelmetBuilder := preload("res://scripts/helmet_builder.gd")
const HelmetPiece := preload("res://scripts/pieces/helmet_piece.gd")
const BASCINET_SCENE := preload("res://assets/pieces/helmet_bascinet.glb")
const ShapedHelmet := preload("res://scripts/pieces/shaped_helmet.gd")
const ShapeGizmo := preload("res://scripts/pieces/shape_gizmo.gd")
const Cuirass := preload("res://scripts/pieces/cuirass.gd")
const SuitBuilder := preload("res://scripts/suit_builder.gd")
const Mannequin := preload("res://scripts/pieces/mannequin.gd")
const MANNEQUIN_SCENE := preload("res://assets/mannequin/mannequin_wood.glb")
const WOOD_SHADER := preload("res://shaders/wood.gdshader")
const METAL_SHADER := preload("res://shaders/metal.gdshader")
const MAIL_SHADER := preload("res://shaders/mail.gdshader")

const FINISHES := [
	{"name": "Armour Steel", "color": Color(0.72, 0.73, 0.75), "metal": 0.88, "rough": 0.34, "patina": 0.55, "mail": Color(0.6, 0.6, 0.62)},
	{"name": "Polished Steel", "color": Color(0.84, 0.86, 0.89), "metal": 0.92, "rough": 0.2, "patina": 0.2, "mail": Color(0.7, 0.71, 0.74)},
	{"name": "Blackened Steel", "color": Color(0.2, 0.2, 0.22), "metal": 0.75, "rough": 0.48, "patina": 0.45, "mail": Color(0.25, 0.25, 0.27)},
	{"name": "Brass", "color": Color(0.82, 0.64, 0.34), "metal": 0.88, "rough": 0.34, "patina": 0.5, "mail": Color(0.6, 0.6, 0.62)},
	{"name": "Gilded", "color": Color(0.98, 0.8, 0.4), "metal": 0.92, "rough": 0.24, "patina": 0.25, "mail": Color(0.85, 0.7, 0.38)},
	{"name": "Rusted Iron", "color": Color(0.47, 0.29, 0.17), "metal": 0.35, "rough": 0.85, "patina": 1.0, "mail": Color(0.42, 0.27, 0.17)},
]

const HELMET_PRESETS := {
	"Hounskull Bascinet": {"width": 0.122, "depth": 0.136, "height": 0.268, "dome": 0.62, "taper": 0.97, "flare": 0.0,
		"snout": 0.15, "apex": 0.75, "visor": true, "breaths": true,
		"slit_style": 1, "slit_count": 1, "slit_w": 0.62, "slit_thick": 0.024, "slit_y": 0.6, "plume": false, "rim": true},
	"Great Helm": {"width": 0.128, "depth": 0.142, "height": 0.27, "dome": 0.22, "taper": 0.95, "flare": 0.0, "snout": 0.0,
		"apex": 0.0, "visor": false, "breaths": false,
		"slit_style": 0, "slit_count": 2, "slit_w": 0.55, "slit_thick": 0.024, "slit_y": 0.62, "plume": false, "rim": true},
	"Barbute": {"width": 0.122, "depth": 0.137, "height": 0.27, "dome": 0.6, "taper": 1.0, "flare": 0.0, "snout": 0.0,
		"apex": 0.15, "visor": false, "breaths": false,
		"slit_style": 2, "slit_count": 1, "slit_w": 0.42, "slit_thick": 0.035, "slit_y": 0.6, "plume": false, "rim": true},
	"Sallet": {"width": 0.122, "depth": 0.142, "height": 0.25, "dome": 0.55, "taper": 1.0, "flare": 0.35, "snout": 0.0,
		"apex": 0.0, "visor": false, "breaths": false,
		"slit_style": 0, "slit_count": 1, "slit_w": 0.75, "slit_thick": 0.02, "slit_y": 0.62, "plume": true, "rim": true},
	"Grilled Bascinet": {"width": 0.122, "depth": 0.137, "height": 0.275, "dome": 0.5, "taper": 0.97, "flare": 0.0, "snout": 0.04,
		"apex": 0.45, "visor": false, "breaths": false,
		"slit_style": 3, "slit_count": 7, "slit_w": 0.6, "slit_thick": 0.02, "slit_y": 0.64, "plume": true, "rim": true},
}

## name, key, min, max, step
const HELMET_SLIDERS := [
	["Width", "width", 0.10, 0.20, 0.001],
	["Depth", "depth", 0.10, 0.22, 0.001],
	["Height", "height", 0.20, 0.42, 0.001],
	["Dome", "dome", 0.10, 0.90, 0.01],
	["Apex", "apex", 0.0, 1.0, 0.01],
	["Taper", "taper", 0.70, 1.15, 0.01],
	["Brim Flare", "flare", 0.0, 0.60, 0.01],
	["Snout", "snout", 0.0, 0.2, 0.002],
]
const VISOR_SLIDERS := [
	["Slit Count", "slit_count", 1, 9, 1],
	["Slit Width", "slit_w", 0.15, 1.0, 0.01],
	["Slit Thickness", "slit_thick", 0.008, 0.06, 0.001],
	["Slit Height", "slit_y", 0.40, 0.85, 0.005],
]
const HELMET_TOGGLES := [["Pig-Face Visor", "visor"], ["Breaths", "breaths"], ["Plume", "plume"], ["Rolled Rim", "rim"]]

## Rim height of the procedural (legacy) helmet.
const HELMET_Y := 1.545
## Modelled helmet sliders: label, morph, min, max ("Visor" opens the hinge).
const MODEL_SLIDERS := [
	["Width", "Width", -1.0, 1.0],
	["Height", "Height", -1.0, 1.0],
	["Apex", "Apex", -0.6, 1.0],
	["Snout", "Snout", -0.8, 1.0],
	["Visor Raised", "Visor", 0.0, 1.0],
]

var camera: Camera3D
var yaw := 0.55
var pitch := 0.1
var distance := 3.3
var focus := Vector3(0, 1.0, 0)
var target_focus := focus
var target_distance := distance
var dragging := false
var turntable := false

var body_mat: StandardMaterial3D
var hose_mat: StandardMaterial3D
var metal_mat: ShaderMaterial
var mail_mat: ShaderMaterial
var cloth_mat: StandardMaterial3D
var leather_mat: StandardMaterial3D
var linen_mat: StandardMaterial3D
var brass_mat: StandardMaterial3D
var dark_mat: StandardMaterial3D

var head_node: Node3D
var mannequin: Node3D
var suit_root: Node3D
var wood_mat: ShaderMaterial
var wood_dark_mat: ShaderMaterial
var helmet_node: Node3D
var modeled_helmet: Node3D
var spangenhelm: Node3D
var gizmo: Node3D
var helmet_selected := false
var press_pos := Vector2.ZERO
var press_moved := false
var drag_handle := ""
var shape_sliders := {}
var helm_mat: ShaderMaterial
var cuirass: Node3D
var hole_mode := false
var hole_shape := 0
var hole_w := 0.009
var hole_h := 0.009
var hole_mirror := true
var hole_ui := {}
var helmet_mode := 0  # 0 = spangenhelm, 1 = modelled bascinet, 2 = procedural designer
var model_controls := {}
var groups := {}
var group_checks := {}
var wear_helmet := true

var helmet_params: Dictionary = {}
var helmet_controls := {}
var helmet_toggles := {}
var finish_option: OptionButton
var preset_option: OptionButton
var style_option: OptionButton
var cloth_picker: ColorPickerButton


func _ready() -> void:
	randomize()
	_build_environment()
	_build_materials()
	_build_mannequin()
	suit_root = Node3D.new()
	suit_root.name = "Suit"
	suit_root.visible = false  # legacy procedural suit; pieces are being modelled one by one
	add_child(suit_root)
	groups = SuitBuilder.new(suit_root, {
		"metal": metal_mat, "mail": mail_mat, "leather": leather_mat,
		"linen": linen_mat, "cloth": cloth_mat, "brass": brass_mat,
	}).build()
	helmet_params = HELMET_PRESETS["Hounskull Bascinet"].duplicate()
	modeled_helmet = HelmetPiece.new()
	modeled_helmet.name = "ModeledHelmet"
	# Helmets are authored around the centre of the head at eye level: the head socket.
	mannequin.node("Socket_Head").add_child(modeled_helmet)
	modeled_helmet.setup(BASCINET_SCENE, {"Steel": metal_mat, "Leather": leather_mat})
	spangenhelm = ShapedHelmet.new()
	spangenhelm.name = "Spangenhelm"
	mannequin.node("Socket_Head").add_child(spangenhelm)
	# own copy of the steel so its holes don't cut other pieces
	helm_mat = ShaderMaterial.new()
	helm_mat.shader = METAL_SHADER
	spangenhelm.setup(helm_mat)
	cuirass = Cuirass.new()
	cuirass.name = "Cuirass"
	add_child(cuirass)
	cuirass.setup({"metal": metal_mat, "leather": leather_mat, "brass": brass_mat},
		mannequin.measurements, mannequin.node("Chest"), mannequin.node("Pelvis"))
	gizmo = ShapeGizmo.new(spangenhelm)
	gizmo.name = "ShapeGizmo"
	add_child(gizmo)
	_rebuild_helmet()
	_build_ui()
	_apply_finish(0)


# --------------------------------------------------------------------------
# World
# --------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.21, 0.24)
	sky_mat.sky_horizon_color = Color(0.46, 0.44, 0.42)
	sky_mat.ground_bottom_color = Color(0.17, 0.17, 0.18)
	sky_mat.ground_horizon_color = Color(0.4, 0.38, 0.36)
	sky_mat.sky_curve = 0.35
	sky_mat.ground_curve = 0.35
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.29, 0.29, 0.3)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-38), deg_to_rad(28), 0)
	key.light_energy = 1.15
	key.light_color = Color(1.0, 0.96, 0.9)
	key.shadow_enabled = true
	key.shadow_bias = 0.05
	key.shadow_normal_bias = 1.3
	key.shadow_blur = 2.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_max_distance = 4.5
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-15), deg_to_rad(-60), 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.85, 0.9, 1.0)
	add_child(fill)

	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-25), deg_to_rad(190), 0)
	rim.light_energy = 0.7
	rim.light_color = Color(0.9, 0.93, 1.0)
	add_child(rim)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.27, 0.27, 0.28)
	floor_mat.roughness = 0.95
	var floor_mi := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.6
	pm.bottom_radius = 0.62
	pm.height = 0.04
	floor_mi.mesh = pm
	floor_mi.material_override = floor_mat
	floor_mi.position = Vector3(0, -0.02, 0.04)
	add_child(floor_mi)

	camera = Camera3D.new()
	camera.fov = 38
	add_child(camera)
	_update_camera()


func _build_materials() -> void:
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.72, 0.66, 0.55)
	body_mat.roughness = 0.95
	hose_mat = StandardMaterial3D.new()
	hose_mat.albedo_color = Color(0.2, 0.17, 0.15)
	hose_mat.roughness = 0.95

	metal_mat = ShaderMaterial.new()
	metal_mat.shader = METAL_SHADER
	mail_mat = ShaderMaterial.new()
	mail_mat.shader = MAIL_SHADER

	cloth_mat = StandardMaterial3D.new()
	cloth_mat.albedo_color = Color(0.5, 0.08, 0.08)
	cloth_mat.roughness = 0.95
	cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	linen_mat = StandardMaterial3D.new()
	linen_mat.albedo_color = Color(0.45, 0.42, 0.36)
	linen_mat.roughness = 0.97
	linen_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	leather_mat = StandardMaterial3D.new()
	leather_mat.albedo_color = Color(0.22, 0.135, 0.075)
	leather_mat.roughness = 0.72
	leather_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	brass_mat = StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.78, 0.6, 0.32)
	brass_mat.metallic = 0.9
	brass_mat.roughness = 0.35

	dark_mat = StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.01, 0.01, 0.012)
	dark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _apply_finish(idx: int) -> void:
	var f: Dictionary = FINISHES[idx]
	metal_mat.set_shader_parameter("albedo", f["color"])
	metal_mat.set_shader_parameter("metallic", f["metal"])
	metal_mat.set_shader_parameter("roughness", f["rough"])
	metal_mat.set_shader_parameter("patina", f["patina"])
	if helm_mat:
		for k in ["albedo", "metallic", "roughness", "patina"]:
			helm_mat.set_shader_parameter(k, metal_mat.get_shader_parameter(k))
	mail_mat.set_shader_parameter("albedo", f["mail"])
	mail_mat.set_shader_parameter("metallic", f["metal"])


# --------------------------------------------------------------------------
# Mannequin: carved wooden figure built in Blender from measurements.json
# --------------------------------------------------------------------------

func _build_mannequin() -> void:
	wood_mat = ShaderMaterial.new()
	wood_mat.shader = WOOD_SHADER
	wood_dark_mat = ShaderMaterial.new()
	wood_dark_mat.shader = WOOD_SHADER
	wood_dark_mat.set_shader_parameter("light_col", Color(0.17, 0.09, 0.04))
	wood_dark_mat.set_shader_parameter("dark_col", Color(0.1, 0.05, 0.022))
	mannequin = Mannequin.new()
	mannequin.name = "Mannequin"
	add_child(mannequin)
	mannequin.setup(MANNEQUIN_SCENE, {"Wood": wood_mat, "WoodDark": wood_dark_mat})
	head_node = mannequin.node("HeadBlock")


func _rebuild_helmet() -> void:
	if helmet_node:
		helmet_node.queue_free()
	helmet_node = HelmetBuilder.build(helmet_params, metal_mat, dark_mat, cloth_mat)
	helmet_node.position = Vector3(0, HELMET_Y, 0)
	add_child(helmet_node)
	_update_helmet_visibility()


func _update_helmet_visibility() -> void:
	if helmet_node:
		helmet_node.visible = wear_helmet and helmet_mode == 2
	if spangenhelm:
		spangenhelm.visible = wear_helmet and helmet_mode == 0
		if not spangenhelm.visible:
			_set_helmet_selected(false)
	if modeled_helmet:
		modeled_helmet.visible = wear_helmet and helmet_mode == 1
	# The modelled helmet has a real face opening, so keep the head inside it.
	head_node.visible = not wear_helmet or helmet_mode != 2


# --------------------------------------------------------------------------
# Camera
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if turntable and not dragging:
		yaw += delta * 0.5
	focus = focus.lerp(target_focus, minf(1.0, delta * 6.0))
	distance = lerpf(distance, target_distance, minf(1.0, delta * 6.0))
	_update_camera()


func _update_camera() -> void:
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.position = focus + dir * distance
	camera.look_at(focus, Vector3.UP)
	# Shift the subject left so it isn't hidden behind the side panel.
	camera.h_offset = distance * 0.13


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				press_pos = mb.position
				press_moved = false
				drag_handle = gizmo.handle_at(camera, mb.position) if helmet_selected else ""
				dragging = drag_handle == ""
			else:
				if drag_handle == "" and not press_moved:
					_click(mb.position)
				drag_handle = ""
				dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			target_distance = maxf(0.35, target_distance * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			target_distance = minf(6.0, target_distance * 1.1)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.position.distance_to(press_pos) > 4.0:
			press_moved = true
		if drag_handle != "":
			gizmo.drag(camera, drag_handle, mm.relative)
		elif dragging:
			yaw -= mm.relative.x * 0.008
			pitch = clampf(pitch + mm.relative.y * 0.006, -0.6, 1.2)
		elif hole_mode:
			_update_hole_preview(mm.position)
		elif helmet_selected:
			gizmo.hovered = gizmo.handle_at(camera, mm.position)


## A click (press + release without dragging): select or deselect the helmet.
func _click(pos: Vector2) -> void:
	if hole_mode:
		if not spangenhelm.visible:
			return
		var hp = spangenhelm.hit_local(camera.project_ray_origin(pos), camera.project_ray_normal(pos))
		if hp != null and not spangenhelm.remove_hole_at(hp):
			spangenhelm.add_hole(hp, hole_shape, hole_w, hole_h, hole_mirror)
		_update_hole_preview(pos)
		return
	var hit: bool = spangenhelm.visible and spangenhelm.ray_hits(
		camera.project_ray_origin(pos), camera.project_ray_normal(pos))
	_set_helmet_selected(hit)


func _set_helmet_selected(on: bool) -> void:
	if on == helmet_selected:
		return
	helmet_selected = on
	spangenhelm.set_selected(on)
	gizmo.visible = on
	gizmo.hovered = ""
	if on:
		target_focus = Vector3(0, 1.74, 0)
		target_distance = minf(target_distance, 1.25)


# --------------------------------------------------------------------------
# UI
# --------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "ARMOR CRAFT"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.93, 0.78, 0.45))
	title.position = Vector2(22, 14)
	layer.add_child(title)

	var hint := Label.new()
	hint.text = "v0.10  -  drag to orbit, scroll to zoom"
	hint.add_theme_color_override("font_color", Color(0.85, 0.83, 0.8))
	hint.position = Vector2(24, 56)
	layer.add_child(hint)

	var turn := CheckBox.new()
	turn.text = "Turntable"
	turn.position = Vector2(20, 82)
	turn.toggled.connect(func(on: bool) -> void: turntable = on)
	layer.add_child(turn)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -340
	panel.offset_right = -12
	panel.offset_top = 12
	panel.offset_bottom = -12
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.09, 0.9)
	sb.border_color = Color(0.6, 0.48, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)

	var tabs := TabContainer.new()
	panel.add_child(tabs)
	tabs.tab_changed.connect(_on_tab_changed)

	_build_body_tab(_make_tab(tabs, "Body"))
	_build_suit_tab(_make_tab(tabs, "Suit"))
	_build_helmet_tab(_make_tab(tabs, "Helmet"))
	_build_cuirass_tab(_make_tab(tabs, "Cuirass"))


func _make_tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	return box


func _header(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_color_override("font_color", Color(0.93, 0.78, 0.45))
	l.add_theme_font_size_override("font_size", 15)
	parent.add_child(l)


func _build_body_tab(box: VBoxContainer) -> void:
	_header(box, "Wooden Mannequin")
	var note := Label.new()
	note.text = "Every armour piece is fitted to this figure. Measurements from your outline:"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(280, 0)
	note.add_theme_color_override("font_color", Color(0.8, 0.78, 0.74))
	box.add_child(note)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	box.add_child(grid)
	for row in mannequin.summary():
		var metres: float = row[1]
		var name_l := Label.new()
		name_l.text = row[0]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_l)
		var cm := Label.new()
		cm.text = "%.1f cm" % (metres * 100.0)
		cm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(cm)
		var inch := Label.new()
		inch.text = "%.1f in" % (metres / 0.0254)
		inch.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		inch.add_theme_color_override("font_color", Color(0.65, 0.63, 0.6))
		grid.add_child(inch)

	_header(box, "Show")
	var show_suit := CheckBox.new()
	show_suit.text = "Legacy procedural suit"
	show_suit.toggled.connect(func(v: bool) -> void: suit_root.visible = v)
	box.add_child(show_suit)


func _build_cuirass_tab(box: VBoxContainer) -> void:
	_header(box, "Gothic Cuirass")
	var note := Label.new()
	note.text = "Mid section: fluted breastplate and backplate. Bottom section: the fauld of overlapping lames. The belt marks the division."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(280, 0)
	note.add_theme_color_override("font_color", Color(0.8, 0.78, 0.74))
	box.add_child(note)
	_header(box, "Pieces")
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for pair in [["Breastplate", "Breastplate"], ["Backplate", "Backplate"], ["Fauld", "Fauld"], ["Belt & Straps", "Belt"]]:
		var key: String = pair[1]
		var cb := CheckBox.new()
		cb.text = pair[0]
		cb.button_pressed = true
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.toggled.connect(func(v: bool) -> void: (cuirass.pieces[key] as Node3D).visible = v)
		grid.add_child(cb)
	_header(box, "Details")
	var flutes := CheckBox.new()
	flutes.text = "Fluting"
	flutes.button_pressed = true
	flutes.toggled.connect(func(v: bool) -> void: cuirass.set_fluting(v))
	box.add_child(flutes)
	var lbl := Label.new()
	lbl.text = "Fauld lames: %d" % cuirass.lames
	box.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = 1
	sl.max_value = 7
	sl.step = 1
	sl.value = cuirass.lames
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(v: float) -> void:
		cuirass.set_lames(int(v))
		lbl.text = "Fauld lames: %d" % int(v))
	box.add_child(sl)


func _build_suit_tab(box: VBoxContainer) -> void:
	_header(box, "Metal Finish")
	finish_option = OptionButton.new()
	for f in FINISHES:
		finish_option.add_item(f["name"])
	finish_option.item_selected.connect(_apply_finish)
	box.add_child(finish_option)

	for section in [["Plate", SuitBuilder.PLATE_GROUPS], ["Mail", SuitBuilder.MAIL_GROUPS],
			["Cloth & Leather", SuitBuilder.SOFT_GROUPS]]:
		_header(box, section[0])
		var grid := GridContainer.new()
		grid.columns = 2
		box.add_child(grid)
		for g in section[1]:
			_group_check(grid, g, not SuitBuilder.OFF_BY_DEFAULT.has(g))

	var row := HBoxContainer.new()
	box.add_child(row)
	var cl := Label.new()
	cl.text = "Cloth Colour"
	row.add_child(cl)
	cloth_picker = ColorPickerButton.new()
	cloth_picker.color = cloth_mat.albedo_color
	cloth_picker.custom_minimum_size = Vector2(90, 30)
	cloth_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cloth_picker.edit_alpha = false
	cloth_picker.color_changed.connect(func(c: Color) -> void: cloth_mat.albedo_color = c)
	row.add_child(cloth_picker)

	var rnd := Button.new()
	rnd.text = "Forge Random Suit"
	rnd.pressed.connect(_randomize_suit)
	box.add_child(rnd)


func _group_check(parent: Control, group: String, on: bool) -> void:
	var cb := CheckBox.new()
	cb.text = group
	cb.button_pressed = on
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb.toggled.connect(func(v: bool) -> void: _set_group_visible(group, v))
	parent.add_child(cb)
	group_checks[group] = cb
	_set_group_visible(group, on)


func _set_group_visible(group: String, on: bool) -> void:
	if groups.has(group):
		(groups[group] as Node3D).visible = on


func _build_helmet_tab(box: VBoxContainer) -> void:
	var wear := CheckBox.new()
	wear.text = "Wear Helmet"
	wear.button_pressed = true
	wear.toggled.connect(func(v: bool) -> void:
		wear_helmet = v
		_update_helmet_visibility())
	box.add_child(wear)

	_header(box, "Helmet")
	var model_option := OptionButton.new()
	model_option.add_item("Spangenhelm")
	model_option.add_item("Hounskull Bascinet")
	model_option.add_item("Procedural Designer")
	box.add_child(model_option)

	var shaped := VBoxContainer.new()
	shaped.add_theme_constant_override("separation", 6)
	box.add_child(shaped)
	_build_shape_controls(shaped)

	var modeled := VBoxContainer.new()
	modeled.add_theme_constant_override("separation", 6)
	modeled.visible = false
	box.add_child(modeled)
	_header(modeled, "Morph")
	for spec in MODEL_SLIDERS:
		_model_slider(modeled, spec)
	var reset := Button.new()
	reset.text = "Reset Shape"
	reset.pressed.connect(func() -> void:
		for spec in MODEL_SLIDERS:
			(model_controls[spec[1]] as HSlider).value = 0.0)
	modeled.add_child(reset)

	var proc := VBoxContainer.new()
	proc.add_theme_constant_override("separation", 6)
	proc.visible = false
	box.add_child(proc)
	model_option.item_selected.connect(func(i: int) -> void:
		helmet_mode = i
		shaped.visible = i == 0
		if i != 0 and hole_mode:
			_set_hole_mode(false)
		modeled.visible = i == 1
		proc.visible = i == 2
		_update_helmet_visibility())

	_header(proc, "Preset")
	preset_option = OptionButton.new()
	for k in HELMET_PRESETS.keys():
		preset_option.add_item(k)
	preset_option.item_selected.connect(_on_preset)
	proc.add_child(preset_option)

	_header(proc, "Shape")
	for s in HELMET_SLIDERS:
		_helmet_slider(proc, s)

	_header(proc, "Visor & Slits")
	style_option = OptionButton.new()
	for st in HelmetBuilder.SLIT_STYLES:
		style_option.add_item(st)
	style_option.item_selected.connect(func(i: int) -> void:
		helmet_params["slit_style"] = i
		_rebuild_helmet())
	proc.add_child(style_option)
	for s in VISOR_SLIDERS:
		_helmet_slider(proc, s)

	_header(proc, "Features")
	var grid := GridContainer.new()
	grid.columns = 2
	proc.add_child(grid)
	for tg in HELMET_TOGGLES:
		var key: String = tg[1]
		var cb := CheckBox.new()
		cb.text = tg[0]
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.toggled.connect(func(v: bool) -> void:
			helmet_params[key] = v
			_rebuild_helmet())
		grid.add_child(cb)
		helmet_toggles[key] = cb

	var rnd := Button.new()
	rnd.text = "Forge Random Helmet"
	rnd.pressed.connect(_randomize_helmet)
	proc.add_child(rnd)

	_sync_helmet_ui()


func _build_shape_controls(box: VBoxContainer) -> void:
	var hint := Label.new()
	hint.text = "Click the helmet to grab its handles: drag the down arrow to stretch it, the top arrow to skew it pointed or flat."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(280, 0)
	hint.add_theme_color_override("font_color", Color(0.8, 0.78, 0.74))
	box.add_child(hint)

	_header(box, "Shape")
	var presets := HBoxContainer.new()
	box.add_child(presets)
	for pr in [["Dome", 0.0, 0.0], ["Pointed", 0.0, 1.0], ["Bucket", 0.135, -1.0]]:
		var b := Button.new()
		b.text = pr[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st: float = pr[1]
		var cr: float = pr[2]
		b.pressed.connect(func() -> void: spangenhelm.set_shape(st, cr))
		presets.add_child(b)

	for spec in [["Stretch", "stretch", 0.0, ShapedHelmet.MAX_STRETCH], ["Skew", "crown", -1.0, 1.0]]:
		var lbl := Label.new()
		box.add_child(lbl)
		var sl := HSlider.new()
		sl.min_value = spec[2]
		sl.max_value = spec[3]
		sl.step = 0.001
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(sl)
		var key: String = spec[1]
		sl.value_changed.connect(func(v: float) -> void:
			if key == "stretch":
				spangenhelm.set_shape(v, spangenhelm.crown)
			else:
				spangenhelm.set_shape(spangenhelm.stretch, v))
		shape_sliders[key] = [sl, lbl]
	spangenhelm.shape_changed.connect(_sync_shape_ui)
	_sync_shape_ui()
	_build_hole_controls(box)


func _update_hole_preview(pos: Vector2) -> void:
	var hp = null
	if hole_mode and spangenhelm.visible:
		hp = spangenhelm.hit_local(camera.project_ray_origin(pos), camera.project_ray_normal(pos))
	spangenhelm.set_preview(hp, hole_shape, hole_w, hole_h)


func _set_hole_mode(on: bool) -> void:
	hole_mode = on
	if on:
		_set_helmet_selected(false)
		target_focus = Vector3(0, 1.72, 0)
		target_distance = minf(target_distance, 1.1)
	else:
		spangenhelm.set_preview(null, 0, 0.0, 0.0)
	var b: Button = hole_ui["toggle"]
	b.set_pressed_no_signal(on)
	b.text = "Adding Holes: click the helmet (click a hole to remove)" if on else "Add Holes"


const HOLE_SHAPES := [
	# name, default width, default height, width range, height range
	["Round", 0.009, 0.009, [0.004, 0.03], [0.004, 0.03]],
	["Slot", 0.048, 0.01, [0.015, 0.12], [0.004, 0.03]],
	["Cross", 0.022, 0.006, [0.01, 0.05], [0.003, 0.015]],
]


func _build_hole_controls(box: VBoxContainer) -> void:
	_header(box, "Holes")
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.text = "Add Holes"
	toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toggle.toggled.connect(_set_hole_mode)
	box.add_child(toggle)
	hole_ui["toggle"] = toggle

	var row := HBoxContainer.new()
	box.add_child(row)
	var shape_opt := OptionButton.new()
	for hs in HOLE_SHAPES:
		shape_opt.add_item(hs[0])
	shape_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(shape_opt)
	var mirror := CheckBox.new()
	mirror.text = "Mirror"
	mirror.button_pressed = true
	mirror.toggled.connect(func(v: bool) -> void: hole_mirror = v)
	row.add_child(mirror)

	for key in ["w", "h"]:
		var lbl := Label.new()
		box.add_child(lbl)
		var sl := HSlider.new()
		sl.step = 0.0005
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(sl)
		hole_ui[key] = [sl, lbl]
		sl.value_changed.connect(func(v: float) -> void:
			if key == "w":
				hole_w = v
			else:
				hole_h = v
			_sync_hole_labels())
	shape_opt.item_selected.connect(_select_hole_shape)
	_select_hole_shape(0)

	var quick := HBoxContainer.new()
	box.add_child(quick)
	for q in [["Eye Slits", _add_eye_slits], ["Breaths", _add_breaths]]:
		var b := Button.new()
		b.text = q[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(q[1])
		quick.add_child(b)
	var edit := HBoxContainer.new()
	box.add_child(edit)
	for q in [["Undo Hole", func() -> void: spangenhelm.undo_hole()], ["Clear Holes", func() -> void: spangenhelm.clear_holes()]]:
		var b := Button.new()
		b.text = q[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(q[1])
		edit.add_child(b)


func _select_hole_shape(i: int) -> void:
	hole_shape = i
	var hs: Array = HOLE_SHAPES[i]
	var w: Array = hole_ui["w"]
	var h: Array = hole_ui["h"]
	# set ranges first (changing a range can clamp the value and fire the slider)
	(w[0] as HSlider).min_value = hs[3][0]
	(w[0] as HSlider).max_value = hs[3][1]
	(h[0] as HSlider).min_value = hs[4][0]
	(h[0] as HSlider).max_value = hs[4][1]
	hole_w = hs[1]
	hole_h = hs[2]
	(w[0] as HSlider).set_value_no_signal(hole_w)
	(h[0] as HSlider).set_value_no_signal(hole_h)
	(h[0] as HSlider).visible = i != 0
	(h[1] as Label).visible = i != 0
	_sync_hole_labels()


func _sync_hole_labels() -> void:
	var w_name := "Diameter" if hole_shape == 0 else ("Length" if hole_shape == 1 else "Arm length")
	(hole_ui["w"][1] as Label).text = "%s: %.1f cm" % [w_name, hole_w * 100.0]
	(hole_ui["h"][1] as Label).text = "%s: %.1f cm" % ["Width" if hole_shape == 1 else "Arm width", hole_h * 100.0]


## Two slots at eye level (stretches the helmet over the eyes if needed).
func _add_eye_slits() -> void:
	if spangenhelm.stretch < 0.06:
		spangenhelm.set_shape(0.06, spangenhelm.crown)
	spangenhelm.add_hole_set([[0.36, 0.0, 1, 0.05, 0.0095]], true)


## Rows of round breathing holes over the mouth and cheeks.
func _add_breaths() -> void:
	if spangenhelm.stretch < 0.13:
		spangenhelm.set_shape(0.135, spangenhelm.crown)
	var set := []
	for row in 4:
		var y := -0.05 - row * 0.014
		for col in 5 - row:
			set.append([0.42 + col * 0.11 + row * 0.03, y, 0, 0.0075, 0.0075])
	spangenhelm.add_hole_set(set, true)


func _sync_shape_ui() -> void:
	var st: Array = shape_sliders["stretch"]
	(st[0] as HSlider).set_value_no_signal(spangenhelm.stretch)
	(st[1] as Label).text = "Stretch: %d cm below the brow" % roundi(spangenhelm.stretch * 100.0)
	var cr: Array = shape_sliders["crown"]
	(cr[0] as HSlider).set_value_no_signal(spangenhelm.crown)
	var c: float = spangenhelm.crown
	var word := "Round"
	if c > 0.05:
		word = "Pointed %d%%" % roundi(c * 100.0)
	elif c < -0.05:
		word = "Flat %d%%" % roundi(-c * 100.0)
	(cr[1] as Label).text = "Skew: " + word


func _model_slider(parent: Control, spec: Array) -> void:
	var label_text: String = spec[0]
	var key: String = spec[1]
	var lbl := Label.new()
	lbl.text = "%s: 0.00" % label_text
	parent.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = spec[2]
	sl.max_value = spec[3]
	sl.step = 0.01
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sl)
	sl.value_changed.connect(func(v: float) -> void:
		lbl.text = "%s: %.2f" % [label_text, v]
		if key == "Visor":
			modeled_helmet.set_visor_open(v)
		else:
			modeled_helmet.set_morph(key, v))
	model_controls[key] = sl


func _helmet_slider(parent: Control, spec: Array) -> void:
	var label_text: String = spec[0]
	var key: String = spec[1]
	var lbl := Label.new()
	parent.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = spec[2]
	sl.max_value = spec[3]
	sl.step = spec[4]
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sl)
	sl.value_changed.connect(func(v: float) -> void:
		if key == "slit_count":
			helmet_params[key] = int(v)
		else:
			helmet_params[key] = v
		lbl.text = "%s: %s" % [label_text, _fmt(key, v)]
		_rebuild_helmet())
	helmet_controls[key] = [sl, lbl, label_text]


func _fmt(key: String, v: float) -> String:
	if key == "slit_count":
		return str(int(v))
	return "%.2f" % v


func _sync_helmet_ui() -> void:
	for key in helmet_controls.keys():
		var c: Array = helmet_controls[key]
		var sl: HSlider = c[0]
		var lbl: Label = c[1]
		var v: float = helmet_params[key]
		sl.set_value_no_signal(v)
		lbl.text = "%s: %s" % [c[2], _fmt(key, v)]
	style_option.select(int(helmet_params["slit_style"]))
	for key in helmet_toggles.keys():
		(helmet_toggles[key] as CheckBox).set_pressed_no_signal(bool(helmet_params.get(key, false)))


func _on_preset(i: int) -> void:
	var key: String = HELMET_PRESETS.keys()[i]
	helmet_params = HELMET_PRESETS[key].duplicate()
	_sync_helmet_ui()
	_rebuild_helmet()


func _on_tab_changed(tab: int) -> void:
	if tab == 3:
		target_focus = Vector3(0, 1.22, 0)
		target_distance = 1.7
	elif tab == 2:
		target_focus = Vector3(0, 1.76, 0)
		target_distance = 1.05
	else:
		target_focus = Vector3(0, 1.0, 0)
		target_distance = 3.3


func _randomize_suit() -> void:
	var fi := randi() % FINISHES.size()
	finish_option.select(fi)
	_apply_finish(fi)
	for g in group_checks.keys():
		var on := randf() < 0.8
		if g == "Breastplate":
			on = true
		elif SuitBuilder.OFF_BY_DEFAULT.has(g):
			on = randf() < 0.35
		group_checks[g].button_pressed = on
	var c := Color.from_hsv(randf(), randf_range(0.45, 0.85), randf_range(0.25, 0.7))
	cloth_picker.color = c
	cloth_mat.albedo_color = c


func _randomize_helmet() -> void:
	for spec in HELMET_SLIDERS + VISOR_SLIDERS:
		var key: String = spec[1]
		var v := randf_range(float(spec[2]), float(spec[3]))
		helmet_params[key] = int(round(v)) if key == "slit_count" else v
	# Keep randoms wearable: not too squashed, slits on the face.
	helmet_params["height"] = randf_range(0.26, 0.36)
	helmet_params["slit_y"] = randf_range(0.54, 0.7)
	helmet_params["slit_count"] = randi_range(1, 3)
	helmet_params["slit_style"] = randi() % HelmetBuilder.SLIT_STYLES.size()
	if helmet_params["slit_style"] == 3:
		helmet_params["slit_count"] = randi_range(4, 9)
	helmet_params["visor"] = randf() < 0.4
	helmet_params["breaths"] = randf() < 0.6
	helmet_params["plume"] = randf() < 0.3
	helmet_params["rim"] = randf() < 0.6
	_sync_helmet_ui()
	_rebuild_helmet()
