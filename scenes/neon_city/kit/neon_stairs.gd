@tool
class_name NeonStairs
extends SlumPiece
## Gerade Treppe der Neon City: beginnt am Ursprung auf dem Boden (Oberkante `base`) und steigt in
## Richtung +Z bis `height`. Stufen 0,2 m hoch und 0,3 m tief, jede Stufe ist eine volle Box bis
## zum Boden (keine Lücken, Gegner-Navmesh kann sie hoch). Geländer links und rechts, oben ein
## Podest von `landing` Metern Länge.

@export var height := 7.0:
	set(v):
		height = v
		queue_rebuild()
@export var base := 0.15:
	set(v):
		base = v
		queue_rebuild()
@export var width := 2.4:
	set(v):
		width = v
		queue_rebuild()
@export var landing := 2.0:
	set(v):
		landing = v
		queue_rebuild()
@export var accent := 1:
	set(v):
		accent = v
		queue_rebuild()

const RISE := 0.2
const RUN := 0.3


## Länge auf dem Boden inklusive Podest (für den Generator).
static func footprint_length(p_height: float, p_base: float, p_landing: float) -> float:
	return ceili((p_height - p_base) / RISE) * RUN + p_landing


func _build(b: SlumBuilder) -> void:
	var step := NeonMats.flat(Color(0.3, 0.31, 0.35))
	var metal := NeonMats.flat(NeonMats.METAL, 0.5, 0.5)
	var steps := ceili((height - base) / RISE)
	var rise := (height - base) / steps
	var top := b.stairs(Vector3(0, base, 0), Vector3.BACK, steps, width, step, rise, RUN, true)
	var run := steps * RUN
	if landing > 0.0:
		b.box(Vector3(0, (top.y + base) * 0.5, run + landing * 0.5), Vector3(width, top.y - base, landing), step)
	var hw := width * 0.5 - 0.05
	for s: float in [-1.0, 1.0]:
		b.railing(Vector3(s * hw, base + rise, 0.15), Vector3(s * hw, top.y, run), metal, 1.0, 1.5, true)
		if landing > 0.0:
			b.railing(Vector3(s * hw, top.y, run), Vector3(s * hw, top.y, run + landing - 0.05), metal, 1.0, 1.5)
		b.box(Vector3(s * (width * 0.5 + 0.02), (top.y + base) * 0.25, run * 0.5), Vector3(0.05, 0.05, run),
				NeonMats.glow(NeonMats.neon(accent), 2.0), false, false)
