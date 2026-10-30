extends SceneTree
## Optionsmenü: Kopf und Knöpfe bleiben sichtbar, die Liste scrollt.
##
## Aufruf: godot --headless --path . -s res://tools/tests/test_options_scroll.gd
## Letzte Zeile: "CHECKS n FAILS m".

var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  FAIL " + what)
	else:
		print("  ok   " + what)


func _run() -> void:
	await process_frame
	var host := Control.new()
	host.custom_minimum_size = Vector2(620, 430)
	host.size = Vector2(620, 430)
	root.add_child(host)
	var options := load("res://scenes/options/options_menu.tscn").instantiate() as Control
	options.set_anchors_preset(Control.PRESET_FULL_RECT)
	options.offset_right = 0
	options.offset_bottom = 0
	host.add_child(options)
	await process_frame
	await process_frame
	var scroll := options.get_node(^"Tabs/ContentScroll") as ScrollContainer
	var audio := options.get_node(^"Tabs/AudioScroll") as ScrollContainer
	var controls := options.get_node(^"Tabs/ControlsScroll") as ScrollContainer
	var apply := options.get_node(^"%ApplyButton") as Button
	var header := options.get_node(^"Header") as Control
	var fog := options.get("volumetric_check") as Control
	var host_rect := host.get_global_rect()
	var apply_rect := apply.get_global_rect()
	var header_rect := header.get_global_rect()
	_check(options.get_node(^"Tabs").get_tab_title(0) == "GRAFIK", "Reiter bleibt GRAFIK")
	_check(options.get_node(^"Tabs").get_tab_title(1) == "AUDIO", "Reiter bleibt AUDIO")
	_check(options.get_node(^"Tabs").get_tab_title(2) == "STEUERUNG", "Reiter bleibt STEUERUNG")
	_check(header_rect.position.y >= host_rect.position.y - 1.0, "Kopf oben im Feld")
	_check(apply_rect.end.y <= host_rect.end.y + 1.0, "Übernehmen unten im Feld (y %.1f / %.1f)" % [apply_rect.end.y, host_rect.end.y])
	_check(apply_rect.position.y > scroll.get_global_rect().position.y, "Knöpfe unter der Liste")
	for box: ScrollContainer in [scroll, audio, controls]:
		_check(box.mouse_filter == Control.MOUSE_FILTER_PASS, "%s Mausfilter PASS" % box.name)
		_check(box.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s kein Quer-Scroll" % box.name)
		_check(box.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "%s Hoch-Scroll automatisch" % box.name)
		_check(box.follow_focus, "%s folgt dem Fokus" % box.name)
	var bar := scroll.get_v_scroll_bar()
	_check(bar.max_value > scroll.size.y, "Grafik scrollt (inhalt %.1f, sicht %.1f)" % [bar.max_value, scroll.size.y])
	fog.grab_focus()
	await process_frame
	_check(scroll.scroll_vertical > 0, "Fokus auf Volumetrischer Nebel scrollt auf %d" % scroll.scroll_vertical)
	scroll.scroll_vertical = int(bar.max_value)
	await process_frame
	var fog_rect := fog.get_global_rect()
	var scroll_rect := scroll.get_global_rect()
	_check(fog_rect.end.y <= scroll_rect.end.y + 2.0 and fog_rect.position.y >= scroll_rect.position.y - 2.0, "Nebel liegt im sichtbaren Scrollbereich")
	_check(apply.get_global_rect().end.y <= host_rect.end.y + 1.0, "Übernehmen bleibt nach dem Scrollen sichtbar")
	var min_h := options.get_combined_minimum_size().y
	_check(min_h <= 430.0, "Options-Mindesthöhe %.1f passt ins 430-px-Feld" % min_h)
	host.queue_free()
	await _check_pause_menu()
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(_fails)


## Im Pausemenü sitzen die Optionen in einem CenterContainer. Ohne Mindestgröße klappten
## die Scroll-Listen dort auf Höhe 0 zusammen und ingame war nur der Kopf zu sehen.
func _check_pause_menu() -> void:
	var pause := load("res://scenes/pause/pause_menu.tscn").instantiate() as CanvasLayer
	root.add_child(pause)
	await process_frame
	pause.call("open")
	pause.call("_show_options")
	await process_frame
	await process_frame
	var options := pause.get_node(^"%Options") as Control
	var scroll := options.get_node(^"Tabs/ContentScroll") as ScrollContainer
	var fullscreen := options.get_node(^"%FullscreenCheck") as Control
	_check(options.visible, "Pausemenü zeigt die Optionen")
	_check(scroll.size.y > 200.0, "Pausemenü: Grafikliste %.1f px hoch" % scroll.size.y)
	_check(fullscreen.is_visible_in_tree() and fullscreen.get_global_rect().intersects(scroll.get_global_rect()), "Pausemenü: Vollbild-Schalter sichtbar")
	var view := pause.get_viewport().get_visible_rect()
	var apply := options.get_node(^"%ApplyButton") as Control
	_check(view.encloses(apply.get_global_rect()), "Pausemenü: Übernehmen im Bild")
	pause.call("close")
	pause.queue_free()
	await process_frame
