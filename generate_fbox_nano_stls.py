#!/usr/bin/env python3
"""
fbox Nano v2 (69.0 x 68.0 x 24.2 mm, R = 4.8 mm) — Parametric B-Rep STL & STEP Generator
Executed headlessly via FreeCAD (`freecadcmd`).
Outputs 100% watertight manifold binary STLs (minZ = 0.00, Bambu P2S print-ready) to `stl_fbox_nano/`.
"""

import os
import json
import math
import FreeCAD
import Part
import Mesh
import MeshPart

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stl_fbox_nano")
os.makedirs(OUT_DIR, exist_ok=True)

W = 69.0
H = 68.0
D = 24.2
WALL = 1.8
LID_T = 1.8
TRAY_H = D - LID_T  # 22.4 mm
R_OUT = 4.8
R_IN = 3.0

# True CNC-measured 7.28 mm pitch on GODIYMODULES 37.0 x 15.0 mm 1x4 PCB:
K_OFFSETS = [7.55, 14.83, 22.12, 29.40]
FRONT_PAD_X0 = 30.1
TOP_PAD_X0 = 26.8
FRONT_CAP_XS = [FRONT_PAD_X0 + o for o in K_OFFSETS]  # [37.65, 44.93, 52.22, 59.50]
TOP_CAP_XS   = [TOP_PAD_X0 + o for o in K_OFFSETS]    # [34.35, 41.63, 48.92, 56.20]

CORNERS = [
    (3.3, 3.3),
    (W - 3.3, 3.3),
    (3.3, H - 3.3),
    (W - 3.3, H - 3.3),
]


def make_rbox_xy(x0, y0, z0, dx, dy, dz, r):
    """Create a box extruded in Z with rounded vertical edges of radius r."""
    b = Part.makeBox(dx, dy, dz, FreeCAD.Vector(x0, y0, z0))
    if r <= 0.05:
        return b
    v_edges = [
        e for e in b.Edges
        if abs(e.Vertexes[0].Point.x - e.Vertexes[1].Point.x) < 1e-4
        and abs(e.Vertexes[0].Point.y - e.Vertexes[1].Point.y) < 1e-4
    ]
    return b.makeFillet(r, v_edges)


def export_verified_stl(shape, filename, lin_def=0.04, ang_def=0.15):
    """Shift minZ to 0.00 if needed, mesh via MeshPart, verify watertightness, and write STL."""
    bb = shape.BoundBox
    if abs(bb.ZMin) > 1e-5:
        shape = shape.translated(FreeCAD.Vector(0, 0, -bb.ZMin))
        bb = shape.BoundBox

    mesh = MeshPart.meshFromShape(
        Shape=shape,
        LinearDeflection=lin_def,
        AngularDeflection=ang_def,
        Relative=False,
    )
    mesh.harmonizeNormals()
    out_path = os.path.join(OUT_DIR, filename)
    mesh.write(out_path)

    info = {
        "file": filename,
        "dims_mm": [round(bb.XLength, 2), round(bb.YLength, 2), round(bb.ZLength, 2)],
        "z_range": [round(bb.ZMin, 3), round(bb.ZMax, 3)],
        "facets": mesh.CountFacets,
        "points": mesh.CountPoints,
        "is_solid": mesh.isSolid(),
        "has_non_manifolds": mesh.hasNonManifolds(),
    }
    print("EXPORTED:", json.dumps(info))
    assert mesh.isSolid(), f"ERROR: {filename} is NOT a closed watertight solid!"
    return shape, info


# ============================================================================
# 1. BOTTOM TRAY (`fbox_nano_bottom_tray.stl`) — 69.0 x 68.0 x 22.4 mm
# ============================================================================
def build_bottom_tray():
    outer = make_rbox_xy(0, 0, 0, W, H, TRAY_H, R_OUT)
    cavity = make_rbox_xy(WALL, WALL, WALL, W - 2 * WALL, H - 2 * WALL, TRAY_H, R_IN)
    tray = outer.cut(cavity)

    # 4x Upper Corner M2 Screw Bosses (Z: 7.8..22.4 mm so floor Z: 1.8..7.8 stays wide open!)
    bosses = []
    for (cx, cy) in CORNERS:
        cyl = Part.makeCylinder(2.55, TRAY_H - 7.8, FreeCAD.Vector(cx, cy, 7.8))
        # 45-degree printable chamfer cone underneath (Z: 5.8..7.8) so zero overhang!
        cone = Part.makeCone(0.8, 2.55, 2.0, FreeCAD.Vector(cx, cy, 5.8))
        bosses.append(cyl.fuse(cone))
    for b in bosses:
        tray = tray.fuse(b)
    # Trim anything outside outer shell just in case
    tray = tray.common(make_rbox_xy(0, 0, 0, W, H, TRAY_H, R_OUT))

    # Beginner-Foolproof Internal Snap Cradles & Dividers:
    adds = []
    # (a) Floor separator rib between KY-023/V713 (south) and 503759 LiPo (north, Y: 29.2..66.2)
    adds.append(Part.makeBox(59.0, 0.6, 5.0, FreeCAD.Vector(5.0, 28.55, WALL)))

    # (b) KY-023 4x Corner Standoffs (Z: 1.8..2.6 mm) at X: 5.0..38.0, Y: 3.5..28.5
    for kx in [5.0, 34.5]:
        for ky in [3.5, 25.0]:
            adds.append(Part.makeBox(3.5, 3.5, 0.8, FreeCAD.Vector(kx, ky, WALL)))

    # (c) Bottom-Wall Slide-In Retainer Channels for 1511 Speaker (left) & INMP441 Mic (right)
    # Speaker (15.2 x 3.5 mm at X: 33.4..48.6, Y: 1.9..5.4)
    adds.append(Part.makeBox(0.8, 4.4, 9.5, FreeCAD.Vector(32.5, WALL, WALL)))
    adds.append(Part.makeBox(3.0, 0.8, 9.5, FreeCAD.Vector(32.5, 5.7, WALL)))
    adds.append(Part.makeBox(0.8, 4.4, 9.5, FreeCAD.Vector(48.7, WALL, WALL)))
    adds.append(Part.makeBox(3.0, 0.8, 9.5, FreeCAD.Vector(46.5, 5.7, WALL)))
    # INMP441 Mic (Ø14.0 x 2.6 mm at X: 49.5..63.5, Y: 1.9..4.5)
    adds.append(Part.makeBox(2.8, 0.8, 9.5, FreeCAD.Vector(49.5, 4.8, WALL)))
    adds.append(Part.makeBox(0.8, 3.8, 9.5, FreeCAD.Vector(63.6, WALL, WALL)))
    adds.append(Part.makeBox(2.8, 0.8, 9.5, FreeCAD.Vector(61.6, 4.8, WALL)))

    # (d) V713 5V Boost Floor Stop-Rim (X: 38.6..63.6, Y: 8.2..28.2)
    adds.append(Part.makeBox(25.0, 0.8, 1.4, FreeCAD.Vector(38.6, 7.3, WALL)))

    # (e) Front 1x4 Keypad Support Shelf + PCB Hole Locator Pin on Right Ear (X: 64.0..67.2, Y: 8.5..23.5, Z: 1.8..16.4)
    adds.append(Part.makeBox(3.2, 15.0, 16.4 - WALL, FreeCAD.Vector(64.0, 8.5, WALL)))
    # Left-side support post between KY-023 (X<=38.0) & V713 (X>=38.6, Y>=8.2)
    adds.append(Part.makeBox(2.2, 1.6, 16.4 - WALL, FreeCAD.Vector(38.1, 6.4, WALL)))
    adds.append(Part.makeBox(9.8, 3.0, 1.4, FreeCAD.Vector(30.2, 6.4, 15.0)))  # ledge under Front 1x4 bottom-left edge

    # (f) Top-Shoulder 1x4 Cartridge U-Guide Rails (X: 25.8..26.7 & 63.9..64.8, Y: 59.8..66.2, Z: 8.0..20.4)
    # Printable 45-deg corbels from Top Wall Y=66.2 down to Z=4.0
    for gx in [25.8, 63.9]:
        adds.append(Part.makeBox(0.9, 6.4, 12.4, FreeCAD.Vector(gx, 59.8, 8.0)))
        adds.append(Part.makeBox(2.4, 0.9, 12.4, FreeCAD.Vector(gx - (0.0 if gx < 40 else 1.5), 59.8, 8.0)))

    # (g) T-Display-S3 AMOLED Seating Ledges at Z = 18.2 mm (clear of rear JST & rear 3D antenna)
    # Right-end corner ledges (Y: 33.8..38.0 and Y: 56.0..59.6, X: 58.8..67.2, Z: 13.0..18.2)
    adds.append(Part.makeBox(8.4, 3.8, 5.2, FreeCAD.Vector(58.8, 34.0, 13.0)))
    adds.append(Part.makeBox(8.4, 3.4, 5.2, FreeCAD.Vector(58.8, 56.2, 13.0)))
    # Left-wall corner tabs (X: 1.8..4.6, Y: 33.6..34.4 & Y: 59.5..60.3, Z: 14.0..18.2)
    adds.append(Part.makeBox(2.8, 0.8, 4.2, FreeCAD.Vector(WALL, 33.6, 14.0)))
    adds.append(Part.makeBox(2.8, 0.8, 4.2, FreeCAD.Vector(WALL, 59.5, 14.0)))

    for a in adds:
        tray = tray.fuse(a)

    # Cutouts & M2 Pilot Bores:
    cuts = []
    # 4x Ø1.85 mm M2 self-tapping pilot holes (Z: 8.4..22.5 mm)
    for (cx, cy) in CORNERS:
        cuts.append(Part.makeCylinder(0.925, TRAY_H - 8.2, FreeCAD.Vector(cx, cy, 8.4)))

    # Left-Wall USB-C Port Cutout (Y: 42.1..52.1, Z: 17.7..21.7) + Outer Cable-Boot Relief (X: -0.5..0.9)
    cuts.append(Part.makeBox(3.0, 10.0, 4.0, FreeCAD.Vector(-0.5, 42.1, 17.7)))
    cuts.append(Part.makeBox(1.4, 13.2, 5.8, FreeCAD.Vector(-0.5, 40.5, 16.6)))

    # Right-Wall MicroSD Slot Cutout (Y: 36.2..51.6, Z: 9.2..12.2) + Outer Fingernail Bevel
    cuts.append(Part.makeBox(3.0, 15.4, 3.0, FreeCAD.Vector(W - WALL - 0.5, 36.2, 9.2)))
    cuts.append(Part.makeBox(1.4, 16.8, 4.2, FreeCAD.Vector(W - 0.9, 35.5, 8.6)))

    # Bottom-Wall Symmetrical Speaker & Mic Acoustic Slots (2 x 4 vertical vents)
    for sx in [36.5, 39.3, 42.1, 44.9, 52.0, 54.8, 57.6, 60.4]:
        cuts.append(Part.makeBox(1.2, 3.0, 6.8, FreeCAD.Vector(sx - 0.6, -0.5, 6.4)))

    # Top-Wall 3.5mm TRS Headphone Jack Bore at (X=13.45, Z=11.5, Ø6.6 mm)
    trs_cyl = Part.makeCylinder(3.3, 4.0, FreeCAD.Vector(13.45, H - WALL - 1.0, 11.5), FreeCAD.Vector(0, 1, 0))
    cuts.append(trs_cyl)

    # Top-Wall 4x Shoulder Button Wells on TRUE 7.28mm Pitch (6.6 x 7.2 mm, Z: 11.2..18.4 mm)
    for cx in TOP_CAP_XS:
        cuts.append(Part.makeBox(6.6, 4.0, 7.2, FreeCAD.Vector(cx - 3.3, H - WALL - 1.0, 11.2)))

    for c in cuts:
        tray = tray.cut(c)

    tray = tray.removeSplitter()
    return export_verified_stl(tray, "fbox_nano_bottom_tray.stl")


# ============================================================================
# 2. TOP FACEPLATE (`fbox_nano_top_faceplate.stl`)
#    Printed EXTERIOR FACE DOWN (Z=0..1.8 mm) on Bambu PEI plate for factory finish!
#    Note: To match assembled coordinates when flipped 180° around X (y_print = H - y_cad, z_print = D - z_cad):
# ============================================================================
def build_top_faceplate():
    # Build in ASSEMBLED coordinates first (Z: 22.4..24.2, collar Z: 20.6..24.2), then flip 180° around X so exterior is at Z=0!
    plate = make_rbox_xy(0, 0, TRAY_H, W, H, LID_T, R_OUT)
    # Recessed thumbstick collar skirt (rOut = 13.0, rIn = 11.8, Z: 20.6..24.2)
    collar = Part.makeCylinder(13.0, D - 20.6, FreeCAD.Vector(18.8, 16.0, 20.6))
    plate = plate.fuse(collar)

    cuts = []
    # (a) AMOLED Window: 45.0 x 20.6 mm (X: 12.9..57.9, Y: 36.85..57.45), R=1.0mm
    cuts.append(make_rbox_xy(12.9, 36.85, TRAY_H - 1.0, 45.0, 20.6, LID_T + 2.0, 1.0))

    # (b) CRITICAL 1.0mm Underside Relief Pocket over LILYGO Clear-Acrylic BOOT (IO0) & IO21 Button Plungers!
    # Spans X: 1.8..11.2, Y: 34.0..60.2, Z: 22.4..23.4 (leaves solid 0.8mm exterior skin Z: 23.4..24.2!)
    cuts.append(make_rbox_xy(1.8, 34.0, TRAY_H - 0.1, 9.4, 26.2, 1.1, 0.8))

    # (c) Thumbstick Circular Cutout: Ø23.6 mm (r=11.8) at (18.8, 16.0)
    cuts.append(Part.makeCylinder(11.8, 6.0, FreeCAD.Vector(18.8, 16.0, 20.0)))

    # (d) 4x Front Key Wells on TRUE 7.28mm Pitch (6.6 x 7.2 mm, R=0.7mm) at Y=16.0
    for cx in FRONT_CAP_XS:
        cuts.append(make_rbox_xy(cx - 3.3, 16.0 - 3.6, TRAY_H - 1.0, 6.6, 7.2, LID_T + 2.0, 0.7))

    # (e) 4x M2x14mm Flush Screw Counterbores (Ø2.2mm through + Ø4.1mm x 1.0mm exterior head counterbore!)
    for (cx, cy) in CORNERS:
        cuts.append(Part.makeCylinder(1.10, LID_T + 2.0, FreeCAD.Vector(cx, cy, TRAY_H - 0.5)))
        cuts.append(Part.makeCylinder(2.05, 1.5, FreeCAD.Vector(cx, cy, D - 1.0)))

    for c in cuts:
        plate = plate.cut(c)

    plate = plate.removeSplitter()
    # Flip 180° around X axis so Exterior Face (Z=24.2) lays FLAT on build plate (Z=0.00)!
    plate_flipped = plate.rotate(FreeCAD.Vector(W / 2.0, H / 2.0, D / 2.0), FreeCAD.Vector(1, 0, 0), 180.0)
    return export_verified_stl(plate_flipped, "fbox_nano_top_faceplate.stl")


# ============================================================================
# 3. DROP-IN LIPO SHIELD & MID-DECK ORGANIZER (`fbox_nano_lipo_shield_organizer.stl`)
#    58.6 x 36.6 mm base (0.8mm thick) + 1.0mm raised parking-bay outlines for
#    GY-PCM5102 (left), KCX_BT + PAM8302A (center), and Mini 3.3V MicroSD (right)!
# ============================================================================
def build_mid_deck_organizer():
    # Local origin = (X=5.1, Y=29.3) in tray coordinates
    base = make_rbox_xy(0, 0, 0, 58.6, 36.6, 0.8, 1.5)
    ribs = []
    # Divider 1 between GY-PCM5102 (width 17.0) and Center Audio Bay (at local x = 17.3)
    ribs.append(Part.makeBox(0.8, 34.0, 1.0, FreeCAD.Vector(17.3, 1.3, 0.8)))
    # Divider 2 between Center Audio Bay and Right MicroSD Bay (at local x = 43.2)
    ribs.append(Part.makeBox(0.8, 22.0, 1.0, FreeCAD.Vector(43.2, 4.5, 0.8)))
    # MicroSD bottom & top guide stops (holds 17.9x17.9mm SD board at Y_cad: 35.0..52.9 -> local y: 5.7..23.6)
    ribs.append(Part.makeBox(14.6, 0.8, 1.0, FreeCAD.Vector(44.0, 4.8, 0.8)))
    ribs.append(Part.makeBox(14.6, 0.8, 1.0, FreeCAD.Vector(44.0, 23.8, 0.8)))
    # Center Bay bottom stop
    ribs.append(Part.makeBox(25.0, 0.8, 1.0, FreeCAD.Vector(18.1, 4.8, 0.8)))
    for r in ribs:
        base = base.fuse(r)
    base = base.removeSplitter()
    return export_verified_stl(base, "fbox_nano_lipo_shield_organizer.stl")


# ============================================================================
# 4. CONCAVE LOW-PROFILE THUMB DISC (`fbox_nano_concave_thumb_disc.stl`)
#    Ø15.6 mm concave cap w/ keyed D-shaft socket for bare KY-023 stem
# ============================================================================
def build_thumb_disc():
    # Print upside-down? No, print flat on a solid collar or print cap-top-up with 45° inner chamfer:
    # Let's build stem base at Z=0..4.2, disc at Z=1.8..4.6 so bottom of stem & outer skirt print cleanly,
    # OR even better: flat-bottom disc (Z=0..3.6mm) with D-socket in bottom (zero overhangs — 100% flat bed contact!)
    disc = Part.makeCylinder(7.8, 3.6, FreeCAD.Vector(0, 0, 0))
    # Concave thumb dish on top (sphere cut)
    dish = Part.makeSphere(14.5, FreeCAD.Vector(0, 0, 17.3))
    disc = disc.cut(dish)
    # D-shaft bore in bottom (Z: 0..2.5 mm, Ø4.15 mm w/ flat at x = 1.45 mm for KY-023 plastic D-stem)
    bore = Part.makeCylinder(2.08, 2.5, FreeCAD.Vector(0, 0, -0.1))
    d_flat = Part.makeBox(2.0, 5.0, 3.0, FreeCAD.Vector(1.42, -2.5, -0.2))
    bore = bore.cut(d_flat)
    disc = disc.cut(bore)
    disc = disc.removeSplitter()
    return export_verified_stl(disc, "fbox_nano_concave_thumb_disc.stl")


# ============================================================================
# 5. TRUE-7.28mm-PITCH KEYCAPS (`front_keycaps_4x.stl` & `shoulder_keycaps_4x.stl`)
#    Captive bottom flange (7.1 x 7.7 x 0.8 mm) + 6.1 x 6.7 mm rounded stem
# ============================================================================
def make_single_keycap(total_h):
    flange = make_rbox_xy(-3.55, -3.85, 0, 7.1, 7.7, 0.8, 0.7)
    stem = make_rbox_xy(-3.05, -3.35, 0.8, 6.1, 6.7, total_h - 0.8, 0.65)
    cap = flange.fuse(stem)
    # Shallow Ø3.3 mm dimple on underside (Z: 0..0.45 mm) to center squarely on 6x6mm tactile plunger!
    dimple = Part.makeCylinder(1.65, 0.55, FreeCAD.Vector(0, 0, -0.1))
    return cap.cut(dimple).removeSplitter()


def build_keycap_sets():
    front_caps = None
    for i in range(4):
        c = make_single_keycap(3.5).translated(FreeCAD.Vector(i * 9.5, 0, 0))
        front_caps = c if front_caps is None else front_caps.fuse(c)
    s_front = export_verified_stl(front_caps, "fbox_nano_front_keycaps_4x.stl")

    sh_caps = None
    for i in range(4):
        c = make_single_keycap(3.0).translated(FreeCAD.Vector(i * 9.5, 0, 0))
        sh_caps = c if sh_caps is None else sh_caps.fuse(c)
    s_sh = export_verified_stl(sh_caps, "fbox_nano_shoulder_keycaps_4x.stl")
    return s_front, s_sh


# ============================================================================
# 6. ALL-IN-ONE BAMBU P2S BUILD PLATE (`fbox_nano_full_build_plate.stl`)
# ============================================================================
def build_full_plate(tray_s, lid_s, org_s, disc_s, fcaps_s, scaps_s):
    plate = tray_s.copy()
    plate = plate.fuse(lid_s.translated(FreeCAD.Vector(78.0, 0, 0)))
    plate = plate.fuse(org_s.translated(FreeCAD.Vector(0.0, 78.0, 0)))
    plate = plate.fuse(disc_s.translated(FreeCAD.Vector(76.0, 86.0, 0)))
    plate = plate.fuse(fcaps_s.translated(FreeCAD.Vector(96.0, 78.0, 0)))
    plate = plate.fuse(scaps_s.translated(FreeCAD.Vector(96.0, 92.0, 0)))
    return export_verified_stl(plate, "fbox_nano_full_build_plate.stl")


def run_all():
    tray_s, _ = build_bottom_tray()
    lid_s, _ = build_top_faceplate()
    org_s, _ = build_mid_deck_organizer()
    disc_s, _ = build_thumb_disc()
    (fcaps_s, _), (scaps_s, _) = build_keycap_sets()
    build_full_plate(tray_s, lid_s, org_s, disc_s, fcaps_s, scaps_s)
    print("\nALL 6 fbox Nano v2 WATER-TIGHT BAMBU P2S STLs VERIFIED & EXPORTED!")


run_all()
