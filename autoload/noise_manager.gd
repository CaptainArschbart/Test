extends Node
## Hörradius für Einbruch und andere laute Aktionen (Autoload "NoiseManager").
##
## Gibt das Geräusch an StealthNoise weiter (Gruppe noise_listener, hear_noise)
## und meldet es zusätzlich über das Signal `heard`.

signal heard(position: Vector3, radius: float, kind: StringName)


func emit_noise(position: Vector3, radius: float, source: Node = null, kind: StringName = StealthNoise.BURGLARY) -> void:
	if radius <= 0.0:
		return
	heard.emit(position, radius, kind)
	StealthNoise.emit(get_tree(), position, radius, source, kind)
