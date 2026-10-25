class_name Player
extends CharacterBody3D
## Spielfigur: WASD-Bewegung, Sprint, Sprung und Maus-Kamera (First Person).
##
## Escape gibt die Maus frei, ein Klick ins Fenster fängt sie wieder ein.

@export_group("Bewegung")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
## Wie schnell die Zielgeschwindigkeit erreicht wird (höher = direkter).
@export var acceleration := 12.0
## Anteil der Steuerbarkeit in der Luft (0 = keine, 1 = wie am Boden).
@export_range(0.0, 1.0) var air_control := 0.3

@export_group("Kamera")
@export var mouse_sensitivity := 0.002
@export_range(0.0, 89.0) var max_pitch_degrees := 85.0

@export_group("Respawn")
## Fällt der Spieler unter diese Höhe, wird er zum Startpunkt zurückgesetzt.
@export var respawn_height := -30.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _spawn_transform: Transform3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	_spawn_transform = global_transform
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		var max_pitch := deg_to_rad(max_pitch_degrees)
		head.rotation.x = clampf(head.rotation.x, -max_pitch, max_pitch)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var accel := acceleration if is_on_floor() else acceleration * air_control
	var weight := minf(accel * delta, 1.0)
	velocity.x = lerpf(velocity.x, direction.x * speed, weight)
	velocity.z = lerpf(velocity.z, direction.z * speed, weight)

	move_and_slide()

	if global_position.y < respawn_height:
		respawn()


## Setzt den Spieler an den Startpunkt zurück.
func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
