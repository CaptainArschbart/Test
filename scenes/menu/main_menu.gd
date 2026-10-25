extends Control
## Hauptmenü im Cyberpunk-Stil: Start, Spielstand laden, Optionen, Beenden.
##
## "Spielstand laden" ist ein Platzhalter und bleibt deaktiviert, bis es ein
## Speichersystem gibt.
##
## Die Optionen sind die gemeinsame Szene scenes/options/options_menu.tscn, dieselbe
## wie im Pausemenü. Sie bearbeitet eine Kopie der Einstellungen. Erst "Übernehmen"
## schreibt sie in den Autoload Settings (und damit nach user://settings.cfg).

const OptionsMenu := preload("res://scenes/options/options_menu.gd")

## Szene, die "Start" lädt.
@export_file("*.tscn") var game_scene := "res://scenes/testmap/testmap.tscn"

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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options_panel.hide()

	start_button.pressed.connect(_on_start_pressed)
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


func _on_start_pressed() -> void:
	if _starting:
		return
	_starting = true
	main_buttons.process_mode = Node.PROCESS_MODE_DISABLED
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
		_starting = false


func _on_quit_pressed() -> void:
	get_tree().quit()


# --- Optionen -----------------------------------------------------------------

func _show_options() -> void:
	# Titel ausblenden, damit das Panel Platz hat.
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
