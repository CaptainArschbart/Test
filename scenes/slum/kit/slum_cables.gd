@tool
class_name SlumCables
extends SlumPiece
## Kabel und Lampion-Ketten zwischen Punkten (Strommasten, Fassaden, Dächer).
##
## points sind lokale Positionen. Zwischen je zwei aufeinanderfolgenden Punkten hängt ein Kabel
## mit Durchhang sag. bundle > 1 legt mehrere Kabel leicht versetzt nebeneinander.

@export var points := PackedVector3Array([Vector3(0, 6, 0), Vector3(0, 6, 10)]):
	set(v):
		points = v
		queue_rebuild()
@export var sag := 0.6:
	set(v):
		sag = v
		queue_rebuild()
@export_range(1, 6) var bundle := 3:
	set(v):
		bundle = v
		queue_rebuild()
## Lampions entlang des ersten Kabels.
@export var lanterns := false:
	set(v):
		lanterns = v
		queue_rebuild()


func _build(b: SlumBuilder) -> void:
	var cable := SlumMats.color(Color(0.025, 0.025, 0.03), 0.0, 0.6)
	for i: int in points.size() - 1:
		var a := points[i]
		var e := points[i + 1]
		for k: int in bundle:
			var off := Vector3(0, -0.12 * k, 0.05 * k)
			b.cable(a + off, e + off, sag + 0.15 * k, cable, 0.015, 10)
		if lanterns:
			var span := a.distance_to(e)
			var n := maxi(2, int(span / 1.6))
			for j: int in n:
				var t := (j + 0.5) / n
				var p := a.lerp(e, t) + Vector3.DOWN * (sag * 4.0 * t * (1.0 - t) + 0.25)
				var col: Color = pick([Color(1.0, 0.18, 0.12), Color(1.0, 0.5, 0.12), Color(1.0, 0.25, 0.45), Color(0.3, 0.9, 1.0)])
				b.box(p, Vector3(0.24, 0.32, 0.24), SlumMats.color(col, 3.5), false, false)
				b.box(p + Vector3.UP * 0.18, Vector3(0.12, 0.04, 0.12), cable, false, false)
			add_light(a.lerp(e, 0.5) + Vector3.DOWN * (sag + 0.6), Color(1.0, 0.45, 0.3), 1.2, maxf(5.0, span * 0.5), 0.05)
