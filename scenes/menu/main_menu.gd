extends Control
## Hauptmenü im Cyberpunk-Stil: Start, Optionen, Beenden.
##
## Die Optionen bearbeiten eine Kopie der Einstellungen. Erst "Übernehmen"
## schreibt sie in den Autoload Settings (und damit nach user://settings.cfg).

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

## Bearbeitete, noch nicht übernommene Einstellungen.
var _draft := {}
## Aktion, für die gerade eine neue Taste erwartet wird ("" = keine).
var _rebinding_action := ""
var _key_buttons := {}
var _confirm_discard := false

@onready var overlay_material: ShaderMaterial = $Overlay.material
@onready var title_box: Control = %TitleBox
@onready var title: Label = %Title
@onready var title_cyan: Label = %TitleCyan
@onready var title_magenta: Label = %TitleMagenta
@onready var cursor_label: Label = %Subtitle
@onready var main_buttons: Control = %MainButtons
@onready var start_button: Button = %StartButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var options_panel: Control = %OptionsPanel
@onready var tabs: TabContainer = %Tabs
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value: Label = %SensitivityValue
@onready var invert_y_check: CheckButton = %InvertYCheck
@onready var key_grid: GridContainer = %KeyGrid
@onready var apply_button: Button = %ApplyButton
@onready var defaults_button: Button = %DefaultsButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options_panel.hide()

	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_show_options)
	quit_button.pressed.connect(_on_quit_pressed)
	apply_button.pressed.connect(_on_apply_pressed)
	defaults_button.pressed.connect(_on_defaults_pressed)
	back_button.pressed.connect(_on_back_pressed)
	fullscreen_check.toggled.connect(_set_draft.bind("fullscreen"))
	vsync_check.toggled.connect(_set_draft.bind("vsync"))
	volume_slider.value_changed.connect(_set_draft.bind("master_volume"))
	sensitivity_slider.value_changed.connect(_set_draft.bind("mouse_sensitivity"))
	invert_y_check.toggled.connect(_set_draft.bind("invert_y"))
	tabs.tab_changed.connect(func(_tab: int) -> void: _trigger_glitch(0.5, 0.08))

	_build_key_grid()

	for button: Button in [start_button, options_button, quit_button]:
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(_trigger_glitch.bind(0.35, 0.08))

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


func _input(event: InputEvent) -> void:
	# Während auf eine neue Taste gewartet wird, geht jede Taste an die Belegung.
	if _rebinding_action.is_empty() or not (event is InputEventKey and event.pressed):
		return
	get_viewport().set_input_as_handled()
	if event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		var bindings: Dictionary = _draft.key_bindings
		# Ist die Taste schon vergeben, tauschen die beiden Aktionen.
		for other: String in bindings:
			if other != _rebinding_action and bindings[other] == code:
				bindings[other] = bindings[_rebinding_action]
		bindings[_rebinding_action] = code
		_update_dirty()
	var button: Button = _key_buttons[_rebinding_action]
	_rebinding_action = ""
	_refresh_options()
	button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and options_panel.visible:
		_on_back_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		Settings.toggle_fullscreen()
		if not _draft.is_empty():
			_draft.fullscreen = Settings.fullscreen
			_refresh_options()


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


# --- Optionen -----------------------------------------------------------------

func _show_options() -> void:
	_draft = Settings.get_values()
	_refresh_options()
	_update_dirty()
	status_label.text = " "
	# Titel ausblenden, damit das Panel Platz hat.
	title_box.hide()
	cursor_label.hide()
	main_buttons.hide()
	options_panel.show()
	_trigger_glitch(0.7, 0.12)
	tabs.get_tab_bar().grab_focus()


func _hide_options() -> void:
	_rebinding_action = ""
	_draft = {}
	options_panel.hide()
	title_box.show()
	cursor_label.show()
	main_buttons.show()
	_trigger_glitch(0.7, 0.12)
	options_button.grab_focus()


func _on_back_pressed() -> void:
	if not _rebinding_action.is_empty():
		return
	if _is_dirty() and not _confirm_discard:
		_confirm_discard = true
		_set_status("Nicht übernommen! Nochmal ZURÜCK = Änderungen verwerfen", Color(1, 0.3, 0.3))
		_trigger_glitch(0.8, 0.15)
		return
	_hide_options()


func _on_apply_pressed() -> void:
	Settings.apply_values(_draft)
	_draft = Settings.get_values()
	_update_dirty()
	_set_status("Einstellungen übernommen und gespeichert", Color(0, 0.95, 1))
	_trigger_glitch(0.6, 0.12)


func _on_defaults_pressed() -> void:
	_draft = Settings.get_defaults()
	_refresh_options()
	_update_dirty()


func _set_draft(value: Variant, key: String) -> void:
	_draft[key] = value
	_refresh_labels()
	_update_dirty()


func _is_dirty() -> bool:
	return not _draft.is_empty() and _draft != Settings.get_values()


func _update_dirty() -> void:
	_confirm_discard = false
	var dirty := _is_dirty()
	apply_button.disabled = not dirty
	if dirty:
		_set_status("Ungespeicherte Änderungen", Color(1, 0.1, 0.75))
	else:
		status_label.text = " "


func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


## Schreibt die Werte aus _draft in die Bedienelemente, ohne Signale auszulösen.
func _refresh_options() -> void:
	fullscreen_check.set_pressed_no_signal(_draft.fullscreen)
	vsync_check.set_pressed_no_signal(_draft.vsync)
	volume_slider.set_value_no_signal(_draft.master_volume)
	sensitivity_slider.set_value_no_signal(_draft.mouse_sensitivity)
	invert_y_check.set_pressed_no_signal(_draft.invert_y)
	for action: String in _key_buttons:
		var button: Button = _key_buttons[action]
		if action == _rebinding_action:
			button.text = "[ Taste drücken ]"
		else:
			button.text = Settings.key_name(_draft.key_bindings[action])
	_refresh_labels()


func _refresh_labels() -> void:
	volume_value.text = "%d%%" % int(_draft.master_volume)
	sensitivity_value.text = "%.2fx" % _draft.mouse_sensitivity


func _build_key_grid() -> void:
	for action: String in Settings.REBINDABLE_ACTIONS:
		var label := Label.new()
		label.text = Settings.REBINDABLE_ACTIONS[action]
		label.custom_minimum_size.x = 110
		key_grid.add_child(label)

		var button := Button.new()
		button.custom_minimum_size.x = 150
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_start_rebind.bind(action))
		key_grid.add_child(button)
		_key_buttons[action] = button


func _start_rebind(action: String) -> void:
	if not _rebinding_action.is_empty():
		return
	_rebinding_action = action
	_refresh_options()
	_trigger_glitch(0.5, 0.08)
