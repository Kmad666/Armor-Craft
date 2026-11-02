extends Node3D
## Armor Craft v0.1 - armor stand + helmet designer.
## Everything is built in code so the project stays tiny and easy to iterate on.

const HelmetBuilder := preload("res://scripts/helmet_builder.gd")

const FINISHES := [
	{"name": "Polished Steel", "color": Color(0.82, 0.84, 0.87), "metal": 0.85, "rough": 0.32},
	{"name": "Blackened Steel", "color": Color(0.2, 0.2, 0.22), "metal": 0.75, "rough": 0.5},
	{"name": "Brass", "color": Color(0.82, 0.64, 0.34), "metal": 0.85, "rough": 0.35},
	{"name": "Gilded", "color": Color(0.98, 0.80, 0.38), "metal": 0.9, "rough": 0.25},
	{"name": "Rusted Iron", "color": Color(0.45, 0.27, 0.16), "metal": 0.35, "rough": 0.85},
]

const HELMET_PRESETS := {
	"Great Helm": {"width": 0.135, "depth": 0.15, "height": 0.29, "dome": 0.22, "taper": 0.95, "flare": 0.0, "snout": 0.0,
		"slit_style": 0, "slit_count": 2, "slit_w": 0.55, "slit_thick": 0.024, "slit_y": 0.62, "plume": false, "rim": true},
	"Hounskull": {"width": 0.125, "depth": 0.14, "height": 0.3, "dome": 0.55, "taper": 1.0, "flare": 0.05, "snout": 0.1,
		"slit_style": 1, "slit_count": 1, "slit_w": 0.6, "slit_thick": 0.022, "slit_y": 0.6, "plume": false, "rim": false},
	"Barbute": {"width": 0.13, "depth": 0.145, "height": 0.29, "dome": 0.6, "taper": 1.0, "flare": 0.0, "snout": 0.0,
		"slit_style": 2, "slit_count": 1, "slit_w": 0.42, "slit_thick": 0.035, "slit_y": 0.6, "plume": false, "rim": false},
	"Sallet": {"width": 0.13, "depth": 0.15, "height": 0.27, "dome": 0.55, "taper": 1.0, "flare": 0.35, "snout": 0.0,
		"slit_style": 0, "slit_count": 1, "slit_w": 0.75, "slit_thick": 0.02, "slit_y": 0.62, "plume": true, "rim": true},
	"Grilled Bascinet": {"width": 0.13, "depth": 0.145, "height": 0.3, "dome": 0.45, "taper": 0.97, "flare": 0.0, "snout": 0.04,
		"slit_style": 3, "slit_count": 7, "slit_w": 0.6, "slit_thick": 0.02, "slit_y": 0.64, "plume": true, "rim": true},
}

## name, key, min, max, step
const HELMET_SLIDERS := [
	["Width", "width", 0.10, 0.20, 0.001],
	["Depth", "depth", 0.10, 0.22, 0.001],
	["Height", "height", 0.20, 0.42, 0.001],
	["Dome", "dome", 0.10, 0.90, 0.01],
	["Taper", "taper", 0.70, 1.15, 0.01],
	["Brim Flare", "flare", 0.0, 0.60, 0.01],
	["Snout", "snout", 0.0, 0.16, 0.002],
]
const VISOR_SLIDERS := [
	["Slit Count", "slit_count", 1, 9, 1],
	["Slit Width", "slit_w", 0.15, 1.0, 0.01],
	["Slit Thickness", "slit_thick", 0.008, 0.06, 0.001],
	["Slit Height", "slit_y", 0.40, 0.85, 0.005],
]

const PLATE_GROUPS := ["Gorget", "Cuirass", "Faulds", "Pauldrons", "Arms", "Gauntlets", "Legs", "Sabatons"]
const CLOTH_GROUPS := ["Surcoat", "Belt", "Cape"]

var camera: Camera3D
var yaw := 0.5
var pitch := 0.12
var distance := 3.4
var focus := Vector3(0, 1.0, 0)
var target_focus := focus
var target_distance := distance
var dragging := false
var turntable := false

var body_mat: StandardMaterial3D
var metal_mat: StandardMaterial3D
var cloth_mat: StandardMaterial3D
var leather_mat: StandardMaterial3D
var dark_mat: StandardMaterial3D

var mannequin: Node3D
var suit_root: Node3D
var head_node: MeshInstance3D
var helmet_node: Node3D
var pieces := {}
var group_checks := {}
var wear_helmet := true

var helmet_params: Dictionary = {}
var helmet_controls := {}
var finish_option: OptionButton
var preset_option: OptionButton
var style_option: OptionButton
var cloth_picker: ColorPickerButton
var plume_check: CheckBox
var rim_check: CheckBox


func _ready() -> void:
	randomize()
	_build_environment()
	_build_materials()
	_build_mannequin()
	_build_suit()
	helmet_params = HELMET_PRESETS["Great Helm"].duplicate()
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
	sky_mat.sky_top_color = Color(0.12, 0.13, 0.17)
	sky_mat.sky_horizon_color = Color(0.42, 0.36, 0.30)
	sky_mat.ground_bottom_color = Color(0.16, 0.15, 0.14)
	sky_mat.ground_horizon_color = Color(0.38, 0.33, 0.28)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(35), 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.94, 0.85)
	sun.shadow_enabled = true
	add_child(sun)

	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-20), deg_to_rad(200), 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.6, 0.7, 1.0)
	add_child(rim)

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.22, 0.2, 0.19)
	stone.roughness = 0.9
	var pedestal := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.55
	pm.bottom_radius = 0.6
	pm.height = 0.1
	pedestal.mesh = pm
	pedestal.material_override = stone
	pedestal.position = Vector3(0, -0.05, 0)
	add_child(pedestal)

	camera = Camera3D.new()
	camera.fov = 40
	add_child(camera)
	_update_camera()


func _build_materials() -> void:
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.34, 0.33, 0.31)
	body_mat.roughness = 0.95

	metal_mat = StandardMaterial3D.new()

	cloth_mat = StandardMaterial3D.new()
	cloth_mat.albedo_color = Color(0.55, 0.08, 0.08)
	cloth_mat.roughness = 0.95
	cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	leather_mat = StandardMaterial3D.new()
	leather_mat.albedo_color = Color(0.25, 0.14, 0.07)
	leather_mat.roughness = 0.7

	dark_mat = StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.01, 0.01, 0.012)
	dark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _apply_finish(idx: int) -> void:
	var f: Dictionary = FINISHES[idx]
	metal_mat.albedo_color = f["color"]
	metal_mat.metallic = f["metal"]
	metal_mat.roughness = f["rough"]
	metal_mat.metallic_specular = 0.7
	metal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


# --------------------------------------------------------------------------
# Mesh helpers
# --------------------------------------------------------------------------

func _cap(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = max(h, r * 2.0)
	return m


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	return m


func _sph(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m


func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m


func _part(parent: Node3D, group: String, mesh: Mesh, mat: Material, pos: Vector3,
		scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	if group != "":
		if not pieces.has(group):
			pieces[group] = []
		pieces[group].append(mi)
	return mi


# --------------------------------------------------------------------------
# Mannequin + armor
# --------------------------------------------------------------------------

func _build_mannequin() -> void:
	mannequin = Node3D.new()
	mannequin.name = "Mannequin"
	add_child(mannequin)
	var m := mannequin
	head_node = _part(m, "", _sph(0.11), body_mat, Vector3(0, 1.68, 0), Vector3(0.95, 1.1, 1.0))
	_part(m, "", _cyl(0.05, 0.055, 0.12), body_mat, Vector3(0, 1.54, 0))
	_part(m, "", _cap(0.17, 0.6), body_mat, Vector3(0, 1.26, 0), Vector3(1, 1, 0.7))
	_part(m, "", _cap(0.15, 0.32), body_mat, Vector3(0, 0.95, 0), Vector3(1, 1, 0.75))
	for sx in [-1.0, 1.0]:
		_part(m, "", _cap(0.05, 0.32), body_mat, Vector3(0.26 * sx, 1.29, 0))
		_part(m, "", _cap(0.045, 0.3), body_mat, Vector3(0.26 * sx, 0.99, 0))
		_part(m, "", _sph(0.045), body_mat, Vector3(0.26 * sx, 0.82, 0))
		_part(m, "", _cap(0.075, 0.46), body_mat, Vector3(0.1 * sx, 0.68, 0))
		_part(m, "", _cap(0.06, 0.46), body_mat, Vector3(0.1 * sx, 0.28, 0))
		_part(m, "", _box(Vector3(0.09, 0.06, 0.2)), body_mat, Vector3(0.1 * sx, 0.03, 0.04))


func _build_suit() -> void:
	suit_root = Node3D.new()
	suit_root.name = "Suit"
	add_child(suit_root)
	var s := suit_root
	# Torso
	_part(s, "Gorget", _cyl(0.075, 0.12, 0.1), metal_mat, Vector3(0, 1.53, 0), Vector3(1, 1, 0.9))
	_part(s, "Cuirass", _cap(0.19, 0.48), metal_mat, Vector3(0, 1.3, 0.005), Vector3(1, 1, 0.8))
	_part(s, "Faulds", _cyl(0.185, 0.215, 0.2), metal_mat, Vector3(0, 1.0, 0), Vector3(1, 1, 0.82))
	# Limbs
	for sx in [-1.0, 1.0]:
		_part(s, "Pauldrons", _sph(0.1), metal_mat, Vector3(0.25 * sx, 1.44, 0), Vector3(1.15, 0.8, 1.05))
		_part(s, "Arms", _cyl(0.064, 0.058, 0.27), metal_mat, Vector3(0.26 * sx, 1.27, 0))
		_part(s, "Arms", _sph(0.062), metal_mat, Vector3(0.26 * sx, 1.13, -0.005), Vector3(1, 0.9, 1.1))
		_part(s, "Arms", _cyl(0.056, 0.05, 0.25), metal_mat, Vector3(0.26 * sx, 0.99, 0))
		_part(s, "Gauntlets", _box(Vector3(0.085, 0.12, 0.08)), metal_mat, Vector3(0.26 * sx, 0.81, 0))
		_part(s, "Gauntlets", _cyl(0.06, 0.05, 0.06), metal_mat, Vector3(0.26 * sx, 0.88, 0))
		_part(s, "Legs", _cyl(0.09, 0.08, 0.4), metal_mat, Vector3(0.1 * sx, 0.7, 0))
		_part(s, "Legs", _sph(0.07), metal_mat, Vector3(0.1 * sx, 0.48, 0.02), Vector3(1, 0.9, 1))
		_part(s, "Legs", _cyl(0.07, 0.06, 0.38), metal_mat, Vector3(0.1 * sx, 0.27, 0))
		_part(s, "Sabatons", _box(Vector3(0.11, 0.07, 0.24)), metal_mat, Vector3(0.1 * sx, 0.035, 0.04))
	# Cloth
	_part(s, "Surcoat", _cyl(0.21, 0.31, 0.78), cloth_mat, Vector3(0, 0.99, 0), Vector3(1, 1, 0.8))
	_part(s, "Belt", _cyl(0.222, 0.222, 0.045), leather_mat, Vector3(0, 1.06, 0), Vector3(1, 1, 0.82))
	_part(s, "Cape", _box(Vector3(0.5, 1.15, 0.015)), cloth_mat, Vector3(0, 0.98, -0.2), Vector3.ONE, Vector3(0.08, 0, 0))
	# Cape off by default
	_set_group_visible("Cape", false)


func _set_group_visible(group: String, on: bool) -> void:
	for mi in pieces.get(group, []):
		mi.visible = on


func _rebuild_helmet() -> void:
	if helmet_node:
		helmet_node.queue_free()
	helmet_node = HelmetBuilder.build(helmet_params, metal_mat, dark_mat, cloth_mat)
	helmet_node.position = Vector3(0, 1.53, 0)
	helmet_node.visible = wear_helmet
	add_child(helmet_node)
	head_node.visible = not wear_helmet


# --------------------------------------------------------------------------
# Camera
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if turntable and not dragging:
		yaw += delta * 0.5
	focus = focus.lerp(target_focus, min(1.0, delta * 6.0))
	distance = lerpf(distance, target_distance, min(1.0, delta * 6.0))
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
			target_distance = max(0.5, target_distance * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			target_distance = min(6.0, target_distance * 1.1)
	elif event is InputEventMouseMotion and dragging:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.008
		pitch = clamp(pitch + mm.relative.y * 0.006, -0.6, 1.2)


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
	hint.text = "v0.1  -  drag to orbit, scroll to zoom"
	hint.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68))
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
	sb.bg_color = Color(0.08, 0.08, 0.09, 0.88)
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

	_header(box, "Plates")
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for g in PLATE_GROUPS:
		_group_check(grid, g, true)

	_header(box, "Cloth")
	var grid2 := GridContainer.new()
	grid2.columns = 2
	box.add_child(grid2)
	for g in CLOTH_GROUPS:
		_group_check(grid2, g, g != "Cape")

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

	_header(box, "Visor")
	style_option = OptionButton.new()
	for st in HelmetBuilder.SLIT_STYLES:
		style_option.add_item(st)
	style_option.item_selected.connect(func(i: int) -> void:
		helmet_params["slit_style"] = i
		_rebuild_helmet())
	box.add_child(style_option)
	for s in VISOR_SLIDERS:
		_helmet_slider(box, s)

	_header(box, "Extras")
	plume_check = CheckBox.new()
	plume_check.text = "Plume"
	plume_check.toggled.connect(func(v: bool) -> void:
		helmet_params["plume"] = v
		_rebuild_helmet())
	box.add_child(plume_check)
	rim_check = CheckBox.new()
	rim_check.text = "Rolled Rim"
	rim_check.toggled.connect(func(v: bool) -> void:
		helmet_params["rim"] = v
		_rebuild_helmet())
	box.add_child(rim_check)

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
	plume_check.set_pressed_no_signal(helmet_params["plume"])
	rim_check.set_pressed_no_signal(helmet_params["rim"])


func _on_preset(i: int) -> void:
	var key: String = HELMET_PRESETS.keys()[i]
	helmet_params = HELMET_PRESETS[key].duplicate()
	_sync_helmet_ui()
	_rebuild_helmet()


func _on_tab_changed(tab: int) -> void:
	if tab == 1:
		target_focus = Vector3(0, 1.68, 0)
		target_distance = 1.25
	else:
		target_focus = Vector3(0, 1.0, 0)
		target_distance = 3.4


func _randomize_suit() -> void:
	var fi := randi() % FINISHES.size()
	finish_option.select(fi)
	_apply_finish(fi)
	for g in group_checks.keys():
		var on := randf() < 0.75
		if g == "Cuirass":
			on = true
		elif g == "Cape":
			on = randf() < 0.4
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
	helmet_params["height"] = randf_range(0.25, 0.36)
	helmet_params["slit_y"] = randf_range(0.52, 0.72)
	helmet_params["slit_count"] = randi_range(1, 3)
	helmet_params["slit_style"] = randi() % HelmetBuilder.SLIT_STYLES.size()
	if helmet_params["slit_style"] == 3:
		helmet_params["slit_count"] = randi_range(4, 9)
	helmet_params["plume"] = randf() < 0.35
	helmet_params["rim"] = randf() < 0.5
	_sync_helmet_ui()
	_rebuild_helmet()
