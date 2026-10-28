extends Node3D
## Schießstand in der Testmap: Pistole, SMG und Scharfschützengewehr auf dem Tisch (Kontaktgranaten
## daneben auf dem Boden), Scheiben
## auf 10, 20, 30 und 40 m plus eine fahrende Scheibe auf 25 m (gemessen ab der
## orangen Schusslinie). Eingang von Westen zwischen Schusslinie und 10-m-Scheibe.
##
## Die Tafel über dem Tisch zeigt den Schaden der ausgestellten Waffen (aus ihrer
## WeaponData) und zählt Treffer und Schaden aller Scheiben zusammen.

@export var weapons: Array[WeaponData] = []

var _hits := 0
var _damage := 0.0
var _last_damage := 0.0

@onready var board: Label3D = $Board


func _ready() -> void:
	for node in find_children("*", "", true, false):
		if node is ShootingTarget:
			node.hit.connect(_on_target_hit)
	Settings.changed.connect(_update_board)
	_update_board()


func _on_target_hit(damage: float, _total: float) -> void:
	_hits += 1
	_damage += damage
	_last_damage = damage
	_update_board()


func _update_board() -> void:
	var lines := PackedStringArray(["SCHIESSSTAND"])
	for weapon in weapons:
		if weapon != null:
			lines.append("%s · %s Schaden pro Schuss · %d Schuss" % [
				weapon.display_name, ShootingTarget._fmt(weapon.damage), weapon.magazine_size])
	if _hits == 0:
		var reload_key := Settings.key_name(Settings.key_bindings.get("reload", KEY_R))
		lines.append("Linksklick schießen · Rechtsklick zielen · %s nachladen" % reload_key)
	else:
		lines.append("Letzter Treffer %s · Gesamt %d Treffer, %s Schaden" % [
			ShootingTarget._fmt(_last_damage), _hits, ShootingTarget._fmt(_damage)])
	board.text = "\n".join(lines)
