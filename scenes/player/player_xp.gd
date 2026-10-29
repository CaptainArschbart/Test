extends Node
## Erfahrung und Stufe des lokalen Spielers. Der Player legt den Knoten im Code an (Player.xp).
## Gegner rufen beim Tod add_xp(profile.xp_reward) auf. Bleibt über Tod und Respawn erhalten.
## Ohne class_name (wie CameraShake), der Player lädt das Skript per preload.
## Die Anzeige oben mittig ist XpHud (scenes/survival/xp_hud.gd).

## level, XP in der aktuellen Stufe, XP bis zur nächsten Stufe, gerade dazugekommen.
signal xp_changed(level: int, xp: int, needed: int, gained: int)
signal leveled_up(level: int)

const MAX_LEVEL := 50

var level := 1
## XP innerhalb der aktuellen Stufe (0 … needed() - 1).
var xp := 0
## Alles, was je dazukam.
var total_xp := 0


## XP von dieser Stufe zur nächsten: 100, 160, 220, …
static func needed_for(lvl: int) -> int:
	return 100 + (lvl - 1) * 60


func needed() -> int:
	return needed_for(level)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	total_xp += amount
	if level >= MAX_LEVEL:
		xp_changed.emit(level, xp, needed(), amount)
		return
	xp += amount
	var ups: Array[int] = []
	while xp >= needed() and level < MAX_LEVEL:
		xp -= needed()
		level += 1
		ups.append(level)
	if level >= MAX_LEVEL:
		xp = 0
	xp_changed.emit(level, xp, needed(), amount)
	for lvl in ups:
		leveled_up.emit(lvl)
