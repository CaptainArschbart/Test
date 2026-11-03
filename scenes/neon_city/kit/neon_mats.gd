@tool
class_name NeonMats
extends RefCounted
## Materialien des Neon-City-Baukastens: flache Farben ohne Texturen (Low-Poly-Look), dazu Neon,
## Fenster und Glas. Alle Materialien sind gecacht, damit gleiche Farben über die ganze Map ein
## Material teilen und SlumBuilder sie zu wenigen Draw-Calls zusammenfassen kann.

## Fassadenfarben der Bezirke (gedeckt, damit Neon heraussticht).
const FACADES := {
	&"core": [Color(0.16, 0.18, 0.24), Color(0.22, 0.24, 0.3), Color(0.12, 0.13, 0.17), Color(0.28, 0.3, 0.36)],
	&"harbor": [Color(0.32, 0.3, 0.27), Color(0.25, 0.3, 0.33), Color(0.4, 0.33, 0.24), Color(0.22, 0.24, 0.22)],
	&"blocks": [Color(0.42, 0.36, 0.33), Color(0.3, 0.33, 0.4), Color(0.36, 0.4, 0.38), Color(0.46, 0.42, 0.36)],
	&"neon": [Color(0.2, 0.14, 0.24), Color(0.14, 0.12, 0.2), Color(0.26, 0.16, 0.2), Color(0.18, 0.2, 0.26)],
	&"under": [Color(0.36, 0.3, 0.24), Color(0.3, 0.34, 0.3), Color(0.42, 0.28, 0.24), Color(0.28, 0.26, 0.3)],
}
## Neonfarben für Kanten, Schilder und Leuchtstreifen.
const NEON := [Color(1.0, 0.15, 0.6), Color(0.0, 0.9, 1.0), Color(0.65, 0.3, 1.0), Color(1.0, 0.55, 0.1),
	Color(0.2, 1.0, 0.45), Color(1.0, 0.9, 0.2)]
## Fensterlicht: meist warm, seltener kühl (Bildschirme), ganz selten rosa (Neon im Zimmer).
const WINDOW_LIGHT := [Color(1.0, 0.8, 0.52), Color(1.0, 0.8, 0.52), Color(0.98, 0.88, 0.68), Color(1.0, 0.8, 0.52),
	Color(0.6, 0.8, 0.98), Color(0.6, 0.8, 0.98), Color(0.95, 0.55, 0.8)]

const ASPHALT := Color(0.09, 0.09, 0.11)
const SIDEWALK := Color(0.3, 0.3, 0.33)
const CURB := Color(0.45, 0.45, 0.48)
const PLAZA := Color(0.24, 0.24, 0.28)
const MARKING := Color(0.85, 0.85, 0.8)
const METAL := Color(0.2, 0.21, 0.24)
const WINDOW_DARK := Color(0.05, 0.06, 0.09)

static var _cache := {}


## Matte Flachfarbe. rough 0..1, metal 0..1.
static func flat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var key := "flat_%s_%.2f_%.2f" % [color.to_html(), rough, metal]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		_cache[key] = m
	return _cache[key]


## Leuchtende Farbe (Neonröhren, Fenster, Bildschirme).
static func glow(color: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "glow_%s_%.2f" % [color.to_html(), energy]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color.darkened(0.2)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		m.roughness = 0.5
		_cache[key] = m
	return _cache[key]


## Dunkles, leicht spiegelndes Glas (Schaufenster, Hochhausfassaden).
static func glass(tint := Color(0.1, 0.14, 0.2)) -> StandardMaterial3D:
	var key := "glass_%s" % tint.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = tint
		m.metallic = 0.6
		m.roughness = 0.12
		_cache[key] = m
	return _cache[key]


static func facade(district: StringName, index: int) -> Color:
	var list: Array = FACADES.get(district, FACADES[&"core"])
	return list[posmod(index, list.size())]


static func neon(index: int) -> Color:
	return NEON[posmod(index, NEON.size())]
