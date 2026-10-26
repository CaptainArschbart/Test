@tool
class_name SlumCables
extends SlumPiece
## Kabel und Lampion-Ketten zwischen Punkten (Strommasten, Fassaden, Dächer).
##
## points sind lokale Positionen. Zwischen je zwei aufeinanderfolgenden Punkten hängt ein Kabel
## mit Durchhang sag. bundle > 1 legt mehrere Kabel leicht versetzt nebeneinander.
## Jeder Punkt braucht einen Halt: eine Wand, einen Mast (Strommast-Prop) oder einen eigenen Mast
## aus poles (Index des Punkts), der bis pole_ground hinunter reicht. Punkte ohne Mast bekommen
## einen kleinen Wandhalter.

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
## Punkte (Index), unter denen ein eigener Mast bis zum Boden steht.
@export var poles := PackedInt32Array():
	set(v):
		poles = v
		queue_rebuild()
## Lokale Höhe des Bodens unter den Masten.
@export var pole_ground := 0.0:
	set(v):
		pole_ground = v
		queue_rebuild()
## Holzmast statt Stahlrohr.
@export var wooden_poles := false:
	set(v):
		wooden_poles = v
		queue_rebuild()
## Wandhalter an Punkten ohne Mast (aus, wenn der Punkt an einem Strommast hängt).
@export var wall_brackets := true:
	set(v):
		wall_brackets = v
		queue_rebuild()
## Lampions entlang des ersten Kabels.
@export var lanterns := false:
	set(v):
		lanterns = v
		queue_rebuild()


func _build(b: SlumBuilder) -> void:
	var cable := SlumMats.color(Color(0.025, 0.025, 0.03), 0.0, 0.6)
	_anchors(b)
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


## Masten und Wandhalter an den Punkten.
func _anchors(b: SlumBuilder) -> void:
	var metal := SlumMats.color(Color(0.16, 0.17, 0.18), 0.0, 0.55, 0.6)
	var post_mat: Material = SlumMats.surface("wood_dark") if wooden_poles else metal
	var foot := SlumMats.surface("concrete_dark")
	for i: int in points.size():
		var p := points[i]
		if poles.has(i):
			var base := Vector3(p.x, pole_ground, p.z)
			var top := p + Vector3.UP * 0.35
			var r := 0.09 if wooden_poles else 0.07
			b.cylinder(base, r, top.y - base.y, post_mat, 8)
			b.collider(base + Vector3.UP * (top.y - base.y) * 0.5, Vector3(r * 2.0, top.y - base.y, r * 2.0))
			b.box(base + Vector3.UP * 0.1, Vector3(0.36, 0.2, 0.36), foot)
			b.box(top, Vector3(0.22, 0.06, 0.22), metal, false)
			# Ausleger, an dem die Kabel hängen
			b.box(p + Vector3.UP * 0.05, Vector3(0.5, 0.06, 0.06), metal, false)
		elif wall_brackets and (i == 0 or i == points.size() - 1):
			b.box(p, Vector3(0.12, 0.12, 0.12), metal, false)
