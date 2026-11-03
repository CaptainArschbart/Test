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
def tower(parent: str, x: float, z: float, facing: str, w: float, d: float, floors: int, district: str, **props) -> None:
    yaw = FACING[facing]
    claim(*rect_of(x, z, w, d, yaw), "solid", f"Haus {x:.0f},{z:.0f}")
    props.setdefault("seed_value", rnd.randint(1, 99999))
    props.setdefault("color_index", rnd.randint(0, 3))
    props.setdefault("accent", rnd.randint(0, 5))
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

for i, lx in enumerate(LINES):
    for j in range(len(LINES) - 1):
        za, zb = LINES[j], LINES[j + 1]
        z0, z1 = za + ext(za), zb - ext(zb)
        w, s, m = road_dims(lx)
        claim(lx - w / 2, lx + w / 2, z0, z1, "road", f"Straße x={lx}")
        claim(lx - w / 2 - s, lx - w / 2, z0, z1, "area", "Gehweg")
        cz = (z0 + z1) / 2
        skip = [round(alley_z(b, j) - cz, 2) for b in (i - 1, i) if 0 <= b < 4]
        node(uname("Road"), P_ROADS, "k_road", lx, 0.0, cz, 0.0, length=z1 - z0, road_width=w,
             sidewalk=s, median=m, crosswalk_start=True, crosswalk_end=True, seed_value=rnd.randint(1, 9999),
             lamp_skip=Raw(f"PackedFloat32Array({', '.join(str(v) for v in skip)})"))
for j, lz in enumerate(LINES):
    for i in range(len(LINES) - 1):
        xa, xb = LINES[i], LINES[i + 1]
        x0, x1 = xa + ext(xa), xb - ext(xb)
        w, s, m = road_dims(lz)
        claim(x0, x1, lz - w / 2, lz + w / 2, "road", f"Straße z={lz}")
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
    print(f"geschrieben: {ENEMIES_OUT}: {len(enemies)} Gegner, {len(routes)} Streifen; {court_walks} Hofwege")
    print(f"geschrieben: {LIFE_OUT}: {len(ped.nodes)} Fußgänger-Knoten, {len(ped.edges)} Wege, {len(ROADS)} Straßen")


if __name__ == "__main__":
    main()
