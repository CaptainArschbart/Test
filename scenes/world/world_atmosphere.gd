class_name WorldAtmosphere
extends Node
## Tag-Nacht, Wetter und die Grafikwerte aus Settings.
##
## Hängt an der Map (Slum). Die vorhandene DirectionalLight3D "Moon" ist tagsüber die Sonne und
## nachts der Mond (immer die Lichtquelle, die gerade über dem Horizont steht). Der Himmel ist ein
## eigener Shader (world_sky.gdshader) mit Sonne, Mond, Sternen, Wolken und Stadtschein.
## Wetterwechsel blenden weich über. Volumetrischer Nebel, SSAO, Glow, SDFGI und SSR folgen dem Menü.

const DAY_LENGTH := 480.0
const WEATHER_CLEAR := 0
const WEATHER_CLOUD := 1
const WEATHER_RAIN := 2
const WEATHER_FOG := 3
const SKY_SHADER := preload("res://scenes/world/world_sky.gdshader")

## Sekunden, bis ein Wetterwechsel ganz übergeblendet ist.
const WEATHER_BLEND := 20.0

# Himmelsfarben je Tagesphase: [Zenit, Horizont].
const SKY_NIGHT := [Color(0.01, 0.012, 0.035), Color(0.05, 0.035, 0.085)]
const SKY_TWILIGHT := [Color(0.12, 0.14, 0.34), Color(0.9, 0.46, 0.32)]
const SKY_DAY := [Color(0.2, 0.36, 0.62), Color(0.66, 0.7, 0.76)]
const SKY_OVERCAST := [Color(0.34, 0.36, 0.4), Color(0.5, 0.52, 0.55)]

# Umgebungslicht je Phase: [Farbe, Stärke]. Nacht = der bisherige Look der Map.
const AMBIENT_NIGHT := [Color(0.36, 0.38, 0.52), 1.1]
const AMBIENT_TWILIGHT := [Color(0.55, 0.45, 0.52), 1.1]
const AMBIENT_DAY := [Color(0.6, 0.64, 0.72), 1.15]

# Je Wetter: Wolkendecke 0..1, Licht-Faktor, Zusatz-Nebel, Bedeckt-Anteil des Himmels.
const WEATHER_LOOK := {
	WEATHER_CLEAR: [0.46, 1.0, 0.0, 0.0],
	WEATHER_CLOUD: [0.72, 0.55, 0.003, 0.5],
	WEATHER_RAIN: [0.92, 0.38, 0.008, 0.85],
	WEATHER_FOG: [0.75, 0.45, 0.02, 0.7],
}

var time_of_day := 0.35
var weather := WEATHER_CLEAR
var _weather_left := 120.0
var _env: Environment
var _sun: DirectionalLight3D
var _rain: GPUParticles3D
var _sky_mat: ShaderMaterial
var _base_fog := 0.004
# Glow-Werte der Karte, Settings.glow_strength skaliert sie.
var _base_glow_intensity := 0.5
var _base_glow_bloom := 0.02
# Weich nachgeführte Wetterwerte (siehe WEATHER_LOOK).
var _cover := 0.46
var _dim := 1.0
var _fog_extra := 0.0
var _overcast := 0.0
var _cloud_offset := Vector2.ZERO
var _sky_left := 0.0


func _ready() -> void:
	var map := get_parent()
	if map == null:
		return
	var world := map.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_sun = map.get_node_or_null("Moon") as DirectionalLight3D
	if _sun != null:
		# Sonne/Mond nicht im volumetrischen Nebel: sonst zeichnet sich die Kante der Schattenkarte
		# als heller Kasten am Himmel ab. Neonlichter leuchten den Nebel weiter an.
		_sun.light_volumetric_fog_energy = 0.0
	if world != null and world.environment != null:
		_env = world.environment.duplicate(true) as Environment
		world.environment = _env
		_base_fog = maxf(_env.fog_density, 0.004)
		_base_glow_intensity = _env.glow_intensity
		_base_glow_bloom = _env.glow_bloom
		_setup_sky()
	_snap_weather()
	if not Settings.changed.is_connected(_apply_graphics):
		Settings.changed.connect(_apply_graphics)
	_apply_graphics()
	_drive_sun()


func _setup_sky() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	# Der Himmel ändert sich langsam (Sonne, Wolken): Reflexionen schrittweise über mehrere Bilder
	# nachführen statt jedes Bild komplett (Echtzeit würde eine 256er-Cubemap pro Bild erzwingen).
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	# Nebel soll die Stadt eintrüben, den Himmel aber nicht zu einer grauen Fläche machen.
	_env.volumetric_fog_sky_affect = 0.2


func bind_rain(rain: GPUParticles3D) -> void:
	_rain = rain
	_sync_rain()


func _process(delta: float) -> void:
	time_of_day = fposmod(time_of_day + delta / DAY_LENGTH, 1.0)
	_weather_left -= delta
	if _weather_left <= 0.0:
		weather = (weather + 1) % 4
		_weather_left = randf_range(90.0, 170.0)
		_sync_rain()
	_blend_weather(delta)
	_cloud_offset += Vector2(0.006, 0.0025) * delta * (1.0 + _cover)
	# Himmel nur ein paar Mal pro Sekunde neu einstellen: jede Änderung stößt die Reflexionen neu an.
	_sky_left -= delta
	var sky_now := _sky_left <= 0.0
	if sky_now:
		_sky_left = 0.2
	_drive_sun(sky_now)


func _blend_weather(delta: float) -> void:
	var look: Array = WEATHER_LOOK[weather]
	var step := delta / WEATHER_BLEND
	_cover = move_toward(_cover, look[0], step)
	_dim = move_toward(_dim, look[1], step)
	_fog_extra = move_toward(_fog_extra, look[2], step * 0.02)
	_overcast = move_toward(_overcast, look[3], step)
	if _env != null:
		_env.fog_density = _base_fog + _fog_extra
		_env.fog_sky_affect = 0.15 + _overcast * 0.45


## Wetterwerte sofort setzen (Start, Tests).
func _snap_weather() -> void:
	var look: Array = WEATHER_LOOK[weather]
	_cover = look[0]
	_dim = look[1]
	_fog_extra = look[2]
	_overcast = look[3]
	_blend_weather(0.0)


## Richtung zur Sonne: geht im Osten (+X) auf, steht mittags hoch im Süden, geht im Westen unter.
func sun_direction() -> Vector3:
	var angle := (time_of_day - 0.25) * TAU
	return Vector3(cos(angle), sin(angle) * 0.85, 0.4).normalized()


func _drive_sun(update_sky := true) -> void:
	var sun_dir := sun_direction()
	var moon_dir := Vector3(-sun_dir.x, -sun_dir.y, sun_dir.z * 0.5).normalized()
	var alt := sun_dir.y
	var day := smoothstep(0.0, 0.35, alt)
	var twilight := 1.0 - smoothstep(0.06, 0.3, absf(alt + 0.02))
	var night := 1.0 - smoothstep(-0.2, 0.02, alt)
	var sun_up := smoothstep(-0.03, 0.12, alt)
	var moon_up := smoothstep(-0.03, 0.12, moon_dir.y)

	if _sun != null:
		# Immer die Quelle über dem Horizont. Beim Wechsel sind beide fast aus, das Umspringen
		# fällt nicht auf.
		var source := sun_dir if alt > -0.03 else moon_dir
		_sun.global_basis = Basis.looking_at(-source, Vector3.UP)
		var sun_color := Color(1.0, 0.55, 0.32).lerp(Color(1.0, 0.95, 0.86), day)
		if alt > -0.03:
			_sun.light_color = sun_color
			_sun.light_energy = 1.3 * sun_up * _dim
		else:
			_sun.light_color = Color(0.55, 0.64, 0.95)
			_sun.light_energy = 0.3 * moon_up * lerpf(1.0, _dim, 0.6)
		_sun.shadow_enabled = _sun.light_energy > 0.02

	if _env != null:
		var zenith := _phase_color(0, day, twilight, night)
		var horizon := _phase_color(1, day, twilight, night)
		var ambient_color: Color = AMBIENT_NIGHT[0]
		var ambient_energy: float = AMBIENT_NIGHT[1]
		ambient_color = ambient_color.lerp(AMBIENT_TWILIGHT[0], twilight).lerp(AMBIENT_DAY[0], day)
		ambient_energy = lerpf(lerpf(ambient_energy, AMBIENT_TWILIGHT[1], twilight), AMBIENT_DAY[1], day)
		_env.ambient_light_color = ambient_color
		_env.ambient_light_energy = ambient_energy * lerpf(1.0, 0.8, _overcast * day)
		# Nebel in Horizontfarbe, damit die Ferne in den Himmel übergeht. Nachts bleibt er dunkel-blau.
		var haze := horizon.lerp(Color(horizon.get_luminance(), horizon.get_luminance(), horizon.get_luminance()), 0.45)
		_env.fog_light_color = haze.lerp(Color(0.1, 0.1, 0.16), night * 0.6) * lerpf(0.75, 1.0, night)

		if _sky_mat != null and update_sky:
			var sun_color := Color(1.0, 0.5, 0.28).lerp(Color(1.0, 0.92, 0.8), day)
			_sky_mat.set_shader_parameter("zenith_color", zenith)
			_sky_mat.set_shader_parameter("horizon_color", horizon)
			_sky_mat.set_shader_parameter("ground_color", horizon.darkened(0.75))
			_sky_mat.set_shader_parameter("sun_dir", sun_dir)
			_sky_mat.set_shader_parameter("sun_color", sun_color)
			_sky_mat.set_shader_parameter("sun_strength", sun_up * (1.0 - _overcast * 0.85))
			_sky_mat.set_shader_parameter("moon_dir", moon_dir)
			_sky_mat.set_shader_parameter("moon_strength", moon_up * night * (1.0 - _overcast * 0.9))
			_sky_mat.set_shader_parameter("star_strength", night * (1.0 - _cover) * 1.4)
			_sky_mat.set_shader_parameter("city_strength", night * 0.45 + twilight * 0.1)
			_sky_mat.set_shader_parameter("cloud_cover", _cover)
			var cloud_lit := Color(0.07, 0.065, 0.11).lerp(Color(0.95, 0.6, 0.48), twilight).lerp(Color(0.92, 0.93, 0.96), day)
			var cloud_dark := Color(0.025, 0.022, 0.045).lerp(Color(0.32, 0.22, 0.32), twilight).lerp(Color(0.5, 0.52, 0.58), day)
			var dark := lerpf(1.0, 0.6, _overcast)
			_sky_mat.set_shader_parameter("cloud_color", cloud_lit * dark)
			_sky_mat.set_shader_parameter("cloud_shade", cloud_dark * dark)
			_sky_mat.set_shader_parameter("cloud_offset", _cloud_offset)


## Himmelsfarbe (0 = Zenit, 1 = Horizont) aus Nacht, Dämmerung, Tag und Bewölkung gemischt.
func _phase_color(index: int, day: float, twilight: float, night: float) -> Color:
	var c: Color = SKY_NIGHT[index]
	c = c.lerp(SKY_TWILIGHT[index], twilight * (1.0 - night * 0.5))
	c = c.lerp(SKY_DAY[index], day)
	var grey: Color = SKY_OVERCAST[index]
	return c.lerp(grey * lerpf(0.12, 1.0, day), _overcast * 0.8)


func _sync_rain() -> void:
	if _rain == null:
		return
	_rain.emitting = weather == WEATHER_RAIN


func _apply_graphics() -> void:
	if _env == null:
		return
	_env.fog_enabled = true
	_env.volumetric_fog_enabled = Settings.volumetric_fog
	_env.ssao_enabled = Settings.ssao_enabled
	_env.glow_enabled = Settings.glow_enabled and Settings.glow_strength > 0.0
	_env.glow_intensity = _base_glow_intensity * Settings.glow_strength
	_env.glow_bloom = _base_glow_bloom * Settings.glow_strength
	var high := Settings.gi_mode >= Settings.GI_HIGH
	var normal := Settings.gi_mode >= Settings.GI_NORMAL
	_env.ssr_enabled = normal
	_env.ssr_max_steps = 96 if high else 48
	_env.sdfgi_enabled = high
	if high:
		_env.sdfgi_cascades = 6
		_env.sdfgi_min_cell_size = 0.25
	_apply_shadows()


func _apply_shadows() -> void:
	if _sun == null:
		return
	match Settings.shadow_quality:
		0:
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			_sun.directional_shadow_max_distance = 40.0
			_sun.shadow_blur = 0.4
		1:
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			_sun.directional_shadow_max_distance = 60.0
			_sun.shadow_blur = 0.8
		3:
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			# Mehr Reichweite zeichnet die halbe Stadt pro Kaskade noch einmal (CPU), sieht kaum anders aus.
			_sun.directional_shadow_max_distance = minf(Settings.draw_distance, 100.0)
			_sun.shadow_blur = 1.4
		_:
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			_sun.directional_shadow_max_distance = 80.0
			_sun.shadow_blur = 1.0
