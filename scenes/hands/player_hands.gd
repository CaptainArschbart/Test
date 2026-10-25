class_name PlayerHands
extends Node3D
## First-Person-Hände unter der Kamera.
##
## Idle atmet leicht, Gehen und Sprint wackeln stärker. Die Pose aus der Szene
## bleibt die Mitte; die Abweichung wird jedes Frame neu gesetzt, nicht aufaddiert.
## Hängt an Camera3D, damit Drehen und Nicken die Hände mitnehmen.

@export var bob_frequency: float = 2.2
@export var walk_bob_amplitude: float = 0.012
@export var sprint_bob_amplitude: float = 0.022
@export var idle_bob_amplitude: float = 0.0035
@export var idle_frequency: float = 1.15
@export var sway_amplitude: float = 0.006
## Unter dieser horizontalen Geschwindigkeit gilt der Spieler als stehend.
@export var move_speed_epsilon: float = 0.45

## Faktor auf alle Ausschläge (WeaponHolder senkt ihn beim Zielen).
var motion_scale: float = 1.0

var _base_position: Vector3
var _base_rotation: Vector3
var _time: float = 0.0
var _player: Player


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	_player = _find_player()
	if _player == null:
		push_error("PlayerHands braucht einen Player über sich.")


func _process(delta: float) -> void:
	if _player == null:
		return
	var flat := Vector2(_player.velocity.x, _player.velocity.z)
	var sprinting := _player.stats != null and _player.stats.is_sprinting()
	apply_motion(delta, flat.length(), sprinting)


## Idle, Gehen oder Sprint. `horizontal_speed` in Metern pro Sekunde.
func apply_motion(delta: float, horizontal_speed: float, sprinting: bool) -> void:
	var moving := horizontal_speed > move_speed_epsilon
	var frequency := idle_frequency
	var amplitude_y := idle_bob_amplitude
	var amplitude_x := idle_bob_amplitude * 0.4
	if moving and sprinting:
		frequency = bob_frequency * 1.65
		amplitude_y = sprint_bob_amplitude
		amplitude_x = sway_amplitude * 1.5
	elif moving:
		frequency = bob_frequency
		amplitude_y = walk_bob_amplitude
		amplitude_x = sway_amplitude
	amplitude_y *= motion_scale
	amplitude_x *= motion_scale
	_time += delta * frequency
	var wave := sin(_time)
	var sway := sin(_time * 0.5)
	position = _base_position + Vector3(sway * amplitude_x, wave * amplitude_y, 0.0)
	rotation = _base_rotation + Vector3(wave * amplitude_y * 2.0, 0.0, sway * amplitude_x * 1.5)


func _find_player() -> Player:
	var node: Node = self
	while node != null:
		if node is Player:
			return node as Player
		node = node.get_parent()
	return null
