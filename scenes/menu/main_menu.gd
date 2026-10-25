extends Control
## Hauptmenü im Cyberpunk-Stil: Start, Optionen, Beenden.
##
## Vollbild, VSync und Lautstärke liegen in user://settings.cfg (siehe GameSettings).
## Vollbild wird beim Umschalten sofort geschrieben. VSync und Lautstärke
## werden beim Verlassen der Optionen mitgeschrieben.

const Settings := preload("res://scripts/game_settings.gd")

## Szene, die "Start" lädt.
@export_file("*.tscn") var game_scene := "res://scenes/main/main.tscn"

@export_group("Glitch")
## Zeitraum (Sekunden), in dem zufällig ein Glitch kommt.
@export var glitch_interval_min := 1.5
@export var glitch_interval_max := 4.5
@export var glitch_duration := 0.18

var _glitch_timer := 0.0
var _glitch_left := 0.0
var _starting := false

@onready var overlay_material: ShaderMaterial = $Overlay.material
@onready var title: Label = %Title
@onready var title_cyan: Label = %TitleCyan
@onready var title_magenta: Label = %TitleMagenta
@onready var cursor_label: Label = %Subtitle
@onready var main_buttons: Control = %MainButtons
@onready var start_button: Button = %StartButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var options_panel: Control = %OptionsPanel
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var back_button: Button = %BackButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options_panel.hide()

	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_show_options)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_hide_options)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)

	for button: Button in [start_button, options_button, quit_button, back_button]:
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(_trigger_glitch.bind(0.35, 0.08))

	_load_settings()
	_schedule_glitch()
	start_button.grab_focus()
	if OS.has_feature("web"):
		quit_button.hide()


func _process(delta: float) -> void:
	_glitch_timer -= delta
	if _glitch_timer <= 0.0:
		_trigger_glitch(randf_range(0.4, 1.0), glitch_duration)
		_schedule_glitch()

	var strength := 0.0
	if _glitch_left > 0.0:
		_glitch_left -= delta
		strength = overlay_material.get_shader_parameter("glitch")
		if _glitch_left <= 0.0:
			strength = 0.0
	overlay_material.set_shader_parameter("glitch", strength)

	# Titel: Farbkanäle zittern leicht, beim Glitch stärker.
	var jitter := 2.0 + strength * 14.0
	title_cyan.position = Vector2(randf_range(-jitter, 0.0), randf_range(-1.0, 1.0) * strength * 4.0)
	title_magenta.position = Vector2(randf_range(0.0, jitter), randf_range(-1.0, 1.0) * strength * 4.0)
	title.position.x = randf_range(-1.0, 1.0) * strength * 6.0

	# Blinkender Cursor hinter dem Untertitel.
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5
	cursor_label.text = "// SYSTEM ONLINE" + ("_" if blink else " ")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and options_panel.visible:
		_hide_options()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		fullscreen_check.button_pressed = not fullscreen_check.button_pressed


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
	_trigger_glitch(1.0, 0.5)
	var tween := create_tween()
	tween.tween_property($Fade, "color:a", 1.0, 0.45)
	await tween.finished
	get_tree().change_scene_to_file(game_scene)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _show_options() -> void:
	main_buttons.hide()
	options_panel.show()
	_trigger_glitch(0.7, 0.12)
	fullscreen_check.grab_focus()


func _hide_options() -> void:
	_save_settings()
	options_panel.hide()
	main_buttons.show()
	_trigger_glitch(0.7, 0.12)
	options_button.grab_focus()


func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	)
	Settings.set_fullscreen(on)


func _on_vsync_toggled(on: bool) -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED
	)


func _on_volume_changed(value: float) -> void:
	volume_value.text = "%d%%" % int(value)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value / 100.0))
	AudioServer.set_bus_mute(bus, value <= 0.0)


func _load_settings() -> void:
	var fullscreen := Settings.get_fullscreen(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	var vsync := Settings.get_vsync(true)
	var volume := Settings.get_master_volume(80.0)

	fullscreen_check.button_pressed = fullscreen
	vsync_check.button_pressed = vsync
	volume_slider.value = volume
	# Signale feuern nicht, wenn sich der Wert nicht ändert, daher direkt anwenden.
	_on_fullscreen_toggled(fullscreen)
	_on_vsync_toggled(vsync)
	_on_volume_changed(volume)


func _save_settings() -> void:
	Settings.save_preferences(
		fullscreen_check.button_pressed,
		vsync_check.button_pressed,
		volume_slider.value
	)
