"""Builds the hounskull bascinet for Armor Craft in Blender.

Run with Blender (or the `bpy` Python module):
    blender --background --python art/blender/build_helmet_bascinet.py -- <out_dir>

Outputs <out_dir>/helmet_bascinet.blend and <out_dir>/helmet_bascinet.glb.

Coordinates: metres, Z up, the face looks toward -Y (Blender "front").
The origin is the centre of the wearer's head, roughly at eye level, so the
mannequin only needs a head socket at that point.

Parts (separate objects so they can be tweaked by hand):
  Skull         pointed skull, face opening cut out, 1.8 mm thick
  Skull_Edges   rolled edges round the face opening and lower rim
  Lining        padded leather lining inside the skull
  Rivets        lining rivets
  Vervelles     staples along the lower rim that hold the mail aventail
  Pivots        rosette bosses at the temples
  VisorPivot    empty on the hinge axis; rotate about X to raise the visor
    Visor       pig-faced snout with a real eye slit and breaths
    Visor_Edges rolled edge round the visor
    Visor_Arms  hinge arms reaching back to the pivots

Shape keys on every mesh (the in-game morph sliders):
  Width, Height, Apex, Snout
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

# --------------------------------------------------------------------------
# Dimensions
# --------------------------------------------------------------------------
W = 0.112          # skull half-width at the temples
D = 0.128          # skull half-depth
Z_BOT = -0.135     # lower rim (jaw / nape)
Z_DOME = 0.03      # where the pointed crown begins
Z_TOP = 0.182      # apex
APEX_K = 1.4       # ogive sharpness (1 = hemisphere)
APEX_BACK = 0.026  # apex sits this far behind centre
THICK = 0.0018     # plate thickness

OPEN_W = 0.094     # face opening half-width
OPEN_TOP = 0.046   # brow
OPEN_ARCH = 0.05   # height of the arch at the top of the opening

PIVOT_Z = 0.022    # visor hinge height

VIS_W = 0.108      # visor outline half-width
VIS_ZC = -0.045    # visor outline centre height
VIS_H = 0.1        # visor outline half-height
VIS_N = 3.2        # superellipse exponent of the outline
TIP = Vector((0.0, -0.268, -0.064))  # point of the snout
BULGE = 0.017


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# --------------------------------------------------------------------------
# Skull surface
# --------------------------------------------------------------------------
def skull_radii(z):
    if z <= Z_DOME:
        k = smoothstep(Z_BOT, -0.02, z)
        return W * (0.91 + 0.09 * k), D * (0.93 + 0.07 * k), 0.0
    u = min(1.0, (z - Z_DOME) / (Z_TOP - Z_DOME))
    rho = (1 + APEX_K * APEX_K) / 2
    f = max(0.0, math.sqrt(max(0.0, rho * rho - APEX_K * APEX_K * u * u)) - (rho - 1))
    return W * f, D * f, APEX_BACK * u * u


def skull_point(a, z, push=0.0):
    """a = 0 at the front (-Y), increasing toward +X."""
    rx, ry, cy = skull_radii(z)
    return Vector((math.sin(a) * (rx + push), cy - math.cos(a) * (ry + push), z))


def skull_normal(a, z):
    e = 1e-4
    da = skull_point(a + e, z) - skull_point(a - e, z)
    dz = skull_point(a, z + e) - skull_point(a, z - e)
    n = da.cross(dz).normalized()
    p = skull_point(a, z)
    if n.dot(Vector((p.x, p.y - skull_radii(z)[2], 0.0))) < 0:
        n = -n
    return n


def front_angle(x, z):
    rx, _, _ = skull_radii(z)
    return math.asin(max(-0.985, min(0.985, x / rx)))


def on_skull(x, z, push=0.0):
    return skull_point(front_angle(x, z), z, push)


# --------------------------------------------------------------------------
# Visor surface
# --------------------------------------------------------------------------
def outline_xz(phi):
    s, c = math.sin(phi), math.cos(phi)
    x = VIS_W * math.copysign(abs(s) ** (2 / VIS_N), s)
    z = VIS_ZC + VIS_H * math.copysign(abs(c) ** (2 / VIS_N), c)
    return x, z


def outline_point(phi):
    x, z = outline_xz(phi)
    return skull_point(front_angle(x, z), z, 0.0055)


VIS_C = Vector((0.0, -D * 0.98, VIS_ZC))
VIS_AXIS = (TIP - VIS_C).normalized()


def angdiff(a, b):
    return (a - b + math.pi) % (2 * math.pi) - math.pi


def visor_point(phi, s):
    p = outline_point(phi)
    q = p.lerp(TIP, s)
    r = p - VIS_C
    r = (r - VIS_AXIS * r.dot(VIS_AXIS))
    if r.length > 1e-6:
        r.normalize()
    q += r * BULGE * math.sin(math.pi * s) * (1 - s) ** 0.2
    ridge = math.exp(-(angdiff(phi, 0) / 0.13) ** 2) + math.exp(-(angdiff(phi, math.pi) / 0.13) ** 2)
    q += r * 0.0055 * ridge * (1 - s)
    return q


def visor_normal(phi, s):
    e = 1e-4
    a = visor_point(phi + e, s) - visor_point(phi - e, s)
    b = visor_point(phi, s + e) - visor_point(phi, max(0.0, s - e))
    n = a.cross(b).normalized()
    p = visor_point(phi, s)
    if n.dot(p - (VIS_C + VIS_AXIS * (p - VIS_C).dot(VIS_AXIS))) < 0:
        n = -n
    return n


# --------------------------------------------------------------------------
# Blender helpers
# --------------------------------------------------------------------------
def new_obj(name, verts, faces, mat=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        me.materials.append(mat)
    return ob


def apply_mods(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)


def solidify(ob, t=THICK, offset=-1.0):
    m = ob.modifiers.new("Solidify", "SOLIDIFY")
    m.thickness = t
    m.offset = offset
    m.use_even_offset = True
    m.use_quality_normals = True
    apply_mods(ob)


def boolean_cut(ob, cutter):
    m = ob.modifiers.new("Cut", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.object = cutter
    try:
        m.solver = "EXACT"
    except TypeError:
        m.solver = "MANIFOLD"
    apply_mods(ob)


def remove(ob):
    me = ob.data
    bpy.data.objects.remove(ob)
    if me and me.users == 0:
        if isinstance(me, bpy.types.Mesh):
            bpy.data.meshes.remove(me)
        elif isinstance(me, bpy.types.Curve):
            bpy.data.curves.remove(me)


def orient_outward(ob, center):
    """Flip all faces if they mostly point toward `center`."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    vote = sum(f.normal.dot(f.calc_center_median() - center) * f.calc_area() for f in bm.faces)
    if vote < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


def grid(name, fn, us, vs, close_u=False, tip=None, mat=None, center=Vector()):
    nu = len(us)
    verts = [fn(u, v) for v in vs for u in us]
    faces = []
    cols = nu if close_u else nu - 1
    for j in range(len(vs) - 1):
        for i in range(cols):
            i2 = (i + 1) % nu
            faces.append((j * nu + i, j * nu + i2, (j + 1) * nu + i2, (j + 1) * nu + i))
    if tip is not None:
        ti = len(verts)
        verts.append(tip)
        last = (len(vs) - 1) * nu
        for i in range(cols):
            faces.append((last + i, last + (i + 1) % nu, ti))
    ob = new_obj(name, verts, faces, mat)
    orient_outward(ob, center)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def tube(name, pts, radius, cyclic=False, mat=None, res=3):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = res
    cu.use_fill_caps = not cyclic
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p.x, p.y, p.z, 1.0)
    sp.use_cyclic_u = cyclic
    tmp = bpy.data.objects.new(name + "_curve", cu)
    bpy.context.scene.collection.objects.link(tmp)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    remove(tmp)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        me.materials.clear()
        me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def join(name, obs, mat=None):
    bm = bmesh.new()
    for o in obs:
        m = o.data.copy()
        m.transform(o.matrix_world)
        bm.from_mesh(m)
        bpy.data.meshes.remove(m)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for o in obs:
        remove(o)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def basis_from_normal(n):
    q = n.to_track_quat("Z", "Y")
    return q.to_matrix().to_4x4()


def place(p, n, scale):
    return Matrix.Translation(p) @ basis_from_normal(n) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))


def add_dome(bm, p, n, r, flat=0.5):
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=6, radius=1.0,
                              matrix=place(p + n * r * 0.1, n, (r, r, r * flat)))


def add_disc(bm, p, n, r, depth):
    bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=r, radius2=r * 0.92,
                          depth=depth, matrix=place(p + n * depth * 0.5, n, (1, 1, 1)))


def add_torus(bm, m, R, r, seg=12, rs=6):
    verts = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        for j in range(rs):
            b = 2 * math.pi * j / rs
            v = Vector(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
            verts.append(bm.verts.new(m @ v))
    for i in range(seg):
        for j in range(rs):
            a = verts[i * rs + j]
            b = verts[((i + 1) % seg) * rs + j]
            c = verts[((i + 1) % seg) * rs + (j + 1) % rs]
            d = verts[i * rs + (j + 1) % rs]
            bm.faces.new((a, b, c, d))


def mesh_from_bm(name, bm, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    return ob


# --------------------------------------------------------------------------
# Materials (preview look in Blender; Godot swaps in its own shaders by name)
# --------------------------------------------------------------------------
def make_materials():
    steel = bpy.data.materials.new("Steel")
    steel.use_nodes = True
    nt = steel.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.6, 0.61, 0.63, 1)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.3
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = 30.0
    tex.inputs["Detail"].default_value = 6.0
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["To Min"].default_value = 0.2
    ramp.inputs["To Max"].default_value = 0.45
    nt.links.new(tex.outputs["Fac"], ramp.inputs["Value"])
    nt.links.new(ramp.outputs["Result"], bsdf.inputs["Roughness"])
    hammer = nt.nodes.new("ShaderNodeTexVoronoi")
    hammer.inputs["Scale"].default_value = 220.0
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.06
    nt.links.new(hammer.outputs["Distance"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    leather = bpy.data.materials.new("Leather")
    leather.use_nodes = True
    lb = leather.node_tree.nodes["Principled BSDF"]
    lb.inputs["Base Color"].default_value = (0.09, 0.05, 0.03, 1)
    lb.inputs["Roughness"].default_value = 0.75
    return steel, leather


# --------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------
def opening_outline(n=72):
    """Face opening in (x, z): straight sides with an arched brow."""
    pts = []
    zs = OPEN_TOP - OPEN_ARCH
    # right side bottom -> up, arch over, left side down
    for i in range(n // 4 + 1):
        pts.append((OPEN_W, Z_BOT - 0.03 + (zs - Z_BOT + 0.03) * i / (n // 4)))
    for i in range(1, n // 2):
        a = math.pi * i / (n // 2)
        pts.append((OPEN_W * math.cos(a), zs + OPEN_ARCH * math.sin(a)))
    for i in range(n // 4 + 1):
        pts.append((-OPEN_W, zs - (zs - Z_BOT + 0.03) * i / (n // 4)))
    return pts


def build_skull(steel, leather):
    center = Vector((0, 0.01, 0.0))
    nz = 64
    zs = [Z_BOT + (Z_TOP - Z_BOT) * (i / nz) ** 1.0 for i in range(nz)]
    us = [2 * math.pi * i / 96 for i in range(96)]
    skull = grid("Skull", lambda a, z: skull_point(a, z), us, zs, close_u=True,
                 tip=Vector((0, APEX_BACK, Z_TOP)), mat=steel, center=center)
    solidify(skull)

    # Face opening cutter: the outline extruded through the front wall only
    out = opening_outline()
    verts = [Vector((x, -0.3, z)) for x, z in out] + [Vector((x, -0.015, z)) for x, z in out]
    n = len(out)
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    cutter = new_obj("OpeningCutter", verts, faces)
    orient_outward(cutter, Vector((0, -0.15, -0.04)))
    boolean_cut(skull, cutter)

    # Lining: a softer inner shell, cut the same way
    lzs = [Z_BOT + 0.004 + (0.15 - Z_BOT) * i / 40 for i in range(41)]
    lining = grid("Lining", lambda a, z: skull_point(a, z, -0.0065), us, lzs, close_u=True,
                  mat=leather, center=center)
    solidify(lining, 0.003)
    boolean_cut(lining, cutter)
    remove(cutter)

    # Rolled edges: round the face opening and along the lower rim
    edge_pts = [on_skull(x, z, 0.0012) for x, z in out if z >= Z_BOT]
    a_open = front_angle(OPEN_W, Z_BOT)
    rim = [skull_point(a_open + (2 * math.pi - 2 * a_open) * i / 110, Z_BOT, 0.0012) for i in range(111)]
    e1 = tube("FaceEdge", edge_pts, 0.0028, mat=steel)
    e2 = tube("RimEdge", rim, 0.0028, mat=steel)
    edges = join("Skull_Edges", [e1, e2], steel)

    # Lining rivets round the face opening and the lower rim
    bm = bmesh.new()
    zs_i = OPEN_TOP - OPEN_ARCH
    k = 0
    for x, z in opening_outline(48):
        k += 1
        if k % 2:
            continue
        xi = x + (-0.016 if x > 0.05 else 0.016 if x < -0.05 else 0.0)
        zi = z + (0.014 if z > zs_i else 0.0)
        if zi < Z_BOT + 0.02:
            continue
        a = front_angle(xi, zi)
        add_dome(bm, skull_point(a, zi), skull_normal(a, zi), 0.0034)
    for i in range(22):
        a = a_open + 0.12 + (2 * math.pi - 2 * a_open - 0.24) * i / 21
        add_dome(bm, skull_point(a, Z_BOT + 0.014), skull_normal(a, Z_BOT + 0.014), 0.0034)
    rivets = mesh_from_bm("Rivets", bm, steel)

    # Vervelles: staples round the back and sides that hold the aventail
    bm = bmesh.new()
    for i in range(26):
        a = a_open + 0.1 + (2 * math.pi - 2 * a_open - 0.2) * i / 25
        z = Z_BOT + 0.03
        p = skull_point(a, z)
        n = skull_normal(a, z)
        tangent = Vector((0, 0, 1)).cross(n).normalized()
        m = Matrix.Translation(p + n * 0.0025) @ Matrix((
            (tangent.x, n.x, 0.0, 0.0), (tangent.y, n.y, 0.0, 0.0), (tangent.z, n.z, 1.0, 0.0), (0, 0, 0, 1)))
        add_torus(bm, m @ Matrix.Diagonal((1.0, 0.7, 1.0, 1.0)), 0.0045, 0.0014)
    vervelles = mesh_from_bm("Vervelles", bm, steel)

    # Rosette pivot bosses at the temples
    bm = bmesh.new()
    for side in (-1, 1):
        a = side * math.pi / 2
        p = skull_point(a, PIVOT_Z)
        n = skull_normal(a, PIVOT_Z)
        add_disc(bm, p + n * 0.006, n, 0.015, 0.0025)
        for r in range(8):
            ang = 2 * math.pi * r / 8
            off = basis_from_normal(n).to_3x3() @ Vector((math.cos(ang), math.sin(ang), 0)) * 0.0105
            add_dome(bm, p + n * 0.0085 + off, n, 0.0024)
        add_dome(bm, p + n * 0.0115, n, 0.0085, 0.75)
    pivots = mesh_from_bm("Pivots", bm, steel)
    return [skull, lining, edges, rivets, vervelles, pivots]


def build_visor(steel):
    nphi = 112
    phis = [2 * math.pi * i / nphi for i in range(nphi)]
    ss = [0.985 * (i / 34) for i in range(35)]
    visor = grid("Visor", visor_point, phis, ss, close_u=True, tip=TIP, mat=steel, center=VIS_C)
    solidify(visor)

    # Cutters: eye slits either side of the central bar, and the breaths
    cut = []

    def patch(name, p0, p1, s0, s1, n_p=18, n_s=3):
        ps = [p0 + (p1 - p0) * i / n_p for i in range(n_p + 1)]
        sv = [s0 + (s1 - s0) * j / n_s for j in range(n_s + 1)]
        ob = grid(name, lambda a, s: visor_point(a, s), ps, sv, mat=None, center=VIS_C)
        m = ob.modifiers.new("Solidify", "SOLIDIFY")
        m.thickness = 0.03
        m.offset = 0.0
        m.use_even_offset = True
        apply_mods(ob)
        return ob

    cut.append(patch("SlitR", 0.15, 0.95, 0.08, 0.14))
    cut.append(patch("SlitL", -0.95, -0.15, 0.08, 0.14))
    bm = bmesh.new()
    for side in (1, -1):
        for row in range(6):
            s = 0.16 + row * 0.092
            count = 8 - row
            for c in range(count):
                phi = side * (1.45 + c * 0.165 + row * 0.08)
                p = visor_point(phi, s)
                n = visor_normal(phi, s)
                bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.0033, radius2=0.0033,
                                      depth=0.03, matrix=place(p, n, (1, 1, 1)))
    holes = mesh_from_bm("Breaths", bm, steel)
    cut.append(holes)
    cutter = join("VisorCutter", cut)
    boolean_cut(visor, cutter)
    remove(cutter)

    # Rolled edge round the visor
    rim = [visor_point(p, 0.0) + visor_normal(p, 0.0) * 0.001 for p in phis]
    edge = tube("Visor_Edges", rim, 0.0029, cyclic=True, mat=steel)

    # Hinge arms from the upper sides of the visor back to the pivots
    arms = []
    for side in (1, -1):
        phi0 = side * 1.2
        start = visor_point(phi0, 0.0)
        a0 = front_angle(start.x, start.z)
        a1 = side * math.pi / 2
        pts = []
        for i in range(13):
            t = i / 12
            a = a0 + (a1 - a0) * t
            z = start.z + (PIVOT_Z - start.z) * smoothstep(0, 1, t)
            pts.append((a, z, t))
        verts = []
        for a, z, t in pts:
            h = 0.015 - 0.004 * t
            verts.append(skull_point(a, z + h, 0.0038))
            verts.append(skull_point(a, z - h, 0.0038))
        faces = [(2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1) for i in range(len(pts) - 1)]
        ob = new_obj("Arm", verts, faces, steel)
        orient_outward(ob, Vector((0, 0, 0)))
        m = ob.modifiers.new("Solidify", "SOLIDIFY")
        m.thickness = 0.0025
        m.offset = 0.0
        apply_mods(ob)
        arms.append(ob)
    arm_obj = join("Visor_Arms", arms, steel)
    return [visor, edge, arm_obj]


# --------------------------------------------------------------------------
# Shape keys
# --------------------------------------------------------------------------
def morph_width(v):
    return Vector((v.x * 1.12, v.y * 1.03, v.z))


def morph_height(v):
    return Vector((v.x, v.y, v.z + 0.28 * max(0.0, v.z - 0.03)))


def morph_apex(v):
    u = max(0.0, min(1.0, (v.z - 0.05) / (Z_TOP - 0.05)))
    cy = APEX_BACK * u * u
    return Vector((v.x * (1 - 0.2 * u * u), cy + (v.y - cy) * (1 - 0.2 * u * u), v.z + 0.045 * u * u))


def morph_snout(v):
    d = max(0.0, min(1.2, (-0.122 - v.y) / 0.133))
    return Vector((v.x * (1 - 0.15 * d), v.y - 0.075 * d, v.z - 0.015 * d))


MORPHS = [("Width", morph_width), ("Height", morph_height), ("Apex", morph_apex), ("Snout", morph_snout)]


def add_box_uvs(ob, scale=4.0):
    """Simple box projection (metres * scale) so engines can build tangents."""
    me = ob.data
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                uv.data[li].uv = (co.y * scale, co.z * scale)
            elif ax == 1:
                uv.data[li].uv = (co.x * scale, co.z * scale)
            else:
                uv.data[li].uv = (co.x * scale, co.y * scale)


def add_shape_keys(ob):
    mw = ob.matrix_world
    inv = mw.inverted()
    ob.shape_key_add(name="Basis", from_mix=False)
    for name, fn in MORPHS:
        key = ob.shape_key_add(name=name, from_mix=False)
        for i, v in enumerate(ob.data.vertices):
            key.data[i].co = inv @ fn(mw @ v.co)


# --------------------------------------------------------------------------
def main(out_dir):
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    steel, leather = make_materials()
    skull_parts = build_skull(steel, leather)
    visor_parts = build_visor(steel)

    root = bpy.data.objects.new("Helmet_Bascinet", None)
    bpy.context.scene.collection.objects.link(root)
    pivot = bpy.data.objects.new("VisorPivot", None)
    bpy.context.scene.collection.objects.link(pivot)
    pivot.location = (0.0, APEX_BACK * 0.0, PIVOT_Z)
    pivot.parent = root
    for ob in skull_parts:
        ob.parent = root
    bpy.context.view_layer.update()
    for ob in visor_parts:
        ob.parent = pivot
        ob.matrix_parent_inverse = pivot.matrix_world.inverted()
    bpy.context.view_layer.update()
    for ob in skull_parts + visor_parts:
        add_box_uvs(ob)
        add_shape_keys(ob)

    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "helmet_bascinet.blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "helmet_bascinet.glb"), export_format="GLB",
                              export_yup=True, export_morph=True, export_morph_normal=True,
                              export_apply=False)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in skull_parts + visor_parts)
    print("helmet built:", len(skull_parts + visor_parts), "meshes,", tris, "triangles")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    main(argv[0] if argv else os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"))
