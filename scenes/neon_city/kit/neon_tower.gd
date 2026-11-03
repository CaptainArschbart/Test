@tool
class_name NeonTower
extends SlumPiece
## Gebäude der Neon City im flachen Low-Poly-Look: Konzernturm, Wohnblock, Lagerhalle, Laden.
##
## Ursprung = Bodenmitte der Grundfläche, Vorderseite (Straße, Laden, Schild) zeigt nach +Z.
## Bis zu zwei Rücksprünge (setbacks) machen Türme schlanker nach oben. Kollision: eine Box pro
## Stufe, das Haus ist nicht begehbar, Dächer sind betretbar (Brüstung ringsum).
## Fenster sind Quads vor der Fassade, ein Teil leuchtet (lit_ratio), alles landet in wenigen
## Materialien (NeonMats), damit hunderte Häuser wenige Draw-Calls kosten.

enum Facade { GRID, BANDS, INDUSTRIAL }

## Farbpalette des Bezirks (core, harbor, blocks, neon, under).
@export var district := "core":
	set(v):
		district = v
		queue_rebuild()
@export var footprint := Vector2(16, 14):
	set(v):
		footprint = v
		queue_rebuild()
@export_range(1, 60) var floors := 6:
	set(v):
		floors = v
		queue_rebuild()
@export var floor_height := 3.2:
	set(v):
		floor_height = v
		queue_rebuild()
@export var facade := Facade.GRID:
	set(v):
		facade = v
		queue_rebuild()
## Rücksprünge nach oben (0–2), jeder nimmt ringsum 15 % der Grundfläche weg.
@export_range(0, 2) var setbacks := 0:
	set(v):
		setbacks = v
		queue_rebuild()
## Fassadenfarbe aus der Bezirkspalette.
@export var color_index := 0:
	set(v):
		color_index = v
		queue_rebuild()
## Neonfarbe (NeonMats.NEON) für Kanten, Laden und Dachschild.
@export var accent := 0:
	set(v):
		accent = v
		queue_rebuild()
@export_range(0.0, 1.0) var lit_ratio := 0.4:
	set(v):
		lit_ratio = v
		queue_rebuild()
## Laden im Erdgeschoss vorn: Schaufenster, Tür, Markise, Leuchtschild.
@export var shop_front := false:
	set(v):
		shop_front = v
		queue_rebuild()
## Senkrechte Neonstreifen an den vorderen Kanten.
@export var corner_neon := false:
	set(v):
		corner_neon = v
		queue_rebuild()
## Werbetafel auf dem Dach.
@export var roof_billboard := false:
	set(v):
		roof_billboard = v
		queue_rebuild()
## Lampe vor dem Laden (echtes Licht, nur bei einem Teil der Häuser, kostet Leistung).
@export var street_light := false:
	set(v):
		street_light = v
		queue_rebuild()

const SHOP_HEIGHT := 4.0
const PARAPET := 0.9
const WINDOW_W := 1.1
const WINDOW_H := 1.4
const WINDOW_STEP := 2.7


func _build(b: SlumBuilder) -> void:
	var wall := NeonMats.flat(NeonMats.facade(district, color_index))
	var trim := NeonMats.flat(NeonMats.facade(district, color_index).darkened(0.35))
	var neon := NeonMats.neon(accent)
	var height := floors * floor_height
	var tiers := _tiers(height)
	for i in tiers.size():
		var t: Dictionary = tiers[i]
		var size: Vector2 = t["size"]
		var y0: float = t["y0"]
		var y1: float = t["y1"]
		b.box(Vector3(0, (y0 + y1) * 0.5, 0), Vector3(size.x, y1 - y0, size.y), wall)
		_windows(b, size, y0, y1, i == 0)
		_ledges(b, size, y0, y1, trim)
		_roof(b, size, y1, trim, i == tiers.size() - 1, neon)
	if shop_front:
		_shop(b, neon, trim)
	elif facade == Facade.INDUSTRIAL:
		_roller_doors(b, trim, neon)
	else:
		_entrance(b, trim, neon)
	if corner_neon:
		var top: float = tiers[0]["y1"]
		for sx: float in [-1.0, 1.0]:
			b.box(Vector3(sx * (footprint.x * 0.5 + 0.03), top * 0.5 + 0.5, footprint.y * 0.5 + 0.03),
					Vector3(0.14, top - 1.0, 0.14), NeonMats.glow(neon, 3.0), false, false)


## Stufen des Baukörpers: [{size, y0, y1}]. Rücksprünge erst ab dem dritten Stock.
func _tiers(height: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var count := setbacks + 1 if floors >= 6 else 1
	var y := 0.0
	for i in count:
		var shrink := 1.0 - 0.15 * i * 2.0
		var y1 := height if i == count - 1 else snappedf(height * (0.55 + 0.2 * i), floor_height)
		out.append({"size": footprint * shrink, "y0": y, "y1": y1})
		y = y1
	return out


## Fenster auf allen vier Seiten der Stufe. Im Erdgeschoss vorn sitzt Laden bzw. Eingang.
func _windows(b: SlumBuilder, size: Vector2, y0: float, y1: float, ground_tier: bool) -> void:
	var dark := NeonMats.flat(NeonMats.WINDOW_DARK, 0.2, 0.4)
	var first := int(round(y0 / floor_height))
	var last := int(round(y1 / floor_height))
	for side in 4:
		var normal: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][side]
		var along := size.x if side % 2 == 0 else size.y
		var depth := size.y if side % 2 == 0 else size.x
		var tangent := normal.cross(Vector3.UP)
		for f in range(first, last):
			if f == 0 and (side == 0 or facade == Facade.INDUSTRIAL):
				continue
			if facade == Facade.INDUSTRIAL and f < last - 1:
				continue
			var cy := f * floor_height + floor_height * 0.55
			var face := normal * (depth * 0.5 + 0.02)
			if facade == Facade.BANDS:
				# Durchgehendes Glasband, abschnittsweise beleuchtet.
				var seg := 3.2
				var n := maxi(1, int(along / seg))
				var w := along / n
				for k in n:
					var x := -along * 0.5 + w * (k + 0.5)
					var lit := rng.randf() < lit_ratio
					var mat: Material = NeonMats.glow(pick(NeonMats.WINDOW_LIGHT), 0.55) if lit else NeonMats.glass()
					b.quad(face + tangent * x + Vector3.UP * cy, normal, w - 0.12, floor_height * 0.62, mat)
			else:
				var n := maxi(1, int((along - 1.0) / WINDOW_STEP))
				var h := WINDOW_H if facade == Facade.GRID else 0.8
				for k in n:
					var x := -WINDOW_STEP * (n - 1) * 0.5 + WINDOW_STEP * k
					var lit := rng.randf() < lit_ratio
					var mat: Material = NeonMats.glow(pick(NeonMats.WINDOW_LIGHT), 0.65) if lit else dark
					b.quad(face + tangent * x + Vector3.UP * cy, normal, WINDOW_W, h, mat)


## Gesimse: alle vier Stockwerke ein schmaler Vorsprung, oben ein kräftigerer Abschluss.
func _ledges(b: SlumBuilder, size: Vector2, y0: float, y1: float, trim: Material) -> void:
	var every := 4 if facade != Facade.INDUSTRIAL else 100
	var f := int(round(y0 / floor_height)) + every
	while f * floor_height < y1 - 0.5:
		b.box_on(Vector3(0, f * floor_height, 0), Vector3(size.x + 0.2, 0.18, size.y + 0.2), trim, false)
		f += every
	b.box_on(Vector3(0, y1 - 0.15, 0), Vector3(size.x + 0.3, 0.3, size.y + 0.3), trim, false)


## Dach: Brüstung (begehbar umrandet), Technik. Nur das oberste Dach bekommt Antenne und Tafel.
func _roof(b: SlumBuilder, size: Vector2, top: float, trim: Material, highest: bool, neon: Color) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var y := top + PARAPET * 0.5
	b.box_on(Vector3(0, y, hz - 0.15), Vector3(size.x, PARAPET, 0.3), trim)
	b.box_on(Vector3(0, y, -hz + 0.15), Vector3(size.x, PARAPET, 0.3), trim)
	b.box_on(Vector3(hx - 0.15, y, 0), Vector3(0.3, PARAPET, size.y - 0.6), trim)
	b.box_on(Vector3(-hx + 0.15, y, 0), Vector3(0.3, PARAPET, size.y - 0.6), trim)
	var metal := NeonMats.flat(NeonMats.METAL, 0.5, 0.5)
	var units := clampi(int(size.x * size.y / 60.0), 1, 5)
	for i in units:
		var p := Vector3(rng.randf_range(-hx + 1.6, hx - 1.6), top + 0.55, rng.randf_range(-hz + 1.6, hz - 1.6))
		b.box(p, Vector3(1.4, 1.1, 1.0), metal)
		b.quad(p + Vector3(0, 0.2, 0.51), Vector3.BACK, 0.9, 0.5, NeonMats.flat(NeonMats.METAL.darkened(0.5)))
	if not highest:
		return
	if district in ["blocks", "under"] and size.x > 6.0:
		b.cylinder(Vector3(hx * 0.4, top, -hz * 0.4), 1.2, 2.6, NeonMats.flat(Color(0.35, 0.3, 0.26)), 10, true)
		b.cylinder(Vector3(hx * 0.4, top + 2.6, -hz * 0.4), 1.3, 0.5, metal, 10)
	if floors >= 14:
		b.tube(Vector3(-hx * 0.3, top, hz * 0.2), Vector3(-hx * 0.3, top + 6.0 + floors * 0.15, hz * 0.2), 0.12, metal, 6)
		b.box(Vector3(-hx * 0.3, top + 6.0 + floors * 0.15, hz * 0.2), Vector3(0.35, 0.35, 0.35),
				NeonMats.glow(Color(1, 0.1, 0.1), 4.0), false, false)
	if roof_billboard:
		var w := minf(size.x * 0.8, 12.0)
		var h := w * 0.4
		var base := top + 1.2
		for sx: float in [-0.4, 0.4]:
			b.box(Vector3(sx * w, base * 0.5 + top * 0.5, hz - 1.2), Vector3(0.25, base - top, 0.25), metal)
		b.box(Vector3(0, base + h * 0.5, hz - 1.2), Vector3(w + 0.3, h + 0.3, 0.35), metal)
		b.quad(Vector3(0, base + h * 0.5, hz - 1.0), Vector3.BACK, w, h, NeonMats.glow(neon.darkened(0.55), 1.2))
		for k in 3:
			b.quad(Vector3(0, base + h * (0.25 + 0.25 * k), hz - 0.99), Vector3.BACK, w * (0.8 - 0.15 * k), h * 0.08,
					NeonMats.glow(neon, 3.0))


## Laden vorn im Erdgeschoss: Schaufenster, Tür, Markise mit Neonkante, Leuchtschild.
func _shop(b: SlumBuilder, neon: Color, trim: Material) -> void:
	var hz := footprint.y * 0.5
	var w := footprint.x - 1.6
	var face := Vector3(0, 0, hz + 0.02)
	b.quad(face + Vector3(0, 1.6, 0), Vector3.BACK, w, 2.8, NeonMats.glass(Color(0.12, 0.16, 0.2)))
	# Innen leuchtet es warm durch die Scheibe.
	b.quad(face + Vector3(0, 1.4, -0.01), Vector3.BACK, w - 0.4, 1.6, NeonMats.glow(Color(1.0, 0.8, 0.55), 0.6))
	b.quad(face + Vector3(w * 0.3, 1.1, 0.01), Vector3.BACK, 1.1, 2.2, NeonMats.flat(Color(0.08, 0.08, 0.1), 0.4, 0.3))
	for x: float in [-w * 0.5, w * 0.5]:
		b.box(Vector3(x, 1.6, hz + 0.08), Vector3(0.2, 3.2, 0.16), trim, false)
	# Markise.
	var awn := NeonMats.flat(NeonMats.facade(district, color_index + 1).darkened(0.2))
	b.box_x(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(0, SHOP_HEIGHT - 0.6, hz + 0.75)),
			Vector3(w + 0.4, 0.12, 1.6), awn, false)
	b.box(Vector3(0, SHOP_HEIGHT - 0.78, hz + 1.55), Vector3(w + 0.4, 0.07, 0.07), NeonMats.glow(neon, 3.0), false, false)
	# Leuchtschild über der Markise.
	var sw := minf(w * 0.7, 7.0)
	b.box(Vector3(0, SHOP_HEIGHT + 0.35, hz + 0.12), Vector3(sw, 0.7, 0.2), NeonMats.flat(Color(0.06, 0.06, 0.08)), false)
	b.quad(Vector3(0, SHOP_HEIGHT + 0.35, hz + 0.23), Vector3.BACK, sw - 0.3, 0.42, NeonMats.glow(neon, 2.6))
	if street_light:
		add_light(Vector3(0, SHOP_HEIGHT - 1.2, hz + 1.6), neon.lerp(Color.WHITE, 0.4), 1.4, 7.0)


## Hauseingang vorn: Vordach, Tür, Nummernlicht.
func _entrance(b: SlumBuilder, trim: Material, neon: Color) -> void:
	var hz := footprint.y * 0.5
	b.quad(Vector3(0, 1.15, hz + 0.02), Vector3.BACK, 1.8, 2.3, NeonMats.flat(Color(0.07, 0.07, 0.09), 0.4, 0.3))
	b.box(Vector3(0, 2.6, hz + 0.6), Vector3(3.0, 0.15, 1.2), trim, false)
	b.box(Vector3(0, 2.5, hz + 1.18), Vector3(3.0, 0.05, 0.05), NeonMats.glow(neon, 2.5), false, false)
	if street_light:
		add_light(Vector3(0, 2.3, hz + 1.0), Color(1.0, 0.85, 0.65), 1.0, 5.0)


## Lagerhalle: zwei Rolltore vorn mit Warnstreifen und Lampe.
func _roller_doors(b: SlumBuilder, trim: Material, neon: Color) -> void:
	var hz := footprint.y * 0.5
	var door := NeonMats.flat(Color(0.38, 0.4, 0.42), 0.6, 0.3)
	var count := 2 if footprint.x > 12.0 else 1
	for i in count:
		var x := 0.0 if count == 1 else (i - 0.5) * footprint.x * 0.45
		b.quad(Vector3(x, 2.2, hz + 0.02), Vector3.BACK, 4.0, 4.4, door)
		for k in 5:
			b.quad(Vector3(x, 0.6 + k * 0.85, hz + 0.03), Vector3.BACK, 4.0, 0.06, NeonMats.flat(Color(0.25, 0.26, 0.28)))
		b.box(Vector3(x, 4.65, hz + 0.1), Vector3(4.3, 0.3, 0.2), NeonMats.glow(Color(1.0, 0.75, 0.1), 1.4), false, false)
	b.box(Vector3(0, footprint.y * 0.0 + 5.6, hz + 0.35), Vector3(0.5, 0.15, 0.5), NeonMats.glow(neon, 2.0), false, false)
	if street_light:
		add_light(Vector3(0, 5.2, hz + 1.0), Color(1.0, 0.8, 0.5), 1.2, 9.0)
