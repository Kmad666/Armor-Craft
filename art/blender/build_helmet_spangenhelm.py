"""Spangenhelm, first pass: a plain half-sphere shell.

Run with Blender (or the `bpy` Python module):
    blender --background --python art/blender/build_helmet_spangenhelm.py -- <out_dir>

Writes <out_dir>/helmet_spangenhelm.blend and .glb.

Origin = the mannequin's Socket_Head (centre of the head at eye level),
Z up, face toward -Y. The rim sits just above the brow. The material is
named "Steel" so the game swaps in its hammered-steel shader.
"""

import os
import sys

import bmesh
import bpy
from mathutils import Matrix

RIM_Z = 0.02        # rim height above eye level (brow)
RADIUS_X = 0.088    # half-width  (side to side)
RADIUS_Y = 0.106    # half-depth  (front to back)
RADIUS_Z = 0.115    # dome height
THICK = 0.002       # 2 mm plate


def main(out_dir):
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)

    steel = bpy.data.materials.new("Steel")
    steel.use_nodes = True
    bsdf = steel.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.62, 0.63, 0.65, 1)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.3

    # Unit sphere, keep the top half, then scale to size
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=32, radius=1.0)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-5], context="VERTS")
    bmesh.ops.transform(bm, verts=bm.verts,
                        matrix=Matrix.Translation((0, 0, RIM_Z)) @ Matrix.Diagonal((RADIUS_X, RADIUS_Y, RADIUS_Z, 1)))
    me = bpy.data.meshes.new("Dome")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(steel)
    dome = bpy.data.objects.new("Dome", me)
    bpy.context.scene.collection.objects.link(dome)

    sol = dome.modifiers.new("Thickness", "SOLIDIFY")
    sol.thickness = THICK
    sol.offset = -1.0
    sol.use_even_offset = True

    root = bpy.data.objects.new("Helmet_Spangenhelm", None)
    bpy.context.scene.collection.objects.link(root)
    dome.parent = root

    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "helmet_spangenhelm.blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "helmet_spangenhelm.glb"),
                              export_format="GLB", export_yup=True, export_apply=True)
    print("spangenhelm built")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    main(argv[0] if argv else os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"))
