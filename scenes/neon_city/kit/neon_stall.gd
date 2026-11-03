@tool
class_name NeonStall
extends SlumPiece
## Marktbude der Neon City: Theke vorn (+Z), Rückwand, Vordach auf vier Pfosten mit Neonkante,
## Ware auf der Theke, Leuchtschild. Grundfläche 3 × 2,4 m, Ursprung = Bodenmitte.
## Kollision: Theke und Rückwand, unter dem Vordach steht man frei.

@export var accent := 0:
	set(v):
		accent = v
		queue_rebuild()
@export var cloth := Color(0.55, 0.15, 0.25):
	set(v):
		cloth = v
		queue_rebuild()

const W := 3.0
const D := 2.4
const ROOF := 2.5


func _detail_range() -> float:
	return 80.0


func _build(b: SlumBuilder) -> void:
	var wood := NeonMats.flat(Color(0.36, 0.26, 0.18))
	var metal := NeonMats.flat(NeonMats.METAL, 0.5, 0.5)
	var neon := NeonMats.neon(accent)
	var hz := D * 0.5
	b.box(Vector3(0, 0.5, hz - 0.35), Vector3(W, 1.0, 0.6), wood)
	b.box(Vector3(0, 1.02, hz - 0.33), Vector3(W + 0.1, 0.05, 0.7), NeonMats.flat(Color(0.2, 0.2, 0.22)), false)
	b.box(Vector3(0, ROOF * 0.5, -hz + 0.05), Vector3(W, ROOF, 0.1), wood)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box(Vector3(sx * (W * 0.5 - 0.05), ROOF * 0.5, sz * (hz - 0.05)), Vector3(0.08, ROOF, 0.08), metal, false)
	b.box_x(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(8.0)), Vector3(0, ROOF + 0.12, 0.15)), Vector3(W + 0.4, 0.08, D + 0.6),
			NeonMats.flat(cloth), false)
	b.box(Vector3(0, ROOF - 0.02, hz + 0.45), Vector3(W + 0.4, 0.06, 0.06), NeonMats.glow(neon, 3.0), false, false)
	# Ware: kleine bunte Kisten und Schalen.
	for k in 5:
		var x := -W * 0.5 + 0.35 + k * 0.58
		var c := Color.from_hsv(rng.randf(), 0.6, 0.8)
		b.box(Vector3(x, 1.12, hz - 0.35), Vector3(0.4, rng.randf_range(0.12, 0.3), 0.35), NeonMats.flat(c), false)
	# Schild an der Rückwand.
	b.quad(Vector3(0, ROOF - 0.5, -hz + 0.11), Vector3.BACK, W * 0.7, 0.45, NeonMats.glow(neon, 2.2))
	b.quad(Vector3(0, 1.6, -hz + 0.11), Vector3.BACK, W * 0.8, 0.6, NeonMats.glow(Color(1.0, 0.85, 0.6), 0.5))
