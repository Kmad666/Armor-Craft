extends Node3D
## The wooden mannequin every armour piece is fitted to.
##
## Built in Blender by art/blender/build_mannequin.py from
## assets/mannequin/measurements.json and exported as a hierarchy of joints
## (Pelvis, Waist, Chest, Neck, Head, Shoulder_L, Elbow_L, Wrist_L, Hip_L,
## Knee_L, Ankle_L, ...) with the carved segments as children. Rotate a joint
## to pose the figure; armour pieces attach to sockets such as "Socket_Head".

const MEASUREMENTS_PATH := "res://assets/mannequin/measurements.json"

var measurements: Dictionary = {}
var _root: Node3D


func setup(scene: PackedScene, mats: Dictionary) -> void:
	_root = scene.instantiate()
	add_child(_root)
	for n in _root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var key := m.resource_name if m else ""
			if mats.has(key):
				mi.set_surface_override_material(s, mats[key])
	measurements = load_measurements()


## A joint or socket node by name, e.g. "Socket_Head" or "Elbow_L".
func node(node_name: String) -> Node3D:
	return _root.find_child(node_name, true, false) as Node3D


static func load_measurements() -> Dictionary:
	var text := FileAccess.get_file_as_string(MEASUREMENTS_PATH)
	var data = JSON.parse_string(text) if text != "" else null
	return data if data is Dictionary else {}


## Circumference of an ellipse from its full width and depth (Ramanujan).
static func ellipse_girth(width: float, depth: float) -> float:
	var a := width * 0.5
	var b := depth * 0.5
	return PI * (3.0 * (a + b) - sqrt((3.0 * a + b) * (a + 3.0 * b)))


## Rows for the Body tab: [label, metres].
func summary() -> Array:
	var m := measurements
	if m.is_empty():
		return []
	var sh := Vector3(m["shoulder_joint_x"], m["shoulder_height"] - 0.03, 0.0)
	var el := Vector3(m["elbow_x"], m["elbow_height"], 0.014)
	var wr := Vector3(m["wrist_x"], m["wrist_height"], -0.03)
	return [
		["Height", m["stature"]],
		["Eye height", m["eye_height"]],
		["Shoulder breadth", m["shoulder_breadth"]],
		["Chest", ellipse_girth(m["chest_width"], m["chest_depth"])],
		["Waist", ellipse_girth(m["waist_width"], m["waist_depth"])],
		["Hips", ellipse_girth(m["hip_width"], m["hip_depth"])],
		["Neck", m["neck_girth"]],
		["Arm (shoulder-wrist)", sh.distance_to(el) + el.distance_to(wr)],
		["Upper arm", m["upper_arm_girth"]],
		["Forearm", m["forearm_girth"]],
		["Wrist", m["wrist_girth"]],
		["Inseam", m["crotch_height"]],
		["Thigh", m["thigh_girth"]],
		["Knee", m["knee_girth"]],
		["Calf", m["calf_girth"]],
		["Ankle", m["ankle_girth"]],
		["Hand length", m["hand_length"]],
		["Foot length", m["foot_length"]],
	]
