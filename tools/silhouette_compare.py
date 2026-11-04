import sys
from PIL import Image, ImageDraw
import numpy as np
REF='/mnt/user-data/attachments/046271ea-0a65-502a-ade0-ae197e0066c9/3a16b417-image.png'
im=Image.open(REF).convert('RGB'); A=np.asarray(im).astype(int)
YEL=(A[:,:,0]>180)&(A[:,:,1]>160)&(A[:,:,2]<90)
AN=[(225,1.513),(834,1.513-609*0.000818)]
def y_of(py):
    for (p0,y0),(p1,y1) in zip(AN,AN[1:]):
        if py<=p1: return y0+(y1-y0)*(py-p0)/(p1-p0)
    (p0,y0),(p1,y1)=AN[-2],AN[-1]; return y0+(y1-y0)*(py-p0)/(p1-p0)
SW=0.000818; SD=0.000818; CXF=278.5; CXB=1174.5; CXS=709.5
SCALE=0.62/720.0
def ours(name):
    o=np.asarray(Image.open(sys.argv[1]+'/'+name+'.png').convert('RGB')).astype(int)
    bg=o[5,5]
    return (np.abs(o-bg).sum(2)>18)
views={'front':(ours('o_front'),CXF,SW,+1),'side':(ours('o_side'),CXS,SD,-1),'back':(ours('o_back'),CXB,SW,+1)}
over=im.copy(); d=ImageDraw.Draw(over)
report=[]
def ref_edges(py,x0,x1):
    xs=np.where(YEL[py,x0:x1])[0]
    return (xs.min()+x0, xs.max()+x0) if len(xs) else None
rng={'front':(60,540),'side':(540,930),'back':(930,1420)}
for name,(mask,cx,s,sg) in views.items():
    pts_l=[];pts_r=[]; diffs=[]
    for py in range(232,832,4):
        y=y_of(py)
        row=int(round(360-(y-1.265)/SCALE))
        if row<0 or row>=720: continue
        xs=np.where(mask[row])[0]
        if len(xs)==0: continue
        # our metres -> ref px  (screen x right = +X world for front; side/back handled by sign)
        ml=(xs.min()-640)*SCALE; mr=(xs.max()-640)*SCALE
        if name=='side':   # camera at +X looking -X: screen right = -Z (back)
            pl=CXS - (-ml)/s if False else CXS + ml/s; pr=CXS + mr/s
        else:
            pl=cx+ml/s; pr=cx+mr/s
        pts_l.append((pl,py)); pts_r.append((pr,py))
        re=ref_edges(py,*rng[name])
        if re: diffs.append((py,round(y,3),round((pl-re[0])*s*1000,1),round((pr-re[1])*s*1000,1)))
    d.line(pts_l,fill=(0,220,255),width=3); d.line(pts_r,fill=(0,220,255),width=3)
    report.append((name,diffs))
over.crop((40,190,1430,860)).save(sys.argv[2])
for name,diffs in report:
    print(name, '(left, right edge error in mm; + means ours sits right of the reference)')
    for r in diffs[::5]: print('  ',r)
