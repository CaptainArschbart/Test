@tool
class_name NeonSkywalk
extends SlumPiece
## Fußgängerbrücke der Neon City entlang der lokalen Z-Achse. Ursprung = Mitte der Brücke auf dem
## Boden, die Lauffläche liegt bei `height`. Geländer links und rechts, an den Enden offen, wenn
## dort eine Treppe oder eine andere Brücke anschließt. Stützen bis zum Boden, Neonband unten.

@export var length := 20.0:
	set(v):
		length = v
		queue_rebuild()
@export var width := 3.0:
	set(v):
		width = v
		queue_rebuild()
@export var height := 7.0:
	set(v):
		height = v
		queue_rebuild()
## Geländer quer an den Enden schließen (sonst offen für Anschlüsse).
@export var close_start := false:
	set(v):
		close_start = v
		queue_rebuild()
@export var close_end := false:
	set(v):
		close_end = v
		queue_rebuild()
## Seitengeländer links (-X) und rechts (+X); aus, wo seitlich eine Brücke anschließt.
@export var rail_left := true:
	set(v):
		rail_left = v
		queue_rebuild()
@export var rail_right := true:
	set(v):
		rail_right = v
		queue_rebuild()
## Stützen alle n Meter (0 = keine, z. B. zwischen zwei Häusern).
@export var pillar_spacing := 14.0:
	set(v):
		pillar_spacing = v
		queue_rebuild()
## Stützen nicht hier (lokale z), z. B. über einer Fahrbahn.
@export var pillar_gap := Vector2(0, 0):
	set(v):
		pillar_gap = v
		queue_rebuild()
@export var accent := 1:
	set(v):
		accent = v
		queue_rebuild()

const DECK := 0.35


func _build(b: SlumBuilder) -> void:
	var deck := NeonMats.flat(Color(0.26, 0.27, 0.31))
	var metal := NeonMats.flat(NeonMats.METAL, 0.5, 0.5)
	var neon := NeonMats.glow(NeonMats.neon(accent), 2.8)
	var hl := length * 0.5
	var hw := width * 0.5
	b.box(Vector3(0, height - DECK * 0.5, 0), Vector3(width, DECK, length), deck)
	# Belag mit Neon-Leitlinie in der Mitte.
	b.quad(Vector3(0, height + 0.005, 0), Vector3.UP, 0.08, length - 0.6, neon)
	for s: float in [-1.0, 1.0]:
		var x := s * (hw - 0.05)
		b.box(Vector3(s * hw, height - DECK - 0.05, 0), Vector3(0.08, 0.08, length), neon, false, false)
		if (s < 0.0 and not rail_left) or (s > 0.0 and not rail_right):
			continue
		b.railing(Vector3(x, height, -hl + 0.1), Vector3(x, height, hl - 0.1), metal, 1.05, 1.6)
		# Glasbrüstung zwischen den Pfosten.
		b.quad_x(Transform3D(Basis(Vector3.UP, s * PI * 0.5), Vector3(x + s * 0.01, height + 0.5, 0)), length - 0.2, 0.9,
				NeonMats.glass(Color(0.2, 0.35, 0.45)))
	if close_start:
		b.railing(Vector3(-hw, height, -hl + 0.05), Vector3(hw, height, -hl + 0.05), metal, 1.05, 1.6)
	if close_end:
		b.railing(Vector3(-hw, height, hl - 0.05), Vector3(hw, height, hl - 0.05), metal, 1.05, 1.6)
	if pillar_spacing <= 0.0:
		return
	var n := maxi(1, int(length / pillar_spacing))
	for i in n + 1:
		var z := -hl + 0.5 + (length - 1.0) * float(i) / n
		if z > pillar_gap.x and z < pillar_gap.y:
			continue
		b.box(Vector3(0, (height - DECK) * 0.5, z), Vector3(0.6, height - DECK, 0.6), metal)
