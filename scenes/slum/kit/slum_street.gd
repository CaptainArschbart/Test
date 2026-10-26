@tool
class_name SlumStreet
extends SlumPiece
## Straßenkit: Straßenstück mit Gehwegen und Bordstein, Kreuzung oder einfache Bodenplatte.
##
## ROAD: Straße entlang der lokalen Z-Achse (length), mittig. Gehwege links (-X) und rechts (+X)
## liegen 0,15 m höher, der Bordstein ist damit eine kleine Stufe. Laternen stehen auf dem Gehweg.
## INTERSECTION: quadratische Kreuzung (road_width × road_width) mit Zebrastreifen an allen Seiten.
## SLAB: Platte mit beliebiger Textur (Hof, Platz, Gasse), Oberkante bei y = height.

enum Kind { ROAD, INTERSECTION, SLAB }

@export var kind := Kind.ROAD:
	set(v):
		kind = v
		queue_rebuild()
@export var length := 20.0:
	set(v):
		length = v
		queue_rebuild()
@export var road_width := 9.0:
	set(v):
		road_width = v
		queue_rebuild()
@export var sidewalk_left := 3.0:
	set(v):
		sidewalk_left = v
		queue_rebuild()
@export var sidewalk_right := 3.0:
	set(v):
		sidewalk_right = v
		queue_rebuild()
## Mittellinie (gelb gestrichelt) zeichnen.
@export var center_line := true:
	set(v):
		center_line = v
		queue_rebuild()
## Zebrastreifen am Anfang (-Z) und/oder Ende (+Z).
@export var crosswalk_start := false:
	set(v):
		crosswalk_start = v
		queue_rebuild()
@export var crosswalk_end := false:
	set(v):
		crosswalk_end = v
		queue_rebuild()
## Abstand der Laternen (0 = keine). Sie stehen abwechselnd links und rechts.
@export var lamp_spacing := 11.0:
	set(v):
		lamp_spacing = v
		queue_rebuild()
## Für SLAB: Textur und Breite (x) × Länge (z).
@export var slab_texture := "concrete_dark":
	set(v):
		slab_texture = v
		queue_rebuild()
@export var slab_size := Vector2(10, 10):
	set(v):
		slab_size = v
		queue_rebuild()
@export var height := 0.0:
	set(v):
		height = v
		queue_rebuild()
## Pfützen und Müll-Decals.
@export_range(0.0, 1.0) var dirt := 0.5:
	set(v):
		dirt = v
		queue_rebuild()

const CURB_H := 0.15
## Höhe der Bodenmarkierungen über der Fläche. Jede Art eine eigene Ebene, mindestens 1 cm
## auseinander, damit Überlappungen (Linie unter Zebrastreifen, Pfütze über Gully) nicht flackern.
const LAYER_LINE := 0.015
const LAYER_CROSSWALK := 0.025
const LAYER_MANHOLE := 0.035
const LAYER_PUDDLE := 0.045
const LAYER_TRASH := 0.055


func _build(b: SlumBuilder) -> void:
	match kind:
		Kind.ROAD: _road(b)
		Kind.INTERSECTION: _intersection(b)
		Kind.SLAB: _slab(b)


func _road(b: SlumBuilder) -> void:
	var asphalt := SlumMats.wet("asphalt")
	var hw := road_width * 0.5
	b.box(Vector3(0, -0.25, 0), Vector3(road_width, 0.5, length), asphalt)
	_sidewalk(b, -1.0, sidewalk_left)
	_sidewalk(b, 1.0, sidewalk_right)
	if center_line:
		var yellow := SlumMats.decal("line_yellow")
		var dash := 3.0
		var z := -length * 0.5 + 1.0
		while z + dash <= length * 0.5 - 0.5:
			b.quad_x(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, LAYER_LINE, z + dash * 0.5)), 0.15, dash, yellow)
			z += dash * 2.0
	# Randlinien
	var white := SlumMats.decal("line_white")
	for side: float in [-1.0, 1.0]:
		b.quad_x(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(side * (hw - 0.35), LAYER_LINE, 0)), 0.12, length,
				white, Rect2(0, 0, 1, length / 4.0))
	if crosswalk_start:
		_crosswalk(b, Vector3(0, LAYER_CROSSWALK, -length * 0.5 + 2.0), road_width, false)
	if crosswalk_end:
		_crosswalk(b, Vector3(0, LAYER_CROSSWALK, length * 0.5 - 2.0), road_width, false)
	# Gullydeckel und Pfützen
	var manhole := SlumMats.decal("manhole")
	for i: int in int(length / 12.0) + 1:
		var p := Vector3(rng.randf_range(-hw * 0.5, hw * 0.5), LAYER_MANHOLE, rng.randf_range(-length * 0.45, length * 0.45))
		b.quad_x(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), p), 0.8, 0.8, manhole)
	_dirt(b, Vector2(road_width, length), 0.0)
	# Laternen
	if lamp_spacing > 0.0:
		var count := int(length / lamp_spacing)
		for i: int in count:
			var z := -length * 0.5 + lamp_spacing * (i + 0.5)
			var side := -1.0 if i % 2 == 0 else 1.0
			var walk := sidewalk_left if side < 0 else sidewalk_right
			if walk < 1.0:
				continue
			var lamp := SlumProp.new()
			lamp.kind = SlumProp.Kind.STREET_LAMP
			lamp.variant = 2 if rng.randf() < 0.2 else (1 if i == 0 else 0)
			lamp.name = "Lamp%d" % i
			add_gen(lamp, Vector3(side * (hw + 0.45), CURB_H, z))
			lamp.rotation.y = PI * 0.5 if side < 0 else -PI * 0.5


func _sidewalk(b: SlumBuilder, side: float, width: float) -> void:
	if width <= 0.01:
		return
	var hw := road_width * 0.5
	var walk := SlumMats.wet("sidewalk", Color(0.9, 0.9, 0.92))
	var curb := SlumMats.surface("curb")
	var cx := side * (hw + 0.1)
	b.box(Vector3(cx, CURB_H * 0.5 - 0.15, 0), Vector3(0.2, CURB_H + 0.3, length), curb)
	var wx := side * (hw + 0.2 + (width - 0.2) * 0.5)
	b.box(Vector3(wx, CURB_H * 0.5 - 0.15, 0), Vector3(width - 0.2, CURB_H + 0.3, length), walk)
	# Gelbe Bordsteinkante
	var paint := SlumMats.decal("line_yellow")
	# Quad schaut zur Fahrbahn (-side), läuft entlang Z.
	b.quad_x(Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3(side * (hw - 0.015), CURB_H * 0.5, 0)),
			length, CURB_H, paint, Rect2(0, 0, length / 2.0, 1))


func _intersection(b: SlumBuilder) -> void:
	var asphalt := SlumMats.wet("asphalt_old")
	b.box(Vector3(0, -0.25, 0), Vector3(road_width, 0.5, road_width), asphalt)
	var hw := road_width * 0.5
	_crosswalk(b, Vector3(0, LAYER_CROSSWALK, -hw + 1.6), road_width - 1.0, false)
	_crosswalk(b, Vector3(0, LAYER_CROSSWALK, hw - 1.6), road_width - 1.0, false)
	_crosswalk(b, Vector3(-hw + 1.6, LAYER_CROSSWALK, 0), road_width - 1.0, true)
	_crosswalk(b, Vector3(hw - 1.6, LAYER_CROSSWALK, 0), road_width - 1.0, true)
	b.quad_x(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(1.2, LAYER_MANHOLE, -0.8)), 0.8, 0.8, SlumMats.decal("manhole"))
	_dirt(b, Vector2(road_width * 0.6, road_width * 0.6), 0.0)


## Zebrastreifen quer zur Fahrtrichtung. rotated = Streifen laufen entlang Z statt X.
func _crosswalk(b: SlumBuilder, center: Vector3, width: float, rotated: bool) -> void:
	var stripe := SlumMats.decal("crosswalk")
	var count := int(width / 1.0)
	for i: int in count:
		var off := -width * 0.5 + 0.5 + i * 1.0
		var p := center + (Vector3(0, 0, off) if rotated else Vector3(off, 0, 0))
		var basis := Basis(Vector3.RIGHT, -PI * 0.5)
		if rotated:
			basis = Basis(Vector3.UP, PI * 0.5) * basis
		b.quad_x(Transform3D(basis, p), 0.5, 2.6, stripe)


func _slab(b: SlumBuilder) -> void:
	var mat := SlumMats.wet(slab_texture) if slab_texture.begins_with("asphalt") or slab_texture.begins_with("sidewalk") \
			else SlumMats.surface(slab_texture)
	b.box(Vector3(0, height - 0.25, 0), Vector3(slab_size.x, 0.5, slab_size.y), mat)
	_dirt(b, slab_size * 0.8, height)


## Pfützen und Müll auf der Fläche mit Oberkante y. Alle Pfützen liegen in genau einer Ebene
## (gleiches Material, überlappend flackert das nicht), Müll eine Ebene darüber.
func _dirt(b: SlumBuilder, area: Vector2, y: float) -> void:
	var puddle := SlumMats.decal("puddle")
	var trash := SlumMats.decal("trash")
	var n := int(area.x * area.y / 60.0 * dirt)
	for i: int in n:
		var p := Vector3(rng.randf_range(-area.x * 0.5, area.x * 0.5), y, rng.randf_range(-area.y * 0.5, area.y * 0.5))
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, -PI * 0.5)
		if rng.randf() < 0.6:
			var s := rng.randf_range(1.0, 2.8)
			b.quad_x(Transform3D(basis, p + Vector3.UP * LAYER_PUDDLE), s, s * 0.7, puddle)
		else:
			b.quad_x(Transform3D(basis, p + Vector3.UP * LAYER_TRASH), 1.2, 1.2, trash)
