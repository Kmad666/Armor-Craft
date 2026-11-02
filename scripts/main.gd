extends Node3D
## Armor Craft - armour stand + helmet designer.
## Everything is built in code so the project stays tiny and easy to iterate on.

const HelmetBuilder := preload("res://scripts/helmet_builder.gd")
const SuitBuilder := preload("res://scripts/suit_builder.gd")
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
	"Hounskull Bascinet": {"width": 0.13, "depth": 0.143, "height": 0.31, "dome": 0.62, "taper": 0.97, "flare": 0.0,
		"snout": 0.17, "apex": 0.75, "visor": true, "breaths": true,
		"slit_style": 1, "slit_count": 1, "slit_w": 0.62, "slit_thick": 0.024, "slit_y": 0.6, "plume": false, "rim": true},
	"Great Helm": {"width": 0.135, "depth": 0.15, "height": 0.29, "dome": 0.22, "taper": 0.95, "flare": 0.0, "snout": 0.0,
		"apex": 0.0, "visor": false, "breaths": false,
		"slit_style": 0, "slit_count": 2, "slit_w": 0.55, "slit_thick": 0.024, "slit_y": 0.62, "plume": false, "rim": true},
	"Barbute": {"width": 0.13, "depth": 0.145, "height": 0.29, "dome": 0.6, "taper": 1.0, "flare": 0.0, "snout": 0.0,
		"apex": 0.15, "visor": false, "breaths": false,
		"slit_style": 2, "slit_count": 1, "slit_w": 0.42, "slit_thick": 0.035, "slit_y": 0.6, "plume": false, "rim": true},
	"Sallet": {"width": 0.13, "depth": 0.15, "height": 0.27, "dome": 0.55, "taper": 1.0, "flare": 0.35, "snout": 0.0,
		"apex": 0.0, "visor": false, "breaths": false,
		"slit_style": 0, "slit_count": 1, "slit_w": 0.75, "slit_thick": 0.02, "slit_y": 0.62, "plume": true, "rim": true},
	"Grilled Bascinet": {"width": 0.13, "depth": 0.145, "height": 0.3, "dome": 0.5, "taper": 0.97, "flare": 0.0, "snout": 0.04,
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

const HELMET_Y := 1.535

var camera: Camera3D
var yaw := 0.55
var pitch := 0.1
var distance := 3.3
var focus := Vector3(0, 0.95, 0)
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

var head_node: MeshInstance3D
var helmet_node: Node3D
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
	var suit := Node3D.new()
	suit.name = "Suit"
	add_child(suit)
	groups = SuitBuilder.new(suit, {
		"metal": metal_mat, "mail": mail_mat, "leather": leather_mat,
		"linen": linen_mat, "cloth": cloth_mat, "brass": brass_mat,
	}).build()
	helmet_params = HELMET_PRESETS["Hounskull Bascinet"].duplicate()
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
	mail_mat.set_shader_parameter("albedo", f["mail"])
	mail_mat.set_shader_parameter("metallic", f["metal"])


# --------------------------------------------------------------------------
# Mannequin (arming doublet and hose, visible when plates are removed)
# --------------------------------------------------------------------------

func _body(mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	add_child(mi)
	return mi


func _build_mannequin() -> void:
	var head := SphereMesh.new()
	head.radius = 0.1
	head.height = 0.23
	head_node = _body(head, body_mat, Vector3(0, 1.68, 0.005), Vector3(0.95, 1.0, 1.05))
	var neck := CylinderMesh.new()
	neck.top_radius = 0.05
	neck.bottom_radius = 0.058
	neck.height = 0.14
	_body(neck, body_mat, Vector3(0, 1.53, 0))
	var torso := CapsuleMesh.new()
	torso.radius = 0.15
	torso.height = 0.56
	_body(torso, body_mat, Vector3(0, 1.24, 0), Vector3(1.0, 1.0, 0.75))
	var hips := CapsuleMesh.new()
	hips.radius = 0.14
	hips.height = 0.3
	_body(hips, hose_mat, Vector3(0, 0.93, 0), Vector3(1.0, 1.0, 0.75))
	for sx in [-1.0, 1.0]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.04
		arm.height = 0.55
		_body(arm, body_mat, Vector3(0.275 * sx, 1.14, 0))
		var thigh := CapsuleMesh.new()
		thigh.radius = 0.062
		thigh.height = 0.5
		_body(thigh, hose_mat, Vector3(0.105 * sx, 0.72, 0))
		var shin := CapsuleMesh.new()
		shin.radius = 0.034
		shin.height = 0.46
		_body(shin, hose_mat, Vector3(0.105 * sx, 0.27, -0.004))


func _rebuild_helmet() -> void:
	if helmet_node:
		helmet_node.queue_free()
	helmet_node = HelmetBuilder.build(helmet_params, metal_mat, dark_mat, cloth_mat)
	helmet_node.position = Vector3(0, HELMET_Y, 0)
	helmet_node.visible = wear_helmet
	add_child(helmet_node)
	head_node.visible = not wear_helmet


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
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			target_distance = maxf(0.35, target_distance * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			target_distance = minf(6.0, target_distance * 1.1)
	elif event is InputEventMouseMotion and dragging:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.008
		pitch = clampf(pitch + mm.relative.y * 0.006, -0.6, 1.2)


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
	hint.text = "v0.2  -  drag to orbit, scroll to zoom"
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

	_build_suit_tab(_make_tab(tabs, "Suit"))
	_build_helmet_tab(_make_tab(tabs, "Helmet"))


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
		helmet_node.visible = v
		head_node.visible = not v)
	box.add_child(wear)

	_header(box, "Preset")
	preset_option = OptionButton.new()
	for k in HELMET_PRESETS.keys():
		preset_option.add_item(k)
	preset_option.item_selected.connect(_on_preset)
	box.add_child(preset_option)

	_header(box, "Shape")
	for s in HELMET_SLIDERS:
		_helmet_slider(box, s)

	_header(box, "Visor & Slits")
	style_option = OptionButton.new()
	for st in HelmetBuilder.SLIT_STYLES:
		style_option.add_item(st)
	style_option.item_selected.connect(func(i: int) -> void:
		helmet_params["slit_style"] = i
		_rebuild_helmet())
	box.add_child(style_option)
	for s in VISOR_SLIDERS:
		_helmet_slider(box, s)

	_header(box, "Features")
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
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
	box.add_child(rnd)

	_sync_helmet_ui()


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
	if tab == 1:
		target_focus = Vector3(0, 1.68, 0)
		target_distance = 1.15
	else:
		target_focus = Vector3(0, 0.95, 0)
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
