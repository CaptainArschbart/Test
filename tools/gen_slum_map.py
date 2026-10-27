#!/usr/bin/env python3
"""Erzeugt scenes/slum/slum.tscn, die Slum-Map „Sektor 7“, aus Mapkit-Knoten.

Jeder Eintrag ist ein Kit-Knoten (SlumBuilding, SlumProp, SlumStreet, SlumSign, SlumWalkway,
SlumCables) mit Position, Blickrichtung und Exporten. Die Geometrie baut der Knoten selbst.
Nach dem Erzeugen ist die Szene ganz normal im Editor bearbeitbar; wer hier etwas ändert und neu
erzeugt, überschreibt Änderungen aus dem Editor.

Aufruf aus dem Repo-Root:  python3 tools/gen_slum_map.py

Koordinaten: x nach Osten, z nach Süden (Norden = -Z). Kreuzung in der Mitte, Straßen 9 m breit,
Gehwege 3 m (Oberkante 0,15 m). Viertel: NO Wohnblöcke, NW Lagerhallen A2, SW Shanty-Viertel,
SO Markt/Nachtleben. Rand bei ±80 m mit Hochhäusern und unsichtbaren Wänden.
"""
from __future__ import annotations

import math
import os
import random

OUT = os.path.join(os.path.dirname(__file__), "..", "scenes", "slum", "slum.tscn")
rnd = random.Random(7)

FACING = {"S": 0.0, "E": 90.0, "N": 180.0, "W": -90.0}
STYLE = {"res": 0, "shop": 1, "warehouse": 2, "shanty": 3, "tower": 4}
SIDE = {"none": 0, "left": 1, "right": 2}
PROP = {k: i for i, k in enumerate(
    "CRATE CRATE_STACK MILITARY_CRATES DUMPSTER BARREL BARREL_GROUP AC_UNIT AC_STACK ELECTRIC_BOX "
    "PALLETS TRASH_BAGS TRASH_PILE CONCRETE_BARRIER STRIPED_BARRIER CONE HYDRANT STREET_LAMP POWER_POLE "
    "CONTAINER MARKET_STALL CAR_WRECK GENERATOR FENCE BENCH WATER_TANK NEWS_BOX FIRE_BARREL".split())}
MOUNT = {"wall": 0, "blade": 1, "roof": 2, "decal": 3}

nodes: list[str] = []
counter: dict[str, int] = {}


def uname(base: str) -> str:
    counter[base] = counter.get(base, 0) + 1
    return f"{base}{counter[base]}"


def xform(x: float, y: float, z: float, yaw_deg: float = 0.0) -> str:
    t = math.radians(yaw_deg)
    c, s = round(math.cos(t), 5), round(math.sin(t), 5)
    c = 0.0 if abs(c) < 1e-6 else c
    s = 0.0 if abs(s) < 1e-6 else s
    # Godot schreibt die Basis zeilenweise: (x.x, y.x, z.x, x.y, …). Drehung um Y: x = (c, 0, -s), z = (s, 0, c).
    return f"Transform3D({c}, 0, {s}, 0, 1, 0, {-s if s else 0.0}, 0, {c}, {round(x, 3)}, {round(y, 3)}, {round(z, 3)})"


def val(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return f'"{v}"'
    if isinstance(v, tuple) and len(v) == 2:
        return f"Vector2({v[0]}, {v[1]})"
    if isinstance(v, tuple) and len(v) == 4:
        return f"Color({v[0]}, {v[1]}, {v[2]}, {v[3]})"
    if isinstance(v, list) and all(isinstance(p, int) for p in v):
        return f"PackedInt32Array({', '.join(str(p) for p in v)})"
    if isinstance(v, list):
        inner = ", ".join(f"{p[0]}, {p[1]}, {p[2]}" for p in v)
        return f"PackedVector3Array({inner})"
    return str(v)


def node(name: str, parent: str, script_id: str, x: float, y: float, z: float, yaw: float = 0.0, **props) -> None:
    lines = [f'[node name="{name}" type="Node3D" parent="{parent}"]', f"transform = {xform(x, y, z, yaw)}",
             f'script = ExtResource("{script_id}")']
    for k, v in props.items():
        lines.append(f"{k} = {val(v)}")
    nodes.append("\n".join(lines))


def building(parent: str, style: str, x: float, z: float, facing: str, w: float, d: float, floors: int, **props) -> None:
    props.setdefault("seed_value", rnd.randint(1, 9999))
    node(uname(style.capitalize()), parent, "k_building", x, 0.0, z, FACING[facing], style=STYLE[style],
         footprint=(w, d), floors=floors, **props)


def prop(parent: str, kind: str, x: float, z: float, yaw: float = 0.0, y: float = 0.0, **props) -> None:
    props.setdefault("seed_value", rnd.randint(1, 9999))
    node(uname(kind.title().replace("_", "")), parent, "k_prop", x, y, z, yaw, kind=PROP[kind], **props)


def street(parent: str, x: float, z: float, yaw: float, **props) -> None:
    props.setdefault("seed_value", rnd.randint(1, 9999))
    node(uname("Street"), parent, "k_street", x, 0.0, z, yaw, **props)


def slab(parent: str, x: float, z: float, w: float, d: float, tex: str, height: float = 0.0, dirt: float = 0.5) -> None:
    node(uname("Ground"), parent, "k_street", x, 0.0, z, 0.0, kind=2, slab_texture=tex, slab_size=(w, d),
         height=height, dirt=dirt, seed_value=rnd.randint(1, 9999))


def sign(parent: str, tex: str, x: float, y: float, z: float, yaw: float, mount: str = "wall", width: float = 2.4,
         color=(1.0, 0.3, 0.4, 1.0), flicker: float = 0.0, energy: float = 1.6) -> None:
    node(uname("Sign"), parent, "k_sign", x, y, z, yaw, texture_name=tex, mount=MOUNT[mount], width=width,
         light_color=color, flicker=flicker, light_energy=energy)


def walkway(parent: str, x: float, y: float, z: float, yaw: float, length: float, **props) -> None:
    node(uname("Walkway"), parent, "k_walkway", x, y, z, yaw, length=length, **props)


def cables(parent: str, pts: list, sag: float = 0.6, bundle: int = 3, lanterns: bool = False, **props) -> None:
    """Jeder Punkt muss halten: an einer Wand (Wandhalter), an einem Strommast (wall_brackets=False)
    oder an einem eigenen Mast (poles=[Indizes], ggf. pole_ground)."""
    if "seed_value" not in props:
        props["seed_value"] = rnd.randint(1, 9999)
    node(uname("Cables"), parent, "k_cables", 0, 0, 0, 0, points=pts, sag=sag, bundle=bundle, lanterns=lanterns, **props)


def scatter(parent: str, kinds: list[str], x0: float, x1: float, z0: float, z1: float, count: int) -> None:
    for _ in range(count):
        prop(parent, rnd.choice(kinds), rnd.uniform(x0, x1), rnd.uniform(z0, z1), rnd.uniform(0, 360),
             variant=rnd.randint(0, 2))


# =====================================================================================
# Straßen
# =====================================================================================
nodes.append('[node name="Streets" type="Node3D" parent="."]')
P = "Streets"
HALF = 4.5  # halbe Fahrbahn
WALK = 3.0
EDGE = 75.0
seg_len = (EDGE - HALF) / 3.0
for i in range(3):
    zc = -HALF - seg_len * (i + 0.5)
    street(P, 0, zc, 0, length=seg_len, crosswalk_end=(i == 0))
    street(P, 0, -zc, 0, length=seg_len, crosswalk_start=(i == 0))
    street(P, zc, 0, 90, length=seg_len, crosswalk_end=(i == 0))
    street(P, -zc, 0, 90, length=seg_len, crosswalk_start=(i == 0))
node("Intersection", P, "k_street", 0, 0, 0, 0, kind=1, road_width=9.0, seed_value=3)
# Gehweg-Ecken an der Kreuzung
for sx in (-1, 1):
    for sz in (-1, 1):
        slab(P, sx * (HALF + WALK / 2), sz * (HALF + WALK / 2), WALK, WALK, "sidewalk", 0.15, 0.2)

# Boden der vier Viertel (Oberkante 0)
INNER = HALF + WALK
size = EDGE + 6 - INNER
mid = INNER + size / 2
slab(P, mid, -mid, size, size, "concrete_dark", 0.0, 0.6)       # NO
slab(P, -mid, -mid, size, size, "asphalt_old", 0.0, 0.7)        # NW
slab(P, -mid, mid, size, size, "concrete_green", 0.0, 0.9)      # SW (Schlamm/Moos)
slab(P, mid, mid, size, size, "concrete_dark", 0.0, 0.5)        # SO
# Marktplatz mit Pflaster
slab(P, 40, 37, 38, 30, "sidewalk_small", 0.02, 0.4)

# Straßenenden: Absperrungen
for (x, z, yaw) in ((0, -73.5, 0), (0, 73.5, 0), (-73.5, 0, 90), (73.5, 0, 90)):
    prop(P, "CONCRETE_BARRIER", x, z, yaw, length=8.0)
    prop(P, "STRIPED_BARRIER", x + (2 if yaw == 0 else 0), z + (0 if yaw == 0 else 2) + (-1.5 if z > 0 else 1.5 if z < 0 else 0),
         yaw, length=2.5)

# Strommasten an den Straßen mit Kabeln quer drüber
nodes.append('[node name="Power" type="Node3D" parent="."]')
pole_pts = []
TOP_ARM = 8.65  # Oberkante der Isolatoren am oberen Querträger
LOW_ARM = 7.75  # am unteren
for z in (-66, -46, -26, 26, 46, 66):
    prop("Power", "POWER_POLE", 7.0, z, 90)
    prop("Power", "POWER_POLE", -7.0, z, 90)
    # Quer über die Straße: zwei Leitungen an den äußeren Isolatoren, dazu eine an einem inneren.
    # Ein Zufallswert für alle drei, damit der Rest der Map dieselben Zufallszahlen bekommt wie vorher.
    seed = rnd.randint(1, 9999)
    for k, (dz, sag) in enumerate(((-0.9, 0.9), (0.9, 0.9), (0.3, 1.05))):
        cables("Power", [(7.0, TOP_ARM, z + dz), (-7.0, TOP_ARM, z + dz)], sag, 1, wall_brackets=False, seed_value=seed + k)
for x in (-66, -46, -26, 26, 46, 66):
    prop("Power", "POWER_POLE", x, 7.0, 0)
# Entlang der Straße: vom Ende des unteren Querträgers zum Anfang des nächsten
for z_a, z_b in ((-66, -46), (-46, -26), (26, 46), (46, 66)):
    for px in (7.0, -7.0):
        cables("Power", [(px, LOW_ARM, z_a + 0.9), (px, LOW_ARM, z_b - 0.9)], 1.0, 1, wall_brackets=False)
for x_a, x_b in ((-66, -46), (-46, -26), (26, 46), (46, 66)):
    cables("Power", [(x_a + 0.9, LOW_ARM, 7.0), (x_b - 0.9, LOW_ARM, 7.0)], 1.0, 1, wall_brackets=False)

# Straßen-Kleinkram auf den Gehwegen
nodes.append('[node name="StreetProps" type="Node3D" parent="."]')
SP = "StreetProps"
for (x, z) in ((6.5, -20), (-6.5, 30), (6.3, 55), (-6.4, -58)):
    prop(SP, "HYDRANT", x, z)
for (x, z, yaw) in ((-6.2, 12.0, 90), (6.2, -12.5, -90), (20, -6.3, 0)):
    prop(SP, "NEWS_BOX", x, z, yaw)
prop(SP, "CAR_WRECK", -2.6, 36, 8, variant=0)
prop(SP, "CAR_WRECK", 2.8, -52, 185, variant=1)
prop(SP, "CAR_WRECK", -38, -2.5, 93, variant=2)
for (x, z) in ((-1.5, 33.5), (-3.5, 39.5), (4.0, -50.0), (-40.5, -1.0)):
    prop(SP, "CONE", x, z, rnd.uniform(0, 90))
prop(SP, "TRASH_PILE", 6.4, 40, 0)
prop(SP, "TRASH_BAGS", -6.4, -34, 0, variant=1)
prop(SP, "DUMPSTER", -6.5, 50, 90, variant=2)

# =====================================================================================
# Nordost: Wohnblöcke „07“ mit Feuertreppen und Hinterhof
# =====================================================================================
nodes.append('[node name="NorthEast" type="Node3D" parent="."]')
NE = "NorthEast"
B = 8.0  # Hauskante an der Straße (Gehweg endet bei 7,5)
# Reihe an der Hauptstraße, Front nach Westen. w = Breite entlang z, d = Tiefe in x.
building(NE, "shop", B + 4.5, -14.5, "W", 9, 9, 3, wall="plaster_teal", ground_wall="brick_dark",
         front_sign="sign_ramen", side_sign="sign_noodles")
building(NE, "res", B + 5.0, -28.5, "W", 11, 10, 5, wall="concrete", ground_wall="brick", number="07",
         stair_side=SIDE["right"], front_sign="sign_24h", lit_ratio=0.4)
building(NE, "shop", B + 4.5, -42.0, "W", 8, 9, 3, wall="brick_dark", front_sign="sign_pharmacy",
         side_sign="sign_pharmacy")
building(NE, "res", B + 5.0, -56.5, "W", 12, 10, 6, wall="plaster", ground_wall="concrete_dark",
         stair_side=SIDE["left"], balcony_chance=0.35)
# 2,5 m Abstand zum Nachbarn: dort steht dessen Feuertreppe (2,35 m breit)
building(NE, "res", B + 4.5, -69.5, "W", 9, 9, 4, wall="concrete_green", ground_wall="brick")
# Reihe an der Querstraße, Front nach Süden
building(NE, "res", 26.0, -B - 5.0, "S", 12, 10, 7, wall="concrete", ground_wall="brick", side_sign="sign_hotel",
         front_sign="sign_vacancy", lit_ratio=0.5)
building(NE, "shop", 40.5, -B - 4.5, "S", 9, 9, 2, wall="plaster_pink", front_sign="sign_bar", side_sign="sign_open")
building(NE, "res", 54.0, -B - 4.5, "S", 10, 9, 5, wall="brick", stair_side=SIDE["left"], number="07")
building(NE, "shop", 66.5, -B - 4.0, "S", 8, 8, 3, wall="concrete_dark", front_sign="sign_24h")
# Hinterhof: zwei Blöcke, dazwischen Shanty-Plattformen mit Stegen
building(NE, "res", 37.0, -42.0, "S", 14, 10, 6, wall="concrete", ground_wall="concrete_dark",
         stair_side=SIDE["right"], balcony_chance=0.4)
building(NE, "res", 60.0, -55.0, "W", 10, 8, 4, wall="plaster_teal", stair_side=SIDE["left"])
building(NE, "shanty", 26.0, -62.0, "S", 6, 5, 1, stilt_height=2.4, shanty_stair=SIDE["left"], open_right=True)
building(NE, "shanty", 37.0, -62.0, "S", 6, 5, 1, stilt_height=2.4, shanty_stair=SIDE["right"], open_left=True)
building(NE, "shanty", 48.0, -66.0, "N", 5, 4.5, 1, stilt_height=0.0)
walkway(NE, 31.5, 2.4, -60.1, 90, 5.6, width=1.1, wooden=True, lanterns=True)
building(NE, "shanty", 47.5, -30.0, "W", 5, 5, 1, stilt_height=0.0)
prop(NE, "AC_STACK", 18.6, -36.0, 90)
prop(NE, "DUMPSTER", 19.0, -22.5, 90)
prop(NE, "DUMPSTER", 22.0, -27.0, 0, variant=1)
prop(NE, "GENERATOR", 30.0, -52.5, 20)
prop(NE, "WATER_TANK", 44.0, -54.0, 0)
prop(NE, "FIRE_BARREL", 32.0, -56.0, 0, variant=1)
prop(NE, "ELECTRIC_BOX", 18.4, -48.0, 90)
scatter(NE, ["CRATE_STACK", "TRASH_BAGS", "BARREL_GROUP", "PALLETS", "TRASH_PILE"], 20, 70, -72, -24, 16)
cables(NE, [(30.0, 7.5, -37.0), (26.0, 6.0, -18.05)], 0.8, 2)
cables(NE, [(44.0, 7.0, -37.0), (55.0, 6.5, -17.05)], 0.7, 3, True)
cables(NE, [(14.0, 5.0, -24.0), (14.0, 5.5, -34.0), (14.0, 5.0, -50.45)], 0.6, 2, True)
for (x, z, tex, col) in ((18.06, -31.0, "graffiti_3", (0.4, 0.8, 1.0, 1)), (36.0, -36.9, "graffiti_1", (0.7, 0.3, 1.0, 1))):
    sign(NE, tex, x, 1.6, z, 90 if x < 20 else 0, "decal", 3.0, col, 0.0, 0.0)
sign(NE, "sign_ngc7", 37.0, 18.0, -42.0, 0, "roof", 6.0, (0.5, 0.55, 1.0, 1), 0.0, 2.5)

# =====================================================================================
# Nordwest: Industriegebiet A2 (Lagerhallen, Containerhof, Zaun)
# =====================================================================================
nodes.append('[node name="NorthWest" type="Node3D" parent="."]')
NW = "NorthWest"
# Zaun an der Hauptstraße mit Tor bei z -34..-40
for (z0, z1) in ((-73.0, -40.0), (-34.0, -9.0)):
    prop(NW, "FENCE", -8.3, (z0 + z1) / 2, 90, length=abs(z1 - z0))
for (x0, x1) in ((-73.0, -30.0), (-24.0, -9.0)):
    prop(NW, "FENCE", (x0 + x1) / 2, -8.3, 0, length=abs(x1 - x0))
prop(NW, "STRIPED_BARRIER", -8.6, -37.0, 90, length=3.0)
prop(NW, "STRIPED_BARRIER", -27.0, -8.6, 0, length=3.0)
sign(NW, "sign_noentry", -8.24, 1.45, -42.0, 90, "wall", 1.6, (1.0, 0.2, 0.2, 1), 0.0, 0.0)
sign(NW, "sign_beware", -21.0, 1.45, -8.24, 0, "wall", 1.5, (1.0, 0.3, 0.2, 1), 0.0, 0.0)
building(NW, "warehouse", -34.0, -52.0, "E", 18, 22, 2, floor_height=3.6, wall="corrugated_grey", number="A2",
         front_sign="sign_ngc7")
building(NW, "warehouse", -62.0, -28.0, "S", 16, 18, 2, floor_height=3.4, wall="corrugated_blue", number="07")
building(NW, "warehouse", -63.0, -62.0, "E", 14, 16, 2, floor_height=3.2, wall="corrugated_rust")
# Wachhäuschen am Tor
building(NW, "shanty", -13.0, -32.0, "E", 3.5, 3.2, 1, stilt_height=0.0)
# Containerhof (gestapelt) mit Parkour-Kisten
for i, (x, z, yaw, v) in enumerate(((-18, -60, 0, 0), (-14.8, -60, 0, 1), (-18, -66.5, 0, 2), (-22, -22, 90, 3),
                                     (-22, -16.5, 90, 0), (-44, -20, 90, 1))):
    prop(NW, "CONTAINER", x, z, yaw, variant=v)
prop(NW, "CONTAINER", -18.0, -60.0, 0, y=2.6, variant=3)
prop(NW, "CONTAINER", -22.0, -19.2, 0, y=2.6, variant=2)
prop(NW, "CRATE_STACK", -15.5, -55.6, 0, variant=0)
prop(NW, "CRATE_STACK", -15.0, -58.2, 0, y=2.6, variant=0)  # Zwischenstufe auf den oberen Container
prop(NW, "MILITARY_CRATES", -20.5, -55.0, 0)
prop(NW, "PALLETS", -26.0, -36.0, 10, variant=2)
prop(NW, "PALLETS", -27.5, -38.0, 40, variant=1)
prop(NW, "BARREL_GROUP", -24.0, -66.0, 0, variant=1)
prop(NW, "BARREL_GROUP", -50.0, -40.0, 0, variant=0)
prop(NW, "GENERATOR", -48.0, -44.0, 90)
prop(NW, "CAR_WRECK", -40.0, -31.0, 70, variant=1)
prop(NW, "FIRE_BARREL", -30.0, -24.0, 0)
prop(NW, "STREET_LAMP", -26.0, -46.0, -90)
prop(NW, "STREET_LAMP", -50.0, -14.0, 180, variant=2)
prop(NW, "STREET_LAMP", -14.0, -70.0, 0, variant=1)
scatter(NW, ["CRATE_STACK", "BARREL", "PALLETS", "TRASH_BAGS", "CONE", "MILITARY_CRATES"], -72, -12, -72, -12, 18)

# =====================================================================================
# Südwest: Shanty-Viertel auf Stelzen
# =====================================================================================
nodes.append('[node name="SouthWest" type="Node3D" parent="."]')
SW = "SouthWest"
# Reihe an der Querstraße, Front nach Norden
building(SW, "shop", -14.5, B + 4.5, "N", 9, 9, 3, wall="brick", front_sign="sign_noodles", side_sign="sign_open")
building(SW, "res", -28.5, B + 5.0, "N", 10, 10, 4, wall="concrete_green", ground_wall="brick_dark",
         stair_side=SIDE["left"])
building(SW, "res", -44.0, B + 5.0, "N", 12, 10, 5, wall="plaster", front_sign="sign_hotel2", lit_ratio=0.45)
building(SW, "shop", -59.0, B + 4.5, "N", 9, 9, 2, wall="concrete", front_sign="sign_shop")
building(SW, "res", -70.0, B + 5.0, "N", 8, 10, 3, wall="brick")
# Reihe an der Hauptstraße, Front nach Osten
building(SW, "res", -B - 5.0, 27.0, "E", 10, 10, 4, wall="concrete", ground_wall="brick", number="07",
         stair_side=SIDE["right"])
building(SW, "shop", -B - 4.5, 40.0, "E", 9, 9, 2, wall="plaster_pink", front_sign="sign_ramen")
building(SW, "res", -B - 5.0, 56.0, "E", 12, 10, 6, wall="concrete_dark", side_sign="sign_hotel", lit_ratio=0.5)
building(SW, "shop", -B - 4.5, 69.5, "E", 8, 9, 2, wall="brick_dark", front_sign="sign_24h")
# Shanty-Raster: Gassen 3 m, Plattformen 2,4 m hoch, Stege dazwischen.
# Erst planen, dann bauen: wo ein Steg andockt, bleibt die Plattformseite ohne Geländer, und die
# Treppe kommt auf die andere Seite. Hütten auf Stelzen schauen nach Süden (lokal rechts = Osten).
plan = {}
for gx in range(5):
    for gz in range(4):
        if rnd.random() < 0.15:
            continue
        stilt = rnd.choice([0.0, 2.4, 2.4, 2.4, 3.0])
        plan[(gx, gz)] = {"x": -64.0 + gx * 9.0 + rnd.uniform(-0.5, 0.5), "z": 30.0 + gz * 10.5, "stilt": stilt,
                          "w": round(rnd.uniform(5.0, 6.5), 2), "d": round(rnd.uniform(4.5, 5.5), 2),
                          "open_left": False, "open_right": False}
bridges = []
for (gx, gz), c in sorted(plan.items()):
    n = plan.get((gx + 1, gz))
    if n and c["stilt"] == 2.4 and n["stilt"] == 2.4 and rnd.random() < 0.65:
        c["open_right"] = True
        n["open_left"] = True
        x0 = c["x"] + c["w"] / 2 - 0.3
        x1 = n["x"] - n["w"] / 2 + 0.3
        bridges.append(((x0 + x1) / 2, c["z"] + min(c["d"], n["d"]) / 2 - 0.6, x1 - x0))
for (gx, gz), c in sorted(plan.items()):
    if c["stilt"] > 0:
        if c["open_left"] and c["open_right"]:
            side = "none"
        elif c["open_right"]:
            side = "left"
        elif c["open_left"]:
            side = "right"
        else:
            side = rnd.choice(["left", "right"])
        building(SW, "shanty", c["x"], c["z"], "S", c["w"], c["d"], 1, stilt_height=c["stilt"], shanty_stair=SIDE[side],
                 open_left=c["open_left"], open_right=c["open_right"])
    else:
        building(SW, "shanty", c["x"], c["z"] + rnd.uniform(-0.5, 0.5), rnd.choice(["S", "N", "E", "W"]), c["w"], c["d"], 1,
                 stilt_height=0.0, shanty_stair=SIDE["none"])
for (x, z, length) in bridges:
    walkway(SW, x, 2.4, z, 90, round(length, 2), width=1.1, wooden=True, lanterns=rnd.random() < 0.5)
# Lampion-Ketten über den Gassen
for gz in range(4):
    z = 30.0 + gz * 10.5 + 5.25
    cables(SW, [(-68.0, 5.2, z), (-48.0, 5.6, z + 0.5), (-28.0, 5.0, z - 0.3)], 0.7, 1, True, poles=[0, 1, 2],
           wooden_poles=True)
for (x, z) in ((-50, 37), (-32, 58), (-60, 66), (-40, 24)):
    prop(SW, "FIRE_BARREL", x, z, 0, variant=rnd.randint(0, 1))
prop(SW, "MARKET_STALL", -24.0, 34.0, 90, variant=0)
prop(SW, "MARKET_STALL", -24.0, 38.0, 90, variant=2)
prop(SW, "WATER_TANK", -70.0, 72.0, 0)
prop(SW, "GENERATOR", -42.0, 70.0, 0)
scatter(SW, ["TRASH_PILE", "TRASH_BAGS", "BARREL", "CRATE", "PALLETS", "BARREL_GROUP"], -70, -20, 24, 72, 24)
sign(SW, "graffiti_2", -17.06, 1.6, 40.0, -90, "decal", 3.0)

# =====================================================================================
# Südost: Markt und Nachtleben
# =====================================================================================
nodes.append('[node name="SouthEast" type="Node3D" parent="."]')
SE = "SouthEast"
# Hauptstraße, Front nach Westen
building(SE, "res", B + 6.0, 16.0, "W", 12, 12, 9, wall="concrete_dark", ground_wall="tiles_dark",
         side_sign="sign_hotel", front_sign="sign_hotel2", lit_ratio=0.55, stair_side=SIDE["left"])
building(SE, "shop", B + 4.5, 30.5, "W", 9, 9, 2, wall="brick_dark", front_sign="sign_bar", side_sign="sign_24h")
building(SE, "shop", B + 4.5, 41.0, "W", 8, 9, 3, wall="plaster_teal", front_sign="sign_shop")
building(SE, "res", B + 5.0, 54.0, "W", 12, 10, 5, wall="brick", stair_side=SIDE["right"], number="07")
building(SE, "shop", B + 4.5, 67.5, "W", 9, 9, 2, wall="concrete", front_sign="sign_pharmacy", side_sign="sign_pharmacy")
# Querstraße, Front nach Norden
building(SE, "shop", 28.0, B + 4.5, "N", 9, 9, 3, wall="plaster_pink", front_sign="sign_ramen", side_sign="sign_noodles")
building(SE, "res", 42.0, B + 5.0, "N", 12, 10, 4, wall="concrete_green", ground_wall="brick")
building(SE, "shop", 56.0, B + 4.5, "N", 9, 9, 2, wall="brick", front_sign="sign_open")
building(SE, "res", 68.0, B + 5.0, "N", 9, 10, 6, wall="concrete", side_sign="sign_hotel")
# Rückseite des Marktes, Front nach Norden zum Platz
building(SE, "res", 30.0, 60.0, "N", 12, 10, 5, wall="plaster", ground_wall="brick_dark", front_sign="sign_bar",
         stair_side=SIDE["right"])
building(SE, "shop", 44.0, 59.0, "N", 9, 9, 3, wall="brick", front_sign="sign_24h", side_sign="sign_open")
building(SE, "res", 58.0, 60.0, "N", 11, 10, 7, wall="concrete_dark", side_sign="sign_hotel", lit_ratio=0.5)
building(SE, "warehouse", 66.0, 34.0, "W", 14, 14, 2, floor_height=3.3, wall="corrugated_green")
# Marktstände in zwei Reihen, Lampions drüber
for i in range(5):
    prop(SE, "MARKET_STALL", 26.0 + i * 5.5, 29.0, 180, variant=i % 3)
    prop(SE, "MARKET_STALL", 26.0 + i * 5.5, 44.0, 0, variant=(i + 1) % 3)
for z in (31.5, 36.5, 41.5):
    cables(SE, [(22.0, 5.0, z), (40.0, 5.5, z + 0.5), (56.0, 5.0, z)], 0.6, 1, True, poles=[0, 1, 2], pole_ground=0.02)
for (x, z) in ((24.0, 36.5), (36.0, 36.5), (48.0, 36.5)):
    prop(SE, "BENCH", x, z, rnd.choice([0, 180]))
prop(SE, "FIRE_BARREL", 54.0, 37.0, 0)
prop(SE, "STREET_LAMP", 20.5, 52.0, 180)
prop(SE, "STREET_LAMP", 54.0, 50.5, 90, variant=2)
prop(SE, "DUMPSTER", 36.5, 53.0, 0)
prop(SE, "DUMPSTER", 51.0, 52.5, 0, variant=1)
prop(SE, "TRASH_PILE", 22.0, 54.0, 0)
prop(SE, "AC_STACK", 22.0, 22.0, 180)
scatter(SE, ["CRATE_STACK", "TRASH_BAGS", "BARREL", "CRATE", "CONE"], 20, 60, 20, 55, 10)
sign(SE, "sign_bar", 29.0, 15.06, 58.0, 180, "roof", 5.0, (1.0, 0.2, 0.25, 1), 0.15, 2.5)

# =====================================================================================
# Rand: Hochhäuser (Hintergrund) und unsichtbare Wände
# =====================================================================================
nodes.append('[node name="Skyline" type="Node3D" parent="."]')
SK = "Skyline"
walls = ["concrete_dark", "concrete", "brick_dark", "plaster", "concrete_green"]
signs = ["", "", "", "sign_ngc7", "sign_shop", "sign_24h", "sign_bar"]
for side in ("N", "S", "E", "W"):
    pos = -88.0
    while pos < 88.0:
        w = rnd.uniform(14, 22)
        c = pos + w / 2
        floors = rnd.randint(9, 22)
        d = rnd.uniform(12, 16)
        dist = 84.0 + d / 2 + rnd.uniform(0, 4)
        if side == "N":
            x, z, face = c, -dist, "S"
        elif side == "S":
            x, z, face = c, dist, "N"
        elif side == "E":
            x, z, face = dist, c, "W"
        else:
            x, z, face = -dist, c, "E"
        building(SK, "tower", x, z, face, w, d, floors, wall=rnd.choice(walls), lit_ratio=round(rnd.uniform(0.25, 0.5), 2),
                 front_sign=rnd.choice(signs))
        pos += w + rnd.uniform(0.5, 3.0)

# =====================================================================================
# Kopf, Umgebung, Spieler, Items
# =====================================================================================
HEAD = """[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/slum/slum.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="2_player"]
[ext_resource type="PackedScene" path="res://scenes/pause/pause_menu.tscn" id="3_pause"]
[ext_resource type="Script" path="res://scenes/slum/kit/slum_building.gd" id="k_building"]
[ext_resource type="Script" path="res://scenes/slum/kit/slum_prop.gd" id="k_prop"]
[ext_resource type="Script" path="res://scenes/slum/kit/slum_street.gd" id="k_street"]
[ext_resource type="Script" path="res://scenes/slum/kit/slum_sign.gd" id="k_sign"]
[ext_resource type="Script" path="res://scenes/slum/kit/slum_walkway.gd" id="k_walkway"]
[ext_resource type="Script" path="res://scenes/slum/kit/slum_cables.gd" id="k_cables"]
[ext_resource type="PackedScene" path="res://scenes/items/pickup.tscn" id="i_pickup"]
[ext_resource type="Script" path="res://scenes/interact/vending_machine.gd" id="i_vending"]
[ext_resource type="Resource" path="res://scenes/items/data/credchip.tres" id="i_credchip"]
[ext_resource type="Resource" path="res://scenes/items/data/energy_drink.tres" id="i_drink"]
[ext_resource type="Resource" path="res://scenes/items/data/noodles.tres" id="i_noodles"]
[ext_resource type="Resource" path="res://scenes/items/data/stim_pack.tres" id="i_stim"]
[ext_resource type="Resource" path="res://scenes/items/data/data_shard.tres" id="i_shard"]
[ext_resource type="Resource" path="res://scenes/items/data/mono_blade.tres" id="i_blade"]
[ext_resource type="Resource" path="res://scenes/items/data/emp_grenade.tres" id="i_emp"]
[ext_resource type="Resource" path="res://scenes/items/data/pistol.tres" id="i_pistol"]
[ext_resource type="Resource" path="res://scenes/items/data/sniper.tres" id="i_sniper"]
[ext_resource type="PackedScene" path="res://scenes/slum/slum_enemies.tscn" id="e_enemies"]

[sub_resource type="ProceduralSkyMaterial" id="Sky_mat"]
sky_top_color = Color(0.02, 0.025, 0.05, 1)
sky_horizon_color = Color(0.09, 0.07, 0.13, 1)
ground_bottom_color = Color(0.02, 0.02, 0.03, 1)
ground_horizon_color = Color(0.09, 0.07, 0.13, 1)
sun_angle_max = 1.0

[sub_resource type="Sky" id="Sky_night"]
sky_material = SubResource("Sky_mat")

[sub_resource type="Environment" id="Env_slum"]
background_mode = 2
sky = SubResource("Sky_night")
ambient_light_source = 2
ambient_light_color = Color(0.36, 0.38, 0.52, 1)
ambient_light_energy = 1.1
reflected_light_source = 2
tonemap_mode = 2
tonemap_exposure = 1.15
ssr_enabled = true
ssr_max_steps = 48
ssao_enabled = true
ssao_intensity = 1.6
glow_enabled = true
glow_intensity = 0.9
glow_bloom = 0.05
glow_blend_mode = 1
glow_hdr_threshold = 1.1
fog_enabled = true
fog_light_color = Color(0.1, 0.1, 0.16, 1)
fog_density = 0.009
fog_sky_affect = 0.7
volumetric_fog_enabled = true
volumetric_fog_density = 0.006
volumetric_fog_albedo = Color(0.6, 0.62, 0.75, 1)
volumetric_fog_length = 48.0
adjustment_enabled = true
adjustment_contrast = 1.08
adjustment_saturation = 0.9

[sub_resource type="BoxShape3D" id="Shape_bound"]
size = Vector3(180, 60, 1)

[node name="Slum" type="Node3D"]
script = ExtResource("1_script")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env_slum")

[node name="Moon" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.81915, 0.46985, -0.32899, 0, 0.57358, 0.81915, 0.57358, -0.67101, 0.46985, 0, 40, 0)
light_color = Color(0.5, 0.58, 0.85, 1)
light_energy = 0.35
shadow_enabled = true
directional_shadow_max_distance = 80.0
"""

TAIL = """
[node name="Bounds" type="Node3D" parent="."]

[node name="North" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 30, -80)

[node name="Shape" type="CollisionShape3D" parent="Bounds/North"]
shape = SubResource("Shape_bound")

[node name="South" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 30, 80)

[node name="Shape" type="CollisionShape3D" parent="Bounds/South"]
shape = SubResource("Shape_bound")

[node name="East" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, 80, 30, 0)

[node name="Shape" type="CollisionShape3D" parent="Bounds/East"]
shape = SubResource("Shape_bound")

[node name="West" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, -80, 30, 0)

[node name="Shape" type="CollisionShape3D" parent="Bounds/West"]
shape = SubResource("Shape_bound")

[node name="Player" parent="." instance=ExtResource("2_player")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.1, 62)

[node name="PauseMenu" parent="." instance=ExtResource("3_pause")]
"""

# Item-Plätze: Marker in Gruppe item_spawn, Pickups als Kinder
SPOTS = [
    ("Spot_Street", (2.0, 0.0, 56.0), "i_credchip", 20),
    ("Spot_Kiosk", (-6.0, 0.15, 44.0), "i_drink", 2),
    ("Spot_Market", (40.0, 0.02, 36.5), "i_noodles", 2),
    ("Spot_Bar", (12.0, 0.08, 30.5), "i_stim", 1),
    ("Spot_Warehouse", (-33.0, 0.08, -55.0), "i_pistol", 1),
    ("Spot_Container", (-18.0, 5.2, -60.0), "i_shard", 3),
    ("Spot_HotelRoof", (14.0, 27.1, 16.0), "i_sniper", 1),
    ("Spot_Courtyard", (32.0, 0.0, -50.0), "i_emp", 2),
    ("Spot_Roof07", (13.0, 15.1, -28.5), "i_credchip", 40),
    ("Spot_Alley", (-24.0, 0.0, 66.0), "i_drink", 1),
    ("Spot_Gate", (-14.0, 0.0, -38.0), "i_credchip", 10),
]


def items() -> str:
    # Monoklinge auf der ersten Shanty-Plattform mit Treppe (vorderer Gang)
    for c in sorted(plan.values(), key=lambda c: (c["z"], c["x"])):
        if c["stilt"] == 2.4:
            SPOTS.append(("Spot_Shanty", (round(c["x"] + 1.2, 2), 2.4, round(c["z"] + c["d"] / 2 - 0.6, 2)), "i_blade", 1))
            break
    out = ['[node name="Pickups" type="Node3D" parent="."]', '[node name="SpawnPoints" type="Node3D" parent="Pickups"]']
    for name, (x, y, z), item, count in SPOTS:
        out.append(f'[node name="{name}" type="Marker3D" parent="Pickups/SpawnPoints" groups=["item_spawn"]]\n'
                   f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})")
        out.append(f'[node name="Pickup" parent="Pickups/SpawnPoints/{name}" instance=ExtResource("i_pickup")]\n'
                   f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)\nitem = ExtResource(\"{item}\")\ncount = {count}")
    out.append('[node name="Vending" type="Node3D" parent="."]')
    for name, x, z, yaw, product, price in (("ColaMachine", 7.0, 47.6, -90, "i_drink", 2),
                                            ("NoodleMachine", 7.0, 49.0, -90, "i_noodles", 3),
                                            ("StimMachine", -24.8, 30.0, 90, "i_stim", 6)):
        out.append(f'[node name="{name}" type="StaticBody3D" parent="Vending"]\ntransform = {xform(x, 0.15 if abs(x) < 8 else 0.0, z, yaw)}\n'
                   f'script = ExtResource("i_vending")\nproduct = ExtResource("{product}")\nprice = {price}\n'
                   f'currency = ExtResource("i_credchip")')
    # Gegner, Streifenwege und Navmesh-Director (scenes/slum/slum_enemies.tscn, im Editor bearbeiten)
    out.append('[node name="SlumEnemies" parent="." instance=ExtResource("e_enemies")]')
    return "\n\n".join(out)


def main() -> None:
    text = HEAD + "\n" + "\n\n".join(nodes) + "\n" + TAIL + "\n" + items() + "\n"
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print("geschrieben:", OUT, len(nodes), "Kit-Knoten")


if __name__ == "__main__":
    main()
