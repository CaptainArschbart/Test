@tool
class_name SlumWalkway
extends SlumPiece
## Steg / Brücke aus Riffelblech oder Holz zwischen zwei Dächern oder Plattformen.
##
## Der Steg läuft entlang der lokalen Z-Achse (length), mittig um den Ursprung, Oberkante bei y = 0.
## Geländer auf beiden Seiten, optional Stützen bis zum Boden (support_height).

@export var length := 6.0:
	set(v):
		length = v
		queue_rebuild()
@export var width := 1.4:
	set(v):
		width = v
		queue_rebuild()
## Holzbohlen statt Riffelblech.
@export var wooden := false:
	set(v):
		wooden = v
		queue_rebuild()
## Höhe bis zum Boden für Stützen (0 = frei hängend).
@export var support_height := 0.0:
	set(v):
		support_height = v
		queue_rebuild()
## Lampions am Geländer.
@export var lanterns := false:
	set(v):
		lanterns = v
		queue_rebuild()


func _build(b: SlumBuilder) -> void:
	var deck := SlumMats.surface("wood") if wooden else SlumMats.surface("metal_plate")
	var rail := SlumMats.surface("wood_dark") if wooden else SlumMats.color(Color(0.16, 0.17, 0.18), 0.0, 0.55, 0.6)
	b.box(Vector3(0, -0.06, 0), Vector3(width, 0.12, length), deck)
	var hw := width * 0.5
	var hl := length * 0.5
	b.railing(Vector3(-hw, 0, -hl), Vector3(-hw, 0, hl), rail, 1.0, 1.2)
	b.railing(Vector3(hw, 0, -hl), Vector3(hw, 0, hl), rail, 1.0, 1.2)
	# Träger unter dem Deck
	for x: float in [-hw + 0.05, hw - 0.05]:
		b.box(Vector3(x, -0.2, 0), Vector3(0.08, 0.2, length), rail, false)
	if support_height > 0.1:
		var count := maxi(1, int(length / 4.0))
		for i: int in count + 1:
			var z := -hl + 0.2 + (length - 0.4) * float(i) / count
			for x: float in [-hw + 0.08, hw - 0.08]:
				b.box(Vector3(x, -support_height * 0.5, z), Vector3(0.12, support_height, 0.12), rail, true)
	if lanterns:
		var cable := SlumMats.color(Color(0.03, 0.03, 0.03))
		b.cable(Vector3(-hw, 1.9, -hl), Vector3(-hw, 1.9, hl), 0.4, cable, 0.012)
		for i: int in int(length / 1.5):
			var t := (i + 0.5) / int(length / 1.5)
			var z := -hl + length * t
			var y := 1.9 - 0.4 * 4.0 * t * (1.0 - t) - 0.3
			var col: Color = pick([Color(1.0, 0.2, 0.15), Color(1.0, 0.55, 0.15), Color(1.0, 0.3, 0.5)])
			b.box(Vector3(-hw, y, z), Vector3(0.22, 0.3, 0.22), SlumMats.color(col, 3.0), false, false)
		add_light(Vector3(0, 1.4, 0), Color(1.0, 0.4, 0.25), 1.0, maxf(4.0, length * 0.6), 0.05)
