extends Node3D
## A modelled armour piece loaded from a .glb built in Blender
## (see art/blender/). The piece's origin is its socket on the mannequin;
## for a helmet that is the centre of the head at eye level.
##
## Blender shape keys arrive as blend shapes and become morph sliders.
## A "VisorPivot" node, if present, is the visor hinge (rotate about X).

const MORPHS := ["Width", "Height", "Apex", "Snout"]
const VISOR_MAX_DEG := 75.0

var _meshes: Array[MeshInstance3D] = []
var _visor: Node3D


## mats maps Blender material names ("Steel", "Leather") to game materials.
func setup(scene: PackedScene, mats: Dictionary) -> void:
	var inst := scene.instantiate()
	add_child(inst)
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		_meshes.append(mi)
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var key := m.resource_name if m else ""
			if mats.has(key):
				mi.set_surface_override_material(s, mats[key])
	_visor = inst.find_child("VisorPivot", true, false) as Node3D


func set_morph(morph: String, value: float) -> void:
	for mi in _meshes:
		var idx := mi.find_blend_shape_by_name(morph)
		if idx >= 0:
			mi.set_blend_shape_value(idx, value)


func get_morph(morph: String) -> float:
	for mi in _meshes:
		var idx := mi.find_blend_shape_by_name(morph)
		if idx >= 0:
			return mi.get_blend_shape_value(idx)
	return 0.0


## 0 = visor down, 1 = fully raised.
func set_visor_open(amount: float) -> void:
	if _visor:
		_visor.rotation.x = -deg_to_rad(VISOR_MAX_DEG) * clampf(amount, 0.0, 1.0)


func has_visor() -> bool:
	return _visor != null
