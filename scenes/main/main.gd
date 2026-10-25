extends Node3D
## Hauptszene: Welt, Licht und Spieler. Spiel-Logik auf Szenenebene kommt hierher.


func _unhandled_input(event: InputEvent) -> void:
	# F11 wechselt zwischen Fenster und Vollbild.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
