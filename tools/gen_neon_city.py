#!/usr/bin/env python3
"""Erzeugt scenes/neon_city/neon_city.tscn, die Map „Neon City“, aus dem Neon-Baukasten.

Aufruf aus dem Repo-Root:  python3 tools/gen_neon_city.py

Koordinaten: x nach Osten, z nach Süden (Norden = -Z). Rand bei ±180 m (unsichtbare Wände).
Straßenachsen bei -144, -72, 0, 72, 144 in beide Richtungen, die Achsen x = 0 und z = 0 sind
Hauptstraßen (14 m Fahrbahn mit Mittelstreifen, 4 m Gehweg), die übrigen 10 m mit 3,5 m Gehweg.
Die 16 Innenblöcke gehören zu fünf Bezirken:
  Kern (Mitte 2×2):  Konzerntürme, Plätze an der Hauptkreuzung, Skywalk-Ring auf 7 m Höhe
  Hafen (Norden):    Lagerhallen, Containerhöfe, Lkw
  Megablocks (Süden): Wohntürme, Parks und Parkplätze in den Höfen
  Neonmeile (Osten): Nachtleben, Läden mit Leuchtschildern, Nachtmarkt im Hof
  Unterstadt (Westen): niedrige bunte Häuser, Hütten und Markt im Hof
Außen (Streifen jenseits ±144) steht ein geschlossener Ring aus Hochhäusern als Stadtrand.

Jedes Haus, jede Platte, jede Treppe und jedes Prop meldet seine Grundfläche an (claim). Der
Generator bricht ab, wenn sich zwei feste Dinge überschneiden oder etwas auf der Fahrbahn steht.
"""
from __future__ import annotations

import math
import os
import random

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "scenes", "neon_city", "neon_city.tscn")
LIFE_OUT = os.path.join(ROOT, "scenes", "neon_city", "neon_city_life.tscn")
ENEMIES_OUT = os.path.join(ROOT, "scenes", "neon_city", "neon_city_enemies.tscn")
rnd = random.Random(2077)

EDGE = 180.0
LINES = [-144.0, -72.0, 0.0, 72.0, 144.0]
SIDEWALK_Y = 0.15
SKY_Y = 7.0

FACING = {"S": 0.0, "E": 90.0, "N": 180.0, "W": -90.0}
FACADE = {"grid": 0, "bands": 1, "industrial": 2}

nodes: list[str] = []
counter: dict[str, int] = {}


def road_dims(line: float) -> tuple[float, float, float]:
    """(Fahrbahnbreite, Gehweg, Mittelstreifen) der Straße auf dieser Achse."""
    return (14.0, 4.0, 2.0) if line == 0.0 else (10.0, 3.5, 0.0)


def ext(line: float) -> float:
    """Halbe Breite der Straße inklusive Gehweg."""
    w, s, _ = road_dims(line)
    return w / 2 + s


# =====================================================================================
# Szene schreiben
# =====================================================================================
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


class Raw(str):
    """Wert, der so in die Szene geschrieben wird (z. B. PackedFloat32Array(...))."""


def val(v) -> str:
    if isinstance(v, Raw):
        return str(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return f'"{v}"'
    if isinstance(v, float):
        return str(round(v, 3))
    if isinstance(v, tuple) and len(v) == 2:
        return f"Vector2({round(v[0], 3)}, {round(v[1], 3)})"
    if isinstance(v, tuple) and len(v) == 4:
        return f"Color({v[0]}, {v[1]}, {v[2]}, {v[3]})"
    return str(v)


def node(name: str, parent: str, script_id: str, x: float, y: float, z: float, yaw: float = 0.0, **props) -> None:
    lines = [f'[node name="{name}" type="Node3D" parent="{parent}"]', f"transform = {xform(x, y, z, yaw)}",
             f'script = ExtResource("{script_id}")']
    for k, v in props.items():
        lines.append(f"{k} = {val(v)}")
    nodes.append("\n".join(lines))


def group(name: str, parent: str = ".") -> str:
    nodes.append(f'[node name="{name}" type="Node3D" parent="{parent}"]')
    return name if parent == "." else f"{parent}/{name}"


# =====================================================================================
# Grundflächen: nichts Festes darf sich überschneiden
# =====================================================================================
claims: list[tuple[float, float, float, float, str, str]] = []  # x0, x1, z0, z1, Art, Name


def claim(x0: float, x1: float, z0: float, z1: float, kind: str, what: str) -> None:
    """kind: road (Fahrbahn), solid (Haus, Treppe, Prop), keep (Weg, der frei bleiben muss: Gasse,
    Hofzugang), raised (erhöhte Platte: Props ja, Items und Fußweg-Ziele nein), area (Hof, Platz)."""
    x0, x1 = min(x0, x1), max(x0, x1)
    z0, z1 = min(z0, z1), max(z0, z1)
    if kind not in ("area", "raised"):
        for (a0, a1, b0, b1, k, w) in claims:
            if k in ("area", "raised"):
                continue
            if x0 < a1 - 0.01 and x1 > a0 + 0.01 and z0 < b1 - 0.01 and z1 > b0 + 0.01:
                if kind == "road" and k == "road":
                    continue
                raise SystemExit(f"Überschneidung: {what} ({x0:.1f}..{x1:.1f}, {z0:.1f}..{z1:.1f}) mit {w}")
    if max(abs(x0), abs(x1), abs(z0), abs(z1)) > EDGE + 0.01 and kind != "area":
        raise SystemExit(f"Außerhalb der Map: {what}")
    claims.append((x0, x1, z0, z1, kind, what))


def rect_of(x: float, z: float, w: float, d: float, yaw: float) -> tuple[float, float, float, float]:
    """Grundfläche (achsparallel) eines Teils mit Breite w (lokal x) und Tiefe d (lokal z)."""
    if abs(round(yaw)) % 180 == 90:
        w, d = d, w
    return x - w / 2, x + w / 2, z - d / 2, z + d / 2


def free(x0: float, x1: float, z0: float, z1: float, strict: bool = False) -> bool:
    """Nichts Festes und kein freizuhaltender Weg im Rechteck. strict: auch keine erhöhte Platte."""
    for (a0, a1, b0, b1, k, _) in claims:
        if k == "area" or (k == "raised" and not strict):
            continue
        if x0 < a1 and x1 > a0 and z0 < b1 and z1 > b0:
            return False
    return True


# =====================================================================================
# Bausteine
# =====================================================================================
TOWERS: list[dict] = []  # alle Häuser mit Maßen, für die Details aus den Packs


def tower(parent: str, x: float, z: float, facing: str, w: float, d: float, floors: int, district: str, **props) -> None:
    yaw = FACING[facing]
    claim(*rect_of(x, z, w, d, yaw), "solid", f"Haus {x:.0f},{z:.0f}")
    props.setdefault("seed_value", rnd.randint(1, 99999))
    props.setdefault("color_index", rnd.randint(0, 3))
    props.setdefault("accent", rnd.randint(0, 5))
    TOWERS.append(dict(x=x, z=z, yaw=yaw, w=w, d=d, floors=floors, district=district, parent=parent,
                       fh=props.get("floor_height", 3.2), facade=props.get("facade", 0),
                       setbacks=props.get("setbacks", 0), shop=props.get("shop_front", False),
                       billboard=props.get("roof_billboard", False), rect=rect_of(x, z, w, d, yaw)))
    node(uname("Tower"), parent, "k_tower", x, 0.0, z, yaw, district=district, footprint=(w, d), floors=floors, **props)


def ground(parent: str, x0: float, x1: float, z0: float, z1: float, color, height: float = SIDEWALK_Y,
           grid: float = 0.0, kind: str = "area") -> None:
    claim(x0, x1, z0, z1, "raised" if height > SIDEWALK_Y + 0.01 else kind, "Platte")
    node(uname("Ground"), parent, "k_ground", (x0 + x1) / 2, 0.0, (z0 + z1) / 2, 0.0,
         size=(x1 - x0, z1 - z0), height=height, color=color, grid=grid)


def box_prop(parent: str, x: float, z: float, w: float, d: float, h: float, color, yaw: float = 0.0, y: float = SIDEWALK_Y) -> None:
    """Fester Klotz (Container, Kiste) als NeonGround."""
    claim(*rect_of(x, z, w, d, yaw), "solid", f"Klotz {x:.0f},{z:.0f}")
    if abs(round(yaw)) % 180 == 90:
        w, d = d, w
    node(uname("Crate"), parent, "k_ground", x, y, z, 0.0, size=(w, d), height=h, color=color)


# Props aus den Packs: Modell, Zielgröße (Länge oder Höhe), Kollision, Grundfläche (Breite, Tiefe).
# Die Grundflächen sind die gemessenen Hüllen nach dem Skalieren (+5 cm), bei Bäumen nur der Stamm.
PROPS = {
    "car": ("res://assets/props/city_pack/Car.glb", 4.2, 0.0, True, (1.9, 4.3)),
    "suv": ("res://assets/props/city_pack/SUV.glb", 4.6, 0.0, True, (2.4, 4.7)),
    "sports": ("res://assets/props/city_pack/Sports Car.glb", 4.4, 0.0, True, (2.2, 4.5)),
    "police": ("res://assets/props/city_pack/Police Car.glb", 4.6, 0.0, True, (2.3, 4.7)),
    "pickup": ("res://assets/props/city_pack/Pickup Truck.glb", 5.2, 0.0, True, (2.4, 5.3)),
    "van": ("res://assets/props/city_pack/Van.glb", 5.0, 0.0, True, (2.85, 5.1)),
    "taxi": ("res://assets/props/quaternius_vehicles/Taxi.fbx", 4.4, 0.0, True, (2.25, 4.5)),
    "bench": ("res://assets/props/city_pack/Bench.glb", 2.0, 0.0, True, (1.1, 2.1)),
    "trash": ("res://assets/props/city_pack/Trash Can.glb", 0.0, 1.0, True, (1.0, 1.0)),
    "hydrant": ("res://assets/props/city_pack/Fire hydrant.glb", 0.0, 0.8, True, (0.5, 0.5)),
    "mailbox": ("res://assets/props/city_pack/Mailbox.glb", 0.0, 1.2, True, (0.7, 0.7)),
    "powerbox": ("res://assets/props/city_pack/Power Box.glb", 0.0, 1.3, True, (0.5, 0.5)),
    "planter": ("res://assets/props/city_pack/Planter & Bushes.glb", 2.2, 0.0, True, (0.8, 2.3)),
    "dumpster": ("res://assets/props/city_pack/Dumpster.glb", 2.2, 0.0, True, (1.3, 2.3)),
    "cone": ("res://assets/props/city_pack/Cone.glb", 0.0, 0.7, False, (0.5, 0.5)),
    "bag": ("res://assets/props/city_pack/trah bag grey.glb", 0.0, 0.6, False, (0.45, 0.45)),
    "busstop": ("res://assets/props/city_pack/Bus Stop.glb", 4.2, 0.0, True, (2.8, 4.3)),
    "tree": ("res://assets/buildings/kenney_retro_urban/tree-park-large.glb", 0.0, 6.0, True, (0.8, 0.8)),
    "pine": ("res://assets/buildings/kenney_retro_urban/tree-pine-large.glb", 0.0, 7.0, True, (0.8, 0.8)),
    "pallet": ("res://assets/buildings/kenney_retro_urban/pallet.glb", 1.4, 0.0, False, (1.5, 1.5)),
    "scaffold": ("res://assets/buildings/kenney_retro_urban/scaffolding-structure.glb", 0.0, 3.0, True, (3.1, 3.1)),
}


def prop(parent: str, kind: str, x: float, z: float, yaw: float = 0.0, y: float = SIDEWALK_Y, check: bool = True) -> bool:
    model, length, height, collide, (w, d) = PROPS[kind]
    r = rect_of(x, z, w, d, yaw)
    if check and not free(*r):
        return False
    if collide:
        claim(*r, "solid", f"Prop {kind} {x:.0f},{z:.0f}")
    extra = {"collider_footprint": (w, d)} if kind in ("tree", "pine") else {}
    node(uname(kind.capitalize()), parent, "k_prop", x, y, z, yaw, model=model, fit_length=length,
         fit_height=height if height > 0 else 1.0, collide=collide, **extra)
    return True


# =====================================================================================
# Straßen und Kreuzungen
# =====================================================================================
P_ROADS = group("Streets")

# Bezirke und Tiefe der Nord-/Südreihe je Block stehen vorab fest: daraus folgt die Lage der
# Gassen (Mitte zwischen den Reihen), und an den Gassenmündungen steht keine Laterne.
DISTRICT = {}
for bi in range(4):
    for bj in range(4):
        DISTRICT[(bi, bj)] = "harbor" if bj == 0 else "blocks" if bj == 3 else "under" if bi == 0 else "neon" if bi == 3 else "core"
DEPTHS = {"core": (18, 22), "harbor": (18, 22), "blocks": (14, 17), "neon": (12, 15), "under": (10, 13)}
DEPTH_NS = {k: (rnd.uniform(*DEPTHS[d]), rnd.uniform(*DEPTHS[d])) for k, d in DISTRICT.items()}


def alley_z(bi: int, bj: int) -> float:
    z0 = LINES[bj] + ext(LINES[bj])
    z1 = LINES[bj + 1] - ext(LINES[bj + 1])
    dn, ds = DEPTH_NS[(bi, bj)]
    return (z0 + dn + z1 - ds) / 2

LAMPS: list[tuple[float, float]] = []  # Laternenmasten (Weltlage), wie NeonRoad._lamps sie setzt


def lamp_points(line: float, center: float, along_x: bool, length: float, w: float, s: float,
                skip: list[float]) -> list[tuple[float, float]]:
    out = []
    n = max(1, int(length / 18.0))
    step = length / n
    for i in range(n):
        a = -length / 2 + step * (i + 0.5)
        for side in (-1.0, 1.0):
            if (i % 2 == 0) != (side < 0) or any(abs(a - k) < 2.5 for k in skip):
                continue
            off = side * (w / 2 + s - 0.4)
            # Straße entlang x (Drehung 90°): lokal x zeigt nach -z der Welt.
            out.append((center + a, line - off) if along_x else (line + off, center + a))
    return out


for i, lx in enumerate(LINES):
    for j in range(len(LINES) - 1):
        za, zb = LINES[j], LINES[j + 1]
        z0, z1 = za + ext(za), zb - ext(zb)
        w, s, m = road_dims(lx)
        claim(lx - w / 2, lx + w / 2, z0, z1, "road", f"Straße x={lx}")
        claim(lx - w / 2 - s, lx - w / 2, z0, z1, "area", "Gehweg")
        cz = (z0 + z1) / 2
        skip = [round(alley_z(b, j) - cz, 2) for b in (i - 1, i) if 0 <= b < 4]
        LAMPS.extend(lamp_points(lx, cz, False, z1 - z0, w, s, skip))
        node(uname("Road"), P_ROADS, "k_road", lx, 0.0, cz, 0.0, length=z1 - z0, road_width=w,
             sidewalk=s, median=m, crosswalk_start=True, crosswalk_end=True, seed_value=rnd.randint(1, 9999),
             lamp_skip=Raw(f"PackedFloat32Array({', '.join(str(v) for v in skip)})"))
for j, lz in enumerate(LINES):
    for i in range(len(LINES) - 1):
        xa, xb = LINES[i], LINES[i + 1]
        x0, x1 = xa + ext(xa), xb - ext(xb)
        w, s, m = road_dims(lz)
        claim(x0, x1, lz - w / 2, lz + w / 2, "road", f"Straße z={lz}")
        LAMPS.extend(lamp_points(lz, (x0 + x1) / 2, True, x1 - x0, w, s, []))
        node(uname("Road"), P_ROADS, "k_road", (x0 + x1) / 2, 0.0, lz, 90.0, length=x1 - x0, road_width=w,
             sidewalk=s, median=m, crosswalk_start=True, crosswalk_end=True, seed_value=rnd.randint(1, 9999))

ASPHALT = (0.09, 0.09, 0.11, 1)
WALK = (0.3, 0.3, 0.33, 1)
PLAZA = (0.24, 0.24, 0.28, 1)
for i, lx in enumerate(LINES):
    for j, lz in enumerate(LINES):
        wv, sv, _ = road_dims(lx)
        wh, sh, _ = road_dims(lz)
        arms = {"W": i > 0, "E": i < 4, "N": j > 0, "S": j < 4}
        # Fahrbahnkreuz: Mitte, dazu die Arme quer durch die Gehwegzone der anderen Straße.
        node(uname("Junction"), P_ROADS, "k_ground", lx, 0.0, lz, 0.0, size=(wv, wh), height=0.0, color=ASPHALT)
        claim(lx - wv / 2, lx + wv / 2, lz - wh / 2, lz + wh / 2, "road", "Kreuzung")
        for arm, (dx, dz) in {"W": (-1, 0), "E": (1, 0), "N": (0, -1), "S": (0, 1)}.items():
            if dx:
                cx, cz, sx, sz = lx + dx * (wv / 2 + sv / 2), lz, sv, wh
            else:
                cx, cz, sx, sz = lx, lz + dz * (wh / 2 + sh / 2), wv, sh
            if arms[arm]:
                node(uname("JunctionArm"), P_ROADS, "k_ground", cx, 0.0, cz, 0.0, size=(sx, sz), height=0.0, color=ASPHALT)
                claim(cx - sx / 2, cx + sx / 2, cz - sz / 2, cz + sz / 2, "road", "Kreuzungsarm")
            else:
                # Kein Arm (Rand): der Gehweg der Querstraße läuft durch.
                node(uname("JunctionWalk"), P_ROADS, "k_ground", cx, 0.0, cz, 0.0, size=(sx, sz), height=SIDEWALK_Y, color=WALK)
        for dx in (-1, 1):
            for dz in (-1, 1):
                cx, cz = lx + dx * (wv / 2 + sv / 2), lz + dz * (wh / 2 + sh / 2)
                node(uname("Corner"), P_ROADS, "k_ground", cx, 0.0, cz, 0.0, size=(sv, sh), height=SIDEWALK_Y, color=WALK)
                # Ampelmast an der Ecke (Kreuzungen mit vier Armen).
                if all(arms.values()) and dx == dz:
                    prop(P_ROADS, "powerbox", cx - dx * (sv / 2 - 0.5), cz - dz * (sh / 2 - 0.5), 0.0)

SPAWN = (9.0, 44.0)  # Gehweg der Hauptstraße x = 0, südlich vom Kern
claim(SPAWN[0] - 0.5, SPAWN[0] + 0.5, SPAWN[1] - 0.5, SPAWN[1] + 0.5, "solid", "Spieler-Start")

# Untergrund unter allem (fängt Spalten ab) und Ränder der Blöcke auf Gehweghöhe.
node("Base", ".", "k_ground", 0.0, 0.0, 0.0, 0.0, size=(2 * EDGE + 60, 2 * EDGE + 60), height=-0.3, color=(0.07, 0.07, 0.08, 1))


# =====================================================================================
# Blöcke und Bezirke
# =====================================================================================

# Pro Bezirk: Tiefe der Randbebauung, Länge der Grundstücke, Stockwerke, Fassade.
STYLE = {
    "core": dict(depth=(18, 22), lot=(16, 24), floors=(18, 42), facade="bands", shop=0.6, corner=0.5, billboard=0.35, lit=0.32, setbacks=(1, 2)),
    "harbor": dict(depth=(18, 22), lot=(18, 28), floors=(1, 3), facade="industrial", shop=0.0, corner=0.1, billboard=0.1, lit=0.15, setbacks=(0, 0), fh=4.5),
    "blocks": dict(depth=(14, 17), lot=(14, 22), floors=(10, 22), facade="grid", shop=0.35, corner=0.15, billboard=0.2, lit=0.3, setbacks=(0, 1)),
    "neon": dict(depth=(12, 15), lot=(8, 13), floors=(4, 10), facade="grid", shop=0.95, corner=0.45, billboard=0.4, lit=0.38, setbacks=(0, 0)),
    "under": dict(depth=(10, 13), lot=(7, 11), floors=(2, 4), facade="grid", shop=0.7, corner=0.1, billboard=0.1, lit=0.3, setbacks=(0, 0)),
}

# Läden und Tankstellen: (Bezirk-Block, Seite, Art) – der Generator nimmt das erste passende Grundstück.
# Nur an den langen Nord-/Südseiten: Ost- und Westseiten sind zwischen den Eckhäusern zu kurz.
SHOP_SLOTS = [((3, 1), "N", "guns"), ((0, 2), "S", "guns"), ((2, 3), "N", "guns"), ((1, 1), "N", "guns"),
              ((1, 0), "S", "gas"), ((3, 0), "S", "gas"), ((3, 3), "N", "gas")]
SHOP_SIZE = {"guns": (8.0, 3.5, 3.5), "gas": (15.0, 8.0, 6.0)}  # Breite, vorn und hinten ab Ladenmitte (lokal +Z/-Z)
shop_places: list[dict] = []
courts: list[tuple[str, float, float, float, float]] = []  # Bezirk, Hof-Rechteck (für Fußwege)


def split(length: float, lot: tuple[float, float]) -> list[float]:
    out = []
    left = length
    while left > 0.01:
        l = rnd.uniform(*lot)
        if left - l < lot[0]:
            l = left
        out.append(l)
        left -= l
    return out


def frontage(parent: str, district: str, side: str, a0: float, a1: float, edge: float, depth: float,
             cut=None, shops: list[str] = (), closed: bool = False, floors_scale: float = 1.0) -> None:
    """Häuserreihe an der Blockkante `edge` (Gehweg) entlang a0..a1, Front Richtung `side`.
    N/S: entlang x, Kante bei z = edge. E/W: entlang z, Kante bei x = edge."""
    st = STYLE[district]
    pending = list(shops)
    a = a0
    for l in split(a1 - a0, st["lot"]):
        mid = a + l / 2
        inward = {"N": 1.0, "S": -1.0, "W": 1.0, "E": -1.0}[side]
        if side in "NS":
            cx, cz = mid, edge + inward * depth / 2
            rx0, rx1, rz0, rz1 = a, a + l, min(edge, edge + inward * depth), max(edge, edge + inward * depth)
        else:
            cx, cz = edge + inward * depth / 2, mid
            rx0, rx1, rz0, rz1 = min(edge, edge + inward * depth), max(edge, edge + inward * depth), a, a + l
        a += l
        if cut and rx0 < cut[1] and rx1 > cut[0] and rz0 < cut[3] and rz1 > cut[2]:
            continue
        if pending:
            kind = pending[0]
            sw, front, back = SHOP_SIZE[kind]
            if l >= sw + 1.0 and depth >= front + back:
                pending.pop(0)
                yaw = FACING[side]
                # Front an der Blockkante, der Laden reicht front + back ins Grundstück.
                if side in "NS":
                    sx, sz = mid, edge + inward * front
                    claim(mid - sw / 2, mid + sw / 2, edge, edge + inward * (front + back), "solid", f"Laden {kind}")
                else:
                    sx, sz = edge + inward * front, mid
                    claim(edge, edge + inward * (front + back), mid - sw / 2, mid + sw / 2, "solid", f"Laden {kind}")
                shop_places.append({"kind": kind, "at": (round(sx, 2), SIDEWALK_Y, round(sz, 2)), "yaw": yaw})
                continue
        floors = max(1, int(rnd.randint(*st["floors"]) * floors_scale))
        is_corner = abs(a - l - a0) < 0.01 or abs(a - a1) < 0.01
        if district == "core" and is_corner:
            floors = int(floors * 1.25)
        w = l if closed else l - rnd.choice([0.0, 0.0, 0.6])
        tower(parent, cx, cz, side, w, depth, floors, district, facade=FACADE[st["facade"]],
              floor_height=st.get("fh", 3.2), setbacks=rnd.randint(*st["setbacks"]),
              shop_front=rnd.random() < st["shop"], corner_neon=rnd.random() < st["corner"],
              roof_billboard=rnd.random() < st["billboard"], lit_ratio=st["lit"], street_light=rnd.random() < 0.3)
    if pending:
        raise SystemExit(f"Kein Grundstück für {pending} in {district} {side}")


def block(bi: int, bj: int) -> None:
    district = DISTRICT[(bi, bj)]
    x0, x1 = LINES[bi] + ext(LINES[bi]), LINES[bi + 1] - ext(LINES[bi + 1])
    z0, z1 = LINES[bj] + ext(LINES[bj]), LINES[bj + 1] - ext(LINES[bj + 1])
    parent = group(f"Block_{bi}_{bj}")
    st = STYLE[district]
    dn, ds = DEPTH_NS[(bi, bj)]
    de, dw = rnd.uniform(*st["depth"]), rnd.uniform(*st["depth"])
    # Ecke an der Hauptkreuzung bleibt frei für den Platz mit Skywalk-Treppe.
    cut = None
    if district == "core":
        cx = x1 if bi == 1 else x0
        cz = z1 if bj == 1 else z0
        cut = (min(cx, cx - 26 if bi == 1 else cx + 26), max(cx, cx - 26 if bi == 1 else cx + 26),
               min(cz, cz - 26 if bj == 1 else cz + 26), max(cz, cz - 26 if bj == 1 else cz + 26))
    shops = {s: [k for (b, side, k) in SHOP_SLOTS if b == (bi, bj) and side == s] for s in "NSEW"}
    # Gasse quer durch die Ost- und Westreihe: Zugang zum Hof.
    alley = 5.0
    mz = (z0 + dn + z1 - ds) / 2
    frontage(parent, district, "N", x0, x1, z0, dn, cut, shops["N"])
    frontage(parent, district, "S", x0, x1, z1, ds, cut, shops["S"])
    frontage(parent, district, "W", z0 + dn, mz - alley / 2, x0, dw, cut, shops["W"])
    frontage(parent, district, "W", mz + alley / 2, z1 - ds, x0, dw, cut)
    frontage(parent, district, "E", z0 + dn, mz - alley / 2, x1, de, cut, shops["E"])
    frontage(parent, district, "E", mz + alley / 2, z1 - ds, x1, de, cut)
    ground(parent, x0, x1, z0, z1, PLAZA if district == "core" else WALK, grid=2.0 if district == "core" else 0.0)
    court = (x0 + dw, x1 - de, z0 + dn, z1 - ds)
    courts.append((district, *court))
    # Weg durch jede Gasse bis 1,8 m in den Hof bleibt frei (Fußgänger, Spieler, Gegner).
    claim(x0, x0 + dw + ENTRY, mz - PATH / 2, mz + PATH / 2, "keep", f"Gasse West {bi},{bj}")
    claim(x1 - de - ENTRY, x1, mz - PATH / 2, mz + PATH / 2, "keep", f"Gasse Ost {bi},{bj}")
    # Müllcontainer in jeder Gasse an der Seite.
    for side_x, d in ((x0, dw), (x1, -de)):
        prop(parent, "dumpster", side_x + d / 2, mz - alley / 2 + 0.7, 90.0)
    COURT[district](parent, *court)
    if cut:
        plaza(parent, *cut, bi, bj)


# --- Höfe ------------------------------------------------------------------------------
PATH = 3.0    # Breite des freien Wegs durch die Gasse
ENTRY = 1.8   # so weit reicht er in den Hof (dort endet der Fußweg)

def court_core(parent: str, x0: float, x1: float, z0: float, z1: float) -> None:
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    # Pflanzinsel in der Mitte; rundherum bleibt ein 3 m breiter Weg (Gasse zu Gasse, Streife).
    half_x = min(6.0, (x1 - x0) / 2 - ENTRY - 2.2)
    half_z = min(6.0, (z1 - z0) / 2 - 3.0)
    if min(half_x, half_z) >= 1.2:
        ground(parent, cx - half_x, cx + half_x, cz - half_z, cz + half_z, (0.14, 0.18, 0.16, 1), height=0.45)
        prop(parent, "tree", cx, cz, 0.0, y=0.45)
        # Sitzbänke auf der Kante der Insel, Blick nach außen.
        for (bx, bz, yaw) in ((cx, cz - half_z + 0.4, 180.0), (cx, cz + half_z - 0.4, 0.0)):
            if half_x >= 1.6:
                prop(parent, "bench", bx + half_x * 0.5, bz, yaw, y=0.45)


def court_harbor(parent: str, x0: float, x1: float, z0: float, z1: float) -> None:
    colors = [(0.6, 0.18, 0.12, 1), (0.12, 0.32, 0.5, 1), (0.55, 0.45, 0.12, 1), (0.2, 0.4, 0.25, 1)]
    # Containerreihen mit 4 m breiten Gängen dazwischen.
    z = z0 + 4.0
    while z + 2.6 < z1 - 4.0:
        x = x0 + 4.0
        while x + 6.2 < x1 - 4.0:
            if rnd.random() < 0.8:
                h = 2.6 * rnd.choice([1, 1, 2])
                box_prop(parent, x + 3.1, z + 1.3, 6.2, 2.6, h, rnd.choice(colors))
            x += 7.0
        z += 6.6
    for _ in range(3):
        prop(parent, rnd.choice(["van", "pickup"]), rnd.uniform(x0 + 6, x1 - 6), rnd.uniform(z0 + 6, z1 - 6), rnd.choice([0.0, 90.0]))
    for _ in range(6):
        prop(parent, rnd.choice(["pallet", "cone"]), rnd.uniform(x0 + 2, x1 - 2), rnd.uniform(z0 + 2, z1 - 2), rnd.uniform(0, 360))


def court_blocks(parent: str, x0: float, x1: float, z0: float, z1: float) -> None:
    cx = (x0 + x1) / 2
    # Westhälfte Park, Osthälfte Parkplatz.
    # Rund um den Park bleibt ein Weg frei (von der Westgasse zum Parkplatz).
    px0 = x0 + ENTRY + 2.0
    ground(parent, px0, cx - 1, z0 + 3, z1 - 3, (0.15, 0.24, 0.16, 1), height=0.2)
    for _ in range(7):
        prop(parent, rnd.choice(["tree", "pine"]), rnd.uniform(px0 + 2, cx - 3), rnd.uniform(z0 + 5, z1 - 5), 0.0, y=0.2)
    for _ in range(4):
        prop(parent, "bench", rnd.uniform(px0 + 2, cx - 3), rnd.uniform(z0 + 5, z1 - 5), rnd.choice([0.0, 90.0]), y=0.2)
    z = z0 + 4.0
    mz = (z0 + z1) / 2
    while z < z1 - 4.0:
        if abs(z - mz) < 3.5:
            # Vor der Ostgasse wird nicht geparkt: dort führt der Weg in den Hof.
            z += 3.2
            continue
        if rnd.random() < 0.7:
            prop(parent, rnd.choice(["car", "suv", "sports", "pickup", "van", "taxi"]), cx + 6.0, z, 90.0)
        if rnd.random() < 0.7:
            prop(parent, rnd.choice(["car", "suv", "sports", "pickup"]), x1 - 5.0, z, 90.0)
        z += 3.2


def court_neon(parent: str, x0: float, x1: float, z0: float, z1: float) -> None:
    # Nachtmarkt: zwei Reihen Buden, Gang in der Mitte.
    cz = (z0 + z1) / 2
    x = x0 + 3.0
    while x + 3.0 < x1 - 2.0:
        for row, facing in ((cz - 5.5, "S"), (cz + 5.5, "N")):
            if free(x, x + 3.0, row - 1.2, row + 1.2):
                claim(x, x + 3.0, row - 1.2, row + 1.2, "solid", "Bude")
                node(uname("Stall"), parent, "k_stall", x + 1.5, SIDEWALK_Y, row, FACING[facing], accent=rnd.randint(0, 5),
                     cloth=rnd.choice([(0.55, 0.15, 0.25, 1), (0.12, 0.3, 0.45, 1), (0.5, 0.4, 0.1, 1), (0.25, 0.12, 0.4, 1)]),
                     seed_value=rnd.randint(1, 9999))
        x += 4.0
    for _ in range(5):
        prop(parent, rnd.choice(["bag", "cone", "trash"]), rnd.uniform(x0 + 2, x1 - 2), rnd.uniform(z0 + 2, cz - 8), rnd.uniform(0, 360))


def court_under(parent: str, x0: float, x1: float, z0: float, z1: float) -> None:
    # Hütten in losen Reihen, dazwischen Wege.
    z = z0 + 3.0
    while z + 5.0 < z1 - 3.0:
        x = x0 + 3.0
        while x + 5.0 < x1 - 3.0:
            w, d = rnd.uniform(3.5, 5.0), rnd.uniform(3.5, 5.0)
            if rnd.random() < 0.75 and free(x, x + w, z, z + d):
                tower(parent, x + w / 2, z + d / 2, rnd.choice("NSEW"), w, d, rnd.randint(1, 2), "under",
                      floor_height=2.8, shop_front=rnd.random() < 0.4, lit_ratio=0.5)
            x += w + 3.0
        z += 8.0
    for _ in range(6):
        prop(parent, rnd.choice(["bag", "trash", "pallet"]), rnd.uniform(x0 + 1, x1 - 1), rnd.uniform(z0 + 1, z1 - 1), rnd.uniform(0, 360))


COURT = {"core": court_core, "harbor": court_harbor, "blocks": court_blocks, "neon": court_neon, "under": court_under}


# --- Platz an der Hauptkreuzung mit Skywalk-Treppe ----------------------------------------
SKY_R = 19.0  # Mitte der Skywalk-Bahnen von der Kreuzungsmitte
SKY_W = 3.0


def plaza(parent: str, x0: float, x1: float, z0: float, z1: float, bi: int, bj: int) -> None:
    sx = 1.0 if bi == 2 else -1.0
    sz = 1.0 if bj == 2 else -1.0
    # Treppe vom Platz hoch zur Ecke des Rings, läuft auf die Kreuzung zu (Richtung -sz).
    run = 35 * 0.3 + 2.0
    start_z = sz * (SKY_R + SKY_W / 2 + run)
    claim(sx * SKY_R - 1.25, sx * SKY_R + 1.25, sz * (SKY_R + SKY_W / 2), start_z, "solid", "Skywalk-Treppe")
    node(uname("Stairs"), parent, "k_stairs", sx * SKY_R, 0.0, start_z, 0.0 if sz < 0 else 180.0,
         height=SKY_Y, base=SIDEWALK_Y, width=2.4, landing=2.0, accent=1)
    for _ in range(4):
        prop(parent, "bench", rnd.uniform(x0 + 3, x1 - 3), rnd.uniform(z0 + 3, z1 - 3), rnd.choice([0.0, 90.0]))


for bi in range(4):
    for bj in range(4):
        block(bi, bj)

# Skywalk-Ring über der Hauptkreuzung: vier Bahnen, vier Eckpodeste.
P_SKY = group("Skywalk")
inner = SKY_R - SKY_W / 2
for (x, z, yaw) in ((0.0, -SKY_R, 90.0), (0.0, SKY_R, 90.0), (-SKY_R, 0.0, 0.0), (SKY_R, 0.0, 0.0)):
    main_w = road_dims(0.0)[0] / 2 + 0.5
    node(uname("Walk"), P_SKY, "k_skywalk", x, 0.0, z, yaw, length=2 * inner, width=SKY_W, height=SKY_Y,
         pillar_spacing=8.0, pillar_gap=(-ext(0.0) - 0.5, ext(0.0) + 0.5), accent=1)
for sx in (-1.0, 1.0):
    for sz in (-1.0, 1.0):
        # Podest: Bahn in z-Richtung kommt von innen (−sz), Bahn in x-Richtung von innen (−sx), Treppe von außen (+sz).
        node(uname("Landing"), P_SKY, "k_skywalk", sx * SKY_R, 0.0, sz * SKY_R, 0.0, length=SKY_W, width=SKY_W,
             height=SKY_Y, pillar_spacing=0.0, rail_left=sx < 0, rail_right=sx > 0, accent=1)
        claim(sx * SKY_R - 0.6, sx * SKY_R + 0.6, sz * SKY_R - 0.6, sz * SKY_R + 0.6, "solid", "Podeststütze")
        node(uname("Pillar"), P_SKY, "k_ground", sx * SKY_R, 0.0, sz * SKY_R, 0.0, size=(1.2, 1.2), height=SKY_Y - 0.35,
             color=(0.2, 0.21, 0.24, 1))


# =====================================================================================
# Gehweg-Möbel an allen Straßen
# =====================================================================================
P_FURN = group("StreetProps")
# Nur schmale Dinge an den Bordstein: der Fußweg in der Gehwegmitte bleibt frei.
STREET_KINDS = ["bench", "trash", "trash", "hydrant", "mailbox", "planter", "powerbox"]
for lx in LINES:
    for j in range(4):
        za, zb = LINES[j] + ext(LINES[j]), LINES[j + 1] - ext(LINES[j + 1])
        w, s, _ = road_dims(lx)
        for side in (-1, 1):
            x = lx + side * (w / 2 + 0.9)
            z = za + rnd.uniform(4, 9)
            while z < zb - 4:
                kind = rnd.choice(STREET_KINDS)
                prop(P_FURN, kind, x, z, 0.0)
                z += rnd.uniform(8, 16)
for lz in LINES:
    for i in range(4):
        xa, xb = LINES[i] + ext(LINES[i]), LINES[i + 1] - ext(LINES[i + 1])
        w, s, _ = road_dims(lz)
        for side in (-1, 1):
            z = lz + side * (w / 2 + 0.9)
            x = xa + rnd.uniform(4, 9)
            while x < xb - 4:
                kind = rnd.choice(STREET_KINDS)
                prop(P_FURN, kind, x, z, 90.0)
                x += rnd.uniform(8, 16)


# =====================================================================================
# Stadtrand: geschlossener Ring aus Hochhäusern hinter der Ringstraße
# =====================================================================================
P_EDGE = group("Edge")
RING_IN = LINES[-1] + ext(LINES[-1])  # 152,5: Gehwegkante außen an der Ringstraße
EDGE_D = 20.0
STYLE["edge"] = dict(STYLE["core"], lot=(14, 22), floors=(16, 34), shop=0.5)


def edge_row(side: str, a0: float, a1: float, edge: float) -> None:
    # Gleiche Bauweise wie der Kern, aber geschlossen (keine Lücken, dahinter ist niemand).
    saved = STYLE["core"]
    STYLE["core"] = STYLE["edge"]
    frontage(P_EDGE, "core", side, a0, a1, edge, EDGE_D, closed=True)
    STYLE["core"] = saved


edge_row("S", -RING_IN, RING_IN, -RING_IN)   # Nordrand: Front nach Süden zur Ringstraße
edge_row("N", -RING_IN, RING_IN, RING_IN)    # Südrand
edge_row("E", -RING_IN, RING_IN, -RING_IN)   # Westrand
edge_row("W", -RING_IN, RING_IN, RING_IN)    # Ostrand
for sx in (-1, 1):
    for sz in (-1, 1):
        cx, cz = sx * (RING_IN + EDGE_D / 2), sz * (RING_IN + EDGE_D / 2)
        tower(P_EDGE, cx, cz, "S" if sz < 0 else "N", EDGE_D, EDGE_D, rnd.randint(30, 45), "core",
              facade=FACADE["bands"], setbacks=2, corner_neon=True, roof_billboard=True, lit_ratio=0.55)
# Skyline außerhalb (nur Silhouette, nicht erreichbar).
P_SKYLINE = group("Skyline")
pos = -EDGE - 30
while pos < EDGE + 30:
    for (fx, fz, facing) in ((pos, -EDGE - 25, "S"), (pos, EDGE + 25, "N"), (-EDGE - 25, pos, "E"), (EDGE + 25, pos, "W")):
        if rnd.random() < 0.8:
            w = rnd.uniform(14, 24)
            node(uname("Far"), P_SKYLINE, "k_tower", fx, 0.0, fz, FACING[facing], district="core",
                 footprint=(w, rnd.uniform(14, 22)), floors=rnd.randint(25, 55), facade=1, setbacks=rnd.randint(0, 2),
                 lit_ratio=0.5, accent=rnd.randint(0, 5), corner_neon=rnd.random() < 0.3,
                 roof_billboard=rnd.random() < 0.3, seed_value=rnd.randint(1, 99999))
    pos += 26.0


# =====================================================================================
# Details aus den Packs: Fassaden, Dächer, Straßen, Höfe (NeonDressing, MultiMesh)
# =====================================================================================
# Eigener Zufall, damit die Lage von Häusern, Fußwegen und Gegnern davon unberührt bleibt.
drnd = random.Random(4096)
P_DRESS = group("Details")
QD = "res://assets/buildings/quaternius_downtown_city/"
KR = "res://assets/buildings/kenney_retro_urban/"
CP = "res://assets/props/city_pack/"
# Art: Modell, gemessene Hülle (x, y, z in Modelleinheiten), Meter pro Einheit, yaw_fix, Kollision,
# Sichtweite, Schatten, Kollisionsbox (Meter) und ihr Versatz (nur wo die Hülle nicht passt).
DRESS = {
    "ac": (QD + "Prop_ACUnit.gltf", (0.89, 0.6, 0.35), 1.0, 0.0, False, 90.0, False),
    "acbig": (CP + "Air conditioner.glb", (87.8, 138.11, 210.46), 1.25 / 210.46, -90.0, True, 130.0, False),
    # Balkon: Betonplatte mit Geländer (Downtown-Pflanzkasten, in der Tiefe auf 1,1 m gestaucht).
    "balcony": (QD + "Sidewalk_Planter.gltf", (1.97, 0.51, 1.77), 1.15, 0.0, False, 150.0, False),
    "shopwin": (QD + "Metal_Window_Half.gltf", (2.0, 3.0, 0.23), 1.0, 0.0, False, 110.0, False),
    "brickwin": (QD + "Brick_Window_Trim_Single.gltf", (2.0, 3.0, 0.28), 1.0, 0.0, False, 110.0, False),
    "brickdouble": (QD + "Brick_Window_Square_Single.gltf", (2.0, 3.0, 0.28), 1.0, 0.0, False, 110.0, False),
    "lamp2": (KR + "detail-light-double.glb", (0.09, 0.96, 0.44), 1.1, 180.0, False, 80.0, False),
    "fireexit": (CP + "Fire Exit.glb", (2.29, 1.65, 0.46), 0.0, 0.0, False, 150.0, False),
    "sign": ("res://assets/props/cyberpunk_sign/vertical_cyberpunk_sign.fbx", (0.85, 2.06, 0.09), 2.3, 0.0, False, 130.0, False),
    "plazaboard": (CP + "Billboard.glb", (242.06, 670.0, 600.0), 6.0 / 600.0, 90.0, True, 220.0, True, (0.6, 6.7, 0.6)),
    "poster": (CP + "Rock band poster.glb", (9.96, 14.91, 0.08), 0.12, 180.0, False, 70.0, False),
    "walllamp": (KR + "detail-light-single.glb", (0.09, 0.96, 0.26), 1.1, 180.0, False, 80.0, False),
    "awning": (KR + "detail-awning-wide.glb", (1.0, 0.28, 0.3), 2.6, 0.0, False, 110.0, False),
    "door": (KR + "door-type-a.glb", (0.4, 0.63, 0.05), 3.5, 0.0, False, 80.0, False),
    "cable": (KR + "detail-cables-type-a.glb", (1.0, 0.14, 0.0), 1.0, 0.0, False, 130.0, False),
    "cable2": (KR + "detail-cables-type-b.glb", (1.0, 0.14, 0.0), 1.0, 0.0, False, 130.0, False),
    "traffic": (CP + "Traffic Light.glb", (5.34, 4.66, 1.92), 1.2, 0.0, True, 200.0, True),
    "bollard": (QD + "Prop_Bollard.gltf", (0.22, 0.89, 0.23), 1.0, 0.0, True, 90.0, False),
    "planter": (QD + "Prop_Planter_Single.gltf", (2.0, 0.6, 2.0), 1.0, 0.0, True, 120.0, False),
    "manhole": (QD + "Prop_ManholeCover.gltf", (0.93, 0.03, 0.93), 1.0, 0.0, False, 70.0, False),
    "drain": (QD + "Prop_Drain.gltf", (0.59, 0.04, 0.59), 1.0, 0.0, False, 60.0, False),
    "arrow": (QD + "Decal_ArrowStraight.gltf", (0.94, 0.0, 2.37), 1.0, 0.0, False, 90.0, False),
    "papers": (CP + "Debris Papers.glb", (1.24, 0.0, 1.05), 1.0, 0.0, False, 60.0, False),
    "roofexit": (CP + "Roof Exit.glb", (0.62, 0.64, 0.75), 4.0, 0.0, True, 260.0, False),
    "antenna": (KR + "roof-metal-poles.glb", (1.0, 0.7, 1.0), 2.4, 0.0, False, 220.0, False),
    "billboard": (CP + "Billboard.glb", (242.06, 670.0, 600.0), 7.0 / 600.0, 90.0, False, 260.0, True),
    "washline": (CP + "Washing Line.glb", (1.43, 2.29, 1.81), 1.0, 0.0, True, 90.0, False, (0.2, 2.3, 0.2)),
    "motorbike": (CP + "Motorcycle.glb", (42.86, 67.18, 127.49), 2.1 / 127.49, 0.0, True, 110.0, False),
    "bicycle": (CP + "Bicycle.glb", (3.61, 2.11, 1.24), 1.75 / 3.61, 0.0, True, 90.0, False),
    "barrier": (KR + "detail-barrier-strong-type-a.glb", (0.66, 0.33, 0.25), 3.0, 0.0, True, 110.0, False),
    "truck": (KR + "truck-grey.glb", (0.83, 1.01, 1.64), 4.2, 0.0, True, 180.0, True),
    "trailer": (KR + "truck-green-cargo.glb", (0.83, 0.74, 1.17), 4.6, 0.0, True, 180.0, True),
    "planks": (KR + "planks.glb", (1.13, 0.1, 0.57), 2.0, 0.0, False, 70.0, False),
    "bricks": (KR + "detail-bricks-type-a.glb", (0.57, 0.2, 0.53), 2.0, 0.0, False, 70.0, False),
    "box": (CP + "Box.glb", (0.2, 0.18, 0.2), 3.2, 0.0, True, 80.0, False),
}
# Leuchtschild in fünf Neonfarben (gleiches Modell, eigene Knoten je Farbe).
SIGN_TINTS = [(1.0, 0.15, 0.6), (0.0, 0.9, 1.0), (0.65, 0.3, 1.0), (1.0, 0.75, 0.15), (0.95, 0.95, 1.0)]
for _k, _c in enumerate(SIGN_TINTS):
    DRESS[f"sign{_k}"] = DRESS["sign"]
# Feuertreppe: ein Stück pro Stockwerk (Höhe = Stockwerkshöhe), Maßstab hängt vom Haus ab.
FIRE_H = 1.65
dress_items: dict[tuple[str, int, int, float], list[float]] = {}
CHUNK = 60.0


def dsize(kind: str, scale: float = 0.0) -> tuple[float, float, float]:
    """(Breite, Höhe, Tiefe) in Metern nach Skalierung und yaw_fix (Vorderseite +Z)."""
    _, (sx, sy, sz), s, fix = DRESS[kind][:4]
    s = scale or s
    if abs(abs(fix) % 180 - 90) < 1:
        sx, sz = sz, sx
    return sx * s, sy * s, sz * s


def dress(kind: str, x: float, y: float, z: float, yaw: float, sx: float = 1.0, sy: float = 1.0, sz: float = 1.0,
          scale: float = 0.0) -> None:
    ci, cj = int((x + EDGE + 60) // CHUNK), int((z + EDGE + 60) // CHUNK)
    dress_items.setdefault((kind, ci, cj, scale or DRESS[kind][2]), []).extend(
        [round(x, 3), round(y, 3), round(z, 3), round(yaw % 360.0, 2), round(sx, 3), round(sy, 3), round(sz, 3)])


def dress_ground(kind: str, x: float, z: float, yaw: float, y: float = SIDEWALK_Y, margin: float = 0.0,
                 keep_only: bool = False) -> bool:
    """Ding mit Kollision am Boden: nur auf freier Fläche, mit `margin` Abstand zu allem Festen
    (keep_only: nur zu freizuhaltenden Wegen, für Dinge direkt an einer Hauswand)."""
    w, _, d = dsize(kind)
    if len(DRESS[kind]) > 7:
        w, _, d = DRESS[kind][7]
    r = rect_of(x, z, w, d, yaw)
    if not free(*r):
        return False
    if margin > 0:
        m = (r[0] - margin, r[1] + margin, r[2] - margin, r[3] + margin)
        if keep_only:
            if any(k == "keep" and m[0] < a1 and m[1] > a0 and m[2] < b1 and m[3] > b0 for (a0, a1, b0, b1, k, _) in claims):
                return False
        elif not free(*m):
            return False
    if max(abs(r[0]), abs(r[1]), abs(r[2]), abs(r[3])) > RING_IN - 0.5:
        return False
    claim(*r, "solid", f"Detail {kind} {x:.0f},{z:.0f}")
    dress(kind, x, y, z, yaw)
    return True


def to_world(t: dict, lx: float, lz: float) -> tuple[float, float]:
    a = math.radians(t["yaw"])
    return t["x"] + lx * math.cos(a) + lz * math.sin(a), t["z"] - lx * math.sin(a) + lz * math.cos(a)


def tiers(t: dict) -> tuple[float, float, float, float]:
    """(Höhe der untersten Stufe, Gesamthöhe, Breite und Tiefe des Dachs) wie NeonTower._tiers."""
    fh, floors = t["fh"], t["floors"]
    height = floors * fh
    count = t["setbacks"] + 1 if floors >= 6 else 1
    y0 = height if count == 1 else round(height * 0.55 / fh) * fh
    shrink = 1.0 - 0.3 * (count - 1)
    return y0, height, t["w"] * shrink, t["d"] * shrink


def blocked(x: float, z: float, y: float, own: dict) -> bool:
    """Punkt vor einer Wand steckt in einem anderen Haus (das höher ist) oder außerhalb der Stadt."""
    if max(abs(x), abs(z)) > RING_IN - 0.3:
        return True
    for o in TOWERS:
        if o is own:
            continue
        r = o["rect"]
        if r[0] - 0.05 < x < r[1] + 0.05 and r[2] - 0.05 < z < r[3] + 0.05 and o["floors"] * o["fh"] > y - 0.5:
            return True
    for (a0, a1, b0, b1, k, what) in claims:
        if k == "solid" and what.startswith("Laden") and a0 < x < a1 and b0 < z < b1:
            return True
    return False


def near_lamp(x: float, z: float, dist: float) -> bool:
    return any(math.hypot(x - lx, z - lz) < dist for (lx, lz) in LAMPS)


# Seiten eines Hauses: Name, Normale lokal (x, z), Länge entlang der Wand, Drehung der Wand.
SIDES = (("front", (0.0, 1.0), "w", 0.0), ("right", (1.0, 0.0), "d", 90.0),
         ("back", (0.0, -1.0), "w", 180.0), ("left", (-1.0, 0.0), "d", -90.0))


def wall(t: dict, side: tuple, along: float, y: float, out: float) -> tuple[float, float, float]:
    """Weltpunkt auf der Wand `side` bei Position `along` (lokal entlang), `out` Meter davor."""
    _, (nx, nz), key, _ = side
    half = (t["d"] if key == "w" else t["w"]) / 2
    lx, lz = nx * (half + out) - nz * along, nz * (half + out) + nx * along
    wx, wz = to_world(t, lx, lz)
    return wx, y, wz


def columns(length: float) -> list[float]:
    n = max(1, int((length - 1.0) / 2.7))
    return [-2.7 * (n - 1) / 2 + 2.7 * k for k in range(n)]


ROLE = {}  # id(Haus) -> front (Randbebauung), hut (Hütte im Hof), edge (Stadtrand)
for t in TOWERS:
    ROLE[id(t)] = "edge" if t["parent"] == P_EDGE else "hut" if t["floors"] <= 2 and t["fh"] == 2.8 else "front"

# Pro Bezirk: Balkon-Spalten, Klimageräte je Fenster, Feuertreppe je Haus, Leuchtschild, Plakat.
FACADE_P = {
    "blocks": dict(balcony=0.45, ac=0.12, fire=0.45, sign=0.2, poster=0.3),
    "neon": dict(balcony=0.15, ac=0.2, fire=0.55, sign=0.95, poster=0.6),
    "under": dict(balcony=0.2, ac=0.25, fire=0.75, sign=0.6, poster=0.6),
    "core": dict(balcony=0.0, ac=0.0, fire=0.0, sign=0.35, poster=0.25),
    "harbor": dict(balcony=0.0, ac=0.15, fire=0.3, sign=0.0, poster=0.4),
}
signs_left = 130  # das Leuchtschild ist schwer (94k Ecken): begrenzt


def facade_details(t: dict) -> None:
    global signs_left
    district, role, fh = t["district"], ROLE[id(t)], t["fh"]
    p = FACADE_P[district]
    y0, height, _, _ = tiers(t)
    top_floor = min(int(round(y0 / fh)), 14)
    grid = t["facade"] == FACADE["grid"]
    fire_side = None
    if p["fire"] and grid and top_floor >= 3 and drnd.random() < p["fire"]:
        fire_side = drnd.choice(["back", "left", "right", "front", "front"])
    for side in SIDES:
        name, _, key, face_yaw = side
        if role == "edge" and name != "front":
            continue
        length = t["w"] if key == "w" else t["d"]
        yaw = t["yaw"] + face_yaw
        cols = columns(length)
        used: set[tuple[int, int]] = set()  # (Spalte, Stockwerk) schon belegt
        start = 2 if (name == "front" and t["shop"]) else 1
        # Feuertreppe zwischen zwei Fensterspalten, ein Stück pro Stockwerk.
        if fire_side == name and len(cols) >= 2:
            k = drnd.randrange(len(cols) - 1)
            a = (cols[k] + cols[k + 1]) / 2
            scale = fh / FIRE_H
            for f in range(start, top_floor):
                x, y, z = wall(t, side, a, f * fh, dsize("fireexit", scale)[2] / 2 + 0.03)
                if blocked(*wall(t, side, a, 0, 0.8)[::2], f * fh, t) or near_lamp(x, z, 2.6):
                    break
                dress("fireexit", x, y, z, yaw, scale=scale)
                used.update({(k, f), (k + 1, f)})
        if not grid:
            continue
        # Balkone spaltenweise (alle Stockwerke einer Spalte), Klimageräte einzeln.
        for k, a in enumerate(cols):
            balcony = drnd.random() < p["balcony"]
            for f in range(start, top_floor):
                if (k, f) in used:
                    continue
                probe = wall(t, side, a, 0, 0.8)
                if blocked(probe[0], probe[2], f * fh, t):
                    continue
                if balcony and not near_lamp(probe[0], probe[2], 1.9):
                    x, y, z = wall(t, side, a, f * fh, dsize("balcony")[2] * 0.55 / 2 + 0.02)
                    dress("balcony", x, y, z, yaw, sz=0.55)
                elif drnd.random() < p["ac"]:
                    off = a + 1.35 if k < len(cols) - 1 or a + 1.9 < length / 2 else a - 1.35
                    x, y, z = wall(t, side, off, f * fh + 0.3, dsize("ac")[2] / 2 + 0.02)
                    if not near_lamp(x, z, 1.2) and abs(off) < length / 2 - 0.5:
                        dress("ac", x, y, z, yaw)
    # Leuchtschild quer zur Straße an der Hausecke vorn (Neonmeile, Unterstadt, Kern).
    for corner in (-1, 1):
        if role == "hut" or signs_left <= 0 or drnd.random() >= p["sign"] or height < 9.0:
            continue
        w, h, _ = dsize("sign")
        a = corner * (t["w"] / 2 - 1.0)
        base = drnd.choice([5.4, 6.2, 8.0]) if height > 14 else 4.8
        x, y, z = wall(t, SIDES[0], a, base, 0.15 + w / 2)
        if not blocked(*wall(t, SIDES[0], a, 0, 0.8)[::2], base + h, t) and not near_lamp(x, z, 2.2):
            dress(f"sign{drnd.randrange(len(SIGN_TINTS))}", x, y, z, t["yaw"] + 90.0)
            signs_left -= 1
    # Plakate unten an der Wand (Seiten und Rückseite; vorn nur ohne Laden, neben dem Eingang).
    for side in SIDES:
        name, _, key, _ = side
        # Hinten sitzt die Hintertür, vorn mit Laden ist kein Platz.
        if role == "edge" or name == "back" or drnd.random() >= p["poster"] or (name == "front" and t["shop"]):
            continue
        length = t["w"] if key == "w" else t["d"]
        if length < 6.0:
            continue
        a = drnd.choice([-1, 1]) * drnd.uniform(2.6, length / 2 - 1.0)
        x, y, z = wall(t, side, a, SIDEWALK_Y + 0.5, 0.06)
        if not blocked(*wall(t, side, a, 0, 0.8)[::2], 1.0, t):
            dress("poster", x, y, z, t["yaw"] + side[3])


def ground_floor(t: dict) -> None:
    """Erdgeschoss zur Straße: Schaufenster im Metallrahmen, in der Unterstadt Backstein mit Fenstern.
    Vorn bleiben Eingang (Mitte) und Laden frei; Wandlampen neben dem Eingang."""
    if ROLE[id(t)] == "hut" or t["facade"] == FACADE["industrial"] or t["fh"] < 3.2:
        return
    under = t["district"] == "under"
    for side in SIDES:
        name, _, key, face_yaw = side
        if name == "back" or (name == "front" and t["shop"]):
            continue
        length = t["w"] if key == "w" else t["d"]
        step = 2.0
        n = int((length - 0.6) // step)
        yaw = t["yaw"] + face_yaw
        for k in range(n):
            a = -n * step / 2 + step * (k + 0.5)
            if name == "front" and abs(a) < 1.6 + step / 2:
                continue
            if blocked(*wall(t, side, a, 0, 0.8)[::2], 1.0, t) or blocked(*wall(t, side, a - step / 2 + 0.2, 0, 0.8)[::2], 1.0, t)                     or blocked(*wall(t, side, a + step / 2 - 0.2, 0, 0.8)[::2], 1.0, t):
                continue
            kind = drnd.choice(["brickwin", "brickdouble"]) if under else "shopwin"
            x, y, z = wall(t, side, a, SIDEWALK_Y - 0.15, dsize(kind)[2] / 2 + 0.01)
            dress(kind, x, y, z, yaw)
    if not t["shop"]:
        for sx in (-1.0, 1.0):
            x, y, z = wall(t, SIDES[0], sx * 1.9, 2.1, dsize("lamp2")[2] / 2 + 0.02)
            if not blocked(*wall(t, SIDES[0], sx * 1.9, 0, 0.8)[::2], 1.0, t):
                dress("lamp2", x, y, z, t["yaw"])


def back_door(t: dict) -> None:
    """Hintertür zum Hof mit Lampe darüber, in der Unterstadt und Neonmeile mit Vordach."""
    if ROLE[id(t)] != "front" or t["w"] < 5.0:
        return
    side = SIDES[2]
    cols = columns(t["w"])
    gaps = [(a + b) / 2 for a, b in zip(cols, cols[1:])] or [0.0]
    a = drnd.choice(gaps)
    probe = wall(t, side, a, 0, 1.2)
    if blocked(probe[0], probe[2], 3.0, t):
        return
    yaw = t["yaw"] + 180.0
    t["door"] = a
    x, y, z = wall(t, side, a, SIDEWALK_Y, dsize("door")[2] / 2)
    dress("door", x, y, z, yaw)
    x, y, z = wall(t, side, a, 2.35, dsize("walllamp")[2] / 2 + 0.02)
    dress("walllamp", x, y, z, yaw)
    if t["district"] in ("under", "neon", "blocks"):
        x, y, z = wall(t, side, a, 2.6, dsize("awning")[2] / 2 + 0.02)
        dress("awning", x, y, z, yaw)


def roof_details(t: dict) -> None:
    """Dachaufbauten: Treppenhaus, Klimageräte, Antennen, Wäschespinne, Werbetafel."""
    _, height, rw, rd = tiers(t)
    if rw < 5.0 or rd < 5.0 or t["floors"] > 30:
        return
    taken: list[tuple[float, float, float, float]] = []

    def place(kind: str, lx: float, lz: float, yaw: float = 0.0) -> bool:
        w, _, d = dsize(kind)
        if abs(round(yaw)) % 180 == 90:
            w, d = d, w
        if abs(lx) + w / 2 > rw / 2 - 0.5 or abs(lz) + d / 2 > rd / 2 - 0.5:
            return False
        r = (lx - w / 2 - 0.3, lx + w / 2 + 0.3, lz - d / 2 - 0.3, lz + d / 2 + 0.3)
        if any(r[0] < q[1] and r[1] > q[0] and r[2] < q[3] and r[3] > q[2] for q in taken):
            return False
        taken.append(r)
        x, z = to_world(t, lx, lz)
        dress(kind, x, height, z, t["yaw"] + yaw)
        return True

    hx, hz = rw / 2 - 2.0, rd / 2 - 2.0
    if t["billboard"]:
        # NeonTower stellt die eigene Tafel vorn aufs Dach: dort bleibt es frei.
        taken.append((-rw / 2, rw / 2, rd / 2 - 3.0, rd / 2))
    if drnd.random() < 0.7:
        place("roofexit", drnd.uniform(-hx, hx), drnd.uniform(-hz, hz), drnd.choice([0.0, 90.0, 180.0, -90.0]))
    for _ in range(drnd.randint(1, 4)):
        place("acbig", drnd.uniform(-hx, hx), drnd.uniform(-hz, hz), drnd.choice([0.0, 90.0, 180.0, -90.0]))
    for _ in range(drnd.randint(0, 2)):
        place("antenna", drnd.uniform(-hx, hx), drnd.uniform(-hz, hz))
    if t["district"] in ("under", "blocks") and drnd.random() < 0.45:
        place("washline", drnd.uniform(-hx, hx), drnd.uniform(-hz, hz), drnd.uniform(0, 90))
    if (not t["billboard"] and t["district"] in ("neon", "under", "harbor") and height < 16.0
            and ROLE[id(t)] == "front" and drnd.random() < 0.35):
        place("billboard", 0.0, rd / 2 - 1.8)


def court_ground(t: dict) -> None:
    """Fahrräder, Kisten, Sperren und Laster an der Hofseite des Hauses (dicht an der Wand)."""
    if ROLE[id(t)] != "front":
        return
    side = SIDES[2]
    yaw = t["yaw"] + 180.0
    picks = {"under": ["bicycle", "box", "box", "barrier"], "neon": ["motorbike", "box", "box", "bicycle"],
             "blocks": ["bicycle", "bicycle", "motorbike"], "harbor": ["box", "barrier", "barrier", "truck", "trailer"],
             "core": []}[t["district"]]
    for _ in range(drnd.randint(0, 2) if picks else 0):
        kind = drnd.choice(picks)
        w, _, d = dsize(kind)
        # Fahrzeuge längs zur Wand, alles andere mit der Vorderseite zum Hof.
        along_wall = kind in ("bicycle", "barrier")
        turn = 90.0 if kind in ("motorbike", "truck", "trailer") else 0.0
        depth = w if turn else d
        a = drnd.uniform(-t["w"] / 2 + 1.5, t["w"] / 2 - 1.5)
        x, _, z = wall(t, side, a, 0, depth / 2 + 0.15)
        probe = wall(t, side, a, 0, depth + 0.4)
        if blocked(probe[0], probe[2], 1.0, t):
            continue
        if abs(a - t.get("door", 99.0)) > 2.0:
            dress_ground(kind, x, z, yaw + turn, margin=1.2, keep_only=True)
    for _ in range(drnd.randint(0, 2)):
        a = drnd.uniform(-t["w"] / 2 + 1.0, t["w"] / 2 - 1.0)
        x, _, z = wall(t, side, a, 0, drnd.uniform(1.0, 3.5))
        if not blocked(x, z, 1.0, t):
            dress("papers", x, SIDEWALK_Y + 0.01, z, drnd.uniform(0, 360))


for t in TOWERS:
    facade_details(t)
    ground_floor(t)
    back_door(t)
    roof_details(t)
    court_ground(t)

# Kabel quer über die Gassen (alle Bezirke außer Kern) und über die Straßen der Neonmeile und Unterstadt.
for bi in range(4):
    for bj in range(4):
        district = DISTRICT[(bi, bj)]
        if district == "core":
            continue
        _, cx0, cx1, cz0, cz1 = courts[bi * 4 + bj]
        bx0, bx1 = LINES[bi] + ext(LINES[bi]), LINES[bi + 1] - ext(LINES[bi + 1])
        mz = (cz0 + cz1) / 2
        for (g0, g1) in ((bx0 + 1.0, cx0 - 0.5), (cx1 + 0.5, bx1 - 1.0)):
            x = g0
            while x < g1:
                y = drnd.uniform(4.2, 9.0)
                za, zb = mz - 2.5, mz + 2.5
                if blocked(x, za - 0.3, 0.0, None) and blocked(x, zb + 0.3, 0.0, None):
                    sy = drnd.uniform(2.0, 4.5)
                    dress(drnd.choice(["cable", "cable2"]), x, y - 0.14 * sy, mz, -90.0, sx=zb - za, sy=sy)
                x += drnd.uniform(1.5, 3.5)


def street_cables(line: float, a0: float, a1: float, along_x: bool) -> None:
    w, s, _ = road_dims(line)
    half = w / 2 + s
    a = a0 + drnd.uniform(3, 8)
    while a < a1 - 3:
        p0 = (a, line - half - 0.3) if along_x else (line - half - 0.3, a)
        p1 = (a, line + half + 0.3) if along_x else (line + half + 0.3, a)
        top = drnd.uniform(8.0, 11.0)
        if blocked(*p0, top + 1.0, None) and blocked(*p1, top + 1.0, None) and not near_lamp((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, 3.0):
            for k in range(drnd.randint(1, 3)):
                sy = drnd.uniform(6.0, 12.0)
                mx, mz = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
                # Kabel liegt im Modell entlang x: quer über die Straße drehen.
                yaw = -90.0 if along_x else 0.0
                dress(drnd.choice(["cable", "cable2"]), mx, top - k * 0.7 - 0.14 * sy, mz, yaw, sx=2 * half, sy=sy)
        a += drnd.uniform(5, 11)


for i, lx in enumerate(LINES):
    for j in range(4):
        ds = {DISTRICT.get((i - 1, j)), DISTRICT.get((i, j))}
        if ds & {"neon", "under"}:
            street_cables(lx, LINES[j] + ext(LINES[j]), LINES[j + 1] - ext(LINES[j + 1]), False)
for j, lz in enumerate(LINES):
    for i in range(4):
        ds = {DISTRICT.get((i, j - 1)), DISTRICT.get((i, j))}
        if ds & {"neon", "under"}:
            street_cables(lz, LINES[i] + ext(LINES[i]), LINES[i + 1] - ext(LINES[i + 1]), True)

# Ampeln an jeder Kreuzung: Mast auf der Gehwegecke rechts vor der Kreuzung, Ausleger über die Spur.
TL_POLE = 1.33  # Mast liegt so weit (Modelleinheiten) rechts von der Mitte der Hülle (gemessen)


def arms(jx: float, jz: float) -> list[tuple[float, float]]:
    out = []
    for (dx, dz) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, nz = jx - dx * 72.0, jz - dz * 72.0
        if -144.0 <= nx <= 144.0 and -144.0 <= nz <= 144.0:
            out.append((dx, dz))  # Autos kommen aus Richtung -d und fahren in Richtung d
    return out


for jx in LINES:
    for jz in LINES:
        for (dx, dz) in arms(jx, jz):
            wa = road_dims(jx if dx == 0 else jz)[0]   # Breite der ankommenden Straße
            wc = road_dims(jz if dx == 0 else jx)[0]   # Breite der Querstraße
            # Rechtsverkehr wie RoadNetwork: rechts = Fahrtrichtung × oben = (−dz, dx).
            rgt = (-dz, dx)
            pole_x = jx - dx * (wc / 2 + 0.7) + rgt[0] * (wa / 2 + 0.7)
            pole_z = jz - dz * (wc / 2 + 0.7) + rgt[1] * (wa / 2 + 0.7)
            # Modell: Mast am +X-Ende, Ausleger nach −X. Lokal +X soll nach rechts zeigen.
            yaw = math.degrees(math.atan2(-rgt[1], rgt[0]))
            s = DRESS["traffic"][2]
            cx = pole_x - rgt[0] * TL_POLE * s
            cz = pole_z - rgt[1] * TL_POLE * s
            r = (pole_x - 0.2, pole_x + 0.2, pole_z - 0.2, pole_z + 0.2)
            if free(*r):
                claim(*r, "solid", f"Ampel {pole_x:.0f},{pole_z:.0f}")
                dress("traffic", cx, SIDEWALK_Y, cz, yaw)

# Straßen: Gullydeckel, Abläufe am Bordstein, Pfeile auf den Spuren vor jeder Kreuzung.
for jx in LINES:
    for jz in LINES:
        for (dx, dz) in arms(jx, jz):
            stop = max(ext(jx), ext(jz)) + 1.0
            rgt = (-dz, dx)
            yaw = math.degrees(math.atan2(dx, dz))
            back = stop + 7.0
            dress("arrow", jx - dx * back + rgt[0] * 2.6, 0.008, jz - dz * back + rgt[1] * 2.6, yaw)
for i, lx in enumerate(LINES):
    for j in range(4):
        z0, z1 = LINES[j] + ext(LINES[j]), LINES[j + 1] - ext(LINES[j + 1])
        w = road_dims(lx)[0]
        z = z0 + drnd.uniform(6, 14)
        while z < z1 - 6:
            dress("manhole", lx + drnd.choice([-1, 1]) * 2.6, -0.012, z, drnd.uniform(0, 90))
            z += drnd.uniform(14, 26)
        z = z0 + drnd.uniform(3, 8)
        while z < z1 - 3:
            dress("drain", lx + drnd.choice([-1, 1]) * (w / 2 - 0.45), -0.02, z, 0.0)
            z += drnd.uniform(9, 16)
for j, lz in enumerate(LINES):
    for i in range(4):
        x0, x1 = LINES[i] + ext(LINES[i]), LINES[i + 1] - ext(LINES[i + 1])
        w = road_dims(lz)[0]
        x = x0 + drnd.uniform(6, 14)
        while x < x1 - 6:
            dress("manhole", x, -0.012, lz + drnd.choice([-1, 1]) * 2.6, drnd.uniform(0, 90))
            x += drnd.uniform(14, 26)
        x = x0 + drnd.uniform(3, 8)
        while x < x1 - 3:
            dress("drain", x, -0.02, lz + drnd.choice([-1, 1]) * (w / 2 - 0.45), 90.0)
            x += drnd.uniform(9, 16)
# Papierfetzen auf den Gehwegen (flach, ohne Kollision).
for _ in range(500):
    lx = drnd.choice(LINES)
    w, s, _ = road_dims(lx)
    off = drnd.choice([-1, 1]) * (w / 2 + drnd.uniform(0.3, s - 0.3))
    a = drnd.uniform(-RING_IN + 2, RING_IN - 2)
    x, z = (lx + off, a) if drnd.random() < 0.5 else (a, lx + off)
    if all(not (q[0] < x < q[1] and q[2] < z < q[3]) for q in claims if q[4] == "road"):
        dress("papers", x, SIDEWALK_Y + 0.01, z, drnd.uniform(0, 360))

# Geparkte Motorräder und Fahrräder am Bordstein (längs zur Straße), nicht an den Kreuzungen.
def curb_bikes(line: float, a0: float, a1: float, along_x: bool) -> None:
    w = road_dims(line)[0]
    for side in (-1.0, 1.0):
        a = a0 + drnd.uniform(5, 12)
        while a < a1 - 5:
            kind = drnd.choice(["motorbike", "motorbike", "bicycle"])
            off = line + side * (w / 2 + 0.55)
            x, z = (a, off) if along_x else (off, a)
            # Motorrad: lange Seite im Modell entlang z; Fahrrad entlang x.
            if kind == "motorbike":
                yaw = 90.0 if along_x else 0.0
            else:
                yaw = 0.0 if along_x else 90.0
            dress_ground(kind, x, z, yaw)
            a += drnd.uniform(6, 15)


for i, lx in enumerate(LINES):
    for j in range(4):
        if {DISTRICT.get((i - 1, j)), DISTRICT.get((i, j))} & {"neon", "under", "blocks"}:
            curb_bikes(lx, LINES[j] + ext(LINES[j]), LINES[j + 1] - ext(LINES[j + 1]), False)
for j, lz in enumerate(LINES):
    for i in range(4):
        if {DISTRICT.get((i, j - 1)), DISTRICT.get((i, j))} & {"neon", "under", "blocks"}:
            curb_bikes(lz, LINES[i] + ext(LINES[i]), LINES[i + 1] - ext(LINES[i + 1]), True)

# Plätze am Skywalk: Poller an der Gehwegkante, Pflanzkübel aus dem Downtown-Kit.
for bi, bj in ((1, 1), (2, 1), (1, 2), (2, 2)):
    sx = 1.0 if bi == 2 else -1.0
    sz = 1.0 if bj == 2 else -1.0
    edge_x, edge_z = sx * ext(0.0), sz * ext(0.0)
    for k in range(1, 9):
        # Entlang beider Straßenseiten des Platzes, alle 3 m (Lücken 2,8 m), die Gehwegecke bleibt frei.
        a = sx * (ext(0.0) + k * 3.0)
        dress_ground("bollard", a, edge_z + sz * 0.35, 0.0, margin=0.0)
        a = sz * (ext(0.0) + k * 3.0)
        dress_ground("bollard", edge_x + sx * 0.35, a, 0.0, margin=0.0)
    # Werbetafel auf dem Mast an der Platzecke zur Kreuzung, Blick zur Kreuzung.
    for _ in range(20):
        px, pz = sx * drnd.uniform(ext(0.0) + 3, ext(0.0) + 9), sz * drnd.uniform(ext(0.0) + 3, ext(0.0) + 9)
        if dress_ground("plazaboard", px, pz, math.degrees(math.atan2(-px, -pz)), margin=1.5):
            break
    for _ in range(6):
        px = sx * drnd.uniform(ext(0.0) + 4, ext(0.0) + 24)
        pz = sz * drnd.uniform(ext(0.0) + 4, ext(0.0) + 24)
        # Nicht in den Hof hinein, der an die Platzecke grenzt (dort läuft die Streife um die Insel).
        if any(c[1] - 2.5 < px < c[2] + 2.5 and c[3] - 2.5 < pz < c[4] + 2.5 for c in courts):
            continue
        dress_ground("planter", px, pz, 0.0, margin=1.2)

# Höfe: Bauschutt und Wäschespinnen in der Unterstadt, Laster im Hafen.
for (district, x0, x1, z0, z1) in courts:
    mz = (z0 + z1) / 2
    if district == "under":
        for _ in range(10):
            # Flacher Schutt ohne Kollision, nur wo nichts steht.
            x, z = drnd.uniform(x0 + 1, x1 - 1), drnd.uniform(z0 + 1, z1 - 1)
            if free(x - 0.6, x + 0.6, z - 0.6, z + 0.6, strict=True):
                dress(drnd.choice(["planks", "bricks"]), x, SIDEWALK_Y, z, drnd.uniform(0, 360))
        for _ in range(4):
            dress_ground("washline", drnd.uniform(x0 + 3, x1 - 3), drnd.uniform(z0 + 3, z1 - 3), drnd.uniform(0, 90), margin=1.2)
    if district == "harbor":
        for _ in range(6):
            dress_ground(drnd.choice(["truck", "trailer", "barrier"]), drnd.uniform(x0 + 4, x1 - 4),
                         drnd.uniform(z0 + 4, z1 - 4), drnd.choice([0.0, 90.0]), margin=1.5)

# Knoten schreiben: einer pro Modell und Viertel, Exemplare relativ zur Viertelmitte.
for (kind, ci, cj, scale), vals in sorted(dress_items.items()):
    model, _, _, fix, collide, rng_, shadows = DRESS[kind][:7]
    cx, cz = ci * CHUNK - EDGE - 60 + CHUNK / 2, cj * CHUNK - EDGE - 60 + CHUNK / 2
    rel = []
    for k in range(0, len(vals), 7):
        rel += [round(vals[k] - cx, 3), vals[k + 1], round(vals[k + 2] - cz, 3)] + vals[k + 3:k + 7]
    extra = {}
    if len(DRESS[kind]) > 7:
        extra["collider_size"] = Raw("Vector3(%s, %s, %s)" % DRESS[kind][7])
    if kind.startswith("sign") and kind != "sign":
        r_, g_, b_ = SIGN_TINTS[int(kind[4:])]
        extra["emission_tint"] = (r_, g_, b_, 1.0)
    if kind == "plazaboard":
        # Mast steht nicht in der Mitte der Hülle (gemessen am Fuß des Modells).
        extra["collider_offset"] = Raw(f"Vector3({round(90 * scale, 3)}, 0, {round(-71 * scale, 3)})")
    if kind == "traffic":
        extra["collider_size"] = Raw("Vector3(0.35, 5.6, 0.35)")
        extra["collider_offset"] = Raw(f"Vector3({round(TL_POLE * scale, 3)}, 0, 0)")
    node(uname(f"D_{kind}_"), P_DRESS, "k_dress", cx, 0.0, cz, 0.0, model=model, model_scale=round(scale, 6),
         yaw_fix=fix, collide=collide, shadows=shadows, visible_range=rng_ + 45.0,
         items=Raw(f"PackedFloat32Array({', '.join(str(v) for v in rel)})"), **extra)
DRESS_COUNT = {k: 0 for k in DRESS}
for (kind, _, _, _), vals in dress_items.items():
    DRESS_COUNT[kind] += len(vals) // 7


# =====================================================================================
# Fußwege (Crowd) und Straßennetz (Verkehr)
# =====================================================================================
class Ped:
    def __init__(self) -> None:
        self.nodes: list[tuple[float, float, float]] = []
        self.wait: list[float] = []
        self.edges: dict[tuple[int, int], int] = {}

    def add(self, x: float, z: float, y: float = SIDEWALK_Y, wait: float = 0.0) -> int:
        for i, (nx, ny, nz) in enumerate(self.nodes):
            if abs(nx - x) < 0.3 and abs(nz - z) < 0.3 and abs(ny - y) < 0.3:
                return i
        self.nodes.append((round(x, 2), y, round(z, 2)))
        self.wait.append(wait)
        return len(self.nodes) - 1

    def link(self, a: int, b: int, crossing: bool = False) -> None:
        if a != b:
            self.edges[(min(a, b), max(a, b))] = 1 if crossing else 0

    def line(self, x0: float, z0: float, x1: float, z1: float, step: float) -> list[int]:
        n = max(1, int(math.hypot(x1 - x0, z1 - z0) / step))
        ids = [self.add(x0 + (x1 - x0) * k / n, z0 + (z1 - z0) * k / n) for k in range(n + 1)]
        for a, b in zip(ids, ids[1:]):
            self.link(a, b)
        return ids


ped = Ped()
for i, lx in enumerate(LINES):
    for j, lz in enumerate(LINES):
        wv, sv, _ = road_dims(lx)
        wh, sh, _ = road_dims(lz)
        ox, oz = wv / 2 + sv / 2, wh / 2 + sh / 2
        c = {(dx, dz): ped.add(lx + dx * ox, lz + dz * oz) for dx in (-1, 1) for dz in (-1, 1)}
        # Über die Fahrbahn nur, wo ein Arm ist; sonst ist es ein Gehweg.
        ped.link(c[(-1, -1)], c[(1, -1)], crossing=j > 0)
        ped.link(c[(-1, 1)], c[(1, 1)], crossing=j < 4)
        ped.link(c[(-1, -1)], c[(-1, 1)], crossing=i > 0)
        ped.link(c[(1, -1)], c[(1, 1)], crossing=i < 4)
for lx in LINES:
    for j in range(4):
        wv, sv, _ = road_dims(lx)
        za, zb = LINES[j] + road_dims(LINES[j])[0] / 2 + road_dims(LINES[j])[1] / 2, \
            LINES[j + 1] - road_dims(LINES[j + 1])[0] / 2 - road_dims(LINES[j + 1])[1] / 2
        for dx in (-1, 1):
            ped.line(lx + dx * (wv / 2 + sv / 2), za, lx + dx * (wv / 2 + sv / 2), zb, 12.0)
for lz in LINES:
    for i in range(4):
        wh, sh, _ = road_dims(lz)
        xa, xb = LINES[i] + road_dims(LINES[i])[0] / 2 + road_dims(LINES[i])[1] / 2, \
            LINES[i + 1] - road_dims(LINES[i + 1])[0] / 2 - road_dims(LINES[i + 1])[1] / 2
        for dz in (-1, 1):
            ped.line(xa, lz + dz * (wh / 2 + sh / 2), xb, lz + dz * (wh / 2 + sh / 2), 12.0)
# Abstecher durch die Gasse in jeden Hof.
for bi in range(4):
    for bj in range(4):
        bx0, bx1 = LINES[bi] + ext(LINES[bi]), LINES[bi + 1] - ext(LINES[bi + 1])
        district, x0, x1, z0, z1 = courts[bi * 4 + bj]
        mz = (z0 + z1) / 2
        for walk_x, inside in ((bx0 - road_dims(LINES[bi])[1] / 2, x0 + 1.0), (bx1 + road_dims(LINES[bi + 1])[1] / 2, x1 - 1.0)):
            # Vom Gehweg-Knoten auf Höhe der Gasse durch die Gasse in den Hof.
            start = min(range(len(ped.nodes)), key=lambda k: abs(ped.nodes[k][0] - walk_x) * 10 + abs(ped.nodes[k][2] - mz))
            mouth = ped.add(walk_x, mz)
            ped.link(start, mouth)
            ped.link(mouth, ped.add(inside, mz, SIDEWALK_Y, 5.0))


# =====================================================================================
# Wegplaner: Raster über alle festen Flächen, A* durch Höfe und Plätze
# =====================================================================================
CELL = 0.5
GRID_N = int(2 * EDGE / CELL)


def build_grid(clear: float) -> list[bytearray]:
    """1 = begehbar mit `clear` m Abstand zu Häusern, Props, Fahrbahn und erhöhten Platten."""
    g = [bytearray(b"\x01" * GRID_N) for _ in range(GRID_N)]
    for (a0, a1, b0, b1, k, _) in claims:
        if k not in ("solid", "road", "raised"):
            continue
        i0, i1 = max(0, int((a0 - clear + EDGE) / CELL)), min(GRID_N - 1, int((a1 + clear + EDGE) / CELL))
        j0, j1 = max(0, int((b0 - clear + EDGE) / CELL)), min(GRID_N - 1, int((b1 + clear + EDGE) / CELL))
        for i in range(i0, i1 + 1):
            row = g[i]
            for j in range(j0, j1 + 1):
                row[j] = 0
    return g


GRIDS = {c: build_grid(c) for c in (0.6, 1.0)}


def cell(x: float, z: float) -> tuple[int, int]:
    return int((x + EDGE) / CELL), int((z + EDGE) / CELL)


def walkable(x: float, z: float, clear: float = 0.6) -> bool:
    i, j = cell(x, z)
    return 0 <= i < GRID_N and 0 <= j < GRID_N and GRIDS[clear][i][j] == 1


def sight(a: tuple[float, float], b: tuple[float, float], clear: float) -> bool:
    n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / (CELL * 0.4)))
    return all(walkable(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n, clear) for k in range(n + 1))


def plan(a: tuple[float, float], b: tuple[float, float], box: tuple[float, float, float, float],
         clear: float = 0.6) -> list[tuple[float, float]] | None:
    """Weg von a nach b, nur innerhalb von box (x0, x1, z0, z1), geglättet zu Eckpunkten."""
    import heapq
    g = GRIDS[clear]
    i0, j0 = cell(box[0], box[2])
    i1, j1 = cell(box[1], box[3])
    sa, sb = cell(*a), cell(*b)
    if not (walkable(*a, clear) and walkable(*b, clear)):
        return None
    openq = [(0.0, sa)]
    cost = {sa: 0.0}
    came: dict = {}
    while openq:
        _, cur = heapq.heappop(openq)
        if cur == sb:
            break
        ci, cj = cur
        for di, dj, w in ((1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0),
                          (1, 1, 1.414), (1, -1, 1.414), (-1, 1, 1.414), (-1, -1, 1.414)):
            ni, nj = ci + di, cj + dj
            if not (i0 <= ni <= i1 and j0 <= nj <= j1) or g[ni][nj] == 0:
                continue
            if di and dj and (g[ci + di][cj] == 0 or g[ci][cj + dj] == 0):
                continue
            nc = cost[cur] + w
            if nc < cost.get((ni, nj), 1e18):
                cost[(ni, nj)] = nc
                came[(ni, nj)] = cur
                heapq.heappush(openq, (nc + math.hypot(sb[0] - ni, sb[1] - nj), (ni, nj)))
    if sb not in cost:
        return None
    cells = [sb]
    while cells[-1] != sa:
        cells.append(came[cells[-1]])
    pts = [a] + [((ci + 0.5) * CELL - EDGE, (cj + 0.5) * CELL - EDGE) for (ci, cj) in reversed(cells[1:-1])] + [b]
    # Glätten: von jedem Eckpunkt so weit wie möglich geradeaus.
    out = [pts[0]]
    k = 0
    while k < len(pts) - 1:
        m = len(pts) - 1
        while m > k + 1 and not sight(pts[k], pts[m], clear):
            m -= 1
        out.append(pts[m])
        k = m
    return [(round(x, 2), round(z, 2)) for (x, z) in out]


def free_spot(box: tuple[float, float, float, float], clear: float = 1.0, avoid=(), gap: float = 4.0):
    for _ in range(400):
        x, z = rnd.uniform(box[0] + 1, box[1] - 1), rnd.uniform(box[2] + 1, box[3] - 1)
        if walkable(x, z, clear) and all(math.hypot(x - ax, z - az) > gap for (ax, az) in avoid):
            return round(x, 2), round(z, 2)
    return None


def entry(x: float, z: float, dx: float) -> tuple[float, float]:
    """Erster begehbarer Punkt vom Gassenende aus in den Hof hinein (Richtung dx)."""
    for k in range(13):
        if walkable(x + dx * k * 0.25, z):
            return round(x + dx * k * 0.25, 2), z
    raise SystemExit(f"Gassenende bei {x:.1f},{z:.1f} zugestellt")


# Fußgänger: durch jeden Hof von Gasse zu Gasse, dazu ein Platz zum Stehenbleiben.
court_walks = 0
for bi in range(4):
    for bj in range(4):
        district, x0, x1, z0, z1 = courts[bi * 4 + bj]
        mz = (z0 + z1) / 2
        box = (x0, x1, z0, z1)
        west, east = entry(x0 + 1.0, mz, 1.0), entry(x1 - 1.0, mz, -1.0)
        ped.link(ped.add(x0 + 1.0, mz), ped.add(*west))
        ped.link(ped.add(x1 - 1.0, mz), ped.add(*east))
        route = plan(west, east, box)
        if route:
            ids = [ped.add(x, z) for (x, z) in route]
            for a_, b_ in zip(ids, ids[1:]):
                ped.link(a_, b_)
            court_walks += 1
        spot = free_spot(box, 0.6, avoid=[west, east])
        if spot:
            leg = plan(west, spot, box)
            if leg:
                ids = [ped.add(x, z) for (x, z) in leg[:-1]] + [ped.add(*leg[-1], SIDEWALK_Y, 6.0)]
                for a_, b_ in zip(ids, ids[1:]):
                    ped.link(a_, b_)

JUNCTIONS = [(lx, lz) for lz in LINES for lx in LINES]
ROADS = []
for j in range(5):
    for i in range(5):
        k = j * 5 + i
        if i < 4:
            ROADS.append((k, k + 1))
        if j < 4:
            ROADS.append((k, k + 5))


def life_scene() -> str:
    j_pts = ", ".join(f"{x}, 0, {z}" for (x, z) in JUNCTIONS)
    j_stop = ", ".join(str(max(ext(x), ext(z)) + 1.0) for (x, z) in JUNCTIONS)
    j_cross = ", ".join("1" for _ in JUNCTIONS)
    r_edges = ", ".join(f"{a}, {b}" for (a, b) in ROADS)
    p_pts = ", ".join(f"{x}, {y}, {z}" for (x, y, z) in ped.nodes)
    p_wait = ", ".join(str(w) for w in ped.wait)
    keys = sorted(ped.edges)
    p_edges = ", ".join(f"{a}, {b}" for (a, b) in keys)
    p_cross = ", ".join(str(ped.edges[k]) for k in keys)
    return f"""[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/traffic/traffic_director.gd" id="1_traffic"]
[ext_resource type="Script" path="res://scenes/civilians/crowd_director.gd" id="2_crowd"]

[node name="NeonCityLife" type="Node3D"]

[node name="Traffic" type="Node3D" parent="."]
script = ExtResource("1_traffic")
junctions = PackedVector3Array({j_pts})
junction_stop = PackedFloat32Array({j_stop})
junction_crosswalk = PackedInt32Array({j_cross})
roads = PackedInt32Array({r_edges})
lane_offset = 2.6
car_count = 28

[node name="Crowd" type="Node3D" parent="."]
script = ExtResource("2_crowd")
nodes = PackedVector3Array({p_pts})
node_wait = PackedFloat32Array({p_wait})
edges = PackedInt32Array({p_edges})
edge_crossing = PackedInt32Array({p_cross})
count = 70
"""


# =====================================================================================
# Gegner: Gangs in Unterstadt und Hafen, Türsteher in der Neonmeile, Sicherheitsdienst im Kern.
# Keine Scharfschützen. Streifen bleiben in Höfen und auf Plätzen, nie auf einer Fahrbahn: jede
# Teilstrecke ist eine gerade, freie Linie aus dem Wegplaner.
# =====================================================================================
routes: list[tuple[str, list[tuple[float, float, float]]]] = []  # Name, Punkte (x, z, Wartezeit)
enemies: list[dict] = []


def patrol(name: str, box: tuple[float, float, float, float], stops: int) -> str | None:
    pts: list[tuple[float, float]] = []
    for _ in range(stops):
        spot = free_spot(box, 1.0, avoid=pts, gap=6.0)
        if spot:
            pts.append(spot)
    if len(pts) < 2:
        return None
    marks: list[tuple[float, float, float]] = []
    for a, b in zip(pts, pts[1:] + pts[:1]):
        leg = plan(a, b, box, 1.0)
        if leg is None:
            return None
        marks.append((a[0], a[1], 3.0))
        marks += [(x, z, 0.0) for (x, z) in leg[1:-1]]
    routes.append((name, marks))
    return name


def enemy(name: str, profile: str, x: float, z: float, yaw: float = 0.0, route: str | None = None, start: int = 0) -> None:
    enemies.append(dict(name=name, profile=profile, x=x, z=z, yaw=yaw, route=route, start=start,
                        seed=rnd.randint(1, 99999)))


def route_start(route: str, k: int) -> tuple[float, float, int]:
    marks = dict(routes)[route]
    stops = [i for i, m in enumerate(marks) if m[2] > 0.0]
    i = stops[k % len(stops)]
    return marks[i][0], marks[i][1], i


def plaza_box(bi: int, bj: int) -> tuple[float, float, float, float]:
    x0, x1 = LINES[bi] + ext(LINES[bi]), LINES[bi + 1] - ext(LINES[bi + 1])
    z0, z1 = LINES[bj] + ext(LINES[bj]), LINES[bj + 1] - ext(LINES[bj + 1])
    cx = x1 if bi == 1 else x0
    cz = z1 if bj == 1 else z0
    return (min(cx, cx - 26 if bi == 1 else cx + 26), max(cx, cx - 26 if bi == 1 else cx + 26),
            min(cz, cz - 26 if bj == 1 else cz + 26), max(cz, cz - 26 if bj == 1 else cz + 26))


GANG = {"under": ["p_gm", "p_gp"], "harbor": ["p_gp", "p_gm"]}
for bi in range(4):
    for bj in range(4):
        district, x0, x1, z0, z1 = courts[bi * 4 + bj]
        box = (x0, x1, z0, z1)
        tag = f"{bi}{bj}"
        if district in ("under", "harbor"):
            r = patrol(f"R_Gang{tag}", box, 4)
            if r:
                for k, prof in enumerate(GANG[district]):
                    x, z, i = route_start(r, k * 2)
                    enemy(f"Gang{tag}_{k}", prof, x, z, route=r, start=i)
            if district == "under" or bi % 2 == 0:
                spot = free_spot(box, 1.0)
                if spot:
                    enemy(f"Gang{tag}_Wache", "p_smg", *spot, yaw=round(rnd.uniform(0, 360)))
        elif district == "core":
            r = patrol(f"R_Kern{tag}", box, 4)
            if r:
                for k in range(2):
                    x, z, i = route_start(r, k * 2)
                    enemy(f"Kern{tag}_{k}", "p_sec", x, z, route=r, start=i)
        elif district == "neon":
            # Türsteher an beiden Gassen neben dem freien Weg, Blick zur Straße.
            mz = (z0 + z1) / 2
            bx0, bx1 = LINES[bi] + ext(LINES[bi]), LINES[bi + 1] - ext(LINES[bi + 1])
            for side, x, yaw in (("W", bx0 + 1.5, 90.0), ("E", bx1 - 1.5, -90.0)):
                z = mz + 2.0
                if not free(x - 0.35, x + 0.35, z - 0.35, z + 0.35):
                    raise SystemExit(f"Türsteher {tag}{side} steht im Weg")
                claim(x - 0.35, x + 0.35, z - 0.35, z + 0.35, "solid", f"Türsteher {tag}{side}")
                enemy(f"Tuer{tag}_{side}", "p_sec", round(x, 2), round(z, 2), yaw=yaw)
# Plätze an der Hauptkreuzung: je ein Sicherheitsmann.
for (bi, bj) in ((1, 1), (2, 1), (1, 2), (2, 2)):
    r = patrol(f"R_Platz{bi}{bj}", plaza_box(bi, bj), 3)
    if r:
        x, z, i = route_start(r, 0)
        enemy(f"Platz{bi}{bj}", "p_sec", x, z, route=r, start=i)


def enemies_scene() -> str:
    out = [f"""[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/enemies/enemy_director.gd" id="1_director"]
[ext_resource type="Script" path="res://scenes/enemies/patrol_route.gd" id="2_route"]
[ext_resource type="PackedScene" path="res://scenes/enemies/enemy.tscn" id="3_enemy"]
[ext_resource type="Resource" path="res://scenes/enemies/profiles/gangster_melee.tres" id="p_gm"]
[ext_resource type="Resource" path="res://scenes/enemies/profiles/gangster_pistol.tres" id="p_gp"]
[ext_resource type="Resource" path="res://scenes/enemies/profiles/gangster_smg.tres" id="p_smg"]
[ext_resource type="Resource" path="res://scenes/enemies/profiles/security.tres" id="p_sec"]

[node name="NeonCityEnemies" type="Node3D"]

[node name="Director" type="Node3D" parent="."]
script = ExtResource("1_director")
source_root = NodePath("../..")
bake_area = AABB({-EDGE - 2}, -3, {-EDGE - 2}, {2 * EDGE + 4}, 45, {2 * EDGE + 4})

[node name="Routes" type="Node3D" parent="."]"""]
    for name, marks in routes:
        out.append(f'[node name="{name}" type="Node3D" parent="Routes"]\nscript = ExtResource("2_route")\n'
                   f'loop = true\nwait_time = 3.0')
        for k, (x, z, wait) in enumerate(marks):
            line = f'[node name="P{k + 1}" type="Marker3D" parent="Routes/{name}"]\ntransform = {xform(x, SIDEWALK_Y, z)}'
            if wait == 0.0:
                line += "\nmetadata/wait = 0.0"
            out.append(line)
    out.append('[node name="Enemies" type="Node3D" parent="."]')
    for e in enemies:
        line = (f'[node name="{e["name"]}" parent="Enemies" instance=ExtResource("3_enemy")]\n'
                f'transform = {xform(e["x"], SIDEWALK_Y, e["z"], e["yaw"])}\nprofile = ExtResource("{e["profile"]}")\n'
                f'variant_seed = {e["seed"]}')
        if e["route"]:
            line += f'\nroute = NodePath("../../Routes/{e["route"]}")\nstart_point = {e["start"]}'
        out.append(line)
    return "\n\n".join(out) + "\n"


# =====================================================================================
# Kopf, Umgebung, Spieler, Items
# =====================================================================================
HEAD = """[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/slum/slum.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="2_player"]
[ext_resource type="PackedScene" path="res://scenes/pause/pause_menu.tscn" id="3_pause"]
[ext_resource type="Script" path="res://scenes/neon_city/kit/neon_tower.gd" id="k_tower"]
[ext_resource type="Script" path="res://scenes/neon_city/kit/neon_road.gd" id="k_road"]
[ext_resource type="Script" path="res://scenes/neon_city/kit/neon_ground.gd" id="k_ground"]
[ext_resource type="Script" path="res://scenes/neon_city/kit/neon_prop.gd" id="k_prop"]
[ext_resource type="Script" path="res://scenes/neon_city/kit/neon_skywalk.gd" id="k_skywalk"]
[ext_resource type="Script" path="res://scenes/neon_city/kit/neon_stairs.gd" id="k_stairs"]
[ext_resource type="Script" path="res://scenes/neon_city/kit/neon_stall.gd" id="k_stall"]
[ext_resource type="Script" path="res://scenes/neon_city/kit/neon_dressing.gd" id="k_dress"]
[ext_resource type="PackedScene" path="res://scenes/neon_city/neon_city_enemies.tscn" id="e_enemies"]
[ext_resource type="PackedScene" path="res://scenes/neon_city/neon_city_life.tscn" id="l_life"]

[sub_resource type="ProceduralSkyMaterial" id="Sky_mat"]
sky_top_color = Color(0.03, 0.02, 0.07, 1)
sky_horizon_color = Color(0.2, 0.08, 0.22, 1)
ground_bottom_color = Color(0.02, 0.02, 0.03, 1)
ground_horizon_color = Color(0.2, 0.08, 0.22, 1)
sun_angle_max = 1.0

[sub_resource type="Sky" id="Sky_night"]
sky_material = SubResource("Sky_mat")

[sub_resource type="Environment" id="Env_city"]
background_mode = 2
sky = SubResource("Sky_night")
ambient_light_source = 2
ambient_light_color = Color(0.42, 0.4, 0.58, 1)
ambient_light_energy = 1.25
reflected_light_source = 2
tonemap_mode = 2
tonemap_exposure = 1.1
ssao_enabled = true
ssao_intensity = 1.2
glow_enabled = true
glow_intensity = 0.85
glow_bloom = 0.06
glow_blend_mode = 1
glow_hdr_threshold = 1.0
fog_enabled = true
fog_light_color = Color(0.16, 0.1, 0.22, 1)
fog_density = 0.006
fog_sky_affect = 0.6
adjustment_enabled = true
adjustment_contrast = 1.05
adjustment_saturation = 1.1

[sub_resource type="BoxShape3D" id="Shape_bound"]
size = Vector3(BOUND_SIZE, 80, 1)

[node name="NeonCity" type="Node3D"]
script = ExtResource("1_script")
rain_amount = 2000
shop_places = SHOP_PLACES

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env_city")

[node name="Moon" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.81915, 0.46985, -0.32899, 0, 0.57358, 0.81915, 0.57358, -0.67101, 0.46985, 0, 60, 0)
light_color = Color(0.55, 0.6, 0.9, 1)
light_energy = 0.4
shadow_enabled = true
directional_shadow_max_distance = 90.0
"""

TAIL = """
[node name="Bounds" type="Node3D" parent="."]

[node name="North" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 40, -BOUND)

[node name="Shape" type="CollisionShape3D" parent="Bounds/North"]
shape = SubResource("Shape_bound")

[node name="South" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 40, BOUND)

[node name="Shape" type="CollisionShape3D" parent="Bounds/South"]
shape = SubResource("Shape_bound")

[node name="East" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, BOUND, 40, 0)

[node name="Shape" type="CollisionShape3D" parent="Bounds/East"]
shape = SubResource("Shape_bound")

[node name="West" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, -BOUND, 40, 0)

[node name="Shape" type="CollisionShape3D" parent="Bounds/West"]
shape = SubResource("Shape_bound")

[node name="Player" parent="." instance=ExtResource("2_player")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, SPAWN_X, 0.4, SPAWN_Z)

[node name="PauseMenu" parent="." instance=ExtResource("3_pause")]
"""



def items() -> str:
    # Keine Items auf dem Boden: Beute gibt es nur von besiegten Gegnern.
    out = ['[node name="NeonCityEnemies" parent="." instance=ExtResource("e_enemies")]',
           '[node name="NeonCityLife" parent="." instance=ExtResource("l_life")]']
    return "\n\n".join(out)


def places_text() -> str:
    parts = []
    for p in shop_places:
        x, y, z = p["at"]
        parts.append(f'{{"at": Vector3({x}, {y}, {z}), "kind": "{p["kind"]}", "yaw": {p["yaw"]}}}')
    return f"Array[Dictionary]([{', '.join(parts)}])"


def main() -> None:
    head = HEAD.replace("BOUND_SIZE", str(int(2 * EDGE + 20))).replace("SHOP_PLACES", places_text())
    tail = TAIL.replace("BOUND", str(int(EDGE))).replace("SPAWN_X", str(SPAWN[0])).replace("SPAWN_Z", str(SPAWN[1]))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(head + "\n" + "\n\n".join(nodes) + "\n" + tail + "\n" + items() + "\n")
    with open(LIFE_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(life_scene())
    with open(ENEMIES_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(enemies_scene())
    towers = sum(1 for n in nodes if 'ExtResource("k_tower")' in n)
    props = sum(1 for n in nodes if 'ExtResource("k_prop")' in n)
    print(f"geschrieben: {OUT}: {len(nodes)} Knoten, {towers} Häuser, {props} Props, {len(shop_places)} Läden")
    print("Details: " + ", ".join(f"{k} {v}" for k, v in DRESS_COUNT.items() if v))
    print(f"geschrieben: {ENEMIES_OUT}: {len(enemies)} Gegner, {len(routes)} Streifen; {court_walks} Hofwege")
    print(f"geschrieben: {LIFE_OUT}: {len(ped.nodes)} Fußgänger-Knoten, {len(ped.edges)} Wege, {len(ROADS)} Straßen")


if __name__ == "__main__":
    main()
