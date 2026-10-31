extends VBoxContainer
## Optionen-Seite für Hauptmenü und Pausemenü. Beide binden diese eine Szene ein,
## damit die Optionen überall gleich aussehen und sich gleich verhalten.
##
## Die Seite bearbeitet eine Kopie der Einstellungen (_draft). Erst "Übernehmen"
## schreibt sie über Settings.apply_values() ins Spiel und nach user://settings.cfg.
## Der Musik-Regler stellt den Bus "Music" sofort lauter oder leiser. Verwerfen stellt
## die gespeicherte Lautstärke wieder her.
## "Standard" lädt die Standardwerte in den Entwurf. "Zurück" (oder Esc, das ruft der
## Host über request_back() auf) verlässt die Seite. Steht noch Nicht-Übernommenes im
## Entwurf, braucht es dafür eine zweite Bestätigung.
##
## Der Host zeigt die Seite mit open() und lauscht auf closed. Esc und F11 gehören dem
## Host (Esc = request_back(), F11 = Settings.toggle_fullscreen()). Die Seite zieht
## das Vollbild im Entwurf selbst nach, wenn Settings sich ändert.

## Die Seite wurde verlassen (nach Zurück oder Esc, ggf. nach bestätigtem Verwerfen).
signal closed
## Effektwunsch für das Hauptmenü (Glitch). Das Pausemenü braucht ihn nicht.
signal glitch_requested(strength: float, duration: float)

## Bearbeitete, noch nicht übernommene Einstellungen. Leer, solange die Seite zu ist.
var _draft := {}
## Aktion, für die gerade eine neue Taste erwartet wird ("" = keine).
var _rebinding_action := ""
var _key_buttons := {}
var _confirm_discard := false

@onready var tabs: TabContainer = %Tabs
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var msaa_option: OptionButton = %MsaaOption
@onready var render_scale_slider: HSlider = %RenderScaleSlider
@onready var render_scale_value: Label = %RenderScaleValue
@onready var output_device_option: OptionButton = %OutputDeviceOption
@onready var master_slider: HSlider = %MasterSlider
@onready var master_value: Label = %MasterValue
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value: Label = %SensitivityValue
@onready var invert_y_check: CheckButton = %InvertYCheck
@onready var camera_shake_slider: HSlider = %CameraShakeSlider
@onready var camera_shake_value: Label = %CameraShakeValue
@onready var key_grid: GridContainer = %KeyGrid
@onready var apply_button: Button = %ApplyButton
@onready var defaults_button: Button = %DefaultsButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel

var gi_option: OptionButton
var upscale_option: OptionButton
var draw_distance_slider: HSlider
var draw_distance_value: Label
var shadow_option: OptionButton
var ssao_check: CheckButton
var glow_check: CheckButton
var glow_strength_slider: HSlider
var glow_strength_value: Label
var volumetric_check: CheckButton


func _ready() -> void:
	# Die ID entspricht Viewport.MSAA, so wandert sie unverändert nach Settings.msaa.
	msaa_option.add_item("AUS", Viewport.MSAA_DISABLED)
	msaa_option.add_item("2x", Viewport.MSAA_2X)
	msaa_option.add_item("4x", Viewport.MSAA_4X)
	msaa_option.add_item("8x", Viewport.MSAA_8X)

	apply_button.pressed.connect(_on_apply_pressed)
	defaults_button.pressed.connect(_on_defaults_pressed)
	back_button.pressed.connect(request_back)

	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	resolution_option.item_selected.connect(_on_resolution_selected)
	vsync_check.toggled.connect(_set_draft.bind("vsync"))
	msaa_option.item_selected.connect(_on_msaa_selected)
	render_scale_slider.value_changed.connect(_on_render_scale_changed)
	output_device_option.item_selected.connect(_on_output_device_selected)
	master_slider.value_changed.connect(_set_draft.bind("master_volume"))
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_set_draft.bind("sfx_volume"))
	sensitivity_slider.value_changed.connect(_set_draft.bind("mouse_sensitivity"))
	invert_y_check.toggled.connect(_set_draft.bind("invert_y"))
	camera_shake_slider.value_changed.connect(func(percent: float) -> void: _set_draft(percent / 100.0, "camera_shake"))
	tabs.tab_changed.connect(func(_tab: int) -> void: glitch_requested.emit(0.5, 0.08))

	_build_key_grid()
	_build_nextgen_rows()
	tabs.set_tab_title(0, "GRAFIK")
	tabs.set_tab_title(1, "AUDIO")
	tabs.set_tab_title(2, "STEUERUNG")
	for scroll_name: String in ["ContentScroll", "AudioScroll", "ControlsScroll"]:
		var scroll := tabs.get_node(NodePath(scroll_name)) as ScrollContainer
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.follow_focus = true

	# F11 ändert Settings, während die Seite offen ist: Vollbild im Entwurf nachziehen.
	Settings.changed.connect(_on_settings_changed)


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


## Zeigt die Seite mit den aktuellen Werten aus Settings.
func open() -> void:
	_rebinding_action = ""
	_draft = Settings.get_values()
	tabs.current_tab = 0
	_fill_output_devices()
	_fill_resolutions()
	_refresh_options()
	_update_dirty()
	show()
	glitch_requested.emit(0.7, 0.12)
	tabs.get_tab_bar().grab_focus()


## Zurück (Knopf oder Esc). Mit Nicht-Übernommenem erst nach einer zweiten Bestätigung.
func request_back() -> void:
	if not _rebinding_action.is_empty():
		return
	if _is_dirty() and not _confirm_discard:
		_confirm_discard = true
		_set_status("Nicht übernommen! Nochmal ZURÜCK = Änderungen verwerfen", Color(1, 0.3, 0.3))
		glitch_requested.emit(0.8, 0.15)
		return
	_close()


func _close() -> void:
	Settings.preview_bus(Settings.MUSIC_BUS, Settings.music_volume)
	_rebinding_action = ""
	_draft = {}
	hide()
	glitch_requested.emit(0.7, 0.12)
	closed.emit()


func _on_apply_pressed() -> void:
	Settings.apply_values(_draft)
	_draft = Settings.get_values()
	_update_dirty()
	_set_status("Einstellungen übernommen und gespeichert", Color(0, 0.95, 1))
	glitch_requested.emit(0.6, 0.12)


func _on_defaults_pressed() -> void:
	_draft = Settings.get_defaults()
	_refresh_options()
	_update_dirty()
	Settings.preview_bus(Settings.MUSIC_BUS, float(_draft.music_volume))


func _on_music_slider_changed(percent: float) -> void:
	_set_draft(percent, "music_volume")
	Settings.preview_bus(Settings.MUSIC_BUS, percent)


func _on_settings_changed() -> void:
	if _draft.is_empty():
		return
	_draft.fullscreen = Settings.fullscreen
	_refresh_options()
	_update_dirty()


func _on_msaa_selected(index: int) -> void:
	_set_draft(msaa_option.get_item_id(index), "msaa")


func _on_fullscreen_toggled(on: bool) -> void:
	_set_draft(on, "fullscreen")
	# Fenster und Vollbild haben je eine eigene Auflösung, die Liste zeigt die passende.
	_fill_resolutions()
	_select_resolution(_wanted_resolution())


func _on_resolution_selected(index: int) -> void:
	_set_draft(resolution_option.get_item_metadata(index), _resolution_key())


## Im Vollbild bearbeitet die Liste "fullscreen_resolution", im Fenster "resolution".
func _resolution_key() -> String:
	return "fullscreen_resolution" if _draft.get("fullscreen", false) else "resolution"


func _wanted_resolution() -> Vector2i:
	if _draft.get("fullscreen", false):
		return _draft.get("fullscreen_resolution", Vector2i.ZERO)
	return _draft.get("resolution", Settings.DEFAULT_RESOLUTION)


## Füllt die Auflösungsliste. Im Vollbild steht oben "Monitor" (nativ, Vector2i.ZERO),
## darunter die kleineren Auflösungen. Eine gespeicherte Größe, die nicht (mehr) in
## der Liste steht, bleibt als eigener Eintrag wählbar.
func _fill_resolutions() -> void:
	resolution_option.clear()
	var fullscreen: bool = _draft.get("fullscreen", false)
	var screen := DisplayServer.screen_get_size()
	var sizes := Settings.available_resolutions()
	var wanted := _wanted_resolution()
	if fullscreen:
		sizes.erase(screen)
		var native := "Monitor"
		if screen.x > 0 and screen.y > 0:
			native = "Monitor  (%d × %d)" % [screen.x, screen.y]
		resolution_option.add_item(native)
		resolution_option.set_item_metadata(0, Vector2i.ZERO)
	if wanted != Vector2i.ZERO and not sizes.has(wanted):
		sizes.append(wanted)
		sizes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y)
	if fullscreen:
		sizes.reverse()
	for size: Vector2i in sizes:
		var text := "%d × %d" % [size.x, size.y]
		if size == screen:
			text += "  (Monitor)"
		resolution_option.add_item(text)
		resolution_option.set_item_metadata(resolution_option.item_count - 1, size)


func _select_resolution(size: Vector2i) -> void:
	for _attempt in 2:
		for i in resolution_option.item_count:
			if resolution_option.get_item_metadata(i) == size:
				resolution_option.select(i)
				return
		# "Standard" kann eine Größe verlangen, die noch nicht in der Liste steht.
		_fill_resolutions()


func _on_output_device_selected(index: int) -> void:
	_set_draft(output_device_option.get_item_metadata(index), "output_device")


## Liest die Geräteliste neu ein (Kopfhörer können zwischendurch angesteckt werden).
## Ein gespeichertes Gerät, das gerade fehlt, bleibt als "(nicht verbunden)" wählbar.
func _fill_output_devices() -> void:
	output_device_option.clear()
	var devices := AudioServer.get_output_device_list()
	var wanted: String = _draft.get("output_device", Settings.DEFAULT_OUTPUT_DEVICE)
	if not devices.has(wanted):
		devices.append(wanted)
	for device: String in devices:
		var text := device
		if device == Settings.DEFAULT_OUTPUT_DEVICE:
			text = "Systemstandard"
		elif not AudioServer.get_output_device_list().has(device):
			text = "%s (nicht verbunden)" % device
		output_device_option.add_item(text)
		output_device_option.set_item_metadata(output_device_option.item_count - 1, device)
		output_device_option.set_item_tooltip(output_device_option.item_count - 1, text)


func _select_output_device(device: String) -> void:
	for i in output_device_option.item_count:
		if output_device_option.get_item_metadata(i) == device:
			output_device_option.select(i)
			return
	# "Standard" kann ein Gerät verlangen, das noch nicht in der Liste steht.
	_fill_output_devices()
	for i in output_device_option.item_count:
		if output_device_option.get_item_metadata(i) == device:
			output_device_option.select(i)
			return


func _on_render_scale_changed(percent: float) -> void:
	_set_draft(percent / 100.0, "render_scale")


func _set_draft(value: Variant, key: String) -> void:
	_draft[key] = value
	_refresh_labels()
	_update_dirty()


func _is_dirty() -> bool:
	return not _draft.is_empty() and not _same_values(_draft, Settings.get_values())


## Vergleicht zwei Einstellungs-Dictionaries. Kommazahlen mit Toleranz, weil ein Slider
## (z. B. Schrittweite 0.05) den gespeicherten Wert nicht immer auf das Bit genau trifft.
func _same_values(a: Dictionary, b: Dictionary) -> bool:
	for key: String in a:
		var x: Variant = a[key]
		var y: Variant = b.get(key)
		if x is float and y is float:
			if not is_equal_approx(x, y):
				return false
		elif x != y:
			return false
	return true


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
	_fill_resolutions()
	_select_resolution(_wanted_resolution())
	msaa_option.select(msaa_option.get_item_index(_draft.msaa))
	render_scale_slider.set_value_no_signal(_draft.render_scale * 100.0)
	_select_output_device(_draft.get("output_device", Settings.DEFAULT_OUTPUT_DEVICE))
	master_slider.set_value_no_signal(_draft.master_volume)
	music_slider.set_value_no_signal(_draft.music_volume)
	sfx_slider.set_value_no_signal(_draft.sfx_volume)
	sensitivity_slider.set_value_no_signal(_draft.mouse_sensitivity)
	invert_y_check.set_pressed_no_signal(_draft.invert_y)
	camera_shake_slider.set_value_no_signal(_draft.get("camera_shake", 1.0) * 100.0)
	if gi_option != null:
		_select_id(gi_option, int(_draft.get("gi_mode", Settings.GI_NORMAL)))
		_select_id(upscale_option, int(_draft.get("upscale_mode", Settings.UPSCALE_OFF)))
		_select_id(shadow_option, int(_draft.get("shadow_quality", 2)))
		draw_distance_slider.set_value_no_signal(float(_draft.get("draw_distance", 500.0)))
		ssao_check.set_pressed_no_signal(bool(_draft.get("ssao_enabled", true)))
		glow_check.set_pressed_no_signal(bool(_draft.get("glow_enabled", true)))
		glow_strength_slider.set_value_no_signal(float(_draft.get("glow_strength", 1.0)) * 100.0)
		volumetric_check.set_pressed_no_signal(bool(_draft.get("volumetric_fog", true)))
	for action: String in _key_buttons:
		var button: Button = _key_buttons[action]
		if action == _rebinding_action:
			button.text = "[ Taste drücken ]"
		else:
			button.text = Settings.key_name(_draft.key_bindings[action])
	_refresh_labels()


func _refresh_labels() -> void:
	render_scale_value.text = "%d%%" % roundi(_draft.render_scale * 100.0)
	master_value.text = "%d%%" % roundi(_draft.master_volume)
	music_value.text = "%d%%" % roundi(_draft.music_volume)
	sfx_value.text = "%d%%" % roundi(_draft.sfx_volume)
	sensitivity_value.text = "%.2fx" % _draft.mouse_sensitivity
	var shake: float = _draft.get("camera_shake", 1.0)
	camera_shake_value.text = "AUS" if shake <= 0.0 else "%d%%" % roundi(shake * 100.0)
	if draw_distance_value != null:
		draw_distance_value.text = "%d m" % roundi(float(_draft.get("draw_distance", 500.0)))
	if glow_strength_value != null:
		glow_strength_value.text = "%d %%" % roundi(float(_draft.get("glow_strength", 1.0)) * 100.0)


func _select_id(option: OptionButton, id: int) -> void:
	var index := option.get_item_index(id)
	if index >= 0:
		option.select(index)


func _build_nextgen_rows() -> void:
	var page := tabs.get_node(^"ContentScroll/GrafikList") as VBoxContainer
	gi_option = _add_option(page, "GiOption", "Raytracing / GI", ["Aus", "Normal", "Raytraced High"])
	gi_option.item_selected.connect(func(index: int) -> void:
		_set_draft(gi_option.get_item_id(index), "gi_mode"))
	upscale_option = _add_option(page, "UpscaleOption", "Upscaling", [
		"Aus", "DLSS Qualität", "DLSS Ausgewogen", "DLSS Leistung", "DLSS 5 Hybrid",
	])
	upscale_option.item_selected.connect(func(index: int) -> void:
		_set_draft(upscale_option.get_item_id(index), "upscale_mode"))
	var hint := Label.new()
	hint.name = "UpscaleHint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Die Stufen steuern scaling_3d_mode (FSR 2) und scaling_3d_scale. Nvidia DLSS 5 Frame Generation gibt es in Godot 4.7 nicht; Hybrid senkt nur die interne Auflösung."
	page.add_child(hint)
	var row := HBoxContainer.new()
	row.name = "DrawDistanceRow"
	page.add_child(row)
	var caption := Label.new()
	caption.text = "Renderdistanz"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.custom_minimum_size = Vector2(220, 0)
	row.add_child(caption)
	draw_distance_slider = HSlider.new()
	draw_distance_slider.name = "DrawDistanceSlider"
	draw_distance_slider.unique_name_in_owner = true
	draw_distance_slider.min_value = 80.0
	draw_distance_slider.max_value = 800.0
	draw_distance_slider.step = 10.0
	draw_distance_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(draw_distance_slider)
	draw_distance_slider.owner = self
	draw_distance_value = Label.new()
	draw_distance_value.name = "DrawDistanceValue"
	draw_distance_value.unique_name_in_owner = true
	draw_distance_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_distance_value.custom_minimum_size = Vector2(72, 0)
	row.add_child(draw_distance_value)
	draw_distance_value.owner = self
	draw_distance_slider.value_changed.connect(func(meters: float) -> void:
		_set_draft(meters, "draw_distance"))
	shadow_option = _add_option(page, "ShadowOption", "Schattenqualität", ["Niedrig", "Mittel", "Hoch", "Ultra"])
	shadow_option.item_selected.connect(func(index: int) -> void:
		_set_draft(shadow_option.get_item_id(index), "shadow_quality"))
	ssao_check = _add_check(page, "SsaoCheck", "SSAO")
	glow_check = _add_check(page, "GlowCheck", "Glow")
	var glow_row := HBoxContainer.new()
	glow_row.name = "GlowStrengthRow"
	page.add_child(glow_row)
	var glow_caption := Label.new()
	glow_caption.text = "Bloom-Stärke"
	glow_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_caption.custom_minimum_size = Vector2(220, 0)
	glow_row.add_child(glow_caption)
	glow_strength_slider = HSlider.new()
	glow_strength_slider.name = "GlowStrengthSlider"
	glow_strength_slider.unique_name_in_owner = true
	glow_strength_slider.min_value = 0.0
	glow_strength_slider.max_value = 200.0
	glow_strength_slider.step = 5.0
	glow_strength_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glow_row.add_child(glow_strength_slider)
	glow_strength_slider.owner = self
	glow_strength_value = Label.new()
	glow_strength_value.name = "GlowStrengthValue"
	glow_strength_value.unique_name_in_owner = true
	glow_strength_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_strength_value.custom_minimum_size = Vector2(72, 0)
	glow_row.add_child(glow_strength_value)
	glow_strength_value.owner = self
	glow_strength_slider.value_changed.connect(func(percent: float) -> void:
		_set_draft(percent / 100.0, "glow_strength"))
	volumetric_check = _add_check(page, "VolumetricFogCheck", "Volumetrischer Nebel")
	ssao_check.toggled.connect(_set_draft.bind("ssao_enabled"))
	glow_check.toggled.connect(_set_draft.bind("glow_enabled"))
	volumetric_check.toggled.connect(_set_draft.bind("volumetric_fog"))


func _add_option(page: VBoxContainer, node_name: String, caption: String, items: Array[String]) -> OptionButton:
	var row := HBoxContainer.new()
	row.name = node_name + "Row"
	page.add_child(row)
	var label := Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(220, 0)
	row.add_child(label)
	var option := OptionButton.new()
	option.name = node_name
	option.unique_name_in_owner = true
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var index := 0
	for entry: String in items:
		option.add_item(entry, index)
		index += 1
	row.add_child(option)
	option.owner = self
	return option


func _add_check(page: VBoxContainer, node_name: String, caption: String) -> CheckButton:
	var check := CheckButton.new()
	check.name = node_name
	check.unique_name_in_owner = true
	check.text = caption
	page.add_child(check)
	check.owner = self
	return check


func _build_key_grid() -> void:
	for action: String in Settings.REBINDABLE_ACTIONS:
		var label := Label.new()
		label.text = Settings.REBINDABLE_ACTIONS[action]
		label.custom_minimum_size.x = 96
		key_grid.add_child(label)

		var button := Button.new()
		button.custom_minimum_size.x = 120
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_start_rebind.bind(action))
		key_grid.add_child(button)
		_key_buttons[action] = button


func _start_rebind(action: String) -> void:
	if not _rebinding_action.is_empty():
		return
	_rebinding_action = action
	_refresh_options()
	glitch_requested.emit(0.5, 0.08)
