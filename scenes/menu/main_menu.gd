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
var _net_box: VBoxContainer
var _ip_field: LineEdit
var _net_status: Label

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
	_net_box = _create_net_box()
	start_button.pressed.connect(_show_maps if not maps.is_empty() else _start_game.bind(game_scene))
	NetworkManager.connection_failed.connect(_on_net_failed)
	NetworkManager.session_ended.connect(_on_net_ended)
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
		_net_box.hide()


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
	_net_box.hide()
	_map_buttons.show()
	_trigger_glitch(0.25, 0.1)
	_map_buttons.get_child(0).grab_focus()


func _hide_maps() -> void:
	_map_buttons.hide()
	main_buttons.show()
	_net_box.show()
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
		_net_box.show()
		_starting = false


func _on_quit_pressed() -> void:
	get_tree().quit()


# --- Optionen -----------------------------------------------------------------

func _show_options() -> void:
	# Titel ausblenden, damit das Panel Platz hat.
	_net_box.hide()
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
	_net_box.show()
	options_button.grab_focus()


func _create_net_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "NetBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.theme = main_buttons.theme
	box.add_theme_constant_override("separation", 10)
	main_buttons.add_sibling(box)
	var host := Button.new()
	host.text = "HOST"
	host.alignment = HORIZONTAL_ALIGNMENT_LEFT
	host.custom_minimum_size = start_button.custom_minimum_size
	host.pressed.connect(_on_host_pressed)
	host.mouse_entered.connect(_focus_if_enabled.bind(host))
	box.add_child(host)
	_ip_field = LineEdit.new()
	_ip_field.text = "127.0.0.1"
	_ip_field.placeholder_text = "IP-Adresse"
	_ip_field.custom_minimum_size = Vector2(start_button.custom_minimum_size.x, 48.0)
	_ip_field.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(_ip_field)
	var join := Button.new()
	join.text = "JOIN"
	join.alignment = HORIZONTAL_ALIGNMENT_LEFT
	join.custom_minimum_size = start_button.custom_minimum_size
	join.pressed.connect(_on_join_pressed)
	join.mouse_entered.connect(_focus_if_enabled.bind(join))
	box.add_child(join)
	_net_status = Label.new()
	_net_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_net_status.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	_net_status.text = "Port %d  ·  bis zu %d Spieler" % [NetworkManager.PORT, NetworkManager.MAX_CLIENTS + 1]
	box.add_child(_net_status)
	return box


func _on_host_pressed() -> void:
	var err := NetworkManager.host_map(game_scene)
	if err != OK:
		_net_status.text = "Host fehlgeschlagen (%d)" % err
		return
	_net_status.text = "Host auf Port %d" % NetworkManager.PORT
	_net_launch = true
	_start_game(game_scene)


func _on_join_pressed() -> void:
	var ip := _ip_field.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var err := NetworkManager.create_client(ip)
	if err != OK:
		_net_status.text = "Join fehlgeschlagen (%d)" % err
		return
	_net_status.text = "Verbinde mit %s …" % ip


func _on_net_failed() -> void:
	if _net_status != null:
		_net_status.text = "Verbindung fehlgeschlagen"


func _on_net_ended() -> void:
	if _net_status != null:
		_net_status.text = "Getrennt"
