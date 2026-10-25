class_name Player
extends CharacterBody3D
## Spielfigur: WASD-Bewegung, Sprint, Sprung und Maus-Kamera (First Person).
##
## Escape öffnet das Pausemenü (PauseMenu in testmap.tscn und main.tscn), das auch die
## Maus freigibt und wieder einfängt. Ist das Inventar offen, schließt Escape zuerst das.
## Ein Klick ins Fenster fängt eine freie Maus ebenfalls ein, etwa nach Alt-Tab.
## Zahlentasten und Mausrad wählen den Hotbar-Slot, "drop_item" wirft ein Stück davon weg.
## "noclip" schaltet den Flugmodus um: durch Wände fliegen in Blickrichtung,
## "jump" hoch, "noclip_down" runter, "sprint" schneller.

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

@export_group("Noclip")
@export var noclip_speed := 10.0
## Faktor auf noclip_speed, solange "sprint" gehalten wird.
@export var noclip_sprint_multiplier := 3.0

const PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Wird vom Inventar-Fenster gesetzt: keine Bewegung, kein Umschauen.
var input_locked := false

## Flugmodus ohne Kollision und Schwerkraft (umschalten mit set_noclip).
var noclip := false

var _spawn_transform: Transform3D
var _noclip_label: Label

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var inventory: Inventory = $Inventory
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_spawn_transform = global_transform
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_create_noclip_label()


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if _handle_hotbar_input(event):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Grundwert aus dem Inspector mal Faktor aus dem Optionsmenü.
		var sensitivity := mouse_sensitivity * Settings.mouse_sensitivity
		var pitch_sign := 1.0 if Settings.invert_y else -1.0
		rotate_y(-event.relative.x * sensitivity)
		head.rotate_x(pitch_sign * event.relative.y * sensitivity)
		var max_pitch := deg_to_rad(max_pitch_degrees)
		head.rotation.x = clampf(head.rotation.x, -max_pitch, max_pitch)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("noclip") and not input_locked:
		set_noclip(not noclip)
	if noclip:
		_noclip_move(delta)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not input_locked:
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_locked:
		input_dir = Vector2.ZERO
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


## Wirft `amount` Stück aus einem Inventar-Slot vor den Spieler.
func drop_item(index: int, amount := 1) -> void:
	var item := inventory.get_item(index)
	if item == null or amount <= 0:
		return
	var removed := inventory.remove_at(index, amount)
	var forward := -camera.global_basis.z
	var spawn := camera.global_position + forward * 0.8
	# Nicht in eine Wand direkt vor dem Spieler werfen.
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, spawn, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		spawn = hit.position - forward * 0.3
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item = item
	pickup.count = removed
	get_parent().add_child(pickup)
	pickup.global_position = spawn
	pickup.throw(forward * 4.0 + Vector3.UP * 1.5 + Vector3(velocity.x, 0.0, velocity.z))


## Zahlentasten, Mausrad und Wegwerfen. Gibt true zurück, wenn das Event verbraucht wurde.
func _handle_hotbar_input(event: InputEvent) -> bool:
	for i in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			inventory.select(i)
			return true
	if event.is_action_pressed("drop_item"):
		drop_item(inventory.selected)
		return true
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			inventory.select_next(1)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			inventory.select_next(-1)
			return true
	return false

## Schaltet den Flugmodus ein oder aus.
func set_noclip(enabled: bool) -> void:
	noclip = enabled
	collision_shape.disabled = enabled
	velocity = Vector3.ZERO
	_noclip_label.visible = enabled


## Fliegt in Blickrichtung der Kamera, ohne Kollision und Schwerkraft.
func _noclip_move(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var vertical := Input.get_axis("noclip_down", "jump")
	if input_locked:
		input_dir = Vector2.ZERO
		vertical = 0.0
	var direction := camera.global_basis * Vector3(input_dir.x, 0.0, input_dir.y) + Vector3.UP * vertical
	if direction.length() > 1.0:
		direction = direction.normalized()
	var speed := noclip_speed
	if Input.is_action_pressed("sprint"):
		speed *= noclip_sprint_multiplier
	var weight := minf(acceleration * delta, 1.0)
	velocity = velocity.lerp(direction * speed, weight)
	global_position += velocity * delta


## Kleine Anzeige oben links, solange Noclip an ist (im Code erzeugt, damit player.tscn gleich bleibt).
func _create_noclip_label() -> void:
	var layer := CanvasLayer.new()
	layer.name = "NoclipHud"
	add_child(layer)
	_noclip_label = Label.new()
	_noclip_label.text = "NOCLIP"
	_noclip_label.position = Vector2(24.0, 20.0)
	_noclip_label.add_theme_font_size_override("font_size", 22)
	_noclip_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.95))
	_noclip_label.add_theme_color_override("font_outline_color", Color(1.0, 0.1, 0.6))
	_noclip_label.add_theme_constant_override("outline_size", 4)
	_noclip_label.visible = false
	layer.add_child(_noclip_label)
