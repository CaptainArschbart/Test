extends Node
## Spieler-Einstellungen (Autoload "Settings").
##
## Lädt user://settings.cfg beim Spielstart, wendet alles an und speichert auf
## Wunsch. Das Optionsmenü arbeitet auf einer Kopie (siehe get_values) und ruft
## erst bei "Übernehmen" apply_values() auf.

signal changed

const PATH := "user://settings.cfg"

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
## 0–100 (%)
var master_volume := 80.0
## Faktor auf Player.mouse_sensitivity (1.0 = Standard).
var mouse_sensitivity := 1.0
var invert_y := false
## Aktion → physical_keycode
var key_bindings := {}

var _default_bindings := {}


func _ready() -> void:
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
		"master_volume": master_volume,
		"mouse_sensitivity": mouse_sensitivity,
		"invert_y": invert_y,
		"key_bindings": key_bindings.duplicate(),
	}


## Standardwerte als Dictionary.
func get_defaults() -> Dictionary:
	return {
		"fullscreen": false,
		"vsync": true,
		"master_volume": 80.0,
		"mouse_sensitivity": 1.0,
		"invert_y": false,
		"key_bindings": _default_bindings.duplicate(),
	}


## Übernimmt Werte (z. B. aus dem Menü), wendet sie an und speichert.
func apply_values(values: Dictionary) -> void:
	fullscreen = values.fullscreen
	vsync = values.vsync
	master_volume = values.master_volume
	mouse_sensitivity = values.mouse_sensitivity
	invert_y = values.invert_y
	key_bindings = values.key_bindings.duplicate()
	apply()
	save_settings()


func apply() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume / 100.0))
	AudioServer.set_bus_mute(bus, master_volume <= 0.0)

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
	var keycode := DisplayServer.keyboard_get_keycode_from_physical(physical_keycode)
	return OS.get_keycode_string(keycode if keycode != KEY_NONE else physical_keycode)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return  # Noch keine Datei: Standardwerte bleiben.
	fullscreen = config.get_value("video", "fullscreen", fullscreen)
	vsync = config.get_value("video", "vsync", vsync)
	master_volume = config.get_value("audio", "master_volume", master_volume)
	mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	invert_y = config.get_value("controls", "invert_y", invert_y)
	for action: String in REBINDABLE_ACTIONS:
		key_bindings[action] = config.get_value("keys", action, key_bindings[action])


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("controls", "invert_y", invert_y)
	for action: String in key_bindings:
		config.set_value("keys", action, key_bindings[action])
	config.save(PATH)


func _read_binding(action: String) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	return KEY_NONE
