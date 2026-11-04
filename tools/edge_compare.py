"""Measures the cuirass's neck, armhole and hem edges against the reference sheet.

python3 tools/edge_compare.py edges.json overlay.png
Reads the edges dumped by tests/dump_edges.gd (reference space), projects them
into each view of the sheet and reports the distance to the nearest yellow
outline pixel, in millimetres, per feature.
"""
import json, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

REF = '/mnt/user-data/attachments/046271ea-0a65-502a-ade0-ae197e0066c9/3a16b417-image.png'
S = 0.000818; PY0 = 225; Y0 = 1.513
CXF, CXB, CXS = 278.5, 1174.5, 709.5
VIEWS = {'front': (60, 540), 'side': (540, 930), 'back': (930, 1420)}

im = Image.open(REF).convert('RGB'); A = np.asarray(im).astype(int)
Y = (A[:, :, 0] > 180) & (A[:, :, 1] > 160) & (A[:, :, 2] < 90)
dist = ndimage.distance_transform_edt(~Y)   # px to nearest yellow

def proj(view, p):
    x, y, z = p
    py = PY0 + (Y0 - y) / S
    if view == 'front': return CXF + x / S, py
    if view == 'back':  return CXB - x / S, py
    return CXS - z / S, py   # side: camera at +X, front (+Z) to the left

edges = json.load(open(sys.argv[1]))
loops = {}
for piece, pts in edges.items():
    cur = []; loops[piece] = []
    for p in pts:
        if p is None:
            if cur: loops[piece].append(cur); cur = []
        else: cur.append(p)

# The sheet's yellow line runs around the OUTSIDE of the outline, but along the
# MIDDLE of the rim on inner edges seen face-on (the side-view armhole).
def pick(p, inner):
    return p[3:6] if inner else p[0:3]

def feature_points():
    f = {}
    for piece in ('Breastplate', 'Backplate'):
        front = piece == 'Breastplate'
        for lp in loops.get(piece, []):
            for p in lp:
                x, y, z = p[:3]
                if y < 1.14: continue  # hidden bottom row
                if abs(x) < 0.105 and y > 1.44:
                    f.setdefault(('front' if front else 'back', 'neck'), []).append(pick(p, False))
                elif y > 1.25 and abs(x) > 0.1:
                    if x > 0: f.setdefault(('side', 'armhole ' + ('front' if front else 'back')), []).append(pick(p, True))
                    f.setdefault(('front' if front else 'back', 'armhole (edge-on)'), []).append(pick(p, False))
    for lp in loops.get('Fauld', []):
        for p in lp:
            x, y, z = p[:3]
            if y > 1.1: continue
            q = pick(p, False)
            if z > -0.03: f.setdefault(('front', 'hem'), []).append(q)
            if z < -0.06: f.setdefault(('back', 'hem'), []).append(q)
            if x > 0.0: f.setdefault(('side', 'hem'), []).append(q)
    return f

over = im.copy(); d = ImageDraw.Draw(over)
report = {}
for (view, name), pts in sorted(feature_points().items()):
    ds = []
    x0, x1 = VIEWS[view]
    for p in pts:
        px, py = proj(view, p)
        ix, iy = int(round(px)), int(round(py))
        if not (x0 <= ix < x1 and 0 <= iy < A.shape[0]): continue
        ds.append(dist[iy, ix] * S * 1000)
        d.point((ix, iy), fill=(0, 230, 255))
    if ds:
        ds = np.array(ds)
        report[view + ' ' + name] = (round(float(ds.mean()), 1), round(float(np.percentile(ds, 90)), 1))
        print('%-26s mean %5.1f mm   90%% within %5.1f mm   (%d pts)' % (view + ' ' + name, ds.mean(), np.percentile(ds, 90), len(ds)))
over.crop((40, 190, 1430, 860)).save(sys.argv[2])
json.dump(report, open(sys.argv[2] + '.json', 'w'))
