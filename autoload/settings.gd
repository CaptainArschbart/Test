extends Node
## Spieler-Einstellungen (Autoload "Settings").
##
## Lädt user://settings.cfg beim Spielstart, wendet alles an und speichert auf
## Wunsch. Hauptmenü und Pausemenü benutzen dieselbe Options-Szene
## (scenes/options/options_menu.tscn). Sie arbeitet auf einer Kopie (siehe get_values)
## und ruft erst bei "Übernehmen" apply_values() auf (anwenden und speichern in einem
## Schritt). Nur F11 geht direkt über toggle_fullscreen().

signal changed

const PATH := "user://settings.cfg"

## Audio-Busse. "Master" gibt es immer. Music und SFX stehen in default_bus_layout.tres
## und werden bei Bedarf in _ensure_buses() nachgelegt.
const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

## Kleinste einstellbare 3D-Auflösung (Faktor auf die Fenstergröße).
const RENDER_SCALE_MIN := 0.5

## Aktionen aus der Input Map, die im Menü neu belegt werden können (Aktion → Anzeigename).
const REBINDABLE_ACTIONS := {
	"move_forward": "Vorwärts",
	"move_back": "Rückwärts",
	"move_left": "Links",
	"move_right": "Rechts",
	"jump": "Springen",
	"sprint": "Sprinten",
	"inventory": "Inventar",
	"drop_item": "Wegwerfen",
	"hotbar_1": "Slot 1",
	"hotbar_2": "Slot 2",
	"hotbar_3": "Slot 3",
	"hotbar_4": "Slot 4",
	"hotbar_5": "Slot 5",
	"hotbar_6": "Slot 6",
	"hotbar_7": "Slot 7",
	"hotbar_8": "Slot 8",
	"hotbar_9": "Slot 9",
	"noclip": "Noclip an/aus",
	"noclip_down": "Noclip runter",
}

var fullscreen := false
var vsync := true
## Kantenglättung der 3D-Szene als Viewport.MSAA: 0 = aus, 1 = 2x, 2 = 4x, 3 = 8x.
var msaa: int = Viewport.MSAA_4X
## 3D-Auflösung als Faktor auf die Fenstergröße (RENDER_SCALE_MIN bis 1.0).
var render_scale := 1.0
## 0–100 (%)
var master_volume := 80.0
## 0–100 (%), Bus "Music"
var music_volume := 100.0
## 0–100 (%), Bus "SFX"
var sfx_volume := 100.0
## Faktor auf Player.mouse_sensitivity (1.0 = Standard).
var mouse_sensitivity := 1.0
var invert_y := false
## Aktion → physical_keycode
var key_bindings := {}

var _default_bindings := {}


func _ready() -> void:
	_ensure_buses()
	for action: String in REBINDABLE_ACTIONS:
		_default_bindings[action] = _read_binding(action)
	key_bindings = _default_bindings.duplicate()
	load_settings()
	apply()


## Aktuelle Werte als Dictionary (zum Bearbeiten im Menü).
func get_values() -> Dictionary:
	return {
		"fullscreen": fullscreen,
		"vsync": vsync,
		"msaa": msaa,
		"render_scale": render_scale,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"mouse_sensitivity": mouse_sensitivity,
		"invert_y": invert_y,
		"key_bindings": key_bindings.duplicate(),
	}


## Standardwerte als Dictionary.
func get_defaults() -> Dictionary:
	return {
		"fullscreen": false,
		"vsync": true,
		"msaa": Viewport.MSAA_4X,
		"render_scale": 1.0,
		"master_volume": 80.0,
		"music_volume": 100.0,
		"sfx_volume": 100.0,
		"mouse_sensitivity": 1.0,
		"invert_y": false,
		"key_bindings": _default_bindings.duplicate(),
	}


## Übernimmt Werte (z. B. aus dem Menü), wendet sie an und speichert.
func apply_values(values: Dictionary) -> void:
	fullscreen = values.fullscreen
	vsync = values.vsync
	# Neuere Schlüssel mit Rückfall, falls ein Aufrufer ein älteres Dictionary übergibt.
	msaa = values.get("msaa", msaa)
	render_scale = values.get("render_scale", render_scale)
	master_volume = values.master_volume
	music_volume = values.get("music_volume", music_volume)
	sfx_volume = values.get("sfx_volume", sfx_volume)
	mouse_sensitivity = values.mouse_sensitivity
	invert_y = values.invert_y
	key_bindings = values.key_bindings.duplicate()
	apply()
	save_settings()


## Wendet alle Werte an. Darf beliebig oft aufgerufen werden.
func apply() -> void:
	# Den Fenstermodus nur anfassen, wenn sich der Vollbild-Zustand ändert. Sonst würde
	# jedes apply() ein maximiertes Fenster wieder auf "Fenster" zurücksetzen.
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if fullscreen != is_fullscreen:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

	var viewport := get_viewport()
	viewport.msaa_3d = msaa as Viewport.MSAA
	viewport.scaling_3d_scale = render_scale

	_apply_bus(MASTER_BUS, master_volume)
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)

	for action: String in key_bindings:
		if key_bindings[action] == KEY_NONE:
			continue
		var event := InputEventKey.new()
		event.physical_keycode = key_bindings[action]
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)
	changed.emit()


## Vollbild direkt umschalten (F11) und merken.
func toggle_fullscreen() -> void:
	fullscreen = DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
	apply()
	save_settings()


## Lesbarer Name einer Taste im aktuellen Tastaturlayout.
static func key_name(physical_keycode: int) -> String:
	# Der Headless-Server kennt kein Tastaturlayout und meldet bei der Abfrage einen Fehler.
	var keycode := KEY_NONE
	if DisplayServer.get_name() != "headless":
		keycode = DisplayServer.keyboard_get_keycode_from_physical(physical_keycode) as Key
	return OS.get_keycode_string(keycode if keycode != KEY_NONE else physical_keycode)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return  # Noch keine Datei: Standardwerte bleiben.
	fullscreen = config.get_value("video", "fullscreen", fullscreen)
	vsync = config.get_value("video", "vsync", vsync)
	msaa = clampi(int(config.get_value("video", "msaa", msaa)), Viewport.MSAA_DISABLED, Viewport.MSAA_8X)
	render_scale = clampf(float(config.get_value("video", "render_scale", render_scale)), RENDER_SCALE_MIN, 1.0)
	master_volume = config.get_value("audio", "master_volume", master_volume)
	music_volume = clampf(float(config.get_value("audio", "music_volume", music_volume)), 0.0, 100.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 100.0)
	mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	invert_y = config.get_value("controls", "invert_y", invert_y)
	for action: String in REBINDABLE_ACTIONS:
		key_bindings[action] = config.get_value("keys", action, key_bindings[action])


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "msaa", msaa)
	config.set_value("video", "render_scale", render_scale)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("controls", "invert_y", invert_y)
	for action: String in key_bindings:
		config.set_value("keys", action, key_bindings[action])
	config.save(PATH)


## Lautstärke in Prozent auf einen Bus anwenden. Fehlt der Bus, passiert nichts.
func _apply_bus(bus_name: String, percent: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(percent / 100.0) if percent > 0.0 else -80.0)
	AudioServer.set_bus_mute(bus, percent <= 0.0)


## Legt Music und SFX an, falls default_bus_layout.tres fehlt oder sie dort nicht stehen.
func _ensure_buses() -> void:
	for bus_name: String in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, MASTER_BUS)


func _read_binding(action: String) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	return KEY_NONE
