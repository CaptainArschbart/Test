class_name WorldAtmosphere
extends Node
## Tag-Nacht, Wetter und die Grafikwerte aus Settings.
##
## Hängt an der Map (Slum). Die vorhandene DirectionalLight3D "Moon" wird die Sonne.
## Tiefer Nebel bleibt an. Volumetrischer Nebel, SSAO, Glow, SDFGI und SSR folgen dem Menü.

const DAY_LENGTH := 480.0
const WEATHER_CLEAR := 0
const WEATHER_CLOUD := 1
const WEATHER_RAIN := 2
const WEATHER_FOG := 3

var time_of_day := 0.35
var weather := WEATHER_CLEAR
var _weather_left := 120.0
var _env: Environment
var _sun: DirectionalLight3D
var _rain: GPUParticles3D
var _base_fog := 0.004


func _ready() -> void:
	var map := get_parent()
	if map == null:
		return
	var world := map.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_sun = map.get_node_or_null("Moon") as DirectionalLight3D
	if world != null and world.environment != null:
		_env = world.environment.duplicate(true) as Environment
		world.environment = _env
		_base_fog = maxf(_env.fog_density, 0.004)
	if not Settings.changed.is_connected(_apply_graphics):
		Settings.changed.connect(_apply_graphics)
	_apply_graphics()
	_drive_sun()


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
		_apply_graphics()
	_drive_sun()


func _drive_sun() -> void:
	if _sun == null:
		return
	var altitude := sin((time_of_day - 0.25) * TAU)
	var day := clampf(altitude, 0.0, 1.0)
	_sun.rotation = Vector3(-altitude * 1.1, time_of_day * TAU, 0.0)
	var dim := 1.0
	if weather == WEATHER_CLOUD:
		dim = 0.55
	elif weather == WEATHER_RAIN:
		dim = 0.38
	elif weather == WEATHER_FOG:
		dim = 0.45
	_sun.light_energy = lerpf(0.05, 1.25, day) * dim
	_sun.light_color = Color(0.45, 0.55, 0.9).lerp(Color(1.0, 0.94, 0.82), day)
	_sun.shadow_enabled = true
	_apply_shadows()


func _sync_rain() -> void:
	if _rain == null:
		return
	_rain.emitting = weather == WEATHER_RAIN


func _apply_graphics() -> void:
	if _env == null:
		return
	_env.fog_enabled = true
	var extra := 0.0
	if weather == WEATHER_FOG:
		extra = 0.02
	elif weather == WEATHER_RAIN:
		extra = 0.008
	elif weather == WEATHER_CLOUD:
		extra = 0.003
	_env.fog_density = _base_fog + extra
	_env.volumetric_fog_enabled = Settings.volumetric_fog
	_env.ssao_enabled = Settings.ssao_enabled
	_env.glow_enabled = Settings.glow_enabled
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
			_sun.directional_shadow_max_distance = minf(Settings.draw_distance, 160.0)
			_sun.shadow_blur = 1.4
		_:
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			_sun.directional_shadow_max_distance = 80.0
			_sun.shadow_blur = 1.0
