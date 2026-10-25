extends Node3D
## Testmap "Neon District": Straße, Testzonen (Treppen, Rampen, Sprünge, Tunnel) und Platz.
##
## Die Geometrie steht komplett in testmap.tscn. Freie Plätze für Items sind
## Marker3D-Knoten in der Gruppe "item_spawn" (unter Pickups/SpawnPoints).


func _unhandled_input(event: InputEvent) -> void:
	# F11 wechselt zwischen Fenster und Vollbild.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		Settings.toggle_fullscreen()
