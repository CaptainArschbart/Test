extends Node3D
## Spielwelt: Licht, Test-Level, Spieler und Pausemenü. Spiel-Logik auf Szenenebene kommt hierher.
## F11 gilt hier nur, solange das Spiel läuft. Bei offenem Pausemenü übernimmt es das Menü selbst.


func _unhandled_input(event: InputEvent) -> void:
	# F11 wechselt zwischen Fenster und Vollbild.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		Settings.toggle_fullscreen()
