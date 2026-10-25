class_name ShootingTarget
extends StaticBody3D
## Zielscheibe für den Schießstand. Liegt auf Layer world, damit der Hitscan sie trifft.
##
## Jeder Treffer zeigt den Schaden als aufsteigende Zahl. Darüber steht die Summe
## der Serie (Treffer, Gesamtschaden, Schaden pro Sekunde). Nach `reset_after`
## Sekunden ohne Treffer beginnt eine neue Serie.
## Mit move_distance > 0 fährt die Scheibe seitlich hin und her.

signal hit(damage: float, total: float)

## Sekunden ohne Treffer, bis die Anzeige zurückgesetzt wird.
@export var reset_after := 4.0
## Weg nach links und rechts (Meter). 0 = steht still.
@export var move_distance := 0.0
@export var move_speed := 1.5
## Wird an die Anzeige gehängt, z. B. "10 m".
@export var caption := ""

var total_damage := 0.0
var hit_count := 0

var _first_hit_time := 0.0
var _last_hit_time := -100.0
var _start_position: Vector3
var _time := 0.0
## Läuft nur ohne Pause, damit DPS nicht die Pausenzeit mitzählt.
var _clock := 0.0
var _flash_tween: Tween

@onready var face: MeshInstance3D = $Face
@onready var stats_label: Label3D = $StatsLabel


func _ready() -> void:
	_start_position = position
	face.material_override = face.mesh.surface_get_material(0).duplicate()
	_update_label()


func _process(delta: float) -> void:
	_clock += delta
	if move_distance > 0.0:
		_time += delta
		position = _start_position + basis.x * sin(_time * move_speed) * move_distance
	if hit_count > 0 and _now() - _last_hit_time > reset_after:
		reset_stats()


## Wird von WeaponHolder aufgerufen.
func take_hit(damage: float, point: Vector3, _normal: Vector3) -> void:
	var now := _now()
	if hit_count == 0:
		_first_hit_time = now
	hit_count += 1
	total_damage += damage
	_last_hit_time = now
	_spawn_number(damage, point)
	_flash()
	_update_label()
	hit.emit(damage, total_damage)


func reset_stats() -> void:
	hit_count = 0
	total_damage = 0.0
	_update_label()


## Schaden pro Sekunde seit dem ersten Treffer der Serie (bei einem Treffer: 0).
func get_dps() -> float:
	var span := _last_hit_time - _first_hit_time
	if hit_count < 2 or span <= 0.0:
		return 0.0
	return total_damage / span


func _update_label() -> void:
	var head := caption + "\n" if caption != "" else ""
	if hit_count == 0:
		stats_label.text = head + "SCHIESS MICH"
		return
	stats_label.text = "%sTreffer %d · Schaden %s\nDPS %.1f" % [
		head, hit_count, _fmt(total_damage), get_dps()]


## Zahl, die vom Einschlag aufsteigt und verblasst.
func _spawn_number(damage: float, point: Vector3) -> void:
	var label := Label3D.new()
	label.text = "-" + _fmt(damage)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.font_size = 48
	label.outline_size = 12
	label.modulate = Color(1.0, 0.85, 0.2)
	label.outline_modulate = Color(0.3, 0.0, 0.2, 0.9)
	get_tree().current_scene.add_child(label)
	label.global_position = point + Vector3(randf_range(-0.1, 0.1), 0.15, 0.0)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position:y", label.global_position.y + 0.8, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func _flash() -> void:
	var material := face.material_override as StandardMaterial3D
	if material == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	material.emission_energy_multiplier = 6.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(material, "emission_energy_multiplier", 1.2, 0.25)


func _now() -> float:
	return _clock


static func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
