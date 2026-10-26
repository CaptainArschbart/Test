extends CanvasLayer
## Low-Health-Effekte am Player: rote Vignette im Herzschlag-Takt, Entsättigung, Tunnelblick,
## Herzschlag- und Atemgeräusch (prozedural, VitalSounds) und leichtes Kamerawackeln.
##
## Ab warn_ratio (30 %) beginnt es leise, bei critical_ratio (15 %) ist es deutlich, bei 0 voll.
## Steigt schnell an (rise_speed), klingt beim Heilen langsam ab (fall_speed).
## Jeder HP-Verlust gibt zusätzlich einen kurzen roten Blitz (auch bei voller Gesundheit).
## Wird vom Player im Code erzeugt (player.tscn bleibt gleich). Liegt auf CanvasLayer 1,
## also unter dem HUD (Layer 2). Läuft nicht im Pausemenü (PROCESS_MODE_PAUSABLE), aber weiter,
## wenn der Player beim Tod angehalten wird.

const SHADER := preload("res://scenes/survival/low_health_fx.gdshader")
const VitalSounds := preload("res://scenes/survival/vital_sounds.gd")

## HP-Anteil, ab dem die Effekte beginnen.
@export_range(0.0, 1.0) var warn_ratio := 0.30
## HP-Anteil, ab dem es kritisch wird (Atem, starkes Pulsieren).
@export_range(0.0, 1.0) var critical_ratio := 0.15
## Anstieg bzw. Abklingen der Stärke pro Sekunde.
@export var rise_speed := 2.5
@export var fall_speed := 0.45
## Puls bei Beginn bzw. kurz vor dem Tod.
@export var bpm_low := 78.0
@export var bpm_high := 150.0
## Kamerawackeln in Metern (Camera3D.h_offset/v_offset) bei voller Stärke.
@export var shake_strength := 0.012
@export var heartbeat_db := -3.0
@export var breath_db := -9.0

## Aktuelle (geglättete) Stärke 0…1.
var intensity := 0.0
## Herzschlag-Hüllkurve 0…1 (für Shader und Tests).
var pulse := 0.0

var _player: Player
var _stats: PlayerStats
var _rect: ColorRect
var _material: ShaderMaterial
var _heart: AudioStreamPlayer
var _breath: AudioStreamPlayer
var _phase := 0.0
var _hit := 0.0
var _time := 0.0
var _last_hp := -1.0


func _ready() -> void:
	name = "LowHealthFx"
	layer = 1
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_player = get_parent() as Player
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "Overlay"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)
	_heart = _make_player("Heartbeat", VitalSounds.heartbeat())
	_breath = _make_player("Breath", VitalSounds.breath())
	if _player == null:
		push_error("LowHealthFx braucht den Player als Parent.")
		return
	_stats = _player.get_node_or_null(^"PlayerStats") as PlayerStats
	if _stats != null:
		_last_hp = _stats.hp
		_stats.stat_changed.connect(_on_stat_changed)


func _process(delta: float) -> void:
	if _stats == null:
		return
	advance(delta)


## Eine Zeitscheibe (Tests rufen das direkt auf).
func advance(delta: float) -> void:
	_time += delta
	var alive := _stats.is_alive()
	var target := 1.0 if not alive else level_for_ratio(_stats.hp / maxf(_stats.max_hp, 0.001))
	var rate := rise_speed if target > intensity else fall_speed
	intensity = move_toward(intensity, target, rate * delta)
	_hit = maxf(_hit - delta * 2.2, 0.0)

	# Herzschlag: nur solange man lebt. Beim Tod übernimmt der Flatline-Ton des Death-Screens.
	if alive and intensity > 0.01:
		var bpm := lerpf(bpm_low, bpm_high, intensity)
		_phase += delta * bpm / 60.0
		if _phase >= 1.0:
			_phase = fmod(_phase, 1.0)
			_beat()
		pulse = beat_envelope(_phase)
	else:
		_phase = 0.0
		pulse = move_toward(pulse, 0.0, delta * 4.0)

	_update_breath(alive)
	_update_overlay()
	_update_camera(alive)


## Stärke für einen HP-Anteil: 0 ab warn_ratio, knapp darunter gleich 0,25 (sichtbar),
## 0,6 bei critical_ratio, 1 bei 0 HP.
func level_for_ratio(ratio: float) -> float:
	if ratio >= warn_ratio:
		return 0.0
	var low := clampf((warn_ratio - ratio) / maxf(warn_ratio - critical_ratio, 0.001), 0.0, 1.0)
	var crit := clampf((critical_ratio - ratio) / maxf(critical_ratio, 0.001), 0.0, 1.0)
	return 0.25 + low * 0.35 + crit * 0.4


## „Lub“ am Anfang, „dub“ bei 0,22 der Periode, dazwischen fällt es ab.
static func beat_envelope(phase: float) -> float:
	var lub := exp(-phase * 16.0)
	var dub := 0.0
	if phase >= 0.22:
		dub = exp(-(phase - 0.22) * 16.0) * 0.65
	return clampf(lub + dub, 0.0, 1.0)


## Alles sofort zurück (Respawn). Kein Abklingen, kein Nachhall.
func reset() -> void:
	intensity = 0.0
	pulse = 0.0
	_phase = 0.0
	_hit = 0.0
	if _stats != null:
		_last_hp = _stats.hp
	_heart.stop()
	_breath.stop()
	_rect.visible = false
	_reset_camera()


func _on_stat_changed(stat_name: String, current: float, maximum: float) -> void:
	if stat_name != PlayerStats.STAT_HP:
		return
	var lost := _last_hp - current
	_last_hp = current
	# Hunger/Durst ticken in kleinen Schritten, das soll nicht dauernd blitzen.
	if lost > 1.5 and maximum > 0.0:
		_hit = maxf(_hit, clampf(lost / (maximum * 0.25), 0.35, 1.0))


func _beat() -> void:
	_heart.volume_db = heartbeat_db + linear_to_db(lerpf(0.3, 1.0, intensity))
	_heart.pitch_scale = lerpf(1.0, 1.12, intensity)
	_heart.play()


func _update_breath(alive: bool) -> void:
	var strength := clampf((intensity - 0.45) / 0.55, 0.0, 1.0) if alive else 0.0
	if strength <= 0.01:
		if _breath.playing:
			_breath.stop()
		return
	_breath.volume_db = breath_db + linear_to_db(strength)
	_breath.pitch_scale = lerpf(1.0, 1.25, strength)
	if not _breath.playing:
		_breath.play()


func _update_overlay() -> void:
	var show := intensity > 0.002 or _hit > 0.002
	_rect.visible = show
	if not show:
		return
	_material.set_shader_parameter(&"intensity", intensity)
	_material.set_shader_parameter(&"pulse", pulse)
	_material.set_shader_parameter(&"hit", _hit)


func _update_camera(alive: bool) -> void:
	if _player == null or _player.camera == null:
		return
	if not alive:
		_reset_camera()
		return
	var amount := shake_strength * pow(intensity, 1.5)
	var t := _time
	_player.camera.h_offset = (sin(t * 11.3) + sin(t * 4.1 + 1.7) * 0.7) * 0.5 * amount
	_player.camera.v_offset = (sin(t * 9.7 + 0.4) + sin(t * 3.3) * 0.6) * 0.5 * amount \
		- pulse * intensity * 0.004


func _reset_camera() -> void:
	if _player != null and _player.camera != null:
		_player.camera.h_offset = 0.0
		_player.camera.v_offset = 0.0


func _make_player(node_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = stream
	player.bus = &"SFX"
	add_child(player)
	return player
