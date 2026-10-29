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
# Bis an den inneren Gehweg der Ringstraße (84 - 4,5 - 3 = 76,5), vorher bis 81.
size = 76.5 - INNER
mid = INNER + size / 2
slab(P, mid, -mid, size, size, "concrete_dark", 0.0, 0.6)       # NO
slab(P, -mid, -mid, size, size, "asphalt_old", 0.0, 0.7)        # NW
slab(P, -mid, mid, size, size, "concrete_green", 0.0, 0.9)      # SW (Schlamm/Moos)
slab(P, mid, mid, size, size, "concrete_dark", 0.0, 0.5)        # SO
# Marktplatz mit Pflaster
slab(P, 40, 37, 38, 30, "sidewalk_small", 0.02, 0.4)

# Früher standen hier Absperrungen an den Straßenenden. Seit der Erweiterung (PR #35) gehen die
# Straßen bis zur Ringstraße weiter. Die Zufallszahlen der acht Absperrungen werden trotzdem gezogen,
# damit alles danach genau so aussieht wie vorher.
for _ in range(8):
    rnd.randint(1, 9999)
counter["ConcreteBarrier"] = 4  # und die Namen der späteren Absperrungen bleiben gleich
counter["StripedBarrier"] = 4

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
# Autowracks und Hütchen standen früher auf der Fahrbahn. Dort fahren jetzt Autos, deshalb stehen sie
# auf dem Parkplatz im Südosten bzw. auf dem Schrottplatz im Nordwesten (gleiche Zufallszahlen).
prop(SP, "CAR_WRECK", 104.0, 101.0, 98, variant=0)
prop(SP, "CAR_WRECK", 104.0, 108.0, 85, variant=1)
prop(SP, "CAR_WRECK", -108.0, -112.0, 33, variant=2)
for (x, z) in ((101.0, 97.5), (101.5, 112.0), (-104.0, -106.0), (-111.0, -104.5)):
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
# Erweiterung (PR #35): Ringstraße bei ±84 m und vier Außenviertel bis ±136 m
# =====================================================================================
# Die alten Viertel bleiben, wie sie sind. Die Hauptstraßen laufen jetzt weiter bis zur Ringstraße
# (T-Kreuzungen bei (0, ±84) und (±84, 0), Ecken bei (±84, ±84)). Außen liegen:
#   Nord  „Wohnblöcke Nord“: Häuserreihe, Platz mit Markt, Plattenbauten, Käfig-Sportplatz
#   Ost   „Docks A9“: Lagerhallen, Containerhof hinter einem Tor
#   Süd   „Nachtmeile“: Läden mit Neon, Fußgängergasse mit Lampions, zweite Ladenreihe
#   West  „Shanty-Hang“: Häuserreihe, dahinter ein großes Hüttenfeld auf Stelzen mit Stegen
#   Ecken Kraftwerk (NO), Schrottplatz (NW), Parkplatz mit Hotel (SO), Hütten und Wohnturm (SW)
# Alle neuen Gebäude laufen über claim(): überlappen sich zwei Grundflächen (inkl. Feuertreppen),
# bricht das Skript ab.
RING = 84.0
MAP_EDGE = 136.0
B2 = RING + HALF + WALK + 0.5  # 92: Hauskante außen an der Ringstraße
WALK_OUT = RING + HALF + WALK  # 91,5: Ende des äußeren Gehwegs
GROUND_END = MAP_EDGE + 6.0

placed: list[tuple[float, float, float, float, str]] = []


def claim(x0: float, x1: float, z0: float, z1: float, what: str) -> None:
    for (a0, a1, b0, b1, other) in placed:
        if x0 < a1 and a0 < x1 and z0 < b1 and b0 < z1:
            raise SystemExit(f"Überlappung: {what} mit {other}")
    if max(abs(x0), abs(x1), abs(z0), abs(z1)) > MAP_EDGE - 1.0:
        raise SystemExit(f"Außerhalb der Karte: {what}")
    placed.append((x0, x1, z0, z1, what))


def obuilding(parent: str, style: str, x: float, z: float, facing: str, w: float, d: float, floors: int,
              **props) -> None:
    """building() mit Platzprüfung. Feuertreppen und Hüttentreppen stehen seitlich neben dem Haus."""
    side = 0.3
    if props.get("stair_side", 0) != 0:
        side = 2.8
    if style == "shanty" and props.get("stilt_height", 2.4) > 0 and props.get("shanty_stair", 2) != 0:
        side = 2.2
    if facing in ("S", "N"):
        ex, ez = w / 2 + side, d / 2 + 0.3
    else:
        ex, ez = d / 2 + 0.3, w / 2 + side
    claim(x - ex, x + ex, z - ez, z + ez, f"{style} ({x:.1f}, {z:.1f})")
    building(parent, style, x, z, facing, w, d, floors, **props)


def oprop(parent: str, kind: str, x: float, z: float, yaw: float = 0.0, r: float = 0.0, half=None, **props) -> None:
    """prop() mit Platzprüfung: r = halbe Kantenlänge eines Quadrats, half = (x, z) halbe Maße bei yaw 0
    (bei 90° vertauscht). Ohne beides wird nicht geprüft."""
    if half is not None:
        hx, hz = (half[1], half[0]) if abs(yaw) % 180 == 90 else half
        claim(x - hx, x + hx, z - hz, z + hz, f"{kind} ({x:.1f}, {z:.1f})")
    elif r > 0.0:
        claim(x - r, x + r, z - r, z + r, f"{kind} ({x:.1f}, {z:.1f})")
    prop(parent, kind, x, z, yaw, **props)


CONTAINER_HALF = (1.3, 3.1)


def side_xz(side: str, along: float, across: float) -> tuple[float, float]:
    """Ringseite → Weltkoordinaten. along läuft entlang der Straße, across ist der Abstand von der Mitte."""
    if side == "N":
        return along, -across
    if side == "S":
        return along, across
    if side == "E":
        return across, along
    return -across, along


FRONT = {"N": "S", "S": "N", "E": "W", "W": "E"}
SIGNS = ["sign_bar", "sign_24h", "sign_hotel", "sign_hotel2", "sign_ramen", "sign_noodles", "sign_pharmacy",
         "sign_shop", "sign_open", "sign_vacancy", "sign_ngc7"]
WALLS = ["concrete", "concrete_dark", "concrete_green", "brick", "brick_dark", "plaster", "plaster_teal", "plaster_pink"]


def frontage(parent: str, side: str, a0: float, a1: float, mix: dict, depth=(9.0, 11.0), floors=(3, 7),
             fixed_depth: float = 0.0, base: float = B2) -> list[tuple[float, float, float]]:
    """Häuserreihe entlang einer Ringseite zwischen a0 und a1, Front zur Straße.
    mix: Stil → Gewicht. Gibt (Mitte, Breite, Tiefe) je Haus zurück."""
    out = []
    styles = [k for k, v in mix.items() for _ in range(v)]
    pos = a0
    while True:
        style = rnd.choice(styles)
        w = round(rnd.uniform(8.0, 12.5) if style != "shop" else rnd.uniform(8.0, 10.0), 1)
        d = fixed_depth or round(rnd.uniform(*depth), 1)
        stairs = style == "res" and rnd.random() < 0.45
        margin = 2.9 if stairs else round(rnd.uniform(0.4, 1.8), 1)
        if pos + margin * 2 + w > a1:
            break
        c = pos + margin + w / 2
        x, z = side_xz(side, c, base + d / 2)
        props = {"wall": rnd.choice(WALLS)}
        if rnd.random() < 0.5:
            props["ground_wall"] = rnd.choice(["brick", "brick_dark", "concrete_dark", "tiles_dark"])
        if style == "shop":
            props["front_sign"] = rnd.choice(SIGNS)
            if rnd.random() < 0.6:
                props["side_sign"] = rnd.choice(SIGNS)
            fl = rnd.randint(2, 3)
        else:
            fl = rnd.randint(*floors)
            props["lit_ratio"] = round(rnd.uniform(0.3, 0.55), 2)
            props["balcony_chance"] = round(rnd.uniform(0.15, 0.4), 2)
            if stairs:
                props["stair_side"] = SIDE[rnd.choice(["left", "right"])]
            if rnd.random() < 0.35:
                props["front_sign"] = rnd.choice(SIGNS)
            if rnd.random() < 0.25:
                props["number"] = rnd.choice(["07", "A2"])
        obuilding(parent, style, x, z, FRONT[side], w, d, fl, **props)
        out.append((c, w, d))
        pos = c + w / 2 + margin
    return out


nodes.append('[node name="Ring" type="Node3D" parent="."]')
RG = "Ring"
# Hauptstraßen bis zur Ringstraße verlängern (4,5 m), Zebrastreifen an der T-Kreuzung.
EXT = RING - HALF - EDGE
for s in (-1, 1):
    street(RG, 0, s * (EDGE + EXT / 2), 0, length=EXT, crosswalk_start=s < 0, crosswalk_end=s > 0, lamp_spacing=0.0)
    street(RG, s * (EDGE + EXT / 2), 0, 90, length=EXT, crosswalk_start=s < 0, crosswalk_end=s > 0, lamp_spacing=0.0)
for s in (-1, 1):
    node(uname("RingJunction"), RG, "k_street", 0, 0, s * RING, 0, kind=1, road_width=9.0, seed_value=rnd.randint(1, 9999))
    node(uname("RingJunction"), RG, "k_street", s * RING, 0, 0, 0, kind=1, road_width=9.0, seed_value=rnd.randint(1, 9999))
    for t in (-1, 1):
        slab(RG, s * RING, t * RING, 9.0, 9.0, "asphalt", 0.0, 0.3)  # Ecke ohne Zebrastreifen
# Acht Ringstücke zu je 75 m, drei Straßenteile pro Stück.
SEG = (RING - 2 * HALF) / 3.0
for s in (-1, 1):
    for t in (-1, 1):
        for i in range(3):
            a = t * (HALF + SEG * (i + 0.5))
            street(RG, a, s * RING, 90, length=SEG, crosswalk_start=(i == 0 and t > 0), crosswalk_end=(i == 0 and t < 0))
            street(RG, s * RING, a, 0, length=SEG, crosswalk_start=(i == 0 and t > 0), crosswalk_end=(i == 0 and t < 0))
# Gehweg außen an den T-Kreuzungen (Zugang zu den Plätzen) und an den Ecken (L aus zwei Platten).
OS = HALF + WALK / 2
for s in (-1, 1):
    slab(RG, 0, s * (RING + OS), 9.0, 3.0, "sidewalk", 0.15, 0.2)
    slab(RG, s * (RING + OS), 0, 3.0, 9.0, "sidewalk", 0.15, 0.2)
    for t in (-1, 1):
        slab(RG, s * (RING + 1.5), t * (RING + OS), 12.0, 3.0, "sidewalk", 0.15, 0.2)
        slab(RG, s * (RING + OS), t * RING, 3.0, 9.0, "sidewalk", 0.15, 0.2)
# Boden der Außenviertel (Oberkante 0).
GL = GROUND_END - WALK_OUT
GC = WALK_OUT + GL / 2
slab(RG, 0, -GC, 2 * GROUND_END, GL, "concrete", 0.0, 0.6)
slab(RG, 0, GC, 2 * GROUND_END, GL, "sidewalk_small", 0.0, 0.45)
slab(RG, GC, 0, GL, 2 * WALK_OUT, "asphalt_old", 0.0, 0.7)
slab(RG, -GC, 0, GL, 2 * WALK_OUT, "concrete_green", 0.0, 0.9)
# Strommasten am Ring (außen), Leitungen von Mast zu Mast.
for s in (-1, 1):
    for a in (-66.0, -40.0, 40.0, 66.0):
        prop("Power", "POWER_POLE", a, s * (RING + 7.0), 0)
        prop("Power", "POWER_POLE", s * (RING + 7.0), a, 90)
    for (a, b) in ((-66.0, -40.0), (40.0, 66.0)):
        cables("Power", [(a + 0.9, LOW_ARM, s * (RING + 7.0)), (b - 0.9, LOW_ARM, s * (RING + 7.0))], 1.0, 1,
               wall_brackets=False)
        cables("Power", [(s * (RING + 7.0), LOW_ARM, a + 0.9), (s * (RING + 7.0), LOW_ARM, b - 0.9)], 1.0, 1,
               wall_brackets=False)
for (x, z, yaw) in ((5.0, -90.5, 0), (-90.5, 20.0, 90), (90.5, -25.0, -90), (30.0, 90.5, 180), (-60.0, 77.0, 0)):
    prop(SP, "NEWS_BOX", x, z, yaw)
for (x, z) in ((-90.6, -40.0), (90.6, 33.0), (45.0, -90.6), (-30.0, 90.6), (77.2, 50.0)):
    prop(SP, "HYDRANT", x, z)

# --- Nord: Wohnblöcke Nord --------------------------------------------------------------
nodes.append('[node name="OuterNorth" type="Node3D" parent="."]')
ON = "OuterNorth"
frontage(ON, "N", -88.0, -11.0, {"res": 3, "shop": 2}, floors=(4, 7))
frontage(ON, "N", 11.0, 88.0, {"res": 3, "shop": 2}, floors=(4, 7))
# Platz mit Markt hinter der T-Kreuzung
for i in range(3):
    oprop(ON, "MARKET_STALL", -6.5, -97.0 - i * 4.5, 90, r=1.4, variant=i % 3)
    oprop(ON, "MARKET_STALL", 6.5, -97.0 - i * 4.5, -90, r=1.4, variant=(i + 1) % 3)
for z in (-95.5, -100.5, -105.5):
    cables(ON, [(-9.0, 5.0, z), (0.0, 5.5, z + 0.4), (9.0, 5.0, z)], 0.6, 1, True, poles=[0, 1, 2], pole_ground=0.0)
oprop(ON, "BENCH", -2.5, -108.0, 0, r=1.0)
oprop(ON, "BENCH", 2.5, -108.0, 0, r=1.0)
oprop(ON, "FIRE_BARREL", 0.0, -103.0, 0, r=0.5)
obuilding(ON, "res", 0.0, -118.0, "S", 20, 12, 12, wall="concrete_dark", ground_wall="tiles_dark", number="07",
          front_sign="sign_ngc7", lit_ratio=0.5, stair_side=SIDE["right"])
sign(ON, "sign_hotel2", 0.0, 39.06, -118.0, 0, "roof", 7.0, (1.0, 0.3, 0.75, 1), 0.0, 3.0)
# Plattenbauten links und rechts, dazwischen Höfe
obuilding(ON, "res", -48.0, -121.0, "S", 22, 12, 8, wall="concrete", ground_wall="concrete_dark",
          stair_side=SIDE["left"], balcony_chance=0.45, lit_ratio=0.4)
obuilding(ON, "res", 48.0, -121.0, "S", 22, 12, 8, wall="concrete_green", ground_wall="brick_dark",
          stair_side=SIDE["right"], balcony_chance=0.45, lit_ratio=0.4)
obuilding(ON, "res", -80.0, -121.0, "S", 12, 10, 5, wall="brick", lit_ratio=0.35)
obuilding(ON, "res", 80.0, -121.0, "S", 12, 10, 5, wall="plaster", lit_ratio=0.35)
# Käfig-Sportplatz
slab(ON, -24.0, -121.0, 16.0, 18.0, "asphalt_old", 0.02, 0.2)
oprop(ON, "FENCE", -24.0, -112.2, 0, length=16.0)
oprop(ON, "FENCE", -24.0, -129.8, 0, length=16.0)
oprop(ON, "FENCE", -32.0, -126.0, 90, length=7.6)
oprop(ON, "FENCE", -16.0, -126.0, 90, length=7.6)
oprop(ON, "FENCE", -32.0, -115.0, 90, length=5.6)
oprop(ON, "FENCE", -16.0, -115.0, 90, length=5.6)
claim(-32.5, -15.5, -130.3, -111.7, "Sportplatz")
oprop(ON, "STREET_LAMP", -24.0, -111.4, 0)
# Hütten im Hof rechts
obuilding(ON, "shanty", 21.0, -118.0, "S", 6, 5, 1, stilt_height=0.0)
obuilding(ON, "shanty", 29.0, -126.0, "W", 5, 5, 1, stilt_height=0.0)
oprop(ON, "WATER_TANK", 24.0, -128.5, 0, r=1.5)
oprop(ON, "GENERATOR", 30.0, -113.0, 20, r=1.2)
scatter(ON, ["TRASH_BAGS", "TRASH_PILE", "BARREL", "CRATE_STACK", "PALLETS"], -86, -14, -110, -106, 7)
scatter(ON, ["TRASH_BAGS", "TRASH_PILE", "BARREL", "CRATE_STACK", "PALLETS"], 14, 86, -110, -106, 7)
for x in (-60.0, -36.0, 36.0, 60.0):
    oprop(ON, "DUMPSTER", x, -110.0, 0, r=1.2, variant=rnd.randint(0, 2))
oprop(ON, "STREET_LAMP", -64.0, -108.5, 180)
oprop(ON, "STREET_LAMP", 64.0, -108.5, 180, variant=2)
cables(ON, [(-40.0, 6.5, -114.95), (-8.0, 7.5, -111.95)], 0.7, 2, True)
cables(ON, [(40.0, 6.5, -114.95), (8.0, 7.5, -111.95)], 0.7, 2, True)

# --- Ost: Docks A9 ----------------------------------------------------------------------
nodes.append('[node name="OuterEast" type="Node3D" parent="."]')
OE = "OuterEast"
for (z, w, d, wall, num, fsign) in ((-74.0, 22, 18, "corrugated_grey", "A2", "sign_ngc7"),
                                    (-46.0, 20, 16, "corrugated_rust", "", ""),
                                    (-22.0, 16, 14, "corrugated_blue", "A2", ""),
                                    (24.0, 18, 16, "corrugated_green", "", "sign_24h"),
                                    (50.0, 20, 18, "corrugated_grey", "A2", ""),
                                    (75.0, 16, 14, "corrugated_rust", "", "")):
    obuilding(OE, "warehouse", B2 + d / 2, z, "W", w, d, 2, floor_height=rnd.choice([3.2, 3.4, 3.6]), wall=wall,
              number=num, front_sign=fsign)
# Containerhof hinter dem Tor an der T-Kreuzung
oprop(OE, "FENCE", 93.0, -8.5, 90, length=7.0)
oprop(OE, "FENCE", 93.0, 8.5, 90, length=7.0)
oprop(OE, "STRIPED_BARRIER", 93.4, 0.0, 90, length=3.0)
sign(OE, "sign_noentry", 92.94, 1.45, -9.0, -90, "wall", 1.6, (1.0, 0.2, 0.2, 1), 0.0, 0.0)
obuilding(OE, "shanty", 97.5, 9.0, "W", 3.5, 3.2, 1, stilt_height=0.0)
for (x, z, yaw, stack) in ((106.0, -7.0, 90, 1), (106.0, -9.8, 90, 0), (113.0, 4.0, 0, 1), (116.0, 4.0, 0, 0),
                           (122.0, -8.0, 90, 1), (122.0, -10.8, 90, 1), (128.0, 6.0, 0, 0), (115.0, -20.0, 90, 0)):
    oprop(OE, "CONTAINER", x, z, yaw, half=CONTAINER_HALF, variant=rnd.randint(0, 3))
    if stack:
        prop(OE, "CONTAINER", x, z, yaw, y=2.6, variant=rnd.randint(0, 3))
oprop(OE, "CRATE_STACK", 107.5, -3.0, 0, r=0.8)
oprop(OE, "MILITARY_CRATES", 112.0, -6.0, 0, r=1.1)
oprop(OE, "PALLETS", 118.0, 12.0, 20, r=1.0)
oprop(OE, "FIRE_BARREL", 109.0, 10.0, 0, r=0.4)
for z in (-88.0, -60.0, -32.0, 34.0, 62.0, 88.0):
    oprop(OE, "STREET_LAMP", 113.5 if abs(z) > 80 else 124.0, z, -90, variant=rnd.randint(0, 2))
for (z0, z1) in ((-30.0, -16.0), (16.0, 40.0), (60.0, 86.0), (-86.0, -60.0)):
    for _ in range(3):
        oprop(OE, rnd.choice(["BARREL_GROUP", "CRATE_STACK", "MILITARY_CRATES", "PALLETS"]),
              round(rnd.uniform(118.0, 131.0), 1), round(rnd.uniform(z0, z1), 1), rnd.choice([0, 90]), r=0.0,
              variant=rnd.randint(0, 3))
scatter(OE, ["BARREL", "PALLETS", "TRASH_BAGS", "CONE", "CRATE"], 114, 132, -86, -24, 8)
scatter(OE, ["BARREL", "PALLETS", "TRASH_BAGS", "CONE", "CRATE"], 114, 132, 14, 86, 8)

# --- Süd: Nachtmeile --------------------------------------------------------------------
nodes.append('[node name="OuterSouth" type="Node3D" parent="."]')
OSD = "OuterSouth"
ALLEY0 = B2 + 10.0  # 102: Rückseite der vorderen Reihe
ALLEY1 = ALLEY0 + 8.0  # 110: Front der zweiten Reihe
row1 = frontage(OSD, "S", -88.0, -11.0, {"shop": 3, "res": 2}, fixed_depth=10.0, floors=(3, 6))
row1 += frontage(OSD, "S", 11.0, 88.0, {"shop": 3, "res": 2}, fixed_depth=10.0, floors=(3, 6))
row2 = []
pos = -88.0
while pos < 86.0:
    w = round(rnd.uniform(8.0, 11.0), 1)
    if pos + w > 88.0:
        break
    c = pos + w / 2
    style = rnd.choice(["shop", "shop", "res"])
    props = {"wall": rnd.choice(WALLS), "front_sign": rnd.choice(SIGNS)}
    if rnd.random() < 0.5:
        props["side_sign"] = rnd.choice(SIGNS)
    obuilding(OSD, style, c, ALLEY1 + 5.0, "N", w, 10, rnd.randint(2, 3) if style == "shop" else rnd.randint(4, 7),
              lit_ratio=round(rnd.uniform(0.4, 0.6), 2), **props)
    row2.append((c, w))
    pos = c + w / 2 + round(rnd.uniform(0.8, 1.5), 1)
# Lampionketten quer über die Gasse, von Wand zu Wand
for (c, w, _d) in row1[::2]:
    if any(abs(c - c2) < w2 / 2 - 0.4 and abs(c + 0.8 - c2) < w2 / 2 - 0.4 for (c2, w2) in row2):
        cables(OSD, [(c, 5.2, ALLEY0 + 0.05), (c + 0.8, 5.6, ALLEY1 - 0.05)], 0.6, 1, True)
for x in (-70.0, -38.0, 22.0, 52.0):
    oprop(OSD, "MARKET_STALL", x, ALLEY1 - 1.9, 0, r=1.4, variant=rnd.randint(0, 2))
for x in (-55.0, -18.0, 36.0, 70.0):
    oprop(OSD, "FIRE_BARREL", x, ALLEY0 + 1.2, 0, r=0.4, variant=rnd.randint(0, 1))
    oprop(OSD, "BENCH", x + 3.0, ALLEY0 + 1.6, 180, r=1.0)
oprop(OSD, "STREET_LAMP", -4.5, ALLEY0 + 0.6, 0)
oprop(OSD, "STREET_LAMP", 4.5, ALLEY1 - 0.6, 180, variant=2)
scatter(OSD, ["TRASH_BAGS", "TRASH_PILE", "AC_STACK", "DUMPSTER", "BARREL"], -86, 86, 121.5, 128, 16)
for x in (-60.0, -20.0, 20.0, 60.0):
    oprop(OSD, "STREET_LAMP", x, 129.0, 180, variant=rnd.randint(0, 2))

# --- West: Shanty-Hang ------------------------------------------------------------------
nodes.append('[node name="OuterWest" type="Node3D" parent="."]')
OW = "OuterWest"
frontage(OW, "W", -88.0, -11.0, {"res": 2, "shop": 2}, depth=(9.0, 10.0), floors=(3, 5))
frontage(OW, "W", 11.0, 88.0, {"res": 2, "shop": 2}, depth=(9.0, 10.0), floors=(3, 5))
# Hüttenfeld wie im Südwesten: erst planen, dann bauen.
plan2 = {}
for gx in range(3):
    for gz in range(14):
        z = -72.0 + gz * 11.0
        if abs(z) < 7.0 or rnd.random() < 0.18:
            continue
        stilt = rnd.choice([0.0, 2.4, 2.4, 2.4])
        plan2[(gx, gz)] = {"x": -109.0 - gx * 10.0, "z": z, "stilt": stilt,
                           "w": round(rnd.uniform(4.8, 5.6), 2), "d": round(rnd.uniform(4.5, 5.2), 2),
                           "open_left": False, "open_right": False}
bridges2 = []
for (gx, gz), c in sorted(plan2.items()):
    n = plan2.get((gx + 1, gz))  # westlicher Nachbar (x kleiner)
    if n and c["stilt"] == 2.4 and n["stilt"] == 2.4 and rnd.random() < 0.7:
        c["open_left"] = True
        n["open_right"] = True
        x0 = n["x"] + n["w"] / 2 - 0.3
        x1 = c["x"] - c["w"] / 2 + 0.3
        bridges2.append(((x0 + x1) / 2, c["z"] + min(c["d"], n["d"]) / 2 - 0.6, x1 - x0))
for (gx, gz), c in sorted(plan2.items()):
    if c["stilt"] > 0:
        if c["open_left"] and c["open_right"]:
            sd = "none"
        elif c["open_right"]:
            sd = "left"
        elif c["open_left"]:
            sd = "right"
        else:
            sd = rnd.choice(["left", "right"])
        obuilding(OW, "shanty", c["x"], c["z"], "S", c["w"], c["d"], 1, stilt_height=c["stilt"], shanty_stair=SIDE[sd],
                  open_left=c["open_left"], open_right=c["open_right"])
    else:
        obuilding(OW, "shanty", c["x"], c["z"], rnd.choice(["S", "N", "E", "W"]), c["w"], c["d"], 1,
                  stilt_height=0.0, shanty_stair=SIDE["none"])
for (x, z, length) in bridges2:
    walkway(OW, x, 2.4, z, 90, round(length, 2), width=1.1, wooden=True, lanterns=rnd.random() < 0.5)
for gz in range(0, 14, 2):
    z = -72.0 + gz * 11.0 + 5.5
    cables(OW, [(-106.0, 5.2, z), (-119.5, 5.6, z + 0.4), (-133.0, 5.0, z - 0.3)], 0.7, 1, True, poles=[0, 1, 2],
           wooden_poles=True)
for (x, z) in ((-104.0, -2.0), (-114.0, 32.5), (-124.0, -44.5), (-104.5, 65.5)):
    oprop(OW, "FIRE_BARREL", x, z, 0, variant=rnd.randint(0, 1))
# Kleinkram nur in den Gassen zwischen den Hüttenreihen
for _ in range(22):
    z = -72.0 + rnd.randint(0, 12) * 11.0 + 5.5 + rnd.uniform(-1.5, 1.5)
    prop(OW, rnd.choice(["TRASH_PILE", "TRASH_BAGS", "BARREL", "CRATE", "PALLETS"]), rnd.uniform(-132.0, -105.0), z,
         rnd.uniform(0, 360), variant=rnd.randint(0, 2))

# --- Ecken ------------------------------------------------------------------------------
nodes.append('[node name="OuterCorners" type="Node3D" parent="."]')
OC = "OuterCorners"
# NO: Kraftwerk
obuilding(OC, "warehouse", 113.0, -110.0, "W", 24, 20, 3, floor_height=3.6, wall="corrugated_grey", number="07",
          front_sign="sign_ngc7")
for (x, z) in ((98.0, -126.0), (104.0, -129.0), (127.0, -128.0)):
    oprop(OC, "WATER_TANK", x, z, 0, r=1.6)
for (x, z) in ((96.0, -102.0), (128.0, -96.0)):
    oprop(OC, "GENERATOR", x, z, 0, r=1.2)
for z in (-96.0, -124.0):
    oprop(OC, "POWER_POLE", 99.0, z, 90)
cables(OC, [(99.0, TOP_ARM, -96.9), (99.0, TOP_ARM, -123.1)], 1.0, 1, wall_brackets=False)
# NW: Schrottplatz hinter Zaun
for (x0, x1) in ((-132.0, -118.0), (-112.0, -94.0)):
    oprop(OC, "FENCE", (x0 + x1) / 2, -94.0, 0, length=x1 - x0)
oprop(OC, "FENCE", -94.0, -114.0, 90, length=40.0)
for (x, z, yaw) in ((-102.0, -100.0, 0), (-126.0, -102.0, 90), (-124.0, -124.0, 0), (-100.0, -128.0, 90)):
    oprop(OC, "CONTAINER", x, z, yaw, half=CONTAINER_HALF, variant=rnd.randint(0, 3))
prop(OC, "CONTAINER", -126.0, -102.0, 90, y=2.6, variant=1)
for (x, z, yaw) in ((-116.0, -118.0, 140), (-106.0, -122.0, 15), (-120.0, -110.0, 60)):
    oprop(OC, "CAR_WRECK", x, z, yaw, r=2.0, variant=rnd.randint(0, 2))
oprop(OC, "FIRE_BARREL", -112.0, -102.0, 0, r=0.4)
oprop(OC, "STREET_LAMP", -98.0, -110.0, 90)
for (kind, x, z) in (("BARREL_GROUP", -110.0, -128.0), ("PALLETS", -128.0, -114.0), ("TRASH_PILE", -100.0, -116.0),
                     ("CRATE_STACK", -114.0, -100.0), ("TRASH_BAGS", -130.0, -130.0)):
    oprop(OC, kind, x, z, rnd.uniform(0, 360), r=1.0, variant=rnd.randint(0, 2))
# SO: Parkplatz und Hotel
slab(OC, 112.0, 106.0, 34.0, 20.0, "asphalt", 0.02, 0.4)
obuilding(OC, "res", 118.0, 126.0, "N", 26, 12, 10, wall="concrete_dark", ground_wall="tiles_dark",
          front_sign="sign_hotel", side_sign="sign_vacancy", lit_ratio=0.55, stair_side=SIDE["left"])
sign(OC, "sign_hotel", 118.0, 33.06, 126.0, 180, "roof", 7.0, (0.3, 0.8, 1.0, 1), 0.0, 3.0)
obuilding(OC, "shop", 97.0, 125.0, "N", 9, 9, 2, wall="plaster_pink", front_sign="sign_24h", side_sign="sign_open")
for x in (110.0, 118.0, 126.0):
    oprop(OC, "STREET_LAMP", x, 97.0, 0, variant=rnd.randint(0, 2))
oprop(OC, "CONCRETE_BARRIER", 128.0, 112.0, 90, r=0.0, length=6.0)
# SW: Hütten und Wohnturm
obuilding(OC, "res", -114.0, 120.0, "N", 18, 14, 11, wall="concrete", ground_wall="brick_dark", number="07",
          lit_ratio=0.45, stair_side=SIDE["right"])
obuilding(OC, "shanty", -98.0, 100.0, "S", 6, 5, 1, stilt_height=0.0)
obuilding(OC, "shanty", -98.0, 110.0, "E", 5, 5, 1, stilt_height=0.0)
obuilding(OC, "shanty", -130.0, 98.0, "N", 5, 4.5, 1, stilt_height=0.0)
oprop(OC, "WATER_TANK", -99.0, 129.0, 0, r=1.6)
oprop(OC, "FIRE_BARREL", -106.0, 104.0, 0, r=0.4)
for (kind, x, z) in (("TRASH_PILE", -110.0, 100.0), ("BARREL", -122.0, 104.0), ("CRATE", -116.0, 98.0),
                     ("TRASH_BAGS", -126.0, 108.0)):
    oprop(OC, kind, x, z, rnd.uniform(0, 360), r=0.9, variant=rnd.randint(0, 2))

# =====================================================================================
# Rand: Hochhäuser (Hintergrund) und unsichtbare Wände
# =====================================================================================
nodes.append('[node name="Skyline" type="Node3D" parent="."]')
SK = "Skyline"
walls = ["concrete_dark", "concrete", "brick_dark", "plaster", "concrete_green"]
signs = ["", "", "", "sign_ngc7", "sign_shop", "sign_24h", "sign_bar"]
for side in ("N", "S", "E", "W"):
    pos = -MAP_EDGE - 8.0
    while pos < MAP_EDGE + 8.0:
        w = rnd.uniform(14, 22)
        c = pos + w / 2
        floors = rnd.randint(10, 24)
        d = rnd.uniform(12, 16)
        dist = MAP_EDGE + 4.0 + d / 2 + rnd.uniform(0, 4)
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
# Straßennetz für Autos und Wegenetz für Fußgänger (PR #35) → scenes/slum/slum_life.tscn
# =====================================================================================
LIFE_OUT = os.path.join(os.path.dirname(__file__), "..", "scenes", "slum", "slum_life.tscn")
JUNCTIONS = {"C": (0.0, 0.0), "TN": (0.0, -RING), "TS": (0.0, RING), "TE": (RING, 0.0), "TW": (-RING, 0.0),
             "NE": (RING, -RING), "NW": (-RING, -RING), "SE": (RING, RING), "SW": (-RING, RING)}
# Wo die Fahrspur vor der Kreuzungsmitte endet: vor dem Zebrastreifen (6,5 m) bzw. an den Ecken früher.
JUNCTION_STOP = {"C": 9.0, "TN": 9.0, "TS": 9.0, "TE": 9.0, "TW": 9.0, "NE": 7.0, "NW": 7.0, "SE": 7.0, "SW": 7.0}
ROADS = [("C", "TN"), ("C", "TS"), ("C", "TE"), ("C", "TW"), ("TN", "NE"), ("TN", "NW"), ("TS", "SE"), ("TS", "SW"),
         ("TE", "NE"), ("TE", "SE"), ("TW", "NW"), ("TW", "SW")]
CROSSWALK_JUNCTIONS = {"C", "TN", "TS", "TE", "TW"}
PED = 6.5  # Fußgängerlinie: 6,5 m neben der Straßenmitte, Ecken 6,5 m vor der Kreuzungsmitte


class PedGraph:
    def __init__(self) -> None:
        self.nodes: list[tuple[float, float, float]] = []
        self.wait: list[float] = []
        self.edges: dict[tuple[int, int], int] = {}

    def add(self, x: float, z: float, y: float = 0.15, wait: float = 0.0) -> int:
        key = (round(x, 1), round(z, 1))
        for i, n in enumerate(self.nodes):
            if (round(n[0], 1), round(n[2], 1)) == key:
                self.wait[i] = max(self.wait[i], wait)
                return i
        self.nodes.append((round(x, 2), y, round(z, 2)))
        self.wait.append(wait)
        return len(self.nodes) - 1

    def link(self, a: int, b: int, crossing: bool = False) -> None:
        if a != b:
            self.edges[(min(a, b), max(a, b))] = 1 if crossing else 0

    def line(self, x0: float, z0: float, x1: float, z1: float, step: float = 14.0, y: float = 0.15) -> list[int]:
        n = max(1, int(math.ceil(math.hypot(x1 - x0, z1 - z0) / step)))
        ids = [self.add(x0 + (x1 - x0) * i / n, z0 + (z1 - z0) * i / n, y) for i in range(n + 1)]
        for a, b in zip(ids, ids[1:]):
            self.link(a, b)
        return ids

    def nearest(self, x: float, z: float) -> int:
        return min(range(len(self.nodes)), key=lambda i: (self.nodes[i][0] - x) ** 2 + (self.nodes[i][2] - z) ** 2)


ped = PedGraph()
for (a, b) in ROADS:
    ax, az = JUNCTIONS[a]
    bx, bz = JUNCTIONS[b]
    length = math.hypot(bx - ax, bz - az)
    ux, uz = (bx - ax) / length, (bz - az) / length
    px, pz = -uz, ux
    for side in (-1, 1):
        ped.line(ax + ux * PED + px * PED * side, az + uz * PED + pz * PED * side,
                 bx - ux * PED + px * PED * side, bz - uz * PED + pz * PED * side)
for name, (jx, jz) in JUNCTIONS.items():
    dirs = []
    for (a, b) in ROADS:
        if name in (a, b):
            ox, oz = JUNCTIONS[b if a == name else a]
            length = math.hypot(ox - jx, oz - jz)
            dirs.append(((ox - jx) / length, (oz - jz) / length))
    if name in CROSSWALK_JUNCTIONS:
        if len(dirs) == 3:  # T-Kreuzung: der fehlende Arm ist ein Platz
            sx, sz = sum(d[0] for d in dirs), sum(d[1] for d in dirs)
            dirs.append((-sx, -sz))
        for (ux, uz) in dirs:
            px, pz = -uz, ux
            p1 = ped.add(jx + ux * PED + px * PED, jz + uz * PED + pz * PED)
            p2 = ped.add(jx + ux * PED - px * PED, jz + uz * PED - pz * PED)
            plaza = name != "C" and (ux, uz) == dirs[-1]
            ped.link(p1, p2, crossing=not plaza)
    else:  # Ecke: außen um die Ecke herum
        (u1x, u1z), (u2x, u2z) = dirs
        ox, oz = jx - (u1x + u2x) * PED, jz - (u1z + u2z) * PED
        corner = ped.add(ox, oz)
        for (ux, uz) in dirs:
            # Punkt auf der Außenseite des Arms (u): 6,5 m in Richtung u, 6,5 m nach außen.
            ped.link(corner, ped.nearest(jx + ux * PED - (u1x + u2x - ux) * PED, jz + uz * PED - (u1z + u2z - uz) * PED))


def poi_chain(points: list[tuple[float, float, float]], start: tuple[float, float], y: float = 0.0) -> None:
    """Abzweig vom Gehweg-Knoten bei start zu Orten zum Bummeln (x, z, Wartezeit)."""
    prev = ped.nearest(*start)
    for (x, z, wait) in points:
        cur = ped.add(x, z, y, wait)
        ped.link(prev, cur)
        prev = cur


poi_chain([(40.0, 20.0, 0.0), (40.0, 36.5, 8.0), (30.0, 36.5, 6.0)], (40.0, PED))           # Markt SO
poi_chain([(20.0, -20.0, 0.0), (32.0, -50.0, 5.0)], (20.0, -PED))                          # Hinterhof NO
poi_chain([(-20.0, 36.0, 6.0)], (-PED, 36.0))                                              # Stände SW
poi_chain([(0.0, -98.0, 6.0), (0.0, -106.0, 5.0)], (0.0, -RING - PED))                     # Platz Nord
poi_chain([(0.0, 106.0, 2.0)], (0.0, RING + PED))                                          # Nachtmeile
alley = ped.line(-84.0, 106.0, 84.0, 106.0, 12.0, 0.0)                                      # Gasse
for i in alley[::3]:
    ped.wait[i] = 5.0
poi_chain([(-104.0, 0.0, 0.0), (-118.0, -5.5, 4.0)], (-RING - PED, 0.0))                   # Shanty-Hang
poi_chain([(104.0, 0.0, 6.0)], (RING + PED, 0.0))                                          # Docks-Tor
poi_chain([(112.0, 100.0, 5.0)], (RING + PED, RING + PED))                                 # Parkplatz


def life_scene() -> str:
    names = list(JUNCTIONS)
    j_pts = ", ".join(f"{JUNCTIONS[n][0]}, 0, {JUNCTIONS[n][1]}" for n in names)
    j_stop = ", ".join(str(JUNCTION_STOP[n]) for n in names)
    j_cross = ", ".join("1" if n in CROSSWALK_JUNCTIONS else "0" for n in names)
    r_edges = ", ".join(f"{names.index(a)}, {names.index(b)}" for (a, b) in ROADS)
    p_pts = ", ".join(f"{x}, {y}, {z}" for (x, y, z) in ped.nodes)
    p_wait = ", ".join(str(w) for w in ped.wait)
    keys = sorted(ped.edges)
    p_edges = ", ".join(f"{a}, {b}" for (a, b) in keys)
    p_cross = ", ".join(str(ped.edges[k]) for k in keys)
    return f"""[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/traffic/traffic_director.gd" id="1_traffic"]
[ext_resource type="Script" path="res://scenes/civilians/crowd_director.gd" id="2_crowd"]

[node name="SlumLife" type="Node3D"]

[node name="Traffic" type="Node3D" parent="."]
script = ExtResource("1_traffic")
junctions = PackedVector3Array({j_pts})
junction_stop = PackedFloat32Array({j_stop})
junction_crosswalk = PackedInt32Array({j_cross})
roads = PackedInt32Array({r_edges})

[node name="Crowd" type="Node3D" parent="."]
script = ExtResource("2_crowd")
nodes = PackedVector3Array({p_pts})
node_wait = PackedFloat32Array({p_wait})
edges = PackedInt32Array({p_edges})
edge_crossing = PackedInt32Array({p_cross})
"""

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
[ext_resource type="PackedScene" path="res://scenes/slum/slum_life.tscn" id="l_life"]

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
size = Vector3(BOUND_SIZE, 60, 1)

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
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 30, -BOUND)

[node name="Shape" type="CollisionShape3D" parent="Bounds/North"]
shape = SubResource("Shape_bound")

[node name="South" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 30, BOUND)

[node name="Shape" type="CollisionShape3D" parent="Bounds/South"]
shape = SubResource("Shape_bound")

[node name="East" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, BOUND, 30, 0)

[node name="Shape" type="CollisionShape3D" parent="Bounds/East"]
shape = SubResource("Shape_bound")

[node name="West" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, -BOUND, 30, 0)

[node name="Shape" type="CollisionShape3D" parent="Bounds/West"]
shape = SubResource("Shape_bound")

[node name="Player" parent="." instance=ExtResource("2_player")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 5.8, 0.25, 62)

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
    # Außenviertel (PR #35)
    ("Spot_NorthMarket", (0.0, 0.0, -104.0), "i_noodles", 2),
    ("Spot_Docks", (106.0, 5.2, -7.0), "i_shard", 2),
    ("Spot_NightMile", (-30.0, 0.0, 106.0), "i_drink", 2),
    ("Spot_ShantyHill", (-104.0, 0.0, 4.0), "i_credchip", 15),
    ("Spot_Scrapyard", (-110.0, 0.0, -106.0), "i_stim", 1),
    ("Spot_Parking", (112.0, 0.02, 103.0), "i_credchip", 25),
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
    # Fußgänger und Autos (scenes/slum/slum_life.tscn, wird mit erzeugt)
    out.append('[node name="SlumLife" parent="." instance=ExtResource("l_life")]')
    return "\n\n".join(out)


def main() -> None:
    head = HEAD.replace("BOUND_SIZE", str(int(2 * MAP_EDGE + 20)))
    tail = TAIL.replace("BOUND", str(int(MAP_EDGE)))
    text = head + "\n" + "\n\n".join(nodes) + "\n" + tail + "\n" + items() + "\n"
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print("geschrieben:", OUT, len(nodes), "Kit-Knoten")
    with open(LIFE_OUT, "w", encoding="utf-8") as f:
        f.write(life_scene())
    print("geschrieben:", LIFE_OUT, len(ped.nodes), "Fußgänger-Knoten,", len(ped.edges), "Wege")


if __name__ == "__main__":
    main()
