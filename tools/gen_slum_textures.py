#!/usr/bin/env python3
"""Erzeugt die Low-Poly/PS1-Texturen für das Slum-Mapkit (assets/textures/slum/).

Alle Flächen-Texturen sind kachelbar und klein (128 px, Böden 256 px), damit sie mit
Nearest-Filter nach PS1/PS2 aussehen. Details (Fenster, Türen, Lüfter, Schilder, Graffiti)
haben Alpha und werden als Quads auf die Wände gesetzt.

Aufruf aus dem Repo-Root:  python3 tools/gen_slum_textures.py
Braucht numpy und Pillow, für die japanischen Schilder eine CJK-Schrift (IPAGothic o. ä.).
Gleicher Seed = gleiche Bilder, also kann man das Skript gefahrlos neu laufen lassen.
"""
from __future__ import annotations

import math
import zlib
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "slum")
RNG = np.random.default_rng(1337)

CJK_FONTS = [
    "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf",
    "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf",
    "C:/Windows/Fonts/msgothic.ttc",
    "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
]
LATIN_FONTS = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
]


# ---------------------------------------------------------------- Rauschen

def value_noise(size: int, cells: int, seed: int) -> np.ndarray:
    """Kachelbares Value-Noise (0..1) mit cells×cells Stützstellen."""
    rng = np.random.default_rng(seed)
    grid = rng.random((cells, cells))
    t = np.arange(size) / size * cells
    i0 = np.floor(t).astype(int) % cells
    i1 = (i0 + 1) % cells
    f = t - np.floor(t)
    f = f * f * (3 - 2 * f)
    a = grid[i0][:, i0]
    b = grid[i0][:, i1]
    c = grid[i1][:, i0]
    d = grid[i1][:, i1]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size: int, base: int, octaves: int, seed: int) -> np.ndarray:
    out = np.zeros((size, size))
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        cells = base * (2 ** o)
        if cells > size:
            break
        out += value_noise(size, cells, seed + o * 17) * amp
        total += amp
        amp *= 0.5
    return out / total


def grain(size: int, seed: int, amount: float) -> np.ndarray:
    return (np.random.default_rng(seed).random((size, size)) - 0.5) * amount


def colorize(gray: np.ndarray, dark, light) -> np.ndarray:
    dark = np.array(dark, float) / 255.0
    light = np.array(light, float) / 255.0
    g = np.clip(gray, 0, 1)[..., None]
    return dark * (1 - g) + light * g


def to_img(rgb: np.ndarray, alpha: np.ndarray | None = None) -> Image.Image:
    rgb8 = (np.clip(rgb, 0, 1) * 255).astype(np.uint8)
    if alpha is None:
        return Image.fromarray(rgb8, "RGB")
    a8 = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb8, a8]), "RGBA")


def posterize(rgb: np.ndarray, levels: int = 32) -> np.ndarray:
    """Leichte Farbreduktion mit geordnetem Dithering (PS1-Gefühl)."""
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
    h, w = rgb.shape[:2]
    d = np.tile(bayer, (h // 4 + 1, w // 4 + 1))[:h, :w][..., None]
    return np.floor(rgb * levels + d * 0.9 + 0.5) / levels


def streaks(size: int, seed: int, count: int, length: float, width: int = 2) -> np.ndarray:
    """Senkrechte Wasser-/Rostläufer (0..1), oben kräftig, unten auslaufend."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size))
    for _ in range(count):
        x = rng.integers(0, size)
        y0 = rng.integers(0, size)
        ln = int(size * length * rng.uniform(0.4, 1.0))
        w = rng.integers(1, width + 1)
        for k in range(ln):
            y = (y0 + k) % size
            fade = 1.0 - k / ln
            for dx in range(w):
                out[y, (x + dx) % size] = max(out[y, (x + dx) % size], fade * rng.uniform(0.5, 1.0))
    return out


def cracks(size: int, seed: int, count: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    img = Image.new("L", (size, size), 0)
    dr = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = rng.uniform(0, size, 2)
        ang = rng.uniform(0, math.tau)
        for _ in range(rng.integers(6, 16)):
            ang += rng.normal(0, 0.6)
            step = rng.uniform(3, 9)
            nx, ny = x + math.cos(ang) * step, y + math.sin(ang) * step
            for ox in (-size, 0, size):
                for oy in (-size, 0, size):
                    dr.line([(x + ox, y + oy), (nx + ox, ny + oy)], fill=255, width=1)
            x, y = nx, ny
    return np.asarray(img, float) / 255.0


def save(img: Image.Image, name: str) -> None:
    path = os.path.join(OUT, name)
    img.save(path, optimize=True)
    print("  ", name, img.size)


# ---------------------------------------------------------------- Flächen

def concrete(name: str, dark, light, seed: int, size: int = 128, stains: float = 0.35) -> None:
    n = fbm(size, 4, 5, seed) * 0.7 + grain(size, seed + 1, 0.18)
    dirt = fbm(size, 2, 3, seed + 5)
    rgb = colorize(n, dark, light)
    rgb *= (1 - stains * np.clip(dirt - 0.45, 0, 1) * 2)[..., None]
    rgb *= (1 - 0.35 * streaks(size, seed + 9, 14, 0.7))[..., None]
    rgb *= (1 - 0.55 * cracks(size, seed + 3, 3))[..., None]
    # Schalungsfugen: waagerechte Linie alle 64 px
    for y in range(0, size, 64):
        rgb[y:y + 1] *= 0.6
    rgb[:, ::size // 2][:, :1] *= 0.92
    save(to_img(posterize(rgb)), name)


def brick(name: str, seed: int, size: int = 128, base=(120, 52, 38)) -> None:
    rng = np.random.default_rng(seed)
    bw, bh = 32, 12  # Ziegel in px: 128 px = 1 m Wand → ~25 × 9 cm
    mortar = np.array([70, 64, 58]) / 255.0
    rgb = np.zeros((size, size, 3))
    rgb[:] = mortar
    noise = fbm(size, 8, 4, seed) - 0.5
    for row in range(size // bh + 1):
        off = (bw // 2) * (row % 2)
        for col in range(-1, size // bw + 1):
            x0 = col * bw + off
            y0 = row * bh
            tint = rng.uniform(0.65, 1.15)
            c = np.array(base) / 255.0 * tint
            c = c + rng.normal(0, 0.03, 3)
            for y in range(y0 + 1, min(y0 + bh - 1, size)):
                for x in range(x0 + 1, x0 + bw - 1):
                    rgb[y, x % size] = c
    rgb += noise[..., None] * 0.18
    rgb *= (1 - 0.35 * np.clip(fbm(size, 2, 3, seed + 4) - 0.5, 0, 1) * 2)[..., None]
    rgb *= (1 - 0.4 * streaks(size, seed + 2, 10, 0.6))[..., None]
    save(to_img(posterize(rgb)), name)


def corrugated(name: str, paint, seed: int, rust: float, size: int = 128) -> None:
    x = np.arange(size)
    ribs = 0.5 + 0.5 * np.sin(x / size * math.tau * 16)
    shade = np.tile(ribs, (size, 1))
    base = np.array(paint) / 255.0
    rgb = base * (0.55 + 0.6 * shade)[..., None]
    rgb += (fbm(size, 4, 4, seed) - 0.5)[..., None] * 0.15
    rustmask = np.clip((fbm(size, 3, 5, seed + 3) - (0.86 - rust * 0.3)) * 5, 0, 1)
    rustmask = np.maximum(rustmask, streaks(size, seed + 4, 14, 0.8, 2) * rust * 1.2)
    rustcol = colorize(fbm(size, 8, 3, seed + 6), (70, 30, 14), (150, 70, 30))
    rgb = rgb * (1 - rustmask[..., None]) + rustcol * rustmask[..., None]
    # Plattenstoß oben
    rgb[0:2] *= 0.45
    save(to_img(posterize(rgb)), name)


def plaster(name: str, color, seed: int, size: int = 128) -> None:
    n = fbm(size, 4, 5, seed)
    rgb = colorize(n * 0.6 + 0.4, np.array(color) * 0.55, color)
    peel = np.clip((fbm(size, 3, 4, seed + 2) - 0.62) * 6, 0, 1)
    under = colorize(fbm(size, 8, 3, seed + 7), (60, 58, 55), (100, 96, 90))
    rgb = rgb * (1 - peel[..., None]) + under * peel[..., None]
    rgb *= (1 - 0.4 * streaks(size, seed + 1, 12, 0.6))[..., None]
    rgb *= (1 - 0.5 * cracks(size, seed + 5, 2))[..., None]
    # Paneelfugen
    rgb[:, 0:1] *= 0.55
    rgb[0:1, :] *= 0.55
    save(to_img(posterize(rgb)), name)


def shutter(name: str, seed: int, size: int = 128) -> None:
    y = np.arange(size)
    slats = 0.5 + 0.5 * np.cos((y % 8) / 8 * math.tau)
    shade = np.tile(slats[:, None], (1, size))
    rgb = colorize(shade * 0.5 + fbm(size, 4, 3, seed) * 0.5, (40, 44, 48), (120, 124, 126))
    rgb *= (1 - 0.45 * streaks(size, seed + 3, 16, 0.5))[..., None]
    rust = np.clip((fbm(size, 4, 4, seed + 1) - 0.62) * 5, 0, 1)
    rgb = rgb * (1 - rust[..., None] * 0.6) + np.array([0.45, 0.22, 0.1]) * rust[..., None] * 0.6
    save(to_img(posterize(rgb)), name)


def tiles(name: str, seed: int, size: int = 128, tile_px: int = 32, dark=(30, 34, 38), light=(70, 76, 80)) -> None:
    rng = np.random.default_rng(seed)
    rgb = colorize(fbm(size, 4, 4, seed) * 0.6 + 0.2, dark, light)
    for ty in range(size // tile_px):
        for tx in range(size // tile_px):
            rgb[ty * tile_px:(ty + 1) * tile_px, tx * tile_px:(tx + 1) * tile_px] *= rng.uniform(0.8, 1.15)
    rgb[::tile_px] *= 0.35
    rgb[:, ::tile_px] *= 0.35
    rgb *= (1 - 0.5 * cracks(size, seed + 2, 2))[..., None]
    save(to_img(posterize(rgb)), name)


def asphalt(name: str, seed: int, size: int = 256, wet: float = 0.4) -> None:
    n = fbm(size, 8, 5, seed) * 0.5 + grain(size, seed + 1, 0.35) + 0.25
    rgb = colorize(n, (18, 19, 22), (62, 62, 66))
    patch = np.clip((fbm(size, 3, 3, seed + 4) - 0.6) * 8, 0, 1)
    rgb = rgb * (1 - patch[..., None] * 0.35)
    rgb *= (1 - 0.7 * cracks(size, seed + 2, 6))[..., None]
    puddle = np.clip((fbm(size, 3, 4, seed + 9) - (0.72 - wet * 0.1)) * 10, 0, 1)
    rgb = rgb * (1 - puddle[..., None] * 0.5)
    save(to_img(posterize(rgb)), name)


def sidewalk(name: str, seed: int, size: int = 256, slab_px: int = 64) -> None:
    rng = np.random.default_rng(seed)
    n = fbm(size, 8, 5, seed) * 0.5 + grain(size, seed + 1, 0.2) + 0.3
    rgb = colorize(n, (52, 52, 54), (112, 110, 106))
    for sy in range(size // slab_px):
        for sx in range(size // slab_px):
            rgb[sy * slab_px:(sy + 1) * slab_px, sx * slab_px:(sx + 1) * slab_px] *= rng.uniform(0.78, 1.1)
    rgb[::slab_px] *= 0.4
    rgb[:, ::slab_px] *= 0.4
    rgb *= (1 - 0.6 * cracks(size, seed + 3, 5))[..., None]
    gum = (np.random.default_rng(seed + 8).random((size, size)) > 0.997)
    rgb[gum] *= 0.45
    dirt = np.clip((fbm(size, 2, 4, seed + 5) - 0.5) * 2, 0, 1)
    rgb *= (1 - dirt * 0.35)[..., None]
    save(to_img(posterize(rgb)), name)


def curb(name: str, seed: int, size: int = 128) -> None:
    n = fbm(size, 8, 4, seed) * 0.5 + grain(size, seed, 0.2) + 0.35
    rgb = colorize(n, (70, 70, 70), (140, 138, 132))
    rgb[:, ::64] *= 0.5
    # gelb-schwarze Kante bleibt Geometrie, hier nur Abnutzung
    rgb *= (1 - 0.4 * streaks(size, seed + 1, 8, 0.4))[..., None]
    save(to_img(posterize(rgb)), name)


def wood(name: str, seed: int, size: int = 128, plank_px: int = 21, base=(96, 72, 50)) -> None:
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:size, 0:size]
    rings = 0.5 + 0.5 * np.sin(xx / size * math.tau * 2 + fbm(size, 4, 3, seed) * 8 + yy * 0.25)
    rgb = colorize(rings * 0.4 + fbm(size, 8, 3, seed + 1) * 0.4 + 0.1, np.array(base) * 0.45, base)
    for p in range(size // plank_px + 1):
        rgb[p * plank_px:(p + 1) * plank_px] *= rng.uniform(0.7, 1.15)
        rgb[p * plank_px:p * plank_px + 1] *= 0.3
        nx = rng.integers(2, size - 2)
        rgb[p * plank_px + 3:p * plank_px + 5, nx:nx + 2] = 0.12
    rgb *= (1 - 0.3 * streaks(size, seed + 4, 10, 0.6))[..., None]
    save(to_img(posterize(rgb)), name)


def metal_plate(name: str, seed: int, size: int = 128) -> None:
    rgb = colorize(fbm(size, 4, 4, seed) * 0.5 + 0.3, (40, 42, 46), (110, 112, 116))
    yy, xx = np.mgrid[0:size, 0:size]
    # Riffelblech
    d = ((xx + yy) % 16 < 3) & ((xx // 8 + yy // 8) % 2 == 0)
    d2 = ((xx - yy) % 16 < 3) & ((xx // 8 + yy // 8) % 2 == 1)
    rgb[d | d2] *= 1.35
    rust = np.clip((fbm(size, 4, 4, seed + 2) - 0.6) * 5, 0, 1)
    rgb = rgb * (1 - rust[..., None] * 0.7) + np.array([0.42, 0.2, 0.09]) * rust[..., None] * 0.7
    save(to_img(posterize(rgb)), name)


def roof_tar(name: str, seed: int, size: int = 128) -> None:
    rgb = colorize(fbm(size, 8, 5, seed) * 0.5 + grain(size, seed, 0.3) + 0.2, (16, 16, 18), (58, 56, 54))
    rgb[::42] *= 0.5
    puddle = np.clip((fbm(size, 3, 4, seed + 9) - 0.66) * 10, 0, 1)
    rgb *= (1 - puddle * 0.4)[..., None]
    save(to_img(posterize(rgb)), name)


def rust(name: str, seed: int, size: int = 128) -> None:
    rgb = colorize(fbm(size, 4, 6, seed) + grain(size, seed, 0.25), (40, 20, 10), (150, 72, 32))
    save(to_img(posterize(rgb)), name)


def grime(name: str, seed: int, size: int = 128) -> None:
    """Graustufen-Schmutzmaske (hell = sauber), wird im Shader über alles gelegt."""
    g = 1 - 0.6 * np.clip((fbm(size, 2, 5, seed) - 0.4) * 2.2, 0, 1)
    g *= 1 - 0.4 * streaks(size, seed + 1, 20, 0.9, 3)
    img = Image.fromarray((np.clip(g, 0, 1) * 255).astype(np.uint8), "L")
    save(img, name)


# ---------------------------------------------------------------- Details mit Alpha

def window(name: str, seed: int, lit: bool, bars: bool = False, w: int = 64, h: int = 80) -> None:
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    frame = (48, 50, 52, 255)
    dr.rectangle([0, 0, w - 1, h - 1], fill=frame)
    dr.rectangle([0, h - 6, w - 1, h - 1], fill=(80, 80, 78, 255))  # Sims
    if lit:
        glass_top = np.array([255, 196, 110])
        glass_bot = np.array([200, 120, 60])
    else:
        glass_top = np.array([30, 40, 52])
        glass_bot = np.array([12, 16, 22])
    for y in range(4, h - 9):
        t = (y - 4) / (h - 13)
        c = glass_top * (1 - t) + glass_bot * t
        dr.line([(4, y), (w - 5, y)], fill=tuple(int(v) for v in c) + (255,))
    # Sprossen
    dr.rectangle([w // 2 - 1, 4, w // 2 + 1, h - 9], fill=frame)
    dr.rectangle([4, (h - 9) // 2, w - 5, (h - 9) // 2 + 2], fill=frame)
    if lit:
        # Vorhang / Silhouette
        if rng.random() < 0.5:
            dr.rectangle([4, 4, 4 + rng.integers(6, 20), h - 10], fill=(120, 40, 50, 255))
        if rng.random() < 0.4:
            cx = rng.integers(14, w - 14)
            dr.ellipse([cx - 5, 26, cx + 5, 37], fill=(70, 40, 30, 255))
            dr.rectangle([cx - 8, 37, cx + 8, h - 10], fill=(70, 40, 30, 255))
    else:
        # Spiegelung
        dr.line([(8, h - 14), (w // 2 - 4, 8)], fill=(70, 86, 100, 255), width=2)
    if bars:
        for x in range(6, w - 4, 8):
            dr.line([(x, 0), (x, h - 7)], fill=(30, 30, 30, 255), width=2)
        dr.line([(0, 14), (w, 14)], fill=(30, 30, 30, 255), width=2)
        dr.line([(0, h - 20), (w, h - 20)], fill=(30, 30, 30, 255), width=2)
    save(img, name)


def window_emission_mask(name: str, w: int = 64, h: int = 80) -> None:
    img = Image.new("L", (w, h), 0)
    dr = ImageDraw.Draw(img)
    dr.rectangle([4, 4, w - 5, h - 10], fill=255)
    dr.rectangle([w // 2 - 1, 4, w // 2 + 1, h - 9], fill=0)
    dr.rectangle([4, (h - 9) // 2, w - 5, (h - 9) // 2 + 2], fill=0)
    save(img, name)


def door(name: str, seed: int, kind: str) -> None:
    w, h = 64, 128
    rng = np.random.default_rng(seed)
    if kind == "metal":
        base = colorize(fbm(128, 4, 4, seed)[:h, :w] * 0.5 + 0.3, (34, 50, 46), (78, 100, 92))
    elif kind == "wood":
        base = colorize(fbm(128, 8, 4, seed)[:h, :w] * 0.5 + 0.3, (50, 34, 22), (110, 78, 50))
    else:
        base = colorize(fbm(128, 4, 4, seed)[:h, :w] * 0.5 + 0.3, (40, 40, 44), (96, 96, 100))
    img = to_img(base, np.ones((h, w)))
    dr = ImageDraw.Draw(img)
    dr.rectangle([0, 0, w - 1, h - 1], outline=(20, 20, 20, 255), width=3)
    if kind == "metal":
        dr.rectangle([10, 12, w - 11, 50], outline=(20, 28, 26, 255), width=2)
        dr.rectangle([10, 60, w - 11, h - 12], outline=(20, 28, 26, 255), width=2)
        dr.rectangle([16, 18, w - 17, 40], fill=(20, 26, 30, 255))  # Guckfenster
        dr.rectangle([w - 14, 64, w - 8, 70], fill=(150, 150, 140, 255))
    elif kind == "wood":
        for x in range(8, w, 12):
            dr.line([(x, 4), (x, h - 4)], fill=(36, 24, 16, 255), width=1)
        dr.ellipse([w - 14, 62, w - 8, 68], fill=(160, 140, 90, 255))
    else:  # Gitter-/Sicherheitstür
        for y in range(8, h - 6, 6):
            dr.line([(4, y), (w - 5, y)], fill=(20, 20, 22, 255), width=2)
        dr.rectangle([w - 14, 60, w - 8, 74], fill=(170, 160, 120, 255))
    arr = np.asarray(img).astype(float) / 255.0
    arr[..., :3] *= (1 - 0.35 * streaks(128, seed, 8, 0.6)[:h, :w])[..., None]
    save(to_img(posterize(arr[..., :3]), arr[..., 3]), name)


def vent(name: str, seed: int, kind: str) -> None:
    s = 64
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    if kind == "grille":
        dr.rectangle([0, 0, s - 1, s - 1], fill=(70, 72, 74, 255))
        dr.rectangle([4, 4, s - 5, s - 5], fill=(18, 18, 20, 255))
        for y in range(7, s - 6, 5):
            dr.line([(5, y), (s - 6, y)], fill=(96, 98, 100, 255), width=2)
    elif kind == "fan":  # Klimagerät-Front
        dr.rectangle([0, 0, s - 1, s - 1], fill=(170, 172, 168, 255))
        dr.ellipse([8, 8, s - 9, s - 9], fill=(30, 30, 32, 255))
        for a in range(0, 360, 60):
            r = math.radians(a)
            dr.polygon([(s / 2, s / 2), (s / 2 + math.cos(r) * 22, s / 2 + math.sin(r) * 22),
                        (s / 2 + math.cos(r + 0.6) * 20, s / 2 + math.sin(r + 0.6) * 20)], fill=(90, 92, 94, 255))
        for k in range(10, s - 8, 6):
            dr.arc([s / 2 - (k / 2), s / 2 - (k / 2), s / 2 + (k / 2), s / 2 + (k / 2)], 0, 360, fill=(120, 122, 120, 255))
        dr.ellipse([s / 2 - 4, s / 2 - 4, s / 2 + 4, s / 2 + 4], fill=(150, 150, 150, 255))
    elif kind == "louver":
        dr.rectangle([0, 0, s - 1, s - 1], fill=(120, 124, 120, 255))
        for y in range(6, s - 4, 7):
            dr.rectangle([5, y, s - 6, y + 3], fill=(40, 42, 44, 255))
    arr = np.asarray(img).astype(float) / 255.0
    arr[..., :3] *= (1 - 0.35 * streaks(64, seed, 6, 0.5))[..., None]
    arr[..., :3] *= (0.85 + 0.3 * fbm(64, 4, 3, seed))[..., None]
    save(to_img(posterize(arr[..., :3]), arr[..., 3]), name)


def electric_box(name: str, seed: int) -> None:
    w, h = 64, 80
    base = colorize(fbm(128, 4, 4, seed)[:h, :w] * 0.5 + 0.35, (60, 66, 62), (130, 136, 126))
    img = to_img(base, np.ones((h, w)))
    dr = ImageDraw.Draw(img)
    dr.rectangle([0, 0, w - 1, h - 1], outline=(30, 32, 30, 255), width=2)
    dr.line([(w // 2, 4), (w // 2, h - 4)], fill=(40, 42, 40, 255), width=2)
    dr.polygon([(w // 2 + 16, 16), (w // 2 + 4, 36), (w // 2 + 28, 36)], fill=(240, 200, 30, 255), outline=(20, 20, 20, 255))
    dr.text((w // 2 + 14, 22), "!", fill=(20, 20, 20, 255))
    dr.rectangle([w // 2 - 8, 40, w // 2 - 4, 48], fill=(160, 160, 150, 255))
    arr = np.asarray(img).astype(float) / 255.0
    arr[..., :3] *= (1 - 0.4 * streaks(128, seed, 8, 0.7)[:h, :w])[..., None]
    save(to_img(posterize(arr[..., :3]), arr[..., 3]), name)


def crate(name: str, seed: int, base) -> None:
    s = 64
    rgb = colorize(fbm(64, 8, 4, seed) * 0.5 + 0.3, np.array(base) * 0.5, base)
    img = to_img(rgb)
    dr = ImageDraw.Draw(img)
    dr.rectangle([0, 0, s - 1, s - 1], outline=tuple(int(c * 0.4) for c in base), width=4)
    dr.line([(4, 4), (s - 5, s - 5)], fill=tuple(int(c * 0.55) for c in base), width=4)
    for y in (21, 42):
        dr.line([(4, y), (s - 5, y)], fill=tuple(int(c * 0.5) for c in base), width=1)
    save(img, name)


def military_crate(name: str, seed: int) -> None:
    s = 64
    rgb = colorize(fbm(64, 4, 4, seed) * 0.5 + 0.3, (34, 44, 30), (82, 98, 66))
    img = to_img(rgb)
    dr = ImageDraw.Draw(img)
    dr.rectangle([0, 0, s - 1, s - 1], outline=(20, 26, 18), width=3)
    dr.rectangle([8, 26, s - 9, 38], fill=(200, 190, 140))
    dr.text((12, 27), "NG-07", fill=(30, 30, 20))
    dr.rectangle([2, 8, 8, 16], fill=(30, 30, 30))
    dr.rectangle([s - 9, 8, s - 3, 16], fill=(30, 30, 30))
    save(img, name)


def dumpster(name: str, seed: int, color) -> None:
    s = 64
    rgb = colorize(fbm(64, 4, 4, seed) * 0.6 + 0.25, np.array(color) * 0.45, color)
    rgb *= (1 - 0.5 * streaks(64, seed, 10, 0.7))[..., None]
    rmask = np.clip((fbm(64, 4, 4, seed + 1) - 0.6) * 5, 0, 1)
    rgb = rgb * (1 - rmask[..., None]) + np.array([0.4, 0.2, 0.08]) * rmask[..., None]
    img = to_img(posterize(rgb))
    dr = ImageDraw.Draw(img)
    for x in range(0, s, 16):
        dr.line([(x, 0), (x, s)], fill=tuple(int(c * 0.5) for c in color), width=2)
    dr.polygon([(s - 18, 6), (s - 26, 20), (s - 10, 20)], fill=(230, 190, 30), outline=(20, 20, 20))
    save(img, name)


def barrel(name: str, seed: int, color) -> None:
    w, h = 64, 64
    rgb = colorize(fbm(64, 4, 4, seed) * 0.5 + 0.3, np.array(color) * 0.45, color)
    for y in (10, 32, 54):
        rgb[y:y + 3] *= 0.55
    rmask = np.maximum(np.clip((fbm(64, 4, 5, seed + 2) - 0.55) * 4, 0, 1), streaks(64, seed + 5, 10, 0.6) * 0.8)
    rgb = rgb * (1 - rmask[..., None]) + np.array([0.38, 0.17, 0.07]) * rmask[..., None]
    save(to_img(posterize(rgb)), name)


def pallet(name: str, seed: int) -> None:
    wood("_tmp_pallet.png", seed, 64, 16, (130, 104, 70))
    os.replace(os.path.join(OUT, "_tmp_pallet.png"), os.path.join(OUT, name))


def warning_stripes(name: str, c1=(230, 190, 20), c2=(20, 20, 20), size: int = 64) -> None:
    yy, xx = np.mgrid[0:size, 0:size]
    band = ((xx + yy) // (size // 4)) % 2 == 0
    rgb = np.where(band[..., None], np.array(c1) / 255.0, np.array(c2) / 255.0)
    rgb *= (0.75 + 0.35 * fbm(size, 4, 3, 5))[..., None]
    save(to_img(posterize(rgb)), name)


def red_white(name: str, size: int = 64) -> None:
    warning_stripes(name, (210, 40, 30), (230, 228, 220), size)


def manhole(name: str, seed: int) -> None:
    s = 64
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    dr.ellipse([1, 1, s - 2, s - 2], fill=(40, 40, 42, 255))
    dr.ellipse([5, 5, s - 6, s - 6], fill=(62, 62, 64, 255))
    for k in range(10, s - 10, 6):
        dr.line([(k, 10), (k, s - 10)], fill=(44, 44, 46, 255), width=2)
    dr.ellipse([5, 5, s - 6, s - 6], outline=(30, 30, 30, 255), width=2)
    save(img, name)


def crosswalk(name: str) -> None:
    w, h = 64, 256
    n = fbm(256, 8, 4, 77)[:h, :w]
    a = np.clip(0.95 - (n - 0.5) * 1.6 - (np.random.default_rng(3).random((h, w)) > 0.92) * 0.6, 0, 1)
    rgb = np.ones((h, w, 3)) * np.array([0.86, 0.85, 0.8])
    save(to_img(rgb, a), name)


def road_line(name: str, color) -> None:
    w, h = 16, 128
    n = fbm(128, 8, 4, 31)[:h, :w]
    a = np.clip(0.95 - (n - 0.45) * 1.8, 0, 1)
    rgb = np.ones((h, w, 3)) * np.array(color) / 255.0
    save(to_img(rgb, a), name)


def chainlink(name: str, size: int = 64) -> None:
    """Maschendraht mit Alpha, kachelbar (eine Kachel = 0,5 m)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    col = (150, 152, 150, 255)
    step = size // 4
    for k in range(-size, 2 * size, step):
        dr.line([(k, 0), (k + size, size)], fill=col, width=2)
        dr.line([(k + size, 0), (k, size)], fill=col, width=2)
    save(img, name)


def puddle(name: str, seed: int) -> None:
    s = 128
    yy, xx = np.mgrid[0:s, 0:s]
    d = np.sqrt(((xx - s / 2) / (s / 2)) ** 2 + ((yy - s / 2) / (s / 2.6)) ** 2)
    edge = d + (fbm(s, 4, 4, seed) - 0.5) * 0.8
    a = np.clip((0.85 - edge) * 6, 0, 1)
    rgb = np.ones((s, s, 3)) * np.array([0.04, 0.05, 0.07])
    save(to_img(rgb, a), name)


def trash_decal(name: str, seed: int) -> None:
    s = 128
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    for _ in range(40):
        x, y = rng.normal(s / 2, s / 5, 2)
        r = rng.uniform(2, 7)
        c = rng.choice([(200, 200, 190), (60, 60, 60), (150, 120, 70), (40, 90, 140), (180, 40, 40), (90, 90, 80)])
        dr.polygon([(x + rng.uniform(-r, r), y + rng.uniform(-r, r)) for _ in range(4)], fill=tuple(int(v) for v in c) + (255,))
    save(img, name)


# ---------------------------------------------------------------- Schilder und Graffiti

def font(paths: list[str], size: int) -> ImageFont.FreeTypeFont:
    for p in paths:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    print("WARNUNG: keine passende Schrift gefunden für", paths[0], file=sys.stderr)
    return ImageFont.load_default()


def neon_sign(name: str, text: str, color, vertical: bool = False, cjk: bool = False,
              w: int = 256, h: int = 96, board=(18, 16, 20), frame=True) -> None:
    """RGBA-Schild: dunkle Tafel, Rahmen, Leuchtschrift. Daneben name_emit.png als Leuchtmaske."""
    img = Image.new("RGBA", (w, h), board + (255,))
    emit = Image.new("RGB", (w, h), (0, 0, 0))
    dr = ImageDraw.Draw(img)
    de = ImageDraw.Draw(emit)
    if frame:
        dr.rectangle([1, 1, w - 2, h - 2], outline=(60, 58, 62, 255), width=3)
        dr.rectangle([6, 6, w - 7, h - 7], outline=color + (255,), width=2)
        de.rectangle([6, 6, w - 7, h - 7], outline=color, width=2)
    fnt = font(CJK_FONTS if cjk else LATIN_FONTS, 10)
    if vertical:
        chars = list(text)
        size = int(min(w * 0.72, (h - 20) / len(chars) * 0.92))
        fnt = font(CJK_FONTS if cjk else LATIN_FONTS, size)
        total = size * len(chars)
        y = (h - total) / 2
        for ch in chars:
            bb = dr.textbbox((0, 0), ch, font=fnt)
            x = (w - (bb[2] - bb[0])) / 2 - bb[0]
            dr.text((x, y - bb[1] * 0.3), ch, font=fnt, fill=color + (255,))
            de.text((x, y - bb[1] * 0.3), ch, font=fnt, fill=color)
            y += size
    else:
        size = int(h * 0.62)
        while size > 8:
            fnt = font(CJK_FONTS if cjk else LATIN_FONTS, size)
            bb = dr.textbbox((0, 0), text, font=fnt)
            if bb[2] - bb[0] < w - 28:
                break
            size -= 2
        bb = dr.textbbox((0, 0), text, font=fnt)
        x = (w - (bb[2] - bb[0])) / 2 - bb[0]
        y = (h - (bb[3] - bb[1])) / 2 - bb[1]
        dr.text((x, y), text, font=fnt, fill=color + (255,))
        de.text((x, y), text, font=fnt, fill=color)
    # Schein um die Schrift auf der Tafel
    glow = emit.filter(ImageFilter.GaussianBlur(4))
    base = np.asarray(img).astype(float) / 255.0
    g = np.asarray(glow).astype(float) / 255.0
    base[..., :3] = np.clip(base[..., :3] + g * 0.45, 0, 1)
    base[..., :3] *= (0.85 + 0.25 * fbm(256, 8, 3, zlib.crc32(name.encode()) % 1000)[:h, :w])[..., None]
    to_img(base[..., :3], base[..., 3]).save(os.path.join(OUT, name))
    print("  ", name, (w, h))
    emit.save(os.path.join(OUT, name.replace(".png", "_emit.png")))


def painted_sign(name: str, text: str, fg, bg, w=192, h=64, cjk=False) -> None:
    img = Image.new("RGBA", (w, h), bg + (255,))
    dr = ImageDraw.Draw(img)
    size = int(h * 0.6)
    while True:
        fnt = font(CJK_FONTS if cjk else LATIN_FONTS, size)
        bb = dr.textbbox((0, 0), text, font=fnt)
        if bb[2] - bb[0] < w - 16 or size < 10:
            break
        size -= 2
    x = (w - (bb[2] - bb[0])) / 2 - bb[0]
    y = (h - (bb[3] - bb[1])) / 2 - bb[1]
    dr.rectangle([2, 2, w - 3, h - 3], outline=fg + (255,), width=3)
    dr.text((x, y), text, font=fnt, fill=fg + (255,))
    arr = np.asarray(img).astype(float) / 255.0
    arr[..., :3] *= (1 - 0.45 * streaks(256, zlib.crc32(text.encode()) % 999, 14, 0.6)[:h, :w])[..., None]
    peel = np.clip((fbm(256, 6, 4, len(text) * 7)[:h, :w] - 0.66) * 6, 0, 1)
    arr[..., :3] = arr[..., :3] * (1 - peel[..., None]) + 0.3 * peel[..., None]
    save(to_img(posterize(arr[..., :3]), arr[..., 3]), name)


def stencil(name: str, text: str, color=(220, 220, 210), w=128, h=96) -> None:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    fnt = font(LATIN_FONTS, int(h * 0.8))
    bb = dr.textbbox((0, 0), text, font=fnt)
    dr.text(((w - (bb[2] - bb[0])) / 2 - bb[0], (h - (bb[3] - bb[1])) / 2 - bb[1]), text, font=fnt, fill=color + (230,))
    arr = np.asarray(img).astype(float) / 255.0
    arr[..., 3] *= np.clip(1.1 - fbm(128, 8, 4, 5)[:h, :w] * 0.7, 0, 1)
    save(to_img(arr[..., :3], arr[..., 3]), name)


def graffiti(name: str, text: str, colors, seed: int, w=256, h=128) -> None:
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    fnt = font(LATIN_FONTS, int(h * 0.62))
    x = 12
    for i, ch in enumerate(text):
        col = colors[i % len(colors)]
        y = h * 0.12 + rng.normal(0, 5)
        layer = Image.new("RGBA", (110, 130), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        for ox, oy in ((-3, 0), (3, 0), (0, -3), (0, 3)):
            ld.text((14 + ox, 10 + oy), ch, font=fnt, fill=(15, 15, 15, 255))
        ld.text((14, 10), ch, font=fnt, fill=col + (255,))
        layer = layer.rotate(rng.uniform(-18, 18), resample=Image.BICUBIC)
        img.alpha_composite(layer, (int(x), int(y) - 10))
        x += fnt.getlength(ch) * rng.uniform(0.75, 0.95)
        if x > w - 70:
            break
    # Tropfnasen
    arr = np.asarray(img).astype(float) / 255.0
    for _ in range(14):
        cx = rng.integers(10, w - 10)
        col = np.where(arr[:, cx, 3] > 0.5)[0]
        if len(col) == 0:
            continue
        y0 = col.max()
        ln = rng.integers(4, 20)
        arr[y0:min(h, y0 + ln), cx, :3] = arr[y0 - 1, cx, :3]
        arr[y0:min(h, y0 + ln), cx, 3] = np.linspace(1, 0, min(h, y0 + ln) - y0)
    save(to_img(arr[..., :3], arr[..., 3]), name)


def tag_scribble(name: str, seed: int, color, w=192, h=96) -> None:
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    x, y = 10.0, h / 2
    pts = []
    for _ in range(60):
        x += rng.uniform(1, 5)
        y = np.clip(y + rng.normal(0, 12), 10, h - 10)
        pts.append((x, y))
    dr.line(pts, fill=color + (255,), width=3, joint="curve")
    dr.line([(12, h - 18), (x, h - 14)], fill=color + (255,), width=2)
    save(img, name)


def poster(name: str, seed: int, title: str, cjk=False) -> None:
    rng = np.random.default_rng(seed)
    w, h = 64, 96
    bg = tuple(int(v) for v in rng.choice([(200, 40, 70), (30, 160, 180), (220, 190, 40), (120, 60, 180)]))
    img = Image.new("RGBA", (w, h), bg + (255,))
    dr = ImageDraw.Draw(img)
    dr.rectangle([4, 4, w - 5, 50], fill=(20, 20, 26, 255))
    dr.ellipse([18, 12, 46, 44], fill=tuple(min(255, c + 40) for c in bg) + (255,))
    fnt = font(CJK_FONTS if cjk else LATIN_FONTS, 13)
    dr.text((6, 56), title, font=fnt, fill=(20, 20, 20, 255))
    for yy in range(76, 92, 4):
        dr.line([(6, yy), (w - rng.integers(8, 20), yy)], fill=(30, 30, 30, 255), width=1)
    arr = np.asarray(img).astype(float) / 255.0
    torn = np.clip((fbm(128, 8, 4, seed)[:h, :w] - 0.7) * 8, 0, 1)
    arr[..., 3] *= 1 - torn
    arr[..., :3] *= (0.6 + 0.4 * fbm(128, 4, 3, seed + 3)[:h, :w])[..., None]
    save(to_img(posterize(arr[..., :3]), arr[..., 3]), name)


def tarp(name: str, seed: int, color) -> None:
    s = 64
    rgb = colorize(fbm(64, 4, 4, seed) * 0.7 + 0.2, np.array(color) * 0.45, color)
    yy, xx = np.mgrid[0:s, 0:s]
    rgb *= (0.8 + 0.2 * np.sin(xx / s * math.tau * 3 + yy * 0.1))[..., None]
    save(to_img(posterize(rgb)), name)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    print("Flächen")
    concrete("concrete.png", (58, 58, 58), (128, 126, 120), 1)
    concrete("concrete_dark.png", (30, 32, 34), (82, 84, 86), 2, stains=0.5)
    concrete("concrete_green.png", (40, 52, 46), (92, 108, 96), 3)
    brick("brick.png", 4)
    brick("brick_dark.png", 5, base=(78, 44, 36))
    corrugated("corrugated_blue.png", (60, 82, 104), 6, rust=0.35)
    corrugated("corrugated_rust.png", (96, 74, 58), 7, rust=0.75)
    corrugated("corrugated_grey.png", (92, 96, 98), 8, rust=0.2)
    corrugated("corrugated_green.png", (58, 86, 66), 9, rust=0.4)
    plaster("plaster.png", (150, 140, 112), 10)
    plaster("plaster_teal.png", (82, 120, 116), 11)
    plaster("plaster_pink.png", (150, 104, 104), 12)
    shutter("shutter.png", 13)
    tiles("tiles_dark.png", 14)
    tiles("tiles_white.png", 15, dark=(110, 112, 108), light=(180, 182, 176), tile_px=16)
    asphalt("asphalt.png", 16)
    asphalt("asphalt_old.png", 17, wet=0.9)
    sidewalk("sidewalk.png", 18)
    sidewalk("sidewalk_small.png", 19, slab_px=32)
    curb("curb.png", 20)
    wood("wood.png", 21)
    wood("wood_dark.png", 22, base=(70, 52, 40))
    metal_plate("metal_plate.png", 23)
    roof_tar("roof_tar.png", 24)
    rust("rust.png", 25)
    grime("grime.png", 26)
    tarp("tarp_blue.png", 27, (40, 80, 140))
    tarp("tarp_red.png", 28, (140, 40, 36))
    warning_stripes("hazard.png")
    red_white("red_white.png")

    print("Details")
    window("window_lit.png", 30, True)
    window("window_lit2.png", 31, True)
    window("window_dark.png", 32, False)
    window("window_bars.png", 33, False, bars=True)
    window_emission_mask("window_emit.png")
    door("door_metal.png", 34, "metal")
    door("door_wood.png", 35, "wood")
    door("door_security.png", 36, "security")
    vent("vent_grille.png", 37, "grille")
    vent("ac_front.png", 38, "fan")
    vent("vent_louver.png", 39, "louver")
    electric_box("electric_box.png", 40)
    crate("crate_wood.png", 41, (130, 96, 58))
    military_crate("crate_military.png", 42)
    dumpster("dumpster_green.png", 43, (52, 96, 60))
    dumpster("dumpster_blue.png", 44, (44, 70, 120))
    barrel("barrel_blue.png", 45, (40, 70, 130))
    barrel("barrel_rust.png", 46, (110, 60, 36))
    pallet("pallet.png", 47)
    manhole("manhole.png", 48)
    crosswalk("crosswalk.png")
    road_line("line_white.png", (225, 222, 210))
    road_line("line_yellow.png", (230, 190, 40))
    puddle("puddle.png", 49)
    chainlink("chainlink.png")
    trash_decal("trash.png", 50)

    print("Schilder")
    neon_sign("sign_bar.png", "BAR", (255, 50, 60))
    neon_sign("sign_24h.png", "24時間営業", (60, 220, 255), cjk=True)
    neon_sign("sign_pharmacy.png", "薬局", (60, 255, 120), vertical=True, cjk=True, w=80, h=176)
    neon_sign("sign_hotel.png", "ホテル", (255, 70, 60), vertical=True, cjk=True, w=80, h=200)
    neon_sign("sign_vacancy.png", "空室", (255, 60, 120), cjk=True, w=160, h=80)
    neon_sign("sign_ngc7.png", "NG-C7", (120, 140, 255), w=224, h=96)
    neon_sign("sign_ramen.png", "ラーメン", (255, 170, 40), cjk=True)
    neon_sign("sign_hotel2.png", "ホテル 空室", (230, 230, 210), cjk=True, w=224, h=112)
    neon_sign("sign_shop.png", "東龍堂", (255, 160, 40), cjk=True, w=256, h=96, board=(60, 20, 16))
    neon_sign("sign_noodles.png", "NOODLES", (255, 60, 200))
    neon_sign("sign_open.png", "OPEN", (80, 255, 200), w=160, h=72)
    painted_sign("sign_beware.png", "BEWARE", (220, 60, 40), (30, 26, 24))
    painted_sign("sign_a2.png", "A2", (230, 220, 200), (60, 62, 60), w=96, h=64)
    painted_sign("sign_07.png", "07", (220, 210, 190), (50, 50, 52), w=64, h=48)
    painted_sign("sign_noentry.png", "立入禁止", (240, 240, 230), (170, 30, 30), w=160, h=64, cjk=True)
    stencil("stencil_a2.png", "A2")
    stencil("stencil_07.png", "07")
    graffiti("graffiti_1.png", "DETH", [(160, 60, 220), (90, 230, 120)], 51)
    graffiti("graffiti_2.png", "NEON", [(250, 80, 160), (250, 220, 60)], 52)
    graffiti("graffiti_3.png", "SLMZ", [(80, 200, 255), (255, 255, 255)], 53)
    tag_scribble("tag_1.png", 54, (230, 230, 230))
    tag_scribble("tag_2.png", 55, (40, 220, 140))
    poster("poster_1.png", 56, "EXO//9")
    poster("poster_2.png", 57, "飲む", cjk=True)
    poster("poster_3.png", 58, "RIOT")
    poster("poster_4.png", 59, "ネオン", cjk=True)


if __name__ == "__main__":
    main()
