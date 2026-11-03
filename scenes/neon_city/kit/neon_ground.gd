@tool
class_name NeonGround
extends SlumPiece
## Bodenplatte der Neon City (Platz, Hof, Kreuzung, Gehwegecke), Mitte im Ursprung.
## Oberkante bei `height`, die Platte reicht 0,2 m nach unten. Optional ein Fugenraster.

@export var size := Vector2(10, 10):
	set(v):
		size = v
		queue_rebuild()
@export var height := 0.0:
	set(v):
		height = v
		queue_rebuild()
@export var color := Color(0.24, 0.24, 0.28):
	set(v):
		color = v
		queue_rebuild()
## Fugen alle n Meter (0 = keine).
@export var grid := 0.0:
	set(v):
		grid = v
		queue_rebuild()


func _detail_range() -> float:
	return 100.0


func _build(b: SlumBuilder) -> void:
	# Unterkante 0,2 m unter dem Boden bzw. unter der Oberkante, wenn die Platte tiefer liegt.
	var bottom := minf(height, 0.0) - 0.2
	b.box(Vector3(0, (height + bottom) * 0.5, 0), Vector3(size.x, height - bottom, size.y), NeonMats.flat(color))
	if grid <= 0.0:
		return
	var line := NeonMats.flat(color.darkened(0.3))
	var x := -size.x * 0.5 + grid
	while x < size.x * 0.5 - 0.01:
		b.quad(Vector3(x, height + 0.005, 0), Vector3.UP, 0.05, size.y, line)
		x += grid
	var z := -size.y * 0.5 + grid
	while z < size.y * 0.5 - 0.01:
		b.quad(Vector3(0, height + 0.005, z), Vector3.UP, size.x, 0.05, line)
		z += grid
