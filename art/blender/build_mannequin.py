"""Builds the wooden mannequin that every armour piece is fitted to.

Run with Blender (or the `bpy` Python module):
    blender --background --python art/blender/build_mannequin.py -- <out_dir>

Reads assets/mannequin/measurements.json and writes
<out_dir>/mannequin_wood.blend and <out_dir>/mannequin_wood.glb.

The mannequin is a classic jointed artist's figure: carved segments with
ball joints. It is exported as a hierarchy of joints (empties) with the
segments as children, so the game can pose it by rotating joints and apply
new measurements by moving joints and scaling segments.

Coordinates: metres, Z up, the figure faces -Y. Joint names use _L / _R
(L = the figure's left = +X).

  Root
  └ Pelvis ── PelvisBlock
     ├ Waist ── WaistBall
     │  └ Chest ── ChestBlock
     │     ├ Neck ── NeckPost
     │     │  └ Head ── HeadBlock, NeckBall, Socket_Head (eye level: helmets attach here)
     │     └ Shoulder_L/R ── ShoulderBall, UpperArm
     │        └ Elbow ── ElbowBall, Forearm
     │           └ Wrist ── WristBall, Hand
     └ Hip_L/R ── HipBall, Thigh
        └ Knee ── KneeBall, Shin
           └ Ankle ── AnkleBall, Foot
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
MEAS_PATH = os.path.join(HERE, "..", "..", "assets", "mannequin", "measurements.json")

M = {}


def girth_r(g):
    return g / (2 * math.pi)


def lerp(a, b, t):
    return a + (b - a) * t


def catmull(t, keys):
    n = len(keys)
    if n == 1:
        return keys[0]
    x = max(0.0, min(1.0, t)) * (n - 1)
    i = min(int(x), n - 2)
    f = x - i
    p0, p1, p2, p3 = keys[max(i - 1, 0)], keys[i], keys[i + 1], keys[min(i + 2, n - 1)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f
                  + (-p0 + 3 * p1 - 3 * p2 + p3) * f * f * f)


# --------------------------------------------------------------------------
# Mesh helpers
# --------------------------------------------------------------------------
def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def mesh_obj(name, verts, faces, mat, center):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.validate()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    vote = sum(f.normal.dot(f.calc_center_median() - center) * f.calc_area() for f in bm.faces)
    if vote < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    return link(bpy.data.objects.new(name, me))


def frame(p0, p1, side=Vector((1, 0, 0))):
    d = (p1 - p0).normalized()
    s = (side - d * side.dot(d)).normalized()
    f = s.cross(d)
    if f.y > 0:  # front axis points toward -Y (the way the figure faces)
        f = -f
    return d, s, f


def loft(name, p0, p1, profile, mat, na=40, nt=28, cap0=0.6, cap1=0.6, side=Vector((1, 0, 0)), sq=2.0):
    """Carved segment along p0 -> p1.

    profile(t) -> (rs, rf, os, of): half-widths along the side and front axes
    and an offset of the section centre. Ends are closed with rounded caps
    whose length is cap * radius. sq > 2 makes sections boxier.
    """
    d, s, f = frame(p0, p1, side)
    L = (p1 - p0).length
    rings = []

    def ring(c, rs, rf):
        pts = []
        for i in range(na):
            a = 2 * math.pi * i / na
            ca, sa = math.cos(a), math.sin(a)
            x = math.copysign(abs(ca) ** (2 / sq), ca) * rs
            y = math.copysign(abs(sa) ** (2 / sq), sa) * rf
            pts.append(c + s * x + f * y)
        return pts

    def section(t):
        rs, rf, ox, of = profile(t)
        return p0 + d * (L * t) + s * ox + f * of, rs, rf

    caps = 6
    c, rs, rf = section(0.0)
    if cap0:
        for k in range(caps, 0, -1):
            th = (math.pi / 2) * k / caps
            rings.append(ring(c - d * (cap0 * min(rs, rf) * math.sin(th)), rs * math.cos(th), rf * math.cos(th)))
    for j in range(nt + 1):
        rings.append(ring(*section(j / nt)))
    c, rs, rf = section(1.0)
    if cap1:
        for k in range(1, caps + 1):
            th = (math.pi / 2) * k / caps
            rings.append(ring(c + d * (cap1 * min(rs, rf) * math.sin(th)), rs * math.cos(th), rf * math.cos(th)))

    verts = [v for r in rings for v in r]
    faces = []
    for j in range(len(rings) - 1):
        for i in range(na):
            a, b = j * na + i, j * na + (i + 1) % na
            faces.append((a, b, b + na, a + na))
    ob = mesh_obj(name, verts, faces, mat, (p0 + p1) * 0.5)
    m = ob.modifiers.new("Weld", "WELD")
    m.merge_threshold = 1e-6
    apply_mods(ob)
    return ob


def ball(name, c, r, mat, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=16, radius=1.0,
                              matrix=Matrix.Translation(c) @ Matrix.Diagonal((r * scale[0], r * scale[1], r * scale[2], 1)))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    return link(bpy.data.objects.new(name, me))


def apply_mods(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)


def add_box_uvs(ob, scale=4.0):
    me = ob.data
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u = (co.y, co.z) if ax == 0 else (co.x, co.z) if ax == 1 else (co.x, co.y)
            uv.data[li].uv = (u[0] * scale, u[1] * scale)


def empty(name, loc, parent=None):
    e = link(bpy.data.objects.new(name, None))
    e.empty_display_type = "SPHERE"
    e.empty_display_size = 0.02
    e.location = loc
    if parent:
        e.parent = parent
        e.matrix_parent_inverse = parent.matrix_world.inverted()
        e.location = loc  # world == local because parents carry no rotation
        e.location = Vector(loc) - parent.matrix_world.translation
        e.matrix_parent_inverse = Matrix.Identity(4)
    bpy.context.view_layer.update()
    return e


def attach(ob, joint):
    """Parent a world-space mesh to a joint, re-expressing its vertices locally."""
    off = joint.matrix_world.translation.copy()
    ob.data.transform(Matrix.Translation(-off))
    ob.parent = joint
    ob.matrix_parent_inverse = Matrix.Identity(4)
    ob.location = (0, 0, 0)


# --------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------
def make_materials():
    def wood(name, base, dark):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Roughness"].default_value = 0.38
        bsdf.inputs["Coat Weight"].default_value = 0.25
        coord = nt.nodes.new("ShaderNodeTexCoord")
        mapping = nt.nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (1.0, 1.0, 0.08)
        nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
        wave = nt.nodes.new("ShaderNodeTexWave")
        wave.wave_type = "RINGS"
        wave.inputs["Scale"].default_value = 26.0
        wave.inputs["Distortion"].default_value = 10.0
        wave.inputs["Detail"].default_value = 3.0
        nt.links.new(mapping.outputs["Vector"], wave.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*dark, 1)
        ramp.color_ramp.elements[1].color = (*base, 1)
        ramp.color_ramp.elements[0].position = 0.25
        nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        return mat

    return (wood("Wood", (0.42, 0.24, 0.11), (0.26, 0.13, 0.05)),
            wood("WoodDark", (0.2, 0.1, 0.045), (0.11, 0.05, 0.02)))


# --------------------------------------------------------------------------
# The figure
# --------------------------------------------------------------------------
def build(wood, dark):
    m = M
    parts = []

    def add(ob, joint):
        attach(ob, joint)
        parts.append(ob)
        return ob

    root = empty("Root", (0, 0, 0))
    pelvis_j = empty("Pelvis", (0, 0, m["hip_height"]), root)
    waist_j = empty("Waist", (0, 0, m["waist_height"]), pelvis_j)
    chest_base = m["waist_height"] + 0.025
    chest_j = empty("Chest", (0, 0, chest_base), waist_j)
    neck_j = empty("Neck", (0, 0, m["neck_base_height"]), chest_j)
    head_pivot = m["chin_height"] + 0.02
    head_j = empty("Head", (0, 0, head_pivot), neck_j)
    empty("Socket_Head", (0, 0, m["eye_height"]), head_j)

    # ---- Torso -----------------------------------------------------------
    cw, cd = m["chest_width"] / 2, m["chest_depth"] / 2
    ww, wd = m["waist_width"] / 2, m["waist_depth"] / 2
    hw, hd = m["hip_width"] / 2, m["hip_depth"] / 2
    top = m["neck_base_height"] + 0.005
    z_arm = m["armpit_height"]

    def chest_prof(t):
        z = lerp(chest_base, top, t)
        # widths from the outline: waist -> chest at the armpits -> shoulders -> neck
        keys_z = [chest_base, z_arm - 0.07, z_arm, m["shoulder_height"] - 0.02, top - 0.04, top]
        keys_w = [ww * 1.02, cw * 0.97, cw, cw * 0.93, 0.105, 0.062]
        keys_d = [wd, cd * 0.96, cd, cd * 0.88, 0.075, 0.058]
        rs = interp(z, keys_z, keys_w)
        rf = interp(z, keys_z, keys_d)
        of = interp(z, keys_z, [0.0, 0.008, 0.012, 0.004, -0.01, -0.006])
        return rs, rf, 0.0, of

    add(loft("ChestBlock", Vector((0, 0, chest_base)), Vector((0, 0, top)), chest_prof, wood, na=56, nt=36,
             cap0=0.45, cap1=0.2, sq=2.25), chest_j)
    add(ball("WaistBall", Vector((0, 0, m["waist_height"])), ww * 0.82, dark, (1, wd / ww, 0.62)), waist_j)

    pel_top = m["waist_height"] - 0.03
    crotch = m["crotch_height"]

    def pelvis_prof(t):
        z = lerp(pel_top, crotch, t)
        keys_z = [pel_top, m["hip_height"] + 0.06, m["hip_height"], crotch + 0.03, crotch]
        rs = interp(z, keys_z, [ww * 1.02, hw * 0.94, hw, hw * 0.93, hw * 0.62])
        rf = interp(z, keys_z, [wd, hd * 0.95, hd, hd * 0.86, hd * 0.55])
        of = interp(z, keys_z, [0.0, 0.004, 0.0, -0.004, 0.0])
        return rs, rf, 0.0, of

    add(loft("PelvisBlock", Vector((0, 0, pel_top)), Vector((0, 0, crotch)), pelvis_prof, wood, na=56, nt=24,
             cap0=0.3, cap1=0.55, sq=2.2), pelvis_j)

    # ---- Neck and head ------------------------------------------------------
    nr = girth_r(m["neck_girth"])
    add(loft("NeckPost", Vector((0, 0.008, m["neck_base_height"] - 0.03)), Vector((0, 0.002, head_pivot + 0.03)),
             lambda t: (nr * lerp(1.06, 0.94, t), nr * lerp(1.1, 0.98, t), 0.0, 0.0), wood, na=32, nt=8,
             cap0=0.4, cap1=0.4), neck_j)
    add(ball("NeckBall", Vector((0, 0.004, head_pivot)), nr * 1.02, dark, (1, 1.05, 0.8)), head_j)

    hwid, hdep = m["head_width"] / 2, m["head_depth"] / 2
    chin, crown = m["chin_height"], m["stature"]

    def head_prof(t):
        z = lerp(chin, crown, t)
        keys_z = [chin, chin + 0.04, m["eye_height"] - 0.02, m["eye_height"] + 0.03, crown - 0.062]
        rs = interp(z, keys_z, [0.042, hwid * 0.8, hwid * 0.97, hwid, hwid * 0.9])
        rf = interp(z, keys_z, [0.045, hdep * 0.82, hdep * 0.97, hdep, hdep * 0.9])
        of = interp(z, keys_z, [0.045, 0.02, 0.004, 0.0, -0.006])
        return rs, rf, 0.0, of

    add(loft("HeadBlock", Vector((0, 0.004, chin)), Vector((0, 0.004, crown - 0.062)), head_prof, wood, na=48, nt=30,
             cap0=0.5, cap1=0.062 / (hwid * 0.9)), head_j)

    # ---- Arms ---------------------------------------------------------------
    for sx, tag in ((1, "L"), (-1, "R")):
        sh = Vector((sx * m["shoulder_joint_x"], 0.0, m["shoulder_height"] - 0.03))
        el = Vector((sx * m["elbow_x"], 0.014, m["elbow_height"]))
        wr = Vector((sx * m["wrist_x"], -0.03, m["wrist_height"]))
        sh_j = empty("Shoulder_" + tag, sh, chest_j)
        el_j = empty("Elbow_" + tag, el, sh_j)
        wr_j = empty("Wrist_" + tag, wr, el_j)

        ua = girth_r(m["upper_arm_girth"])
        fa = girth_r(m["forearm_girth"])
        wrr = girth_r(m["wrist_girth"])
        add(ball("ShoulderBall_" + tag, sh, ua * 1.08, dark), sh_j)
        add(loft("UpperArm_" + tag, sh + (el - sh).normalized() * 0.03, el - (el - sh).normalized() * 0.025,
                 lambda t: (ua * catmull(t, [1.0, 1.02, 0.92, 0.8]), ua * catmull(t, [1.0, 0.98, 0.9, 0.8]),
                            0.0, 0.0), wood, na=32, nt=16, cap0=0.5, cap1=0.5, side=Vector((sx, 0, 0))), sh_j)
        add(ball("ElbowBall_" + tag, el, ua * 0.8, dark), el_j)
        add(loft("Forearm_" + tag, el + (wr - el).normalized() * 0.03, wr - (wr - el).normalized() * 0.018,
                 lambda t: (fa * catmull(t, [0.9, 1.0, 0.8, wrr / fa * 0.8]),
                            fa * catmull(t, [0.92, 1.0, 0.86, wrr / fa * 1.1]), 0.0, 0.0),
                 wood, na=32, nt=16, cap0=0.5, cap1=0.5, side=Vector((sx, 0, 0))), el_j)
        add(ball("WristBall_" + tag, wr, wrr * 0.95, dark, (0.8, 1.05, 1.0)), wr_j)
        for ob in build_hand(tag, sx, wr, (wr - el).normalized(), wood):
            add(ob, wr_j)

    # ---- Legs ---------------------------------------------------------------
    for sx, tag in ((1, "L"), (-1, "R")):
        hip = Vector((sx * m["hip_joint_x"], 0.0, crotch + 0.035))
        knee = Vector((sx * lerp(m["hip_joint_x"], m["ankle_x"], 0.45), -0.006, m["knee_height"]))
        ank = Vector((sx * m["ankle_x"], 0.004, m["ankle_height"]))
        hip_j = empty("Hip_" + tag, hip, pelvis_j)
        knee_j = empty("Knee_" + tag, knee, hip_j)
        ank_j = empty("Ankle_" + tag, ank, knee_j)

        th = girth_r(m["thigh_girth"])
        kn = girth_r(m["knee_girth"])
        cf = girth_r(m["calf_girth"])
        an = girth_r(m["ankle_girth"])
        add(ball("HipBall_" + tag, hip, th * 0.8, dark), hip_j)
        add(loft("Thigh_" + tag, hip + (knee - hip).normalized() * 0.02, knee - (knee - hip).normalized() * 0.035,
                 lambda t: (th * catmull(t, [0.92, 0.9, 0.8, kn / th * 0.95]),
                            th * catmull(t, [1.0, 0.98, 0.86, kn / th]), 0.0,
                            catmull(t, [0.004, 0.012, 0.008, 0.002])),
                 wood, na=36, nt=20, cap0=0.4, cap1=0.5, side=Vector((sx, 0, 0))), hip_j)
        add(ball("KneeBall_" + tag, knee, kn * 0.88, dark), knee_j)
        add(loft("Shin_" + tag, knee + (ank - knee).normalized() * 0.035, ank - (ank - knee).normalized() * 0.02,
                 lambda t: (cf * catmull(t, [0.86, 0.94, 0.82, 0.66, an / cf * 0.9]),
                            cf * catmull(t, [0.92, 1.0, 0.86, 0.7, an / cf]), 0.0,
                            catmull(t, [-0.002, -0.012, -0.01, -0.004, 0.0])),
                 wood, na=36, nt=22, cap0=0.5, cap1=0.5, side=Vector((sx, 0, 0))), knee_j)
        add(ball("AnkleBall_" + tag, ank, an * 0.95, dark), ank_j)
        add(build_foot(tag, sx, ank, wood), ank_j)

    return root, parts


def interp(z, zs, vs):
    """Smooth (C1 cubic Hermite) interpolation of vs over monotonic zs."""
    if zs[0] > zs[-1]:
        zs, vs = zs[::-1], vs[::-1]
    n = len(zs)
    if z <= zs[0]:
        return vs[0]
    if z >= zs[-1]:
        return vs[-1]
    tang = []
    for i in range(n):
        a, b = max(i - 1, 0), min(i + 1, n - 1)
        tang.append((vs[b] - vs[a]) / (zs[b] - zs[a]))
    for i in range(n - 1):
        if zs[i] <= z <= zs[i + 1]:
            h = zs[i + 1] - zs[i]
            t = (z - zs[i]) / h
            t2, t3 = t * t, t * t * t
            return ((2 * t3 - 3 * t2 + 1) * vs[i] + (t3 - 2 * t2 + t) * h * tang[i]
                    + (-2 * t3 + 3 * t2) * vs[i + 1] + (t3 - t2) * h * tang[i + 1])
    return vs[-1]


def build_hand(tag, sx, wr, down, wood):
    """Carved hand hanging from the wrist, palm toward the thigh."""
    m = M
    hl, hb = m["hand_length"], m["hand_breadth"]
    side = Vector((sx, 0, 0))
    d, s, f = frame(wr, wr + down, side)
    obs = []
    p0 = wr + d * 0.012
    palm_len = hl * 0.5
    p1 = p0 + d * palm_len - s * 0.004
    obs.append(loft("Palm_" + tag, p0, p1,
                    lambda t: (lerp(0.017, 0.016, t), lerp(hb * 0.36, hb * 0.5, t), 0.0, 0.0),
                    wood, na=28, nt=10, cap0=0.4, cap1=0.25, side=side, sq=2.6))
    # Four fingers, slightly curled toward the palm (inward = -s)
    for i, (frac, ln) in enumerate(((-0.75, 0.82), (-0.25, 0.95), (0.25, 0.9), (0.72, 0.72))):
        base = p1 + f * (hb * 0.5 * 0.78 * frac)
        length = hl * 0.5 * ln
        mid = base + d * length * 0.55 - s * 0.004
        tip = mid + (d * 0.85 - s * 0.45).normalized() * length * 0.45
        r = 0.0088 - abs(frac) * 0.0008
        obs.append(loft("Finger%d_%s" % (i, tag), base, mid, lambda t, r=r: (r, r * 0.95, 0.0, 0.0),
                        wood, na=12, nt=3, cap0=0.6, cap1=0.6, side=side))
        obs.append(loft("FingerTip%d_%s" % (i, tag), mid, tip, lambda t, r=r: (r * 0.95, r * 0.9, 0.0, 0.0),
                        wood, na=12, nt=3, cap0=0.6, cap1=0.9, side=side))
    # Thumb from the front of the palm, angled forward and down
    tb = p0 + d * palm_len * 0.35 + f * hb * 0.32 - s * 0.006
    tm = tb + (d * 0.6 + f * 0.6 - s * 0.35).normalized() * 0.042
    tt = tm + (d * 0.85 + f * 0.2 - s * 0.35).normalized() * 0.033
    obs.append(loft("Thumb_" + tag, tb, tm, lambda t: (0.011, 0.0115, 0.0, 0.0), wood, na=12, nt=3,
                    cap0=0.6, cap1=0.6, side=side))
    obs.append(loft("ThumbTip_" + tag, tm, tt, lambda t: (0.0098, 0.0098, 0.0, 0.0), wood, na=12, nt=3,
                    cap0=0.6, cap1=0.9, side=side))
    hand = join("Hand_" + tag, obs, wood)
    return [hand]


def build_foot(tag, sx, ank, wood):
    """Carved foot: flat sole, rounded heel, toes turned out a little."""
    m = M
    fl, fb = m["foot_length"], m["foot_breadth"] / 2
    turn = math.radians(7) * sx
    fwd = Vector((math.sin(turn), -math.cos(turn), 0))
    heel = Vector((ank.x, ank.y, 0.0)) - fwd * 0.05
    toe = heel + fwd * fl
    hz = [0.03, 0.044, 0.05, 0.036, 0.026, 0.019, 0.012]
    hx = [fb * 0.62, fb * 0.8, fb * 0.84, fb * 0.95, fb, fb * 0.92, fb * 0.55]

    def prof(t):
        h = catmull(t, hz)
        # section centre sits h above the sole so the sole stays flat on the ground
        return catmull(t, hx), h, 0.0, 0.0

    ob = loft_foot("Foot_" + tag, heel, toe, prof, wood)
    return ob


def loft_foot(name, heel, toe, prof, wood, na=36, nt=24):
    d = (toe - heel).normalized()
    up = Vector((0, 0, 1))
    side = d.cross(up).normalized()
    L = (toe - heel).length
    rings = []
    caps = 5

    def ring(t, scale=1.0, extra=0.0):
        w, h, _, _ = prof(t)
        c = heel + d * (L * t + extra) + up * (h + 0.004)
        pts = []
        for i in range(na):
            a = 2 * math.pi * i / na
            ca, sa = math.cos(a), math.sin(a)
            x = math.copysign(abs(ca) ** (2 / 2.8), ca) * w * scale
            z = math.copysign(abs(sa) ** (2 / 2.8), sa) * h * scale
            pts.append(c + side * x + up * z)
        return pts

    for k in range(caps, 0, -1):
        th = (math.pi / 2) * k / caps
        rings.append(ring(0.0, math.cos(th), -0.03 * math.sin(th)))
    for j in range(nt + 1):
        rings.append(ring(j / nt))
    for k in range(1, caps + 1):
        th = (math.pi / 2) * k / caps
        rings.append(ring(1.0, math.cos(th), 0.03 * math.sin(th)))
    verts = [v for r in rings for v in r]
    faces = []
    for j in range(len(rings) - 1):
        for i in range(na):
            a, b = j * na + i, j * na + (i + 1) % na
            faces.append((a, b, b + na, a + na))
    return mesh_obj(name, verts, faces, wood, (heel + toe) * 0.5 + up * 0.03)


def join(name, obs, mat):
    bm = bmesh.new()
    for o in obs:
        me = o.data.copy()
        me.transform(o.matrix_world)
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    for o in obs:
        me = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    return link(bpy.data.objects.new(name, me))


# --------------------------------------------------------------------------
def main(out_dir):
    global M
    with open(MEAS_PATH) as fh:
        M = {k: v for k, v in json.load(fh).items() if not k.startswith("_")}
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    wood, dark = make_materials()
    root, parts = build(wood, dark)
    for ob in parts:
        add_box_uvs(ob)
    root.name = "Mannequin"
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "mannequin_wood.blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "mannequin_wood.glb"), export_format="GLB",
                              export_yup=True, export_apply=False, export_extras=True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts)
    print("mannequin built:", len(parts), "parts,", tris, "triangles")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    main(argv[0] if argv else os.path.join(HERE, "out"))
