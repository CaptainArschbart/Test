class_name Player
extends CharacterBody3D
## Spielfigur: WASD-Bewegung, Sprint, Sprung und Maus-Kamera (First Person).
##
## Escape öffnet das Pausemenü (PauseMenu in testmap.tscn und main.tscn), das auch die
## Maus freigibt und wieder einfängt. Ist das Inventar offen, schließt Escape zuerst das.
## Ein Klick ins Fenster fängt eine freie Maus ebenfalls ein, etwa nach Alt-Tab.
## Zahlentasten (belegbar als hotbar_1…9) und Mausrad wählen den Hotbar-Slot,
## "drop_item" wirft ein Stück davon weg. Beides gilt auch bei offenem Inventar.
## Sprinten verbraucht Ausdauer (PlayerStats). Ohne Hunger oder Durst sinken die HP.
## %PlayerHands sitzt an der Kamera und wackelt bei Idle, Gehen und Sprint.
## %WeaponHolder darunter zeigt eine Waffe aus dem gewählten Slot und schießt ("fire", "reload",
## "aim" zum Zielen).
## %ItemUser: "interact" (E) hebt Items auf und benutzt Objekte, "use_item" (Rechtsklick)
## verbraucht Essen/Trinken/Stims, "fire" wirft Granaten und schlägt mit Nahkampfwaffen.
## Stufen bis max_step_height hebt der Körper an, bevor move_and_slide läuft.
## %Footsteps und %LandImpact spielen auf dem Bus SFX.
## Fällt der Spieler tiefer als fall_damage_min_height, zieht die Landung HP ab (PlayerStats.damage).
## %PlayerMovement: Hocken ("crouch"), Rutschen aus dem Sprint und Klettern an Kanten ("jump" vor einer Kante).
## %PlayerStealth: Sichtbarkeit und Geräuschpegel für Gegner (Schleichen).
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

@export_group("Fallschaden")
## Fallhöhe in Metern, ab der Schaden entsteht. Sprünge, Treppen und Parkour bleiben darunter.
@export var fall_damage_min_height := 5.0
## HP pro Meter über fall_damage_min_height (Dach der Parkour-Zone 7,2 m = 15 HP, 10 m = 35 HP, 15 m = 70 HP).
@export var fall_damage_per_meter := 7.0
## Obergrenze pro Landung. Unter max_hp heißt: ein Sturz allein tötet nicht aus voller Gesundheit.
@export var fall_damage_max := 95.0

@export_group("Noclip")
@export var noclip_speed := 10.0
## Faktor auf noclip_speed, solange "sprint" gehalten wird.
@export var noclip_sprint_multiplier := 3.0

@export_group("Stufen")
## Senkrechte Stufen bis zu dieser Höhe werden erklommen. 0,50 m bleibt eine Kante.
@export var max_step_height := 0.45
## Darüber zählt der Boden als Wand. 46° lässt die 40°-Rampe zu, die 50°-Rampe nicht.
@export_range(1.0, 80.0) var floor_angle_degrees := 46.0
@export_range(1, 16, 1) var slide_count := 8
## Wie weit nach vorn die Kapsel eine Stufe abtastet (etwa der Kapselradius).
@export var stair_probe := 0.46

@export_group("Geräusche")
@export var footstep_sounds: Array[AudioStream] = []
@export var land_sounds: Array[AudioStream] = []
## Schrittzeit bei voller Gehgeschwindigkeit. Langsamer wird der Abstand länger.
@export var walk_step_interval := 0.46
@export var sprint_step_interval := 0.30
@export var step_speed_epsilon := 0.55
@export var walk_volume_db := -2.0
@export var sprint_volume_db := 2.5
@export var sprint_pitch := 1.12
## Aufprall, wenn die Fallgeschwindigkeit darunter liegt (etwa 2 m Fall bei 9,8).
@export var land_speed_threshold := 6.5
@export var land_volume_db := 1.0

const PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Wird vom Inventar-Fenster gesetzt: keine Bewegung, kein Umschauen.
var input_locked := false

## Flugmodus ohne Kollision und Schwerkraft (umschalten mit set_noclip).
var noclip := false

var _spawn_transform: Transform3D
var _noclip_label: Label
var _step_timer: float = 0.0
var _fall_speed: float = 0.0
var _last_footstep: int = -1
var _last_land: int = -1

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var hands: PlayerHands = %PlayerHands
@onready var weapon_holder: WeaponHolder = %WeaponHolder
@onready var item_user: ItemUser = %ItemUser
@onready var inventory: Inventory = $Inventory
@onready var stats: PlayerStats = $PlayerStats
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var footsteps: AudioStreamPlayer3D = %Footsteps
@onready var land_impact: AudioStreamPlayer3D = %LandImpact
@onready var movement: PlayerMovement = %PlayerMovement
@onready var stealth: PlayerStealth = %PlayerStealth


func _ready() -> void:
	add_to_group("player")
	_spawn_transform = global_transform
	floor_snap_length = max_step_height
	floor_max_angle = deg_to_rad(floor_angle_degrees)
	max_slides = slide_count
	input_locked = false
	_ensure_play_input()
	stats.died.connect(_on_stats_died)
	_create_noclip_label()
	if footsteps == null or land_impact == null:
		push_error("Player braucht %Footsteps und %LandImpact.")


func _unhandled_input(event: InputEvent) -> void:
	# Echo würde beim Halten von "drop_item" den ganzen Stapel leeren.
	if event.is_echo():
		return
	# Hotbar und Wegwerfen auch bei offenem Inventar. Umschauen und Mausfang nicht.
	if _handle_hotbar_input(event):
		get_viewport().set_input_as_handled()
		return
	if input_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Grundwert aus dem Inspector mal Faktor aus dem Optionsmenü.
		var sensitivity := mouse_sensitivity * Settings.mouse_sensitivity
		# Beim Zielen langsamer (Zoom).
		if weapon_holder != null:
			sensitivity *= weapon_holder.get_look_scale()
		var pitch_sign := 1.0 if Settings.invert_y else -1.0
		rotate_y(-event.relative.x * sensitivity)
		head.rotate_x(pitch_sign * event.relative.y * sensitivity)
		var max_pitch := deg_to_rad(max_pitch_degrees)
		head.rotation.x = clampf(head.rotation.x, -max_pitch, max_pitch)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_ensure_play_input()
	var sprinting := not input_locked and Input.is_action_pressed("sprint") and stats.is_alive() \
			and not movement.blocks_sprint()
	stats.set_sprinting(sprinting)
	sprinting = stats.is_sprinting()
	# Klettern und Rutschen bewegen den Spieler selbst.
	if not noclip and movement.physics_step(delta, sprinting):
		if global_position.y < respawn_height:
			respawn()
		return
	if Input.is_action_just_pressed("noclip") and not input_locked:
		set_noclip(not noclip)
	if noclip:
		_noclip_move(delta, sprinting)
		return

	var grounded_before := is_on_floor()
	if not grounded_before:
		_fall_speed = minf(_fall_speed, velocity.y)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not input_locked:
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_locked:
		input_dir = Vector2.ZERO
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := sprint_speed if sprinting else walk_speed
	speed = movement.adjust_speed(speed)
	speed *= stats.get_speed_multiplier()
	var accel := acceleration if is_on_floor() else acceleration * air_control
	var weight := minf(accel * delta, 1.0)
	velocity.x = lerpf(velocity.x, direction.x * speed, weight)
	velocity.z = lerpf(velocity.z, direction.z * speed, weight)

	if not _move_with_stairs(delta):
		move_and_slide()

	if is_on_floor():
		if not grounded_before:
			if _fall_speed <= -land_speed_threshold:
				_play_land()
			_apply_fall_damage()
		_fall_speed = 0.0
		_update_footsteps(delta, sprinting, speed)
	else:
		_step_timer = 0.0

	if global_position.y < respawn_height:
		respawn()


## Spiel läuft: kein Menü-Fokus, Maus gefangen. Pause und offenes Inventar bleiben unberührt.
func _ensure_play_input() -> void:
	if input_locked or get_tree().paused:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	if DisplayServer.get_name() == "headless":
		return
	if not DisplayServer.window_is_focused():
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Setzt den Spieler an den Startpunkt zurück.
func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_fall_speed = 0.0
	_stop_sounds()


func _on_stats_died() -> void:
	respawn()
	stats.restore_all()


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
	for i: int in Inventory.HOTBAR_SIZE:
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
	# Kein Fallschaden für Geschwindigkeit von vor dem Flug.
	_fall_speed = 0.0
	_noclip_label.visible = enabled
	if enabled:
		_stop_sounds()


## Fliegt in Blickrichtung der Kamera, ohne Kollision und Schwerkraft.
func _noclip_move(delta: float, sprinting: bool) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var vertical := Input.get_axis("noclip_down", "jump")
	if input_locked:
		input_dir = Vector2.ZERO
		vertical = 0.0
	var direction := camera.global_basis * Vector3(input_dir.x, 0.0, input_dir.y) + Vector3.UP * vertical
	if direction.length() > 1.0:
		direction = direction.normalized()
	var speed := noclip_speed
	if sprinting:
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
	_noclip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noclip_label.position = Vector2(24.0, 20.0)
	_noclip_label.add_theme_font_size_override("font_size", 22)
	_noclip_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.95))
	_noclip_label.add_theme_color_override("font_outline_color", Color(1.0, 0.1, 0.6))
	_noclip_label.add_theme_constant_override("outline_size", 4)
	_noclip_label.visible = false
	layer.add_child(_noclip_label)


## Hebt die Kapsel auf eine Stufe, wenn vorne eine niedrige Kante blockt und oben Platz ist.
## Gibt true zurück, wenn die Bewegung dieses Frames schon ausgeführt wurde.
func _move_with_stairs(delta: float) -> bool:
	if not is_on_floor() or velocity.y > 0.1:
		return false
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if horiz.length() < 0.25:
		return false
	var direction := horiz.normalized()
	var probe := direction * maxf(horiz.length() * delta, stair_probe)
	var unstuck := global_transform
	unstuck.origin.y += 0.03
	var wall_hit := KinematicCollision3D.new()
	if not test_move(unstuck, probe, wall_hit):
		return false
	if not _hit_is_riser(wall_hit):
		return false
	var tread := _find_tread(direction)
	var rise := tread.x
	if rise < 0.0:
		return false
	var lift := minf(rise + 0.05, max_step_height)
	if test_move(global_transform, Vector3.UP * lift):
		return false
	var start := global_position
	var keep := Vector3(velocity.x, 0.0, velocity.z)
	global_position.y += lift
	var climb := direction * tread.y
	var forward := KinematicCollision3D.new()
	if test_move(global_transform, climb, forward) and forward.get_collision_count() > 0:
		global_position += forward.get_travel()
	else:
		global_position += climb
	var drop := KinematicCollision3D.new()
	if test_move(global_transform, Vector3.DOWN * (lift + 0.08), drop) and drop.get_collision_count() > 0:
		global_position += drop.get_travel()
	# Ohne echten Höhengewinn war es keine Stufe. Zurück, sonst rutscht die Kapsel durch.
	if global_position.y < start.y + rise * 0.5:
		global_position = start
		return false
	apply_floor_snap()
	velocity.x = keep.x
	velocity.z = keep.z
	velocity.y = 0.0
	return true


func _hit_is_riser(hit: KinematicCollision3D) -> bool:
	# Kantenkontakt der Kapsel liegt oft bei 40–50°, also noch im begehbaren Winkel.
	var stair_angle := deg_to_rad(36.0)
	for i: int in hit.get_collision_count():
		if hit.get_normal(i).angle_to(Vector3.UP) > stair_angle:
			return true
	return false


## Strahl nach vorn unten. x = Anhebung, y = Reichweite bis zur flachen Trittfläche.
## Schräge Rampen (Normale über 22°) zählen nicht. x = -1, wenn keine Stufe da ist.
func _find_tread(direction: Vector3) -> Vector2:
	var space := get_world_3d().direct_space_state
	var flat := deg_to_rad(22.0)
	for reach: float in [0.12, 0.24, 0.36, 0.5]:
		var from := global_position + Vector3.UP * (max_step_height + 0.08) + direction * reach
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (max_step_height + 0.25), collision_mask)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.normal
		if normal.angle_to(Vector3.UP) > flat:
			continue
		var point: Vector3 = hit.position
		var rise := point.y - global_position.y
		if rise >= 0.05 and rise <= max_step_height:
			return Vector2(rise, reach)
	return Vector2(-1.0, 0.0)


func _update_footsteps(delta: float, sprinting: bool, target_speed: float) -> void:
	var horiz := Vector2(velocity.x, velocity.z).length()
	if horiz < step_speed_epsilon or target_speed <= 0.0:
		_step_timer = 0.0
		return
	var interval := sprint_step_interval if sprinting else walk_step_interval
	var reference := sprint_speed if sprinting else walk_speed
	interval = clampf(interval * reference / horiz, 0.16, 0.75)
	_step_timer += delta
	if _step_timer < interval:
		return
	_step_timer = 0.0
	var volume := sprint_volume_db if sprinting else walk_volume_db
	var pitch := sprint_pitch if sprinting else 1.0
	pitch *= randf_range(0.97, 1.03)
	_last_footstep = _play_on(footsteps, footstep_sounds, _last_footstep, volume, pitch)


## Schaden aus der Aufprallgeschwindigkeit: Höhe = v² / 2g.
func _apply_fall_damage() -> void:
	var amount := fall_damage_for_speed(-_fall_speed)
	if amount > 0.0 and stats.is_alive():
		stats.damage(amount)


func fall_damage_for_speed(speed: float) -> float:
	if speed <= 0.0 or gravity <= 0.0:
		return 0.0
	var height := speed * speed / (2.0 * gravity)
	var excess := height - fall_damage_min_height
	if excess <= 0.0:
		return 0.0
	return minf(excess * fall_damage_per_meter, fall_damage_max)


func _play_land() -> void:
	if footsteps != null and footsteps.playing:
		footsteps.stop()
	_step_timer = 0.0
	var severity := clampf((-_fall_speed - land_speed_threshold) / 8.0, 0.0, 1.0)
	var volume := land_volume_db + severity * 4.0
	var pitch := lerpf(1.0, 0.82, severity)
	_last_land = _play_on(land_impact, land_sounds, _last_land, volume, pitch)


func _play_on(player: AudioStreamPlayer3D, streams: Array[AudioStream], last_index: int, volume_db: float, pitch: float) -> int:
	if player == null or streams.is_empty():
		return last_index
	var index := _pick_index(streams.size(), last_index)
	var stream := streams[index]
	if stream == null:
		return last_index
	if player.playing:
		player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()
	return index


func _pick_index(count: int, last_index: int) -> int:
	var index := randi() % count
	if count > 1 and index == last_index:
		index = (index + 1) % count
	return index


func _stop_sounds() -> void:
	_step_timer = 0.0
	if footsteps != null and footsteps.playing:
		footsteps.stop()
	if land_impact != null and land_impact.playing:
		land_impact.stop()
