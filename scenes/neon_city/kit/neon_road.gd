@tool
class_name NeonRoad
extends SlumPiece
## Gerades Straßenstück der Neon City entlang der lokalen Z-Achse, Mitte im Ursprung.
##
## Fahrbahn (Oberkante 0), Gehwege links und rechts (Oberkante 0,15 m) mit Bordstein, Mittellinie
## gestrichelt oder als Grünstreifen mit Neonkante, Zebrastreifen an den Enden, Laternen am
## äußeren Gehwegrand. Nur jede `light_every`-te Laterne hat ein echtes Licht.

@export var length := 40.0:
	set(v):
		length = v
		queue_rebuild()
@export var road_width := 10.0:
	set(v):
		road_width = v
		queue_rebuild()
@export var sidewalk := 3.5:
	set(v):
		sidewalk = v
		queue_rebuild()
## Mittelstreifen (Breite in m, 0 = nur gestrichelte Linie).
@export var median := 0.0:
	set(v):
		median = v
		queue_rebuild()
@export var crosswalk_start := false:
	set(v):
		crosswalk_start = v
		queue_rebuild()
@export var crosswalk_end := false:
	set(v):
		crosswalk_end = v
		queue_rebuild()
## Abstand der Laternen (0 = keine).
@export var lamp_spacing := 18.0:
	set(v):
		lamp_spacing = v
		queue_rebuild()
@export var light_every := 3:
	set(v):
		light_every = v
		queue_rebuild()
## Keine Laterne bis 2,5 m um diese Stellen (lokale z), z. B. Gassenmündungen.
@export var lamp_skip := PackedFloat32Array():
	set(v):
		lamp_skip = v
		queue_rebuild()
@export var lamp_color := Color(0.75, 0.85, 1.0):
	set(v):
		lamp_color = v
		queue_rebuild()

const CURB_H := 0.15


func _detail_range() -> float:
	return 120.0


func _build(b: SlumBuilder) -> void:
	var asphalt := NeonMats.flat(NeonMats.ASPHALT, 0.75)
	var walk := NeonMats.flat(NeonMats.SIDEWALK)
	var curb := NeonMats.flat(NeonMats.CURB)
	var paint := NeonMats.flat(NeonMats.MARKING, 0.6)
	var hl := length * 0.5
	var hw := road_width * 0.5
	b.box(Vector3(0, -0.1, 0), Vector3(road_width, 0.2, length), asphalt)
	for s: float in [-1.0, 1.0]:
		var cx := s * (hw + sidewalk * 0.5)
		b.box(Vector3(cx, CURB_H * 0.5 - 0.05, 0), Vector3(sidewalk, CURB_H + 0.1, length), walk)
		b.box(Vector3(s * (hw + 0.12), CURB_H * 0.5, 0), Vector3(0.24, CURB_H + 0.02, length), curb, false)
		# Fugen im Gehweg alle 2 m.
		var k := -hl + 2.0
		while k < hl:
			b.quad(Vector3(cx, CURB_H + 0.005, k), Vector3.UP, sidewalk, 0.04, NeonMats.flat(NeonMats.SIDEWALK.darkened(0.25)))
			k += 2.0
	if median > 0.0:
		b.box(Vector3(0, 0.1, 0), Vector3(median, 0.2, length - 2.0), NeonMats.flat(Color(0.16, 0.22, 0.18)), true)
		for s: float in [-1.0, 1.0]:
			b.box(Vector3(s * median * 0.5, 0.21, 0), Vector3(0.06, 0.03, length - 2.0), NeonMats.glow(Color(0.0, 0.9, 1.0), 2.5), false, false)
	else:
		var z := -hl + 1.5
		while z < hl - 1.5:
			b.quad(Vector3(0, 0.005, z + 1.0), Vector3.UP, 0.15, 2.0, paint)
			z += 4.0
	for s: float in [-1.0, 1.0]:
		b.quad(Vector3(s * (hw - 0.35), 0.005, 0), Vector3.UP, 0.12, length, paint)
	if crosswalk_start:
		_crosswalk(b, -hl + 2.0, paint)
	if crosswalk_end:
		_crosswalk(b, hl - 2.0, paint)
	if lamp_spacing > 0.0:
		_lamps(b)


func _crosswalk(b: SlumBuilder, z: float, paint: Material) -> void:
	var x := -road_width * 0.5 + 0.6
	while x < road_width * 0.5 - 0.5:
		b.quad(Vector3(x, 0.006, z), Vector3.UP, 0.5, 3.0, paint)
		x += 1.0


func _lamps(b: SlumBuilder) -> void:
	var metal := NeonMats.flat(NeonMats.METAL, 0.5, 0.6)
	var head := NeonMats.glow(lamp_color, 3.0)
	var n := maxi(1, int(length / lamp_spacing))
	var step := length / n
	var index := 0
	for i in n:
		var z := -length * 0.5 + step * (i + 0.5)
		for s: float in [-1.0, 1.0]:
			var x := s * (road_width * 0.5 + sidewalk - 0.4)
			# Versetzt: links und rechts abwechselnd, damit nicht zwei Lichter nebeneinander stehen.
			if (i % 2 == 0) != (s < 0.0) or _skipped(z):
				continue
			b.cylinder(Vector3(x, CURB_H, z), 0.09, 6.0, metal, 6, true)
			b.box(Vector3(x - s * 0.9, 6.05, z), Vector3(1.8, 0.12, 0.18), metal, false)
			b.box(Vector3(x - s * 1.6, 5.92, z), Vector3(0.6, 0.12, 0.3), head, false, false)
			if light_every > 0 and index % light_every == 0:
				add_light(Vector3(x - s * 1.6, 5.4, z), lamp_color, 1.6, 14.0)
			index += 1


func _skipped(z: float) -> bool:
	for s in lamp_skip:
		if absf(z - s) < 2.5:
			return true
	return false
