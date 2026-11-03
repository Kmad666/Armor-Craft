"""Renders preview images of a piece .blend with Cycles (CPU).

blender --background <file.blend> --python render_preview.py -- <out_dir> [visor_open_deg]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out_dir = argv[0]
views = argv[1] if len(argv) > 1 else "all"
os.makedirs(out_dir, exist_ok=True)

sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 32
sc.cycles.use_denoising = True
sc.render.resolution_x = 760
sc.render.resolution_y = 760
sc.view_settings.view_transform = "AgX"

world = bpy.data.worlds.new("Studio")
sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
grad = world.node_tree.nodes.new("ShaderNodeTexGradient")
coord = world.node_tree.nodes.new("ShaderNodeTexCoord")
sep = world.node_tree.nodes.new("ShaderNodeSeparateXYZ")
ramp = world.node_tree.nodes.new("ShaderNodeValToRGB")
world.node_tree.links.new(coord.outputs["Generated"], sep.inputs[0])
world.node_tree.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
ramp.color_ramp.elements[0].position = 0.45
ramp.color_ramp.elements[0].color = (0.05, 0.05, 0.055, 1)
ramp.color_ramp.elements[1].position = 0.62
ramp.color_ramp.elements[1].color = (0.55, 0.55, 0.58, 1)
world.node_tree.links.new(ramp.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 0.8


def light(name, loc, energy, size):
    l = bpy.data.lights.new(name, "AREA")
    l.energy = energy
    l.size = size
    o = bpy.data.objects.new(name, l)
    sc.collection.objects.link(o)
    o.location = loc
    d = Vector((0, 0, 0)) - Vector(loc)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


if views in ("body", "head"):
    light("Key", (-1.8, -2.4, 2.6), 380, 1.6)
    light("Rim", (2.1, 1.8, 2.2), 260, 1.6)
    light("Fill", (2.4, -1.8, 0.8), 60, 2.5)
else:
    light("Key", (-0.6, -0.8, 0.6), 60, 0.6)
    light("Rim", (0.7, 0.6, 0.4), 40, 0.5)
    light("Fill", (0.8, -0.6, -0.1), 12, 1.0)

cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 85
cam = bpy.data.objects.new("Cam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam


def shoot(name, az_deg, el_deg, dist=1.45, target=(0, -0.04, 0.01)):
    az, el = math.radians(az_deg), math.radians(el_deg)
    t = Vector(target)
    cam.location = t + Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * dist
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)


if views == "body":
    cam_data.lens = 70
    for name, az, el in (("body_front", 0, 2), ("body_three_quarter", -35, 6), ("body_side", -90, 2), ("body_back", 180, 4)):
        shoot(name, az, el, dist=4.6, target=(0, 0, 0.9))
    cam_data.lens = 85
    shoot("body_hand", -60, 0, dist=1.0, target=(0.27, -0.02, 0.86))

if views == "head":
    cam_data.lens = 85
    for name, az, el in (("head_front", 0, 0), ("head_side", 90, 0), ("head_three_quarter", 35, 5), ("head_like_ref", 70, 28)):
        shoot(name, az, el, dist=1.05, target=(0, -0.01, 1.66))

pivot = bpy.data.objects.get("VisorPivot")
if views == "quick":
    shoot("three_quarter", -35, 8)
    shoot("side", -90, 2)
if views in ("all", "closed"):
    shoot("three_quarter", -35, 8)
    shoot("side", -90, 2)
    shoot("front", 0, 4)
    shoot("back", 160, 10)
if views in ("all", "open") and pivot:
    pivot.rotation_euler.x = math.radians(-70)
    shoot("visor_open", -40, 10)
    pivot.rotation_euler.x = 0
if views == "morph":
    for ob in bpy.data.objects:
        if ob.data and getattr(ob.data, "shape_keys", None):
            kb = ob.data.shape_keys.key_blocks
            kb["Apex"].value = 1.0
            kb["Snout"].value = 1.0
            kb["Width"].value = 0.5
    shoot("morphed", -35, 8)
