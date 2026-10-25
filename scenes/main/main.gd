extends Node3D
## Spielwelt: Licht, Test-Level und Spieler.
## F11 schaltet Vollbild und schreibt dasselbe Flag wie das Hauptmenü.

const Settings := preload("res://scripts/game_settings.gd")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var enable_fullscreen := DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if enable_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		)
		Settings.set_fullscreen(enable_fullscreen)
