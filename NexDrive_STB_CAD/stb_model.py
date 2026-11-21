"""
NexDrive STB Power Unit - parametrik montaj modeli
Kaynak: NexDrive STB Unite AR-GE Hesap Raporu v7 (12.11.2026)

Koordinat sistemi (mm):
  X = krank ekseni (−X = ön / zincir ve kayış tarafı, +X = CVT tarafı)
  Y = −Y emme (soğuk) tarafı, +Y egzoz / turbo tarafı (araç önü)
  Z = yukarı, Z=0 krank mili ekseni

Model gösterim konumu: krank açısı 0° (silindir 1 ateşleme ÜÖN, silindir 4
gaz değişimi ÜÖN, silindir 2-3 AÖN). VCR-P pistonlar düşük CR (9,2) konumunda.

Çalıştırma:  python3 stb_model.py   ->  out/ klasörüne STEP, GLB, BOM üretir.
"""
import json, math, os, csv
import cadquery as cq

V = cq.Vector
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")

# ----------------------------------------------------------------------------
# 1) RAPORDAN ANA PARAMETRELER
# ----------------------------------------------------------------------------
BORE = 72.0            # çap (rapor kapak)
STROKE = 73.6          # strok
CRANK_R = STROKE / 2   # 36.8
ROD_L = 128.0          # biyel boyu (bölüm 1.1)
PITCH = 84.0           # bore pitch (bölüm 3.1 karar)
LINER_T = 3.0          # cast-in gömlek (bölüm 3.1 / 13.1)
LINER_OD = BORE + 2 * LINER_T  # 78 -> köprü 6.0 mm
CYL_X = [-1.5 * PITCH, -0.5 * PITCH, 0.5 * PITCH, 1.5 * PITCH]
MAIN_X = [-2 * PITCH, -PITCH, 0.0, PITCH, 2 * PITCH]
COMP_H = 28.0          # piston pim ekseni -> taç
DECK_Z = CRANK_R + ROD_L + COMP_H + 0.5   # 193.3 (0,5 mm deck boşluğu)
GASKET_T = 0.7
HEAD_Z0 = DECK_Z + GASKET_T               # 194.0
VALVE_TILT = 14.0      # supap dahil açısı 28° = 14+14 (bölüm 8.4)
TAN_T = math.tan(math.radians(VALVE_TILT))
SIN_T, COS_T = math.sin(math.radians(VALVE_TILT)), math.cos(math.radians(VALVE_TILT))
D_IN, D_EX = 27.5, 23.5          # supap çapları (bölüm 1.3, 3.3)
LIFT_IN, LIFT_EX = 8.5, 7.5      # supap kaldırma (bölüm 8.1)
# supap merkezi – buji ekseni mesafesi r = Rb − 0,5 − Dv/2  (bölüm 3.3)
R_IN = BORE / 2 - 0.5 - D_IN / 2      # 21.75
R_EX = BORE / 2 - 0.5 - D_EX / 2      # 23.75
X_IN = (D_IN + 4.0) / 2               # emme–emme köprüsü ~4 mm
X_EX = (D_EX + 3.5) / 2
Y_IN = -math.sqrt(R_IN ** 2 - X_IN ** 2)   # ≈ −15.0
Y_EX = math.sqrt(R_EX ** 2 - X_EX ** 2)    # ≈ +19.5
ROOF_HALF = 40.0
def roof_z(y):  # pentroof çatı yüksekliği
    return HEAD_Z0 + (ROOF_HALF - abs(y)) * TAN_T
VALVE_LEN = 105.0
CAM_LOCAL = 136.0      # supap oturma -> kam ekseni (eksen boyunca)
CAM_BASE_R = 18.0
CAM_IN = (Y_IN - CAM_LOCAL * SIN_T, roof_z(Y_IN) + CAM_LOCAL * COS_T)
CAM_EX = (Y_EX + CAM_LOCAL * SIN_T, roof_z(Y_EX) + CAM_LOCAL * COS_T)
HEAD_TOP = max(CAM_IN[1], CAM_EX[1])
BLOCK_X = (-186.0, 186.0)

# ateşleme sırası 1-3-4-2, 180° flat krank; çevrim açısı (0 = ateşleme ÜÖN)
CYCLE = {0: 0.0, 1: 180.0, 2: 540.0, 3: 360.0}   # silindir indeksi 0..3
PIN_UP = {0: True, 1: False, 2: False, 3: True}  # 1-4 yukarı, 2-3 aşağı
IN_PEAK, EX_PEAK = 360 + 104, 360 - 110          # bölüm 8.1 (zirve merkezleri)
IN_DUR, EX_DUR = 274.0, 284.0


def valve_lift(cycle, peak, dur, hmax):
    d = (cycle - peak + 360) % 720 - 360
    half = dur / 2
    if abs(d) >= half:
        return 0.0
    return hmax * math.cos(math.pi / 2 * d / half) ** 1.5

# ----------------------------------------------------------------------------
# 2) GEOMETRİ YARDIMCILARI
# ----------------------------------------------------------------------------
def box(x0, x1, y0, y1, z0, z1):
    return cq.Solid.makeBox(x1 - x0, y1 - y0, z1 - z0, V(x0, y0, z0))

def cyl(r, p, d, h):
    return cq.Solid.makeCylinder(r, h, V(*p), V(*d))

def tube(ro, ri, p, d, h):
    return cyl(ro, p, d, h).cut(cyl(ri, p, d, h))

def cylx(r, x0, x1, y, z):
    return cyl(r, (x0, y, z), (1, 0, 0), x1 - x0)

def cyly(r, y0, y1, x, z):
    return cyl(r, (x, y0, z), (0, 1, 0), y1 - y0)

def cylz(r, z0, z1, x, y):
    return cyl(r, (x, y, z0), (0, 0, 1), z1 - z0)

def fuse(*shapes):
    s = shapes[0]
    for t in shapes[1:]:
        s = s.fuse(t)
    return s.clean()

def cut(s, *tools):
    for t in tools:
        s = s.cut(t)
    return s.clean()

def _perp(t):
    a = V(0, 0, 1) if abs(t.z) < 0.9 else V(1, 0, 0)
    return t.cross(a).normalized()

def pipe(points, r, r_in=None):
    """Spline boyunca boru (r_in verilirse içi boş)."""
    edge = cq.Edge.makeSpline([V(*p) for p in points])
    t = edge.tangentAt(0).normalized()
    plane = cq.Plane(origin=V(*points[0]), xDir=_perp(t), normal=t)
    wp = cq.Workplane(plane).circle(r)
    if r_in:
        wp = wp.circle(r_in)
    return wp.sweep(cq.Workplane().add(cq.Wire.assembleEdges([edge])),
                    transition="right").val()

def yz_plane(x0):
    """Normal +X, yerel x->Y, yerel y->Z."""
    return cq.Plane(origin=(x0, 0, 0), xDir=(0, 1, 0), normal=(1, 0, 0))

def hull2d(pts):
    pts = sorted(set((round(a, 4), round(b, 4)) for a, b in pts))
    def cr(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cr(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cr(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]

def circles_hull(circles, n=72):
    pts = []
    for (cy_, cz_, r) in circles:
        for i in range(n):
            a = 2 * math.pi * i / n
            pts.append((cy_ + r * math.cos(a), cz_ + r * math.sin(a)))
    return hull2d(pts)

def band_x(circles, x0, width, gap, thick):
    """X'e dik düzlemde kasnak/dişli çevresinde kayış / zincir bandı."""
    outer = circles_hull([(a, b, r + gap + thick) for a, b, r in circles])
    inner = circles_hull([(a, b, r + gap) for a, b, r in circles])
    o = cq.Workplane(yz_plane(x0)).polyline(outer).close().extrude(width).val()
    i = cq.Workplane(yz_plane(x0)).polyline(inner).close().extrude(width).val()
    return o.cut(i)

def plate_x(circles, x0, width, off):
    pts = circles_hull([(a, b, r + off) for a, b, r in circles])
    return cq.Workplane(yz_plane(x0)).polyline(pts).close().extrude(width).val()

def gear_x(r, teeth, x0, w, y, z, tooth_h=2.5):
    g = cylx(r - tooth_h, x0, x0 + w, 0, 0)
    for i in range(teeth):
        a = 2 * math.pi * i / teeth
        tw = 2 * math.pi * r / teeth * 0.45
        t = box(x0, x0 + w, -tw / 2, tw / 2, r - tooth_h - 0.5, r)
        g = g.fuse(t.moved(cq.Location(V(0, 0, 0), V(1, 0, 0), math.degrees(a))))
    return g.moved(cq.Location(V(0, y, z))).clean()

# ----------------------------------------------------------------------------
# 3) PARÇA KAYDI
# ----------------------------------------------------------------------------
PARTS = []      # (id, shape, meta)

STEPS = [
    (1, "Silindir bloğu", "Al döküm blok, cast-in gri dökme demir gömlekler"),
    (2, "Piston soğutma jetleri", "4 adet Ø1,5 mm jet, 2,8 bar açma"),
    (3, "Krank mili ve ana yatak grubu", "5 ana yatak, bedplate (yatak iskeleti)"),
    (4, "Balans şaftları (VCR-P varyantı)", "2× ters dönen, 2× devir"),
    (5, "Piston – biyel grubu (VCR-P)", "İki parçalı piston, segman, pim, biyel"),
    (6, "Yağlama: pompa ve karter", "Değişken debili pompa, emiş, karter"),
    (7, "Tahrik plakası ve krank sensörü", "Flexplate (CVT), 60-2 tetik tekerleği"),
    (8, "Silindir kapağı grubu", "MLS conta, DOHC 16V kapak, supap takımı, kapak cıvataları"),
    (9, "Eksantrik, çift VVT ve zincir", "2 eksantrik, 2 faz ayarlayıcı, duplex zincir, gergi, zincir kapağı"),
    (10, "Ateşleme ve kam kapağı", "M10 buji, COP bobin, kam kapağı"),
    (11, "Emme sistemi ve yakıt", "Plenum, runner, gaz kelebeği, enjektör, yakıt rayı"),
    (12, "Egzoz ve turbo", "Twin-scroll manifold, K03 twin-scroll, EWG, downpipe"),
    (13, "Soğutma ve yağ filtresi", "Su pompası, termostat, yağ filtresi"),
    (14, "Ön aksesuar tahriki", "Krank kasnağı, alternatör, gergi, kayış"),
    (15, "Hydro-Turbo", "Rotrex C15-60, hidrolik motor + 1:2 dişli, pompa, tank, akümülatör"),
    (16, "Şarj havası hattı", "Intercooler 300×200×76, boost boruları"),
    (17, "Sensörler", "Vuruntu ×2, kam fazı ×2, MAP"),
    (18, "Motor takozları", "M1 hidrotakoz, M2 şanzıman takozu, M3 roll sınırlayıcı"),
]

MAT_COLOR = {
    "al": (0.72, 0.74, 0.77), "al_dark": (0.55, 0.58, 0.62), "iron": (0.33, 0.34, 0.36),
    "steel": (0.62, 0.64, 0.68), "steel_dark": (0.40, 0.42, 0.46), "black": (0.12, 0.12, 0.13),
    "plastic": (0.16, 0.17, 0.19), "copper": (0.78, 0.45, 0.22), "orange": (0.95, 0.50, 0.10),
    "ss": (0.70, 0.66, 0.60), "rubber": (0.08, 0.08, 0.08), "teal": (0.16, 0.74, 0.76),
    "red": (0.78, 0.18, 0.16), "blue": (0.20, 0.40, 0.75), "gold": (0.80, 0.68, 0.30),
    "ceramic": (0.92, 0.92, 0.88), "green": (0.25, 0.60, 0.35),
}

def add(pid, shape, name, step, mat, color, dims, section, explode, qty_group=None,
        supply="", note=""):
    PARTS.append(dict(id=pid, shape=shape, name=name, step=step, material=mat,
                      color=color, dims=dims, section=section, explode=explode,
                      group=qty_group or name, supply=supply, note=note))

# ----------------------------------------------------------------------------
# 4) PARÇALAR
# ----------------------------------------------------------------------------
def build_block():
    upper = box(*BLOCK_X, -70, 70, 60, DECK_Z)
    lower = box(*BLOCK_X, -95, 95, 0, 60)
    b = upper.fuse(lower)
    # su ceketi (siamese, açık deck) - köprü 6,0 mm
    jacket = box(BLOCK_X[0] + 10, BLOCK_X[1] - 10, -50, 50, DECK_Z - 100, DECK_Z + 1)
    walls = fuse(*[cylz(LINER_OD / 2 + 3, DECK_Z - 101, DECK_Z + 2, cx, 0) for cx in CYL_X])
    b = b.cut(jacket.cut(walls))
    # krank odası boşlukları (bulkhead'ler arasında)
    for cx in CYL_X:
        b = b.cut(box(cx - 32, cx + 32, -78, 78, -1, 72))
    b = b.cut(box(BLOCK_X[0] + 8, BLOCK_X[1] - 8, -60, 60, -1, 40))
    # gömlek yuvaları
    for cx in CYL_X:
        b = b.cut(cylz(LINER_OD / 2, DECK_Z - 140, DECK_Z + 1, cx, 0))
    # ana yatak yarım yuvaları
    b = b.cut(cylx(27, BLOCK_X[0] - 1, BLOCK_X[1] + 1, 0, 0))
    # kapak cıvata delikleri M10 (5+5)
    for mx in MAIN_X:
        for y in (-56, 56):
            b = b.cut(cylz(5.0, DECK_Z - 60, DECK_Z + 1, mx, y))
    # köprü soğutma delikleri Ø2,0 (bölüm 10.3) – 3 köprü × 2
    for i in range(3):
        xb = (CYL_X[i] + CYL_X[i + 1]) / 2
        for zz in (DECK_Z - 6, DECK_Z - 10):
            b = b.cut(cyly(1.0, -60, 60, xb, zz))
    return b.clean()

def build_liner(cx):
    return tube(LINER_OD / 2, BORE / 2, (cx, 0, DECK_Z - 135), (0, 0, 1), 135)

def build_bedplate():
    b = box(*BLOCK_X, -95, 95, -45, 0)
    for cx in CYL_X:
        b = b.cut(box(cx - 32, cx + 32, -78, 78, -46, 1))
    b = b.cut(cylx(27, BLOCK_X[0] - 1, BLOCK_X[1] + 1, 0, 0))
    for mx in MAIN_X:
        for y in (-40, 40):
            b = b.cut(cylz(5, -46, 1, mx, y))
    return b.clean()

def build_crank():
    parts = []
    for mx in MAIN_X:
        parts.append(cylx(24, mx - 10, mx + 10, 0, 0))     # ana muylu Ø48
    for i, cx in enumerate(CYL_X):
        s = 1 if PIN_UP[i] else -1
        pz = s * CRANK_R
        parts.append(cylx(21, cx - 11, cx + 11, 0, pz))     # biyel muylusu Ø42
        for x0 in (cx - 32, cx + 11):
            web = cylx(26, x0, x0 + 21, 0, pz).fuse(
                box(x0, x0 + 21, -25, 25, min(0, pz), max(0, pz)))
            cw = cylx(62, x0, x0 + 21, 0, 0).cut(
                box(x0 - 1, x0 + 22, -70, 70, 0 if s > 0 else -70, 70 if s > 0 else 0))
            cw = cw.cut(box(x0 - 1, x0 + 22, -70, -40, -70, 70)).cut(
                box(x0 - 1, x0 + 22, 40, 70, -70, 70))
            parts.append(web.fuse(cw).fuse(cylx(26, x0, x0 + 21, 0, 0)))
    parts.append(cylx(16, -268, -178, 0, 0))      # ön burun
    parts.append(cylx(40, 178, 190, 0, 0))        # arka flanş
    return fuse(*parts)

def build_rod():
    """Yerel: büyük uç merkezi orijinde, küçük uç +Z 128."""
    big = tube(31, 21, (-10, 0, 0), (1, 0, 0), 20)
    small = tube(14, 9.5, (-10, 0, ROD_L), (1, 0, 0), 20)
    beam = box(-7, 7, -9, 9, 24, ROD_L - 12)
    beam = beam.cut(box(-8, 8, -4, 4, 34, ROD_L - 22)).fuse(box(-2.5, 2.5, -9, 9, 24, ROD_L - 12))
    cap_line = box(-10, 10, -31, -24, -1, 1)  # bölme hattı göstergesi
    r = fuse(big, small, beam)
    # biyel yağ kanalı Ø2,5 (bölüm 20.3)
    r = r.cut(cylz(1.25, 20, ROD_L - 10, 0, 0))
    return r.clean()

def piston_parts(cy):
    """VCR-P iki parçalı piston. Yerel: pim ekseni orijinde, taç +28 (düşük CR)."""
    ix = [(-X_IN, Y_IN, D_IN, 5.8), (X_IN, Y_IN, D_IN, 5.8),
          (-X_EX, Y_EX, D_EX, 4.9), (X_EX, Y_EX, D_EX, 4.9)]
    crown = cylz(36, 12, COMP_H, 0, 0)
    crown = crown.fuse(tube(31, 28, (0, 0, 2), (0, 0, 1), 10.5))
    for zg, h in ((COMP_H - 4.5, 1.2), (COMP_H - 8.0, 1.5), (COMP_H - 12.0, 2.0)):
        crown = crown.cut(tube(37, 32.2, (0, 0, zg - h), (0, 0, 1), h))
    for (x, y, d, depth) in ix:                       # supap cepleri (bölüm 20.4)
        crown = crown.cut(cylz(d / 2 + 1.0, COMP_H - depth, COMP_H + 1, x, y))
    crown = crown.cut(cylz(14, COMP_H - 2.0, COMP_H + 1, 0, 0))  # sığ çanak
    carrier = tube(35.8, 32, (0, 0, -26), (0, 0, 1), 26 + 10)
    carrier = carrier.fuse(box(-30, -16, -14, 14, -14, 10)).fuse(box(16, 30, -14, 14, -14, 10))
    carrier = carrier.fuse(cylz(27.5, 6, 10, 0, 0))
    carrier = carrier.cut(cylx(9.6, -40, 40, 0, 0))
    carrier = carrier.cut(box(-40, -27, -40, 40, -27, -4)).cut(box(27, 40, -40, 40, -27, -4))
    stop_ring = tube(28, 25.5, (0, 0, 10), (0, 0, 1), 2.0)   # dayanma halkası Ø56/Ø51
    lock_pins = fuse(cyly(3, -27, -17, 0, 5), cyly(3, 17, 27, 0, 5))  # 2× Ø6 kilit pimi
    pin = tube(9.5, 5.5, (-29, 0, 0), (1, 0, 0), 58)
    rings = [tube(36, 32.5, (0, 0, zg - h + 0.05), (0, 0, 1), h - 0.1)
             for zg, h in ((COMP_H - 4.5, 1.2), (COMP_H - 8.0, 1.5), (COMP_H - 12.0, 2.0))]
    return crown, carrier, stop_ring, lock_pins, pin, rings

def build_gasket():
    g = box(*BLOCK_X, -70, 70, DECK_Z, HEAD_Z0)
    for cx in CYL_X:
        g = g.cut(cylz(BORE / 2 + 1.0, DECK_Z - 1, HEAD_Z0 + 1, cx, 0))
    for mx in MAIN_X:
        for y in (-56, 56):
            g = g.cut(cylz(5.5, DECK_Z - 1, HEAD_Z0 + 1, mx, y))
    for cx in CYL_X:                                   # kalibre su delikleri Ø4–7
        for (dx, y, r) in ((-20, -46, 2.0), (20, -46, 2.0), (-20, 46, 3.5), (20, 46, 3.5)):
            g = g.cut(cylz(r, DECK_Z - 1, HEAD_Z0 + 1, cx + dx, y))
    return g.clean()

def valve_axis(y_seat, intake):
    a = VALVE_TILT if intake else -VALVE_TILT
    return a, V(0, -SIN_T if intake else SIN_T, COS_T)

def build_head():
    h = box(*BLOCK_X, -80, 80, HEAD_Z0, HEAD_TOP)
    tri = cq.Workplane(yz_plane(BLOCK_X[0] - 1)).polyline(
        [(-ROOF_HALF, HEAD_Z0 - 1), (ROOF_HALF, HEAD_Z0 - 1),
         (ROOF_HALF, HEAD_Z0), (0, roof_z(0)), (-ROOF_HALF, HEAD_Z0)]).close().extrude(
        BLOCK_X[1] - BLOCK_X[0] + 2).val()
    for cx in CYL_X:
        h = h.cut(cylz(BORE / 2, HEAD_Z0 - 1, roof_z(0) + 1, cx, 0).intersect(tri))
        # emme portu (yüksek tumble, dik port)
        h = h.cut(pipe([(cx, -81, 262), (cx, -55, 248), (cx, -30, 226), (cx, -16, 212)], 16))
        h = h.cut(pipe([(cx, 81, 240), (cx, 55, 236), (cx, 35, 222), (cx, 20, 210)], 14))
        h = h.cut(cylz(11, roof_z(0) - 1, HEAD_TOP + 1, cx, 0))   # buji tüpü
        for (sx, sy, d, intake) in ((-X_IN, Y_IN, D_IN, True), (X_IN, Y_IN, D_IN, True),
                                    (-X_EX, Y_EX, D_EX, False), (X_EX, Y_EX, D_EX, False)):
            a, ax = valve_axis(sy, intake)
            seat = V(cx + sx, sy, roof_z(sy))
            h = h.cut(cq.Solid.makeCylinder(d / 2 * 0.9, 18, seat - ax * 1, ax))
            h = h.cut(cq.Solid.makeCylinder(3.0, 70, seat, ax))
            h = h.cut(cq.Solid.makeCylinder(16.5, 120, seat + ax * 56, ax))
    for (cyy, czz) in (CAM_IN, CAM_EX):
        h = h.cut(cylx(28, BLOCK_X[0] - 1, BLOCK_X[1] + 1, cyy, czz))
    for mx in MAIN_X:
        for y in (-56, 56):
            h = h.cut(cylz(5.5, HEAD_Z0 - 1, HEAD_TOP + 1, mx, y))
            h = h.cut(cylz(10, HEAD_Z0 + 96, HEAD_TOP + 1, mx, y))
    return h.clean()

def build_cam_caps():
    caps = []
    for mx in MAIN_X:
        for (cyy, czz) in (CAM_IN, CAM_EX):
            c = box(mx - 10, mx + 10, cyy - 24, cyy + 24, czz, czz + 18).cut(
                cylx(15, mx - 11, mx + 11, cyy, czz))
            caps.append(c)
    return fuse(*caps)

_spring_cache = {}
def spring_local(height):
    key = round(height, 2)
    if key not in _spring_cache:
        try:
            helix = cq.Wire.makeHelix(pitch=height / 6, height=height, radius=11)
            prof = cq.Workplane(cq.Plane(origin=(11, 0, 0), xDir=(1, 0, 0), normal=(0, 1, 0))).circle(1.7)
            s = prof.sweep(cq.Workplane().add(helix), isFrenet=True).val()
        except Exception:
            s = tube(12.7, 9.3, (0, 0, 0), (0, 0, 1), height)
        _spring_cache[key] = s
    return _spring_cache[key]

def valve_set_local(d, lift):
    """Yerel: oturma düzlemi z=0, eksen +Z. Supap 'lift' kadar aşağıda."""
    valve = cylz(d / 2, -lift - 2.2, -lift, 0, 0).fuse(
        cq.Solid.makeCone(d / 2 - 1, 2.75, 12, V(0, 0, -lift), V(0, 0, 1))).fuse(
        cylz(2.75, -lift, VALVE_LEN - lift, 0, 0))
    spring = spring_local(36 - lift).moved(cq.Location(V(0, 0, 58)))
    retainer = tube(11.5, 3.2, (0, 0, 94 - lift), (0, 0, 1), 3)
    bucket = tube(15, 13.5, (0, 0, 100 - lift), (0, 0, 1), 18).fuse(
        cylz(15, 114 - lift, 118 - lift, 0, 0))
    return valve, spring, retainer, bucket

def cam_profile(hmax, dur_crank, n=120):
    half = math.radians(dur_crank / 4)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        d = (a + math.pi) % (2 * math.pi) - math.pi
        lift = hmax * math.cos(math.pi / 2 * d / half) ** 1.5 if abs(d) < half else 0.0
        r = CAM_BASE_R + lift
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts

def build_cam(intake):
    cyy, czz = CAM_IN if intake else CAM_EX
    shaft = cylx(13, -222, 182, cyy, czz)
    for mx in MAIN_X:
        shaft = shaft.fuse(cylx(15, mx - 9, mx + 9, cyy, czz))
    prof = cam_profile(LIFT_IN if intake else LIFT_EX, IN_DUR if intake else EX_DUR)
    axis_ang = math.degrees(math.atan2(-COS_T, SIN_T if intake else -SIN_T))  # kamdan supaba yön
    peak = IN_PEAK if intake else EX_PEAK
    xo = X_IN if intake else X_EX
    for i, cx in enumerate(CYL_X):
        rot = axis_ang - (CYCLE[i] - peak) / 2.0
        for sx in (-xo, xo):
            lobe = cq.Workplane(yz_plane(cx + sx - 7)).polyline(prof).close().extrude(14).val()
            lobe = lobe.moved(cq.Location(V(0, 0, 0), V(1, 0, 0), rot))
            shaft = shaft.fuse(lobe.moved(cq.Location(V(0, cyy, czz))))
    return shaft.clean()

def build_cam_cover():
    outer = box(BLOCK_X[0], BLOCK_X[1], -90, 90, HEAD_TOP, HEAD_TOP + 52)
    inner = box(BLOCK_X[0] + 5, BLOCK_X[1] - 5, -85, 85, HEAD_TOP - 1, HEAD_TOP + 47)
    c = outer.cut(inner)
    for cx in CYL_X:
        c = c.cut(cylz(12, HEAD_TOP + 40, HEAD_TOP + 60, cx, 0))
    c = c.fuse(cylz(14, HEAD_TOP + 52, HEAD_TOP + 66, 120, 40).cut(
        cylz(11, HEAD_TOP + 40, HEAD_TOP + 70, 120, 40)))   # yağ doldurma
    return c.clean()


def build_all():
    S = {k: v for k, v, _ in STEPS}
    C = MAT_COLOR

    # ---------------- 1 Blok
    add("B01", build_block(), "Silindir bloğu", 1, "AlSi7Mg0,3 T6 (LPDC)", C["al"],
        "372×190×193 mm, bore pitch 84, köprü 6,0 mm, açık deck", "3.1, 10.1, 13.1",
        (0, 0, 0), supply="Sanayi (döküm+işleme)", note="Kapak cıvata yuvası M10, köprü soğutma Ø2,0")
    for i, cx in enumerate(CYL_X):
        add(f"B02-{i+1}", build_liner(cx), f"Silindir gömleği {i+1}", 1,
            "Gri dökme demir, cast-in", C["iron"], "Ø72 / Ø78 × 135 mm, et 3,0 mm",
            "3.1, 10.2, 13.1", (0, 0, 0), qty_group="Silindir gömleği",
            note="Cast-in (içe gömme) kararı – bölüm 13.1")

    # ---------------- 2 Piston jetleri
    for i, cx in enumerate(CYL_X):
        j = box(cx - 6, cx + 6, -48, -36, 48, 58).fuse(
            cq.Solid.makeCylinder(1.6, 32, V(cx, -42, 58), V(0, 0.35, 0.94)))
        add(f"L05-{i+1}", j, f"Piston soğutma jeti {i+1}", 2, "Çelik", C["steel_dark"],
            "Ø1,5 mm nozul, Cd 0,70, açma 2,8 bar", "5.2, 13.4", (0, -120, -40),
            qty_group="Piston soğutma jeti")

    # ---------------- 3 Krank
    add("K01", build_crank(), "Krank mili", 3, "Dövme çelik (42CrMo4)", C["steel"],
        "Strok 73,6 (r 36,8), ana muylu Ø48, biyel muylusu Ø42, 180° flat", "1.1, 4, 21",
        (0, 0, -260), supply="Sanayi (kütükten)")
    add("K02", build_bedplate(), "Ana yatak iskeleti (bedplate)", 3, "AlSi9Cu3 + çelik insert",
        C["al_dark"], "372×190×45 mm, 5 ana yatak", "3, 21", (0, 0, -180))
    shells = fuse(*[tube(24.0 + 1.8, 24.0, (mx - 9, 0, 0), (1, 0, 0), 18) for mx in MAIN_X])
    add("K03", shells, "Ana yatak burçları (5 çift)", 3, "Çelik/Al-Sn kaplama", C["gold"],
        "Ø48 × 18 mm, et 1,8", "21", (0, 0, -220))

    # ---------------- 4 Balans şaftları
    for k, y in enumerate((-60, 60)):
        sh = cylx(11, -160, 160, y, -78)
        for xw in (-95, 95):
            w = cylx(27, xw - 18, xw + 18, y, -78).cut(box(xw - 19, xw + 19, y - 30, y + 30, -78, -40))
            sh = sh.fuse(w)
        sh = sh.fuse(gear_x(20, 24, -175, 14, y, -78))
        add(f"K04-{k+1}", sh.clean(), f"Balans şaftı {'emme' if y < 0 else 'egzoz'} tarafı", 4,
            "Çelik", C["steel_dark"], "m·e ≈ 2,3 g·m, 2× krank devri, ters yönlü",
            "4, 15.5, 21", (0, -60 if y < 0 else 60, -340), qty_group="Balans şaftı",
            note="VCR-P varyantında zorunlu (m_hr 507 g > 430 g)")

    # ---------------- 5 Piston-biyel
    rod_local = build_rod()
    for i, cx in enumerate(CYL_X):
        pz = CRANK_R if PIN_UP[i] else -CRANK_R
        pin_z = pz + ROD_L
        loc = cq.Location(V(cx, 0, pin_z))
        crown, carrier, stop_ring, lock_pins, pin, rings = piston_parts(0)
        n = i + 1
        ex = (0, 0, 170)
        add(f"P01-{n}", crown.moved(loc), f"VCR-P üst taç {n}", 5, "Dövme Al 2618-T61", C["al"],
            "Ø72, 3 segman yuvası, supap cebi E 5,8 / Eg 4,9 mm, hareket 1,97 mm",
            "15.2, 20.1, 20.4", ex, qty_group="VCR-P üst taç")
        add(f"P02-{n}", carrier.moved(loc), f"VCR-P alt gövde (pim taşıyıcı) {n}", 5,
            "Dövme Al 2618-T61", C["al_dark"], "Ø71,6 etek, pim deliği Ø19",
            "15, 20.1", ex, qty_group="VCR-P alt gövde")
        add(f"P03-{n}", stop_ring.moved(loc), f"Dayanma halkası {n}", 5, "42CrMo4, preslenmiş",
            C["steel"], "Ø56 / Ø51 mm, alan 420 mm², 97 MPa", "20.1, 20.2", ex,
            qty_group="Dayanma halkası")
        add(f"P04-{n}", lock_pins.moved(loc), f"Kilit pimleri (2×) {n}", 5, "42CrMo4 nitrürlü",
            C["red"], "2× Ø6 radyal, 3,0–3,5 bar geçiş, yay 5–8 N", "20.1–20.3", ex,
            qty_group="Kilit pimi seti")
        add(f"P05-{n}", pin.moved(loc), f"Piston pimi {n}", 5, "Çelik (içi boş DLC)", C["steel"],
            "Ø19 / Ø11 × 58 mm, 62 g", "4", ex, qty_group="Piston pimi")
        add(f"P06-{n}", fuse(*rings).moved(loc), f"Segman seti {n}", 5, "Çelik / dökme demir",
            C["steel_dark"], "3 segman: 1,2 / 1,5 / 2,0 mm", "4, 21", ex, qty_group="Segman seti")
        add(f"P07-{n}", rod_local.moved(cq.Location(V(cx, 0, pz))), f"Biyel {n}", 5,
            "Dövme çelik, yağ kanallı", C["steel_dark"],
            "L = 128 mm (λ 0,2875), büyük uç Ø42, küçük uç Ø19, Ø2,5 yağ kanalı",
            "1.1, 20.3, 21", (0, 0, 90), qty_group="Biyel")

    # ---------------- 6 Yağlama
    pan_o = box(*BLOCK_X, -95, 95, -105, -45).fuse(box(-150, 150, -80, 80, -155, -100))
    pan_i = box(BLOCK_X[0] + 4, BLOCK_X[1] - 4, -91, 91, -101, -44).fuse(
        box(-146, 146, -76, 76, -151, -99))
    add("L01", pan_o.cut(pan_i).clean(), "Yağ karteri", 6, "Al döküm / çelik sac", C["al_dark"],
        "372×190 mm, sump 300×160, ≈ 4,5 L", "5", (0, 0, -430))
    pump = cylx(42, -170, -130, 0, -112).fuse(gear_x(18, 20, -184, 10, 0, -112))
    add("L02", pump.clean(), "Değişken debili yağ pompası", 6, "Al gövde, vane tip", C["blue"],
        "11 cc/dev, 2 kademe, röle 5 bar", "5.1, 13.4, 21", (0, 0, -380),
        supply="İkinci el (donör)")
    add("L03", pipe([(-130, 0, -120), (-90, 0, -135), (-40, 0, -143)], 9, 7).fuse(
        cylz(22, -148, -144, -40, 0)), "Yağ emiş borusu ve süzgeç", 6, "Çelik", C["steel"],
        "Ø18 boru, süzgeç Ø44", "5", (0, 0, -380))

    # ---------------- 7 Tahrik plakası / tetik
    fp = cylx(140, 192, 195, 0, 0).fuse(tube(143, 128, (192, 0, 0), (1, 0, 0), 12))
    fp = fp.cut(cylx(20, 190, 200, 0, 0))
    for k in range(6):
        a = 2 * math.pi * k / 6
        fp = fp.cut(cylx(14, 190, 200, 85 * math.cos(a), 85 * math.sin(a)))
    add("K05", fp.clean(), "Tahrik plakası (flexplate) + marş dişlisi", 7, "Çelik sac",
        C["steel_dark"], "Ø286, CVT tork konvertörüne bağlanır (damper'sız)", "6, 11.2, 13.5",
        (220, 0, 0))
    tw = cylx(52, -239, -235, 0, 0)
    for k in range(60):
        if k in (58, 59):
            continue
        a = 360 * k / 60
        tw = tw.fuse(box(-239, -235, -1.8, 1.8, 51, 56).moved(cq.Location(V(0, 0, 0), V(1, 0, 0), a)))
    add("K06", tw.clean(), "Krank tetik tekerleği 60-2", 7, "Çelik", C["steel"],
        "Ø112, 58 diş + 2 boşluk", "7.3, 7.9", (-150, 0, 0))
    cs = cylz(9, -95, -62, -237, 0).fuse(box(-247, -227, -12, 12, -105, -95))
    add("S01", cs.clean(), "Krank konum sensörü (Hall)", 7, "Plastik gövde", C["black"],
        "Hall, tek cıvata flanşlı", "7.3, 7.9", (-150, 0, -80))

    # ---------------- 8 Kapak grubu
    add("H01", build_gasket(), "Kapak contası (MLS)", 8, "Çok katlı çelik", C["steel"],
        "0,7 mm, bore Ø74, kalibre su delikleri Ø4–7", "3.1, 10.3", (0, 0, 200))
    add("H02", build_head(), "Silindir kapağı DOHC 16V", 8, "AlSi7Mg T6 / AlSi10Mg", C["al"],
        "Pentroof 28°, emme Ø27,5 / egzoz Ø23,5, M10 buji, 84 mm pitch", "1.3, 3.3, 8.4, 10.1",
        (0, 0, 380), supply="Sanayi (döküm+işleme)")
    add("H03", build_cam_caps(), "Eksantrik yatak kepleri (10)", 8, "Al", C["al_dark"],
        "Ø30 yatak, 20 mm genişlik", "3.3", (0, 0, 540))
    vi = 0
    for i, cx in enumerate(CYL_X):
        lin = valve_lift(CYCLE[i], IN_PEAK, IN_DUR, LIFT_IN)
        lex = valve_lift(CYCLE[i], EX_PEAK, EX_DUR, LIFT_EX)
        for (sx, sy, d, intake, lift) in ((-X_IN, Y_IN, D_IN, True, lin), (X_IN, Y_IN, D_IN, True, lin),
                                          (-X_EX, Y_EX, D_EX, False, lex), (X_EX, Y_EX, D_EX, False, lex)):
            vi += 1
            a, _ = valve_axis(sy, intake)
            loc = cq.Location(V(cx + sx, sy, roof_z(sy)), V(1, 0, 0), a)
            valve, spring, retainer, bucket = valve_set_local(d, lift)
            kind = "emme" if intake else "egzoz"
            ex = (0, 0, 380)
            add(f"H04-{vi:02d}", valve.moved(loc), f"Supap {kind} (sil. {i+1})", 8,
                "Emme: çelik / Egzoz: Ni-Cr, sodyum dolgulu ops.", C["steel"] if intake else C["gold"],
                f"Ø{d}, sap Ø5,5, kaldırma {LIFT_IN if intake else LIFT_EX} mm", "1.3, 8.1",
                ex, qty_group=f"Supap {kind}")
            add(f"H05-{vi:02d}", spring.moved(loc), f"Supap yayı (sil. {i+1})", 8, "Si-Cr yay çeliği",
                C["blue"], "Ø22 ort., ön yük ≥ 384 N, k ≈ 29 N/mm", "7.2", ex, qty_group="Supap yayı")
            add(f"H06-{vi:02d}", retainer.moved(loc), f"Supap tutucu + kama (sil. {i+1})", 8, "Çelik",
                C["steel_dark"], "Ø23", "7.2", ex, qty_group="Supap tutucu")
            add(f"H07-{vi:02d}", bucket.moved(loc), f"Kovan itici (sil. {i+1})", 8, "Çelik, DLC",
                C["steel"], "Ø30 × 18, ayar pulu", "7.2", ex, qty_group="Kovan itici")
    for mx in MAIN_X:
        for y in (-56, 56):
            bolt = cylz(5, HEAD_Z0 + 96 - 140, HEAD_Z0 + 96, mx, y).fuse(
                cylz(8.5, HEAD_Z0 + 96, HEAD_Z0 + 106, mx, y))
            add(f"H08-{mx:+.0f}{'E' if y < 0 else 'X'}", bolt, "Kapak cıvatası M10×1,25 12.9",
                8, "12.9 alaşımlı çelik", C["black"],
                "Ön yük 38,7 kN, tork + açı (30 Nm + 2×90°)", "3.2, 10.1", (0, 0, 560),
                qty_group="Kapak cıvatası M10×1,25 12.9")

    # ---------------- 9 Eksantrik + VVT + zincir
    for intake in (True, False):
        k = "emme" if intake else "egzoz"
        add(f"V01-{k}", build_cam(intake), f"Eksantrik mili {k}", 9, "Çelik (kütükten taşlama)",
            C["steel"], f"Taban Ø36, kaldırma {LIFT_IN if intake else LIFT_EX} mm, süre "
            f"{IN_DUR if intake else EX_DUR}° KA, LSA 107°", "8.1, 7.2", (0, 0, 520),
            qty_group="Eksantrik mili")
        cyy, czz = CAM_IN if intake else CAM_EX
        ph = cylx(46, -224, -205, cyy, czz).fuse(gear_x(50, 40, -203, 14, cyy, czz))
        ph = ph.fuse(cylx(20, -229, -224, cyy, czz))
        add(f"V02-{k}", ph.clean(), f"VVT faz ayarlayıcı + dişli ({k})", 9, "Çelik/Al, kanatlı",
            C["teal"], f"Kanatlı tip, aralık {'50' if intake else '30'}° KA, kilit pimi",
            "14.1, 8.2", (-120, 0, 520), qty_group="VVT faz ayarlayıcı",
            supply="İkinci el (donör)")
        ocv = cyly(9, -20, 20, -175, czz + 30).fuse(box(-185, -165, -8, 8, czz + 38, czz + 52))
        ocv = ocv.moved(cq.Location(V(0, cyy, 0)))
        add(f"V03-{k}", ocv.clean(), f"OCV oransal solenoid ({k})", 9, "Plastik/çelik", C["black"],
            "4/3 oransal, PWM 250–300 Hz", "14.1", (-60, 0, 560), qty_group="OCV solenoid")
    add("V04", gear_x(25, 20, -203, 14, 0, 0), "Krank zincir dişlisi", 9, "Çelik", C["steel"],
        "Ø50, 2:1 oran", "21", (-120, 0, 0))
    circles = [(0, 0, 25), (CAM_IN[0], CAM_IN[1], 50), (CAM_EX[0], CAM_EX[1], 50)]
    add("V05", band_x(circles, -203, 14, 0.5, 7), "Duplex triger zinciri", 9, "Çelik",
        C["steel_dark"], "Duplex, gergi + kılavuz", "21", (-120, 0, 250))
    tens = box(-202, -190, -62, -52, 60, 260).fuse(cylx(10, -202, -186, -68, 120))
    guide = box(-202, -190, 50, 62, 60, 260)
    add("V06", tens.clean(), "Zincir gergisi + pabuç", 9, "Hidrolik gergi, PA66 pabuç",
        C["orange"], "Hidrolik, yağ beslemeli", "21", (-120, -60, 250))
    add("V07", guide, "Zincir kılavuzu", 9, "PA66", C["orange"], "Sabit kılavuz", "21",
        (-120, 60, 250))
    cover = plate_x([(0, 0, 40), (CAM_IN[0], CAM_IN[1], 62), (CAM_EX[0], CAM_EX[1], 62),
                     (0, -100, 40)], -234, 6, 6).cut(cylx(17, -240, -220, 0, 0))
    add("V08", cover, "Zincir kapağı (ön kapak)", 9, "Al döküm", C["al_dark"],
        "Krank keçesi Ø34", "21", (-260, 0, 150))

    # ---------------- 10 Ateşleme
    for i, cx in enumerate(CYL_X):
        z0 = roof_z(0)
        plug = fuse(cylz(5, z0 - 1, z0 + 19, cx, 0),
                    cq.Workplane("XY", origin=(cx, 0, z0 + 19)).polygon(6, 16 / math.cos(math.pi / 6)).extrude(10).val(),
                    cylz(5, z0 + 29, z0 + 70, cx, 0))
        add(f"I01-{i+1}", plug, f"M10 buji {i+1}", 10, "Cu çekirdek, 2 kademe soğuk, ince elektrot",
            C["ceramic"], "M10, ısı derecesi 2 kademe soğuk, aralık 0,7 mm", "3.3, 13.2", (0, 0, 640),
            qty_group="M10 buji")
        coil = cylz(10, z0 + 66, HEAD_TOP + 60, cx, 0).fuse(
            box(cx - 16, cx + 16, -14, 30, HEAD_TOP + 60, HEAD_TOP + 82))
        add(f"I02-{i+1}", coil.clean(), f"Kalem bobin (COP) {i+1}", 10, "Plastik gövde", C["black"],
            "Gövde Ø ≤ 20, ≥ 28 kV, 60–80 mJ", "7.5", (0, 0, 760), qty_group="COP bobin")
    add("I03", build_cam_cover(), "Kam kapağı (külbütör kapağı)", 10, "PA66-GF / Al", C["plastic"],
        "372×180×52 mm, COP delikleri Ø24", "7", (0, 0, 620))

    # ---------------- 11 Emme
    plen = box(-205, 175, -225, -165, 228, 296).cut(box(-200, 170, -220, -170, 233, 291))
    runners = []
    for cx in CYL_X:
        runners.append(tube(21, 17, (cx, -168, 262), (0, 1, 0), 78))
    flange = box(-180, 180, -92, -80, 238, 286)
    for cx in CYL_X:
        flange = flange.cut(cyly(17, -93, -79, cx, 262))
    im = fuse(plen, *runners, flange)
    for cx in CYL_X:
        im = im.cut(cyly(17, -170, -79, cx, 262))
    add("E01", im.clean(), "Emme manifoldu (plenum + runner, TCV entegre)", 11, "PA6-GF30",
        C["plastic"], "Plenum ≤ 2,5 L, runner Ø34, TCV (alt %60 kesit)", "1.3, 8.4, 2.4", (0, -240, 40))
    tb = tube(32, 25, (-262, -195, 262), (1, 0, 0), 58).fuse(box(-245, -235, -235, -215, 240, 290))
    tb = tb.fuse(box(-236, -234, -196, -194, 238, 286))          # kelebek mili / plaka
    tb = tb.fuse(cylx(24.5, -236, -234, -195, 262))
    add("E02", tb.clean(), "Elektronik gaz kelebeği (drive-by-wire)", 11, "Al gövde", C["al"],
        "Ø50 kelebek, çift TPS", "7.3", (-120, -240, 40), supply="İkinci el")
    rail_y, rail_z = -112, 300
    for i, cx in enumerate(CYL_X):
        tip = V(cx, -88, 270)
        d = V(0, -0.45, 0.893)
        inj = cq.Solid.makeCylinder(7, 48, tip, d).fuse(cq.Solid.makeCylinder(4, 8, tip - d * 6, d))
        add(f"E03-{i+1}", inj, f"Enjektör {i+1} (MPI)", 11, "Plastik/çelik", C["orange"],
            "≥ 200 cc/dk @ 3,5 bar, EOI IVO'dan 20–40° önce", "7.4", (0, -280, 120),
            qty_group="Enjektör")
    rail = cylx(11, -200, 180, rail_y, rail_z + 14).fuse(box(-190, -180, rail_y - 10, rail_y + 10, 250, rail_z + 14))
    add("E04", rail.clean(), "Yakıt rayı", 11, "Paslanmaz çelik", C["ss"], "Ø22, 3,5 bar sabit fark",
        "7.4", (0, -300, 180))

    # ---------------- 12 Egzoz + turbo
    fl = box(-180, 180, 80, 92, 220, 262)
    for cx in CYL_X:
        fl = fl.cut(cyly(17.5, 79, 93, cx, 240))
    prim = [fl]
    portA, portB = (20, 184, 182), (20, 184, 232)
    for i, cx in enumerate(CYL_X):
        if i in (0, 3):  # 1-4 kolu
            s = 1 if cx > 0 else -1
            pts = [(cx, 90, 240), (cx, 115, 236), (s * 55, 150, 200), portA]
        else:            # 2-3 kolu
            pts = [(cx, 90, 240), (cx, 115, 242), (cx * 0.5 + 10, 152, 236), portB]
        prim.append(pipe(pts, 19, 17.5))
    coll = box(-10, 50, 182, 194, 160, 255)
    prim.append(coll)
    add("X01", fuse(*prim), "Twin-scroll egzoz manifoldu (1-4 / 2-3)", 12, "1.4828 / 321 paslanmaz",
        C["ss"], "Kol Ø38×1,5 (iç Ø35), kol boyu 150–200 mm, flanş 10 mm", "19.2, 7.6", (0, 240, 0),
        supply="Sanayi (kaynak)")
    TY, TZ = 245, 207
    turb = fuse(cylx(62, 0, 55, TY, TZ), cylx(30, 55, 85, TY, TZ), box(-5, 45, 192, 215, 165, 250))
    chra = cylx(34, -38, 0, TY, TZ)
    comp = fuse(cylx(58, -92, -38, TY, TZ), tube(28, 24, (-140, TY, TZ), (1, 0, 0), 48),
                tube(26, 22, (-65, TY, TZ + 40), (0, 0, 1), 35))
    add("X02", turb, "Turbo türbin gövdesi (twin-scroll, A/R 0,65–0,70)", 12, "Ni-Resist / paslanmaz",
        C["red"], "BorgWarner K03 twin-scroll, T3 ≤ 1273 K", "2.3, 19.1", (0, 400, 0),
        supply="Yeni ilan ≈ 443 € / ikinci el")
    add("X03", chra, "Turbo yatak gövdesi (CHRA, su soğutmalı)", 12, "Dökme demir", C["iron"],
        "Motor yağı + su soğutma", "19.1", (0, 400, 0))
    add("X04", comp, "Turbo kompresör gövdesi", 12, "Al döküm", C["al"],
        "TD025/K03 sınıfı, D2 42–46 mm, PR 2,14", "2.2, 19.1", (0, 400, 0))
    ewg = box(-80, -30, TY + 55, TY + 95, TZ - 20, TZ + 25).fuse(cyly(4, TY + 40, TY + 60, 20, TZ - 5))
    add("X05", ewg.clean(), "Elektronik wastegate aktüatörü (rotary)", 12, "Al/plastik", C["black"],
        "Etkin alan ≥ 196 mm², valf Ø22", "2.3, 9.2", (0, 470, 60))
    dp = pipe([(85, TY, TZ), (120, TY, TZ), (135, TY, 120), (135, TY, -80)], 28, 26)
    add("X06", dp, "Downpipe + yakın bağlı katalizör girişi", 12, "Paslanmaz", C["ss"],
        "Ø56, katalizör ısıtma (bölüm 13.3)", "13.3", (0, 400, -120))

    # ---------------- 13 Soğutma / filtre
    wp = cylx(42, -226, -186, 60, 120).fuse(cyly(14, 100, 140, -205, 120))
    add("C01", wp.clean(), "Mekanik su pompası", 13, "Al gövde", C["al_dark"],
        "154 L/dk @6000, Δp 1,2 bar", "5.3, 10.3", (-200, 80, 0), supply="İkinci el (donör)")
    th = box(186, 216, -25, 25, 230, 270).fuse(cylx(14, 216, 250, 0, 250))
    add("C02", th.clean(), "Termostat gövdesi + ECT sensörü", 13, "PA66 / Al", C["plastic"],
        "Termostat → radyatör, bypass", "10.3", (200, 0, 0))
    of = cyly(38, 95, 190, -110, 30).fuse(cyly(26, 70, 95, -110, 30))
    add("C03", of.clean(), "Yağ filtresi + modül", 13, "Çelik kartuş", C["blue"], "Ø76 × 95", "5",
        (0, 220, -40))

    # ---------------- 14 Aksesuar tahriki
    AP = {"krank": (0, 0, 75), "alt": (-160, 110, 30), "su": (60, 120, 50),
          "hp": (-150, -20, 55), "ger": (70, -10, 35)}
    add("A01", cylx(75, -265, -243, 0, 0).cut(cylx(55, -266, -258, 0, 0)).fuse(cylx(55, -265, -258, 0, 0)),
        "Krank kasnağı (torsiyon damperli)", 14, "Çelik/kauçuk", C["steel_dark"], "Ø150, PK kayış",
        "7.7", (-320, 0, 0))
    ay, az, _ = AP["alt"]
    alt = cylx(60, -236, -128, ay, az).fuse(cylx(28, -262, -236, ay, az))
    add("A02", alt.clean(), "Alternatör (OAD kasnaklı)", 14, "Al gövde / Cu sargı", C["copper"],
        "110–140 A @14 V, kasnak oranı 2,3–2,6", "7.7", (-300, -120, 60))
    add("A03", cylx(50, -262, -243, 60, 120), "Su pompası kasnağı", 14, "Çelik", C["steel_dark"],
        "Ø100", "5.3", (-320, 80, 0))
    gy, gz, _ = AP["ger"]
    add("A04", cylx(35, -262, -243, gy, gz).fuse(box(-240, -232, gy - 10, gy + 10, gz, gz + 60)),
        "Kayış gergisi", 14, "Çelik/Al", C["al_dark"], "Otomatik gergi Ø70", "—", (-320, 40, 0))
    belt = band_x([(0, 0, 75), (ay, az, 28), (60, 120, 50), (-150, -20, 55), (gy, gz, 35)],
                  -261, 17, 0.3, 4)
    add("A05", belt, "Kanallı kayış (PK)", 14, "EPDM", C["rubber"], "6PK", "7.7", (-360, 0, 0))

    # ---------------- 15 Hydro-Turbo
    hy, hz = -150, -20
    hp = cylx(45, -236, -136, hy, hz).fuse(cylx(55, -262, -243, hy, hz)).fuse(cylx(30, -243, -236, hy, hz))
    add("T01", hp.clean(), "Hidrolik pompa 10 cc + elektromanyetik kavrama", 15, "Çelik/Al",
        C["green"], "10 cc/dev, klima kompresörü konumunda", "18.2, 18.3", (-200, -200, -60),
        supply="Yeni / hurdacı (kavrama)")
    RY, RZ = -182, 42
    rot = fuse(cylx(48, 30, 150, RY, RZ), cylx(70, 0, 34, RY, RZ),
               tube(26, 22, (-30, RY, RZ), (1, 0, 0), 32), tube(24, 20, (17, RY, RZ - 85), (0, 0, 1), 20))
    add("T02", rot.clean(), "Rotrex C15-60 yardımcı kompresör", 15, "Al, traction drive", C["teal"],
        "0,22 kg/s, PR 2,35, 150.000 / 11.840 d/d, 2,9 kg", "18.1", (0, -280, -60),
        supply="Yeni (2.100–2.400 €)")
    gm = box(150, 185, RY - 35, RY + 35, RZ - 35, RZ + 35).fuse(cylx(30, 185, 240, RY, RZ))
    add("T03", gm.clean(), "Hidrolik motor 3,2 cc + 1:2 dişli kademe", 15, "Çelik/Al", C["green"],
        "Flanşlı 1:2 hız artırıcı", "18.2, 18.3", (120, -280, -60))
    byp = cylz(30, 90, 140, -10, RY - 70).fuse(cylz(25, 140, 155, -10, RY - 70))
    add("T04", byp.clean(), "Baypas klapesi Ø50 + HT valf bloğu", 15, "Al", C["black"],
        "Kompresöre paralel, Ø50", "18.2", (0, -330, 40))
    tank = box(60, 190, -310, -240, 150, 245)
    add("T05", tank, "Hidrolik tank 2 L + filtre + hava-yağ soğutucu", 15, "Al / plastik", C["green"],
        "HLP 46, 10 µm dönüş filtresi", "18.2", (0, -360, 60))
    acc = cylx(65, -200, 200, -460, -110).fuse(cylx(70, -205, -195, -460, -110))
    add("T06", acc.clean(), "Akümülatör 4 L, 250+ bar (şasi rayı)", 15, "Çelik", C["red"],
        "Egzozdan ≥ 250 mm uzak, ısı kalkanı arkası", "18.2, 18.3", (0, -200, -60),
        note="Motor bölmesi dışında - konum temsilidir")
    hl1 = pipe([(-136, hy, hz), (-60, -200, -40), (100, -205, -20), (200, RY, RZ - 20)], 6)
    hl2 = pipe([(220, RY, RZ + 25), (215, -230, 120), (150, -255, 150)], 6)
    add("T07", hl1.fuse(hl2), "Hidrolik hortumlar (basınç / dönüş)", 15, "Hidrolik hortum",
        C["black"], "Ø12", "18.2", (0, -320, -60))

    # ---------------- 16 Şarj havası
    core = box(-150, 150, 330, 406, 0, 200)
    tanks = box(-190, -150, 325, 411, -10, 210).fuse(box(150, 190, 325, 411, -10, 210))
    add("F01", core, "Intercooler çekirdeği 300×200×76 (≈4,5 L)", 16, "Al, ofset şerit kanat",
        C["al"], "UA ≈ 224 W/K, ε 0,85, Δp ≤ 50 mbar", "2.4, 9.3", (0, 200, 0))
    add("F02", tanks, "Intercooler giriş / çıkış tankları", 16, "Al döküm", C["al_dark"],
        "Hacim ≤ 2,5 L (kompresör sonrası)", "2.4, 9.3", (0, 200, 0))
    pA = pipe([(-65, TY, TZ + 75), (-65, TY, 300), (-200, 200, 320), (-305, 90, 250),
               (-305, -120, 120), (-190, -240, 40), (-60, RY, RZ), (-30, RY, RZ)], 27)
    pC = pipe([(17, RY, RZ - 85), (30, -170, -130), (80, -60, -195), (130, 150, -195),
               (170, 280, -60), (170, 325, 40)], 27)
    pB = pipe([(-170, 325, 150), (-240, 290, 250), (-315, 150, 340), (-315, -100, 330),
               (-290, -195, 262), (-262, -195, 262)], 27)
    add("F03", pA, "Boost borusu: turbo → Rotrex", 16, "Al boru / silikon", C["blue"], "Ø54",
        "18.2", (0, 120, 80))
    add("F04", pC, "Boost borusu: Rotrex → intercooler", 16, "Al boru / silikon", C["blue"], "Ø54",
        "18.2", (0, 120, -120))
    add("F05", pB, "Boost borusu: intercooler → gaz kelebeği", 16, "Al boru / silikon", C["blue"],
        "Ø54, boru içi ≤ 20 mbar", "2.4", (-120, 120, 120))

    # ---------------- 17 Sensörler
    for k, xk in enumerate((-84, 84)):
        ks = cyly(13, -84, -70, xk, 120).fuse(box(xk - 6, xk + 6, -96, -84, 115, 140))
        add(f"S02-{k+1}", ks.clean(), f"Vuruntu sensörü {k+1}", 17, "Piezo", C["black"],
            "Sil. 1-2 / 3-4 arası, 20 Nm, band 5–9 kHz", "7.9, 12.2", (0, -150, 0),
            qty_group="Vuruntu sensörü")
    for k, (cyy, czz) in enumerate((CAM_IN, CAM_EX)):
        cms = cylx(9, 186, 212, cyy, czz).fuse(box(212, 228, cyy - 8, cyy + 8, czz - 6, czz + 20))
        add(f"S03-{k+1}", cms.clean(), f"Kam fazı sensörü {'emme' if k == 0 else 'egzoz'}", 17,
            "Hall", C["black"], "VVT konum geri beslemesi", "7.3, 14.1", (150, 0, 0),
            qty_group="Kam fazı sensörü")
    add("S04", box(-120, -90, -205, -180, 296, 312), "MAP + IAT sensörü (plenum)", 17, "Plastik",
        C["black"], "Plenum basınç/sıcaklık, speed-density", "7.3", (0, -240, 140))

    # ---------------- 18 Takozlar
    m1 = box(-232, -190, -40, 40, 330, 372).fuse(cylz(40, 372, 430, -211, 0))
    add("M01", m1.clean(), "M1 sağ motor takozu (hidrotakoz)", 18, "Hidrotakoz, Shore A 55",
        C["rubber"], "Yük %45, kz 311 N/mm", "11.1", (-60, 0, 300))
    m2 = box(186, 222, -40, 40, 200, 250).fuse(cylz(40, 250, 300, 240, 0)).fuse(box(222, 260, -30, 30, 225, 250))
    add("M02", m2.clean(), "M2 sol takoz (şanzıman tarafı)", 18, "Kauçuk, Shore A 55", C["rubber"],
        "Yük %40, kz 276 N/mm", "11.1", (120, 0, 200))
    m3 = box(-25, 25, -100, -60, -95, -45).fuse(box(-10, 10, -260, -100, -80, -60)).fuse(
        cyly(22, -280, -255, 0, -70))
    add("M03", m3.clean(), "M3 roll sınırlayıcı (burç tipi)", 18, "Kauçuk, Shore A 65–70",
        C["rubber"], "Yük %15, kz 104 N/mm", "11.1", (0, -180, -150))
    return STEPS


def export():
    os.makedirs(os.path.join(OUT, "step"), exist_ok=True)
    build_all()
    assy = cq.Assembly(name="NexDrive_STB")
    meta = []
    for p in PARTS:
        r, g, b = p["color"]
        assy.add(p["shape"], name=p["id"], color=cq.Color(r, g, b, 1.0))
        bb = p["shape"].BoundingBox()
        vol = p["shape"].Volume()
        m = {k: p[k] for k in ("id", "name", "step", "material", "dims", "section", "explode",
                               "group", "supply", "note")}
        m["color"] = "#%02x%02x%02x" % tuple(int(c * 255) for c in p["color"])
        m["bbox"] = [round(bb.xlen, 1), round(bb.ylen, 1), round(bb.zlen, 1)]
        m["center"] = [round(bb.center.x, 1), round(bb.center.y, 1), round(bb.center.z, 1)]
        m["volume_cm3"] = round(vol / 1000, 1)
        meta.append(m)
    # adım bazlı STEP
    for sid, sname, _ in STEPS:
        sa = cq.Assembly(name=f"Adim_{sid:02d}")
        for p in PARTS:
            if p["step"] == sid:
                r, g, b = p["color"]
                sa.add(p["shape"], name=p["id"], color=cq.Color(r, g, b, 1.0))
        sa.export(os.path.join(OUT, "step", f"{sid:02d}_{_slug(sname)}.step"))
    assy.export(os.path.join(OUT, "NexDrive_STB_Montaj.step"))
    assy.export(os.path.join(OUT, "NexDrive_STB_Montaj.glb"), tolerance=0.3, angularTolerance=0.45)
    with open(os.path.join(OUT, "parts.json"), "w", encoding="utf-8") as f:
        json.dump({"steps": [dict(id=s, name=n, desc=d) for s, n, d in STEPS], "parts": meta,
                   "params": dict(bore=BORE, stroke=STROKE, rod=ROD_L, pitch=PITCH, deck=round(DECK_Z, 2),
                                  head_top=round(HEAD_TOP, 1), cam_in=[round(c, 1) for c in CAM_IN],
                                  cam_ex=[round(c, 1) for c in CAM_EX], y_in=round(Y_IN, 2),
                                  y_ex=round(Y_EX, 2))},
                  f, ensure_ascii=False, indent=1)
    # BOM (gruplanmış)
    groups = {}
    for m in meta:
        g = groups.setdefault((m["step"], m["group"]), dict(qty=0, ids=[], m=m))
        g["qty"] += 1
        g["ids"].append(m["id"])
    with open(os.path.join(OUT, "BOM_parca_listesi.csv"), "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["Montaj adımı", "Adım adı", "Parça", "Adet", "Parça no", "Malzeme",
                    "Ana ölçüler", "Rapor bölümü", "Tedarik", "Not"])
        sn = {s: n for s, n, _ in STEPS}
        for (step, grp), g in sorted(groups.items(), key=lambda kv: (kv[0][0], kv[1]["ids"][0])):
            m = g["m"]
            w.writerow([step, sn[step], grp, g["qty"], ", ".join(g["ids"]), m["material"],
                        m["dims"], m["section"], m["supply"], m["note"]])
    print(f"{len(PARTS)} parça, {len(groups)} kalem, {len(STEPS)} montaj adımı -> {OUT}")


def _slug(s):
    tr = str.maketrans("çğıöşüÇĞİÖŞÜ ", "cgiosuCGIOSU_")
    return "".join(ch for ch in s.translate(tr) if ch.isalnum() or ch == "_")


if __name__ == "__main__":
    export()
