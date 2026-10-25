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
## So heißt das System-Standardgerät in AudioServer.get_output_device_list().
const DEFAULT_OUTPUT_DEVICE := "Default"

## Kleinste einstellbare 3D-Auflösung (Faktor auf die Fenstergröße).
const RENDER_SCALE_MIN := 0.5
## 3D wird höchstens auf diese Kantenlänge gerendert. Darüber würde ein 2K-/4K-Puffer
## den Frame so lang machen, dass die Steuerung stehen bleibt.
const RENDER_LONG_EDGE := 1920
## Auswählbare Fenstergrößen. Im Menü erscheinen nur die, die auf den Monitor passen.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1366, 768),
	Vector2i(1440, 900),
	Vector2i(1600, 900),
	Vector2i(1680, 1050),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]
## Fenstergröße beim ersten Start (wie viewport_width/height in project.godot).
const DEFAULT_RESOLUTION := Vector2i(1280, 720)

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
## Fenstergröße im Fenstermodus.
var resolution := DEFAULT_RESOLUTION
## Auflösung der 3D-Welt im Vollbild. Vector2i.ZERO = Monitorauflösung (Standard).
## Kleinere Werte rendern die 3D-Welt gröber und skalieren sie hoch, die Oberfläche
## bleibt immer scharf in Monitorauflösung.
var fullscreen_resolution := Vector2i.ZERO
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
## Name des Audio-Ausgabegeräts aus AudioServer.get_output_device_list().
## "Default" = Standardgerät des Systems.
var output_device := DEFAULT_OUTPUT_DEVICE
## Faktor auf Player.mouse_sensitivity (1.0 = Standard).
var mouse_sensitivity := 1.0
var invert_y := false
## Aktion → physical_keycode
var key_bindings := {}

var _default_bindings := {}
var _applied_window_size := Vector2i(-1, -1)
## Zuletzt gesetzte Fenstergröße. Nur bei einer Änderung wird das Fenster neu gesetzt,
## damit apply() ein von Hand vergrößertes Fenster nicht jedes Mal zurücksetzt.
var _applied_resolution := Vector2i(-1, -1)
var _applying_scale := false


func _ready() -> void:
	_ensure_buses()
	for action: String in REBINDABLE_ACTIONS:
		_default_bindings[action] = _read_binding(action)
	key_bindings = _default_bindings.duplicate()
	load_settings()
	apply()
	var root := get_tree().root
	if not root.size_changed.is_connected(_on_root_size_changed):
		root.size_changed.connect(_on_root_size_changed)


## Aktuelle Werte als Dictionary (zum Bearbeiten im Menü).
func get_values() -> Dictionary:
	return {
		"fullscreen": fullscreen,
		"vsync": vsync,
		"resolution": resolution,
		"fullscreen_resolution": fullscreen_resolution,
		"msaa": msaa,
		"render_scale": render_scale,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"output_device": output_device,
		"mouse_sensitivity": mouse_sensitivity,
		"invert_y": invert_y,
		"key_bindings": key_bindings.duplicate(),
	}


## Standardwerte als Dictionary.
func get_defaults() -> Dictionary:
	return {
		"fullscreen": false,
		"vsync": true,
		"resolution": DEFAULT_RESOLUTION,
		"fullscreen_resolution": Vector2i.ZERO,
		"msaa": Viewport.MSAA_4X,
		"render_scale": 1.0,
		"master_volume": 80.0,
		"music_volume": 100.0,
		"sfx_volume": 100.0,
		"output_device": DEFAULT_OUTPUT_DEVICE,
		"mouse_sensitivity": 1.0,
		"invert_y": false,
		"key_bindings": _default_bindings.duplicate(),
	}


## Übernimmt Werte (z. B. aus dem Menü), wendet sie an und speichert.
func apply_values(values: Dictionary) -> void:
	fullscreen = values.fullscreen
	vsync = values.vsync
	# Neuere Schlüssel mit Rückfall, falls ein Aufrufer ein älteres Dictionary übergibt.
	resolution = values.get("resolution", resolution)
	fullscreen_resolution = values.get("fullscreen_resolution", fullscreen_resolution)
	msaa = values.get("msaa", msaa)
	render_scale = values.get("render_scale", render_scale)
	master_volume = values.master_volume
	music_volume = values.get("music_volume", music_volume)
	sfx_volume = values.get("sfx_volume", sfx_volume)
	output_device = values.get("output_device", output_device)
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
	_apply_resolution()
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

	var viewport := get_viewport()
	viewport.msaa_3d = msaa as Viewport.MSAA
	_apply_3d_scale()

	_apply_bus(MASTER_BUS, master_volume)
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)
	_apply_output_device()

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
	var saved_resolution: Variant = config.get_value("video", "resolution", resolution)
	if saved_resolution is Vector2i and saved_resolution.x >= 640 and saved_resolution.y >= 360:
		resolution = saved_resolution
	var saved_fullscreen: Variant = config.get_value("video", "fullscreen_resolution", fullscreen_resolution)
	if saved_fullscreen is Vector2i and (saved_fullscreen == Vector2i.ZERO or (saved_fullscreen.x >= 640 and saved_fullscreen.y >= 360)):
		fullscreen_resolution = saved_fullscreen
	msaa = clampi(int(config.get_value("video", "msaa", msaa)), Viewport.MSAA_DISABLED, Viewport.MSAA_8X)
	render_scale = clampf(float(config.get_value("video", "render_scale", render_scale)), RENDER_SCALE_MIN, 1.0)
	master_volume = config.get_value("audio", "master_volume", master_volume)
	music_volume = clampf(float(config.get_value("audio", "music_volume", music_volume)), 0.0, 100.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 100.0)
	output_device = str(config.get_value("audio", "output_device", output_device))
	mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	invert_y = config.get_value("controls", "invert_y", invert_y)
	for action: String in REBINDABLE_ACTIONS:
		key_bindings[action] = config.get_value("keys", action, key_bindings[action])


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "resolution", resolution)
	config.set_value("video", "fullscreen_resolution", fullscreen_resolution)
	config.set_value("video", "msaa", msaa)
	config.set_value("video", "render_scale", render_scale)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "output_device", output_device)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("controls", "invert_y", invert_y)
	for action: String in key_bindings:
		config.set_value("keys", action, key_bindings[action])
	config.save(PATH)


## Auflösungen aus RESOLUTIONS, die auf den aktuellen Monitor passen, plus die
## Monitorauflösung selbst. Ohne Monitorgröße (headless) alle aus RESOLUTIONS.
static func available_resolutions() -> Array[Vector2i]:
	var screen := DisplayServer.screen_get_size()
	var result: Array[Vector2i] = []
	for size: Vector2i in RESOLUTIONS:
		if screen.x <= 0 or screen.y <= 0 or (size.x <= screen.x and size.y <= screen.y):
			result.append(size)
	if screen.x > 0 and screen.y > 0 and not result.has(screen):
		result.append(screen)
		result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y)
	return result


## Fenstermodus: das Fenster bekommt die gewählte Größe (höchstens Monitorgröße) und
## wird zentriert. Das passiert nur, wenn sich die Größe ändert oder man aus dem
## Vollbild kommt, damit apply() ein von Hand vergrößertes Fenster nicht zurücksetzt.
## Vollbild: das Fenster hat Monitorgröße, die gewählte Vollbild-Auflösung wirkt über
## _apply_3d_scale() auf die 3D-Welt.
## Die Oberfläche skaliert in beiden Fällen über den Stretch-Modus aus project.godot
## (canvas_items, Basis 1280×720) und wird immer in voller Fenstergröße gezeichnet.
func _apply_resolution() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		_applied_resolution = Vector2i(-1, -1)
		return
	if resolution == _applied_resolution:
		return
	_applied_resolution = resolution
	var screen_id := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen_id)
	var size := resolution
	if screen_size.x > 0 and screen_size.y > 0:
		size = Vector2i(mini(size.x, screen_size.x), mini(size.y, screen_size.y))
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	var origin := DisplayServer.screen_get_position(screen_id)
	DisplayServer.window_set_position(origin + (screen_size - size) / 2)


## Faktor fürs 3D-Bild. Unter oder bei 1920 px bleibt der Reglerwert. Darüber wird
## auf etwa Full HD begrenzt. Fenstergröße 0 (noch kein Fenster) teilt nicht.
static func scale_for_window(scale: float, window_size: Vector2i) -> float:
	var longest := maxi(window_size.x, window_size.y)
	if longest <= RENDER_LONG_EDGE:
		return scale
	return minf(scale, float(RENDER_LONG_EDGE) / float(longest))


## Faktor, um den die Vollbild-Auflösung kleiner ist als das Fenster (1.0 = nativ).
static func fullscreen_factor(target: Vector2i, window_size: Vector2i) -> float:
	if target == Vector2i.ZERO or window_size.x <= 0 or window_size.y <= 0:
		return 1.0
	return minf(1.0, minf(float(target.x) / window_size.x, float(target.y) / window_size.y))


func _on_root_size_changed() -> void:
	if _applying_scale:
		return
	var size := DisplayServer.window_get_size()
	if size.x <= 0 or size.y <= 0 or size == _applied_window_size:
		return
	_applied_window_size = size
	_apply_3d_scale()


func _apply_3d_scale() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var size := DisplayServer.window_get_size()
	var scale := render_scale
	if fullscreen:
		scale *= fullscreen_factor(fullscreen_resolution, size)
	scale = scale_for_window(scale, size)
	# Hochskalieren mit FSR statt bilinear, sieht deutlich schärfer aus. Der
	# Kompatibilitäts-Renderer (OpenGL) kann nur bilinear.
	var mode := Viewport.SCALING_3D_MODE_BILINEAR
	if scale < 1.0 and RenderingServer.get_current_rendering_method() != "gl_compatibility":
		mode = Viewport.SCALING_3D_MODE_FSR
	if viewport.scaling_3d_mode != mode:
		viewport.scaling_3d_mode = mode
	if is_equal_approx(viewport.scaling_3d_scale, scale):
		_applied_window_size = size
		return
	_applying_scale = true
	viewport.scaling_3d_scale = scale
	_applying_scale = false
	_applied_window_size = size


## Stellt einen Bus sofort, ohne zu speichern. Der Musik-Regler nutzt das für "Music".
func preview_bus(bus_name: String, percent: float) -> void:
	_apply_bus(bus_name, percent)


## Stellt das gewählte Ausgabegerät ein. Ist es gerade nicht angeschlossen, läuft der
## Ton über das Standardgerät; die Wahl bleibt gespeichert und greift wieder, sobald
## das Gerät da ist und apply() erneut läuft (z. B. beim nächsten Spielstart).
func _apply_output_device() -> void:
	var target := output_device
	if not AudioServer.get_output_device_list().has(target):
		target = DEFAULT_OUTPUT_DEVICE
	if AudioServer.output_device != target:
		AudioServer.output_device = target


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
