extends Control
## Hauptmenü im Cyberpunk-Stil: Start, Spielstand laden, Optionen, Beenden.
##
## "Start" öffnet die Map-Auswahl (Buttons aus maps, im Code erzeugt, gleicher Stil wie das
## Hauptmenü).
##
## "Spielstand laden" ist ein Platzhalter und bleibt deaktiviert, bis es ein
## Speichersystem gibt.
##
## Die Optionen sind die gemeinsame Szene scenes/options/options_menu.tscn, dieselbe
## wie im Pausemenü. Sie bearbeitet eine Kopie der Einstellungen. Erst "Übernehmen"
## schreibt sie in den Autoload Settings (und damit nach user://settings.cfg).

const OptionsMenu := preload("res://scenes/options/options_menu.gd")

## Szene, die "Start" lädt, wenn maps leer ist.
@export_file("*.tscn") var game_scene := "res://scenes/testmap/testmap.tscn"
## Map-Auswahl nach "Start": Anzeigename -> Szene.
@export var maps: Dictionary[String, String] = {
	"SEKTOR 7 // SLUM": "res://scenes/slum/slum.tscn",
	"NEON DISTRICT // TESTMAP": "res://scenes/testmap/testmap.tscn",
}

@export_group("Glitch")
## Zeitraum (Sekunden), in dem zufällig ein schwacher Glitch kommt.
@export var glitch_interval_min := 5.0
@export var glitch_interval_max := 10.0
@export var glitch_duration := 0.12
## Stärke der zufälligen Glitches (0–1).
@export_range(0.0, 1.0) var glitch_strength := 0.3

var _glitch_timer := 0.0
var _glitch_left := 0.0
var _starting := false
var _net_launch := false
var _map_buttons: VBoxContainer
var _lobby: Control
var _net_box: VBoxContainer
var _ip_field: LineEdit
var _host_port: LineEdit
var _map_select: OptionButton
var _join_port: LineEdit
var _token_field: LineEdit
var _share_label: Label
var _copy_button: Button
var _play_button: Button
var _ngrok_button: Button
var _net_status: Label
var _share_address := ""
var _ip_http: HTTPRequest
var _join_timer: Timer
var _join_pending := false

@onready var overlay_material: ShaderMaterial = $Overlay.material
@onready var title_box: Control = %TitleBox
@onready var title: Label = %Title
@onready var cursor_label: Label = %Subtitle
@onready var main_buttons: Control = %MainButtons
@onready var start_button: Button = %StartButton
@onready var load_button: Button = %LoadButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var options_panel: Control = %OptionsPanel
@onready var options: OptionsMenu = %Options


func _ready() -> void:
	# Zurück ins Menü beendet die Session. Nur die echte Menüszene.
	if get_tree().current_scene == self:
		NetworkManager.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options_panel.hide()

	_map_buttons = _create_map_buttons()
	_lobby = _create_lobby()
	_add_multiplayer_button()
	start_button.pressed.connect(_show_maps if not maps.is_empty() else _start_game.bind(game_scene))
	NetworkManager.connection_failed.connect(_on_net_failed)
	NetworkManager.session_ended.connect(_on_net_ended)
	NetworkManager.client_connected.connect(_on_client_connected)
	NgrokManager.tunnel_ready.connect(_on_tunnel_ready)
	NgrokManager.tunnel_failed.connect(_on_tunnel_failed)
	options_button.pressed.connect(_show_options)
	quit_button.pressed.connect(_on_quit_pressed)
	options.closed.connect(_hide_options)
	# Die Optionen fordern recht kräftige Glitches an; im Hauptmenü gedämpft.
	options.glitch_requested.connect(
		func(strength: float, duration: float) -> void: _trigger_glitch(strength * 0.3, duration)
	)

	for button: Button in [start_button, load_button, options_button, quit_button]:
		button.mouse_entered.connect(_focus_if_enabled.bind(button))
		button.focus_entered.connect(_trigger_glitch.bind(0.12, 0.06))

	_schedule_glitch()
	start_button.grab_focus()
	if OS.has_feature("web"):
		quit_button.hide()
		_ngrok_button.disabled = true
		_ngrok_button.tooltip_text = "ngrok läuft im Browser nicht."


func _process(delta: float) -> void:
	_glitch_timer -= delta
	if _glitch_timer <= 0.0:
		_trigger_glitch(randf_range(0.5, 1.0) * glitch_strength, glitch_duration)
		_schedule_glitch()

	var strength := 0.0
	if _glitch_left > 0.0:
		_glitch_left -= delta
		strength = overlay_material.get_shader_parameter("glitch")
		if _glitch_left <= 0.0:
			strength = 0.0
	overlay_material.set_shader_parameter("glitch", strength)

	# Titel: ruhiges Neon, das beim Glitch kurz flackert.
	title.modulate.a = 1.0 - strength * randf_range(0.0, 0.6)

	# Blinkender Cursor hinter dem Untertitel.
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5
	cursor_label.text = "// SYSTEM ONLINE" + ("_" if blink else " ")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and options_panel.visible:
		options.request_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _map_buttons.visible and not _starting:
		_hide_maps()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _lobby.visible and not _starting:
		_hide_lobby()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		# Die Optionen ziehen das Vollbild im Entwurf selbst nach (Settings.changed).
		Settings.toggle_fullscreen()


func _focus_if_enabled(button: Button) -> void:
	if not button.disabled:
		button.grab_focus()


func _trigger_glitch(strength: float, duration: float) -> void:
	overlay_material.set_shader_parameter("glitch", strength)
	_glitch_left = duration


func _schedule_glitch() -> void:
	_glitch_timer = randf_range(glitch_interval_min, glitch_interval_max)


# --- Map-Auswahl ----------------------------------------------------------------

## Zweite Button-Liste neben MainButtons, gleicher Theme und gleiche Größe.
func _create_map_buttons() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "MapButtons"
	box.custom_minimum_size = main_buttons.custom_minimum_size
	box.size_flags_horizontal = main_buttons.size_flags_horizontal
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.theme = main_buttons.theme
	box.add_theme_constant_override("separation", 16)
	main_buttons.add_sibling(box)
	box.hide()
	var entries: Array = maps.keys()
	entries.append("ZURÜCK")
	for label: String in entries:
		var button := Button.new()
		button.text = label
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = start_button.custom_minimum_size
		if maps.has(label):
			var path: String = maps[label]
			button.pressed.connect(_start_game.bind(path))
			if not ResourceLoader.exists(path):
				button.disabled = true
				button.tooltip_text = "Szene fehlt: " + path
		else:
			button.pressed.connect(_hide_maps)
		button.mouse_entered.connect(_focus_if_enabled.bind(button))
		button.focus_entered.connect(_trigger_glitch.bind(0.12, 0.06))
		box.add_child(button)
	return box


func _show_maps() -> void:
	main_buttons.hide()
	_lobby.hide()
	_map_buttons.show()
	_trigger_glitch(0.25, 0.1)
	_map_buttons.get_child(0).grab_focus()


func _hide_maps() -> void:
	_map_buttons.hide()
	main_buttons.show()
	start_button.grab_focus()


func _start_game(scene_path: String) -> void:
	if _starting:
		return
	if not _net_launch:
		NetworkManager.stop()
	_net_launch = false
	_starting = true
	game_scene = scene_path
	main_buttons.process_mode = Node.PROCESS_MODE_DISABLED
	_map_buttons.process_mode = Node.PROCESS_MODE_DISABLED
	# Kurzer, harter Glitch als Übergang, dann ins Spiel.
	_trigger_glitch(0.6, 0.4)
	var tween := create_tween()
	tween.tween_property($Fade, "color:a", 1.0, 0.45)
	await tween.finished
	var err := get_tree().change_scene_to_file(game_scene)
	if err != OK:
		# Spielszene lässt sich nicht laden (z. B. Skriptfehler nach einem Update).
		# Nicht im schwarzen Bild hängen bleiben, sondern zurück ins Menü.
		push_error("Spielszene %s konnte nicht geladen werden (Fehler %d). Details stehen im Debugger/Output." % [game_scene, err])
		var back := create_tween()
		back.tween_property($Fade, "color:a", 0.0, 0.3)
		main_buttons.process_mode = Node.PROCESS_MODE_INHERIT
		_map_buttons.process_mode = Node.PROCESS_MODE_INHERIT
		_starting = false


func _on_quit_pressed() -> void:
	get_tree().quit()


# --- Optionen -----------------------------------------------------------------

func _show_options() -> void:
	# Titel ausblenden, damit das Panel Platz hat.
	_lobby.hide()
	title_box.hide()
	cursor_label.hide()
	main_buttons.hide()
	options_panel.show()
	options.open()


func _hide_options() -> void:
	options_panel.hide()
	title_box.show()
	cursor_label.show()
	main_buttons.show()
	options_button.grab_focus()


func _add_multiplayer_button() -> void:
	var button := _net_button("MULTIPLAYER")
	button.custom_minimum_size = start_button.custom_minimum_size
	button.pressed.connect(_show_lobby)
	main_buttons.add_child(button)
	main_buttons.move_child(button, 1)


func _create_lobby() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Lobby"
	scroll.custom_minimum_size = Vector2(480, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	main_buttons.add_sibling(scroll)
	scroll.hide()
	_net_box = VBoxContainer.new()
	_net_box.name = "NetBox"
	_net_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_net_box.theme = main_buttons.theme
	_net_box.add_theme_constant_override("separation", 8)
	_net_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_net_box)
	var back := _net_button("ZURÜCK")
	back.pressed.connect(_hide_lobby)
	_net_box.add_child(back)
	_map_select = _create_map_select()
	_net_box.add_child(_map_select)
	_host_port = _net_field("Lokaler Port", "7777")
	_net_box.add_child(_host_port)
	var host_port := _net_button("HOST (PORTFREIGABE)")
	host_port.pressed.connect(_on_host_port_pressed)
	_net_box.add_child(host_port)
	_ngrok_button = _net_button("HOST (NGROK)")
	_ngrok_button.pressed.connect(_on_host_ngrok_pressed)
	_net_box.add_child(_ngrok_button)
	_token_field = _net_field("ngrok Authtoken, optional", "")
	_token_field.secret = true
	_token_field.text = NgrokManager.saved_token()
	_net_box.add_child(_token_field)
	_share_label = Label.new()
	_share_label.name = "ShareAddress"
	_share_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_share_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_share_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	_share_label.text = "Adresse erscheint nach dem Hosten."
	_net_box.add_child(_share_label)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	_net_box.add_child(row)
	_copy_button = _net_button("KOPIEREN")
	_copy_button.disabled = true
	_copy_button.pressed.connect(_on_copy_pressed)
	row.add_child(_copy_button)
	_play_button = _net_button("SPIEL STARTEN")
	_play_button.disabled = true
	_play_button.pressed.connect(_on_play_online_pressed)
	row.add_child(_play_button)
	_ip_field = _net_field("IP, Hostname oder ngrok-Adresse", "127.0.0.1")
	_ip_field.name = "JoinHost"
	_ip_field.focus_exited.connect(_split_join_fields)
	_ip_field.text_submitted.connect(func(_text: String) -> void: _split_join_fields())
	_net_box.add_child(_ip_field)
	_join_port = _net_field("Port zum Beitreten", "7777")
	_join_port.name = "JoinPort"
	_net_box.add_child(_join_port)
	var join := _net_button("BEITRETEN")
	join.pressed.connect(_on_join_pressed)
	_net_box.add_child(join)
	_net_status = Label.new()
	_net_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_net_status.custom_minimum_size = Vector2(460, 0)
	_net_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_net_status.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	_net_status.text = "Bis zu %d Spieler. ngrok braucht einmalig einen Authtoken." % [NetworkManager.MAX_CLIENTS + 1]
	_net_box.add_child(_net_status)
	_ip_http = HTTPRequest.new()
	_ip_http.timeout = 4.0
	_ip_http.request_completed.connect(_on_public_ip)
	add_child(_ip_http)
	return scroll


## Map für den Multiplayer (dieselbe Liste wie bei "Start"). Der Host lädt sie, Clients bekommen sie von ihm.
func _create_map_select() -> OptionButton:
	var select := OptionButton.new()
	select.name = "MapSelect"
	select.custom_minimum_size = Vector2(0, 44)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.tooltip_text = "Map für die Sitzung"
	for label: String in maps:
		var path: String = maps[label]
		select.add_item("MAP: " + label)
		var index := select.item_count - 1
		select.set_item_metadata(index, path)
		select.set_item_disabled(index, not ResourceLoader.exists(path))
	if select.item_count == 0:
		select.add_item("MAP: " + game_scene.get_file().get_basename().to_upper())
		select.set_item_metadata(0, game_scene)
	# Vorauswahl wie bisher: game_scene (Testmap).
	for i: int in select.item_count:
		if str(select.get_item_metadata(i)) == game_scene:
			select.select(i)
	select.item_selected.connect(_on_map_selected)
	return select


## Gewählte Map (Pfad). Ohne Auswahl die Standard-Szene.
func _selected_map() -> String:
	if _map_select == null or _map_select.selected < 0:
		return game_scene
	var path: Variant = _map_select.get_item_metadata(_map_select.selected)
	return str(path) if path != null and not str(path).is_empty() else game_scene


## Läuft schon ein Host, gilt die neue Map für alle, die ab jetzt beitreten, und für "SPIEL STARTEN".
func _on_map_selected(_index: int) -> void:
	if NetworkManager.has_session() and multiplayer.is_server():
		NetworkManager.map_path = _selected_map()
		_set_status("Map: %s" % _map_select.get_item_text(_map_select.selected).trim_prefix("MAP: "))


func _net_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_entered.connect(_focus_if_enabled.bind(button))
	return button


func _net_field(placeholder: String, text: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.text = text
	field.custom_minimum_size = Vector2(0, 40)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	return field


func _show_lobby() -> void:
	title_box.hide()
	main_buttons.hide()
	_map_buttons.hide()
	_lobby.show()
	_trigger_glitch(0.25, 0.1)


func _hide_lobby() -> void:
	_cancel_join_wait()
	_ip_http.cancel_request()
	_lobby.hide()
	title_box.show()
	main_buttons.show()
	start_button.grab_focus()
	if get_tree().current_scene == self:
		NetworkManager.stop()


func _read_port(field: LineEdit) -> int:
	var text := field.text.strip_edges()
	if not text.is_valid_int():
		return -1
	var port := text.to_int()
	if port < 1 or port > 65535:
		return -1
	return port


func _set_status(text: String) -> void:
	if _net_status != null:
		_net_status.text = text


func _show_share(address: String) -> void:
	_share_address = address
	_share_label.text = address
	_copy_button.disabled = address.is_empty()


func _on_host_port_pressed() -> void:
	# Sonst feuert die Join-Wartezeit später und reißt den neuen Host ab.
	_cancel_join_wait()
	var port := _read_port(_host_port)
	if port <= 0:
		_set_status("Port ungültig.")
		return
	var err := NetworkManager.host_map(_selected_map(), port)
	if err != OK:
		_set_status(NetworkManager.error_text(err))
		return
	_play_button.disabled = false
	var local := NetworkManager.local_share_address()
	_show_share(local)
	_set_status("Server lauscht auf 0.0.0.0. Fürs Internet den Port als UDP am Router weiterleiten.")
	NetworkManager.show_share_banner("Port %d weiterleiten" % port)
	_fetch_public_ip(port)


func _on_host_ngrok_pressed() -> void:
	_cancel_join_wait()
	if OS.has_feature("web"):
		_set_status("ngrok läuft im Browser nicht.")
		return
	var port := _read_port(_host_port)
	if port <= 0:
		_set_status("Port ungültig.")
		return
	var err := NetworkManager.host_map(_selected_map(), port, true)
	if err != OK:
		_set_status(NetworkManager.error_text(err))
		return
	_play_button.disabled = true
	_copy_button.disabled = true
	_set_status("ngrok wird geladen oder gestartet …")
	NgrokManager.start_tunnel(port, _token_field.text)


func _on_tunnel_ready(address: String) -> void:
	_show_share(address)
	_play_button.disabled = false
	_set_status("Tunnel steht. Die ganze Adresse einfügen, Host und Port werden getrennt.")
	NetworkManager.show_share_banner("Freunde: " + address)


func _on_tunnel_failed(message: String) -> void:
	_play_button.disabled = true
	_copy_button.disabled = true
	if NetworkManager.has_session():
		NetworkManager.stop()
	_set_status(message)


func _fetch_public_ip(port: int) -> void:
	_ip_http.set_meta("share_port", port)
	_ip_http.cancel_request()
	var err := _ip_http.request("https://api.ipify.org")
	if err != OK:
		_set_status("Öffentliche IP nicht lesbar. Lokal: %s" % _share_address)


func _on_public_ip(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_set_status("Öffentliche IP nicht erreichbar. Lokal: %s. Internet prüfen." % _share_address)
		return
	var ip := body.get_string_from_utf8().strip_edges()
	if not ip.is_valid_ip_address():
		_set_status("Öffentliche IP ungültig. Lokal: %s" % _share_address)
		return
	var port := int(_ip_http.get_meta("share_port", NetworkManager.listen_port))
	var address := "%s:%d" % [ip, port]
	_show_share(address)
	_set_status("Internet-Adresse kopieren. Port %d muss am Router weitergeleitet sein." % port)
	NetworkManager.show_share_banner("Freunde: " + address)


func _on_copy_pressed() -> void:
	if _share_address.is_empty():
		_set_status("Noch keine Adresse.")
		return
	if DisplayServer.get_name() == "headless":
		_set_status(_share_address)
		return
	DisplayServer.clipboard_set(_share_address)
	_set_status("Kopiert: " + _share_address)


func _on_play_online_pressed() -> void:
	_cancel_join_wait()
	if not NetworkManager.has_session() or not multiplayer.is_server():
		_set_status("Erst einen Host starten.")
		return
	_net_launch = true
	_start_game(_selected_map())


func _split_join_fields() -> void:
	if _ip_field == null or _join_port == null:
		return
	var endpoint := NetworkManager.split_endpoint(_ip_field.text, -1)
	if not bool(endpoint.get("explicit", false)):
		return
	var host := str(endpoint["host"])
	var port := int(endpoint["port"])
	if host.is_empty() or port < 1 or port > 65535:
		return
	_ip_field.text = host
	_join_port.text = str(port)


func _on_join_pressed() -> void:
	_cancel_join_wait()
	_split_join_fields()
	var port := _read_port(_join_port)
	if port <= 0:
		_set_status("Port ungültig.")
		return
	var host := _ip_field.text.strip_edges()
	if host.is_empty():
		host = "127.0.0.1"
		_ip_field.text = host
	var resolved := NetworkManager.resolve_host(host)
	if resolved.is_empty():
		_set_status(NetworkManager.error_text(ERR_CANT_RESOLVE))
		return
	if NetworkManager.wants_tcp_tunnel(host):
		_set_status("Verbinde mit ngrok-Server...\n%s:%d → %s:%d" % [host, port, resolved, port])
	else:
		_set_status("Verbinde mit %s:%d …" % [resolved, port])
	var err := NetworkManager.create_client(_ip_field.text, port)
	if err != OK:
		_join_pending = false
		_set_status(NetworkManager.error_text(err))
		return
	_begin_join_wait()


func _cancel_join_wait() -> void:
	_join_pending = false
	if _join_timer != null:
		_join_timer.stop()


func _begin_join_wait() -> void:
	_join_pending = true
	if _join_timer == null:
		_join_timer = Timer.new()
		_join_timer.one_shot = true
		_join_timer.wait_time = 10.0
		_join_timer.timeout.connect(_on_join_timeout)
		add_child(_join_timer)
	_join_timer.start()


func _on_join_timeout() -> void:
	if not _join_pending:
		return
	_join_pending = false
	if _join_timer != null:
		_join_timer.stop()
	# Zwischenzeitlich kann ein Host stehen. Den darf die alte Wartezeit nicht schließen.
	if NetworkManager.has_session() and multiplayer.is_server():
		return
	NetworkManager.stop()
	_play_button.disabled = true
	_set_status(_join_failure("Zeitüberschreitung nach 10 Sekunden."))


func _on_client_connected() -> void:
	_join_pending = false
	if _join_timer != null:
		_join_timer.stop()
	_set_status("Verbunden. Die Map kommt vom Host.")


func _join_failure(reason: String) -> String:
	return reason + "\n1. Host prüfen: Wurde die Windows-Firewall für Godot und ngrok zugelassen?\n2. Port-Match: Stimmt der von ngrok erzeugte, meist 5-stellige Port exakt mit der Eingabe überein?"


func _on_net_failed() -> void:
	# Eigenes stop() (Lobby zu, neuer Host) ist kein fehlgeschlagener Beitritt.
	if not _join_pending:
		return
	_join_pending = false
	if _join_timer != null:
		_join_timer.stop()
	_play_button.disabled = true
	_set_status(_join_failure("Server nicht erreichbar."))


func _on_net_ended() -> void:
	_play_button.disabled = true
	_set_status("Verbindung zum Host verloren.")
