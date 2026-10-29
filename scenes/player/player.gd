class_name Player
extends CharacterBody3D
## Spielfigur: WASD-Bewegung, Sprint, Sprung und Maus-Kamera (First Person).
##
## Escape öffnet das Pausemenü (PauseMenu in testmap.tscn und slum.tscn), das auch die
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
## PlayerMelee (im Code angelegt, Player.melee): Boxen ("melee" oder "fire" mit leeren Händen),
## Halten lädt einen Dash-Schlag auf.
## "noclip" schaltet den Flugmodus um: durch Wände fliegen in Blickrichtung,
## "jump" hoch, "noclip_down" runter, "sprint" schneller. Im Noclip gibt es keinen HP-Verlust.
## Low-Health-Effekte (LowHealthFx) und der Death-Screen „FLATLINE“ (DeathScreen) werden im Code
## erzeugt. Bei HP 0 wird der Player angehalten (process_mode DISABLED), der Death-Screen bietet
## Respawn (revive()), Mission neu laden und Hauptmenü.

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
## Wie schnell die Kamera nach einer Stufe nachzieht (höher = härter).
@export var step_smooth_speed := 18.0

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

@export_group("Tod")
## Beim Tod fällt das Inventar als Beute an die Todesstelle, man respawnt mit leeren Taschen.
## Aus: Inventar bleibt beim Respawn erhalten.
@export var drop_items_on_death := true

const PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")
const LowHealthFxScript := preload("res://scenes/survival/low_health_fx.gd")
const DeathScreenScript := preload("res://scenes/survival/death_screen.gd")
const CameraShakeScript := preload("res://scenes/player/camera_shake.gd")
const PlayerMeleeScript := preload("res://scenes/player/player_melee.gd")

signal revived

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Wird vom Inventar-Fenster gesetzt: keine Bewegung, kein Umschauen.
var input_locked := false

## Flugmodus ohne Kollision und Schwerkraft (umschalten mit set_noclip).
var noclip := false
## true zwischen Tod und Respawn. Der Player ist dann angehalten.
var dead := false
var low_health_fx: LowHealthFxScript
var death_screen: DeathScreenScript
## Renn-Wippen und Explosions-Wackeln der Kamera (nur beim lokalen Spieler, sonst null).
var camera_shake: CameraShakeScript
## Faustkampf und Dash-Schlag (nur beim lokalen Spieler, sonst null).
var melee: PlayerMeleeScript

var _spawn_transform: Transform3D
var _noclip_label: Label
var _step_timer: float = 0.0
## Schrittzähler des Körpers beim letzten Schrittgeräusch.
var _last_step_count := 0
var _fall_speed: float = 0.0
var _last_footstep: int = -1
var _last_land: int = -1
## Kurz nach einem Stufenschritt gilt der Spieler noch als am Boden (Kapsel liegt auf der Kante).
var _stair_grace: float = 0.0
var _view_step_offset: float = 0.0
var _head_height: float = 1.6
var _life_started_msec := 0

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
	_head_height = head.position.y
	floor_snap_length = max_step_height
	floor_max_angle = deg_to_rad(floor_angle_degrees)
	max_slides = slide_count
	input_locked = false
	if not controls_local_body():
		_configure_puppet()
		return
	_ensure_play_input()
	stats.died.connect(_on_stats_died)
	_life_started_msec = Time.get_ticks_msec()
	low_health_fx = LowHealthFxScript.new()
	add_child(low_health_fx)
	camera_shake = CameraShakeScript.new()
	camera_shake.name = "CameraShake"
	add_child(camera_shake)
	melee = PlayerMeleeScript.new()
	melee.name = "PlayerMelee"
	add_child(melee)
	_create_noclip_label()
	death_screen = DeathScreenScript.new()
	add_child(death_screen)
	if footsteps == null or land_impact == null:
		push_error("Player braucht %Footsteps und %LandImpact.")


func _unhandled_input(event: InputEvent) -> void:
	if not controls_local_body():
		return
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
	if not controls_local_body():
		return
	_ensure_play_input()
	var sprinting := not input_locked and Input.is_action_pressed("sprint") and stats.is_alive() \
			and not movement.blocks_sprint() and not (melee != null and melee.blocks_sprint())
	stats.set_sprinting(sprinting)
	sprinting = stats.is_sprinting()
	# Klettern und Rutschen bewegen den Spieler selbst, danach der Dash des aufgeladenen Schlags.
	var moved_by_movement := not noclip and movement.physics_step(delta, sprinting)
	if not noclip and melee != null and melee.physics_step(delta) and not moved_by_movement:
		moved_by_movement = true
	if moved_by_movement:
		if global_position.y < respawn_height:
			respawn()
		return
	if Input.is_action_just_pressed("noclip") and not input_locked:
		set_noclip(not noclip)
	if noclip:
		_noclip_move(delta, sprinting)
		return

	_stair_grace = maxf(_stair_grace - delta, 0.0)
	var grounded_before := is_on_floor() or _stair_grace > 0.0
	if not grounded_before:
		_fall_speed = minf(_fall_speed, velocity.y)

	if not grounded_before:
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and grounded_before and not input_locked:
		velocity.y = jump_velocity
		_stair_grace = 0.0

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_locked:
		input_dir = Vector2.ZERO
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := sprint_speed if sprinting else walk_speed
	speed = movement.adjust_speed(speed)
	if melee != null:
		speed *= melee.get_move_factor()
	speed *= stats.get_speed_multiplier()
	var accel := acceleration if grounded_before else acceleration * air_control
	var weight := minf(accel * delta, 1.0)
	velocity.x = lerpf(velocity.x, direction.x * speed, weight)
	velocity.z = lerpf(velocity.z, direction.z * speed, weight)

	var y_before := global_position.y
	if not _move_with_stairs(delta):
		move_and_slide()
		# Floor-Snap beim Treppab: Kamera rutscht weich mit statt zu springen.
		var snapped_down := y_before - global_position.y
		if grounded_before and is_on_floor() and snapped_down > 0.06 \
				and get_floor_normal().angle_to(Vector3.UP) < deg_to_rad(8.0):
			_add_view_step(-snapped_down)
	_update_view_step(delta)

	if is_on_floor() or _stair_grace > 0.0:
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


## Offline ist jeder Spieler lokal. Online nur der Peer mit Autorität.
## Ohne Peer wirft is_multiplayer_authority() einen Fehler und liefert falsch.
func controls_local_body() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return true
	return is_multiplayer_authority()


## Fremde Figuren: keine Steuerung, keine Kamera, kein HUD. Der Synchronizer bleibt an.
func _configure_puppet() -> void:
	set_physics_process(false)
	set_process_unhandled_input(false)
	camera.current = false
	var layers: Array[Node] = find_children("*", "CanvasLayer", true, false)
	for node: Node in layers:
		var layer := node as CanvasLayer
		if layer != null:
			layer.visible = false
	if item_user != null:
		item_user.set_physics_process(false)
		item_user.set_process(false)
		item_user.set_process_unhandled_input(false)
	if weapon_holder != null:
		weapon_holder.set_physics_process(false)
		weapon_holder.set_process(false)
		weapon_holder.set_process_unhandled_input(false)
	if stats != null:
		stats.set_process(false)
	if stealth != null:
		stealth.set_physics_process(false)
		stealth.set_process(false)


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
	_view_step_offset = 0.0
	_stair_grace = 0.0
	_fall_speed = 0.0
	_stop_sounds()


func _on_stats_died() -> void:
	if dead:
		return
	dead = true
	movement.cancel()
	_stop_sounds()
	velocity = Vector3.ZERO
	camera_shake.reset()
	movement.refresh_camera()
	var inventory_ui := get_node_or_null(^"InventoryUI")
	if inventory_ui != null and inventory_ui.has_method("force_close"):
		inventory_ui.call("force_close")
	input_locked = true
	if drop_items_on_death:
		_drop_all_items()
	# Alles am Player steht still (Bewegung, Waffe, Inventar, Stats). LowHealthFx und
	# DeathScreen haben eigene Prozessmodi und laufen weiter.
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	var alive_for := (Time.get_ticks_msec() - _life_started_msec) / 1000.0
	death_screen.show_death(stats.last_damage_cause, alive_for)


## Zurück ins Leben am Spawnpunkt: Vitals voll, Boost/Zustände weg, Kamera gerade, Gegner beruhigt.
func revive() -> void:
	dead = false
	process_mode = Node.PROCESS_MODE_INHERIT
	if noclip:
		set_noclip(false)
	stats.restore_all()
	movement.cancel()
	if melee != null:
		melee.cancel()
	respawn()
	head.position.y = _head_height
	head.rotation = Vector3.ZERO
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	camera_shake.reset()
	movement.refresh_camera()
	input_locked = false
	low_health_fx.reset()
	_life_started_msec = Time.get_ticks_msec()
	for listener: Node in get_tree().get_nodes_in_group(StealthNoise.GROUP):
		if listener.has_method("reset_alert"):
			listener.call("reset_alert")
	revived.emit()


## Wirft alles aus dem Inventar rund um die Todesstelle (wie drop_item, nur ohne Blickrichtung).
func _drop_all_items() -> void:
	var dropped := 0
	for index: int in inventory.get_size():
		var item := inventory.get_item(index)
		var count := inventory.get_count(index)
		if item == null or count <= 0:
			continue
		var removed := inventory.remove_at(index, count)
		var angle := dropped * 2.39996
		var spread := Vector3(cos(angle), 0.0, sin(angle))
		var pickup: ItemPickup = PICKUP_SCENE.instantiate()
		pickup.item = item
		pickup.count = removed
		get_parent().add_child(pickup)
		pickup.global_position = global_position + Vector3.UP * 0.6 + spread * 0.3
		pickup.throw(spread * (1.2 + 0.25 * (dropped % 3)) + Vector3.UP * 2.0, 0.5)
		dropped += 1


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
	# Im Flugmodus stirbt man nicht (auch nicht an Hunger/Durst).
	stats.invulnerable = enabled
	collision_shape.disabled = enabled
	velocity = Vector3.ZERO
	# Kein Fallschaden für Geschwindigkeit von vor dem Flug.
	_fall_speed = 0.0
	_noclip_label.visible = enabled
	if enabled:
		_stop_sounds()
		if melee != null:
			melee.cancel()


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


## Steigt eine Stufe hoch, wenn vorne eine niedrige Kante blockt und dahinter eine flache Trittfläche liegt.
## Bewegt nach vorn nur so weit wie in diesem Frame gelaufen, also Stufe für Stufe. Die runde
## Kapselunterseite rollt dabei über die Kante (meist 2–4 Frames pro Stufe), die Kamera federt nach.
## Gibt true zurück, wenn die Bewegung dieses Frames schon ausgeführt wurde.
func _move_with_stairs(delta: float) -> bool:
	if velocity.y > 0.1:
		return false
	if not is_on_floor() and _stair_grace <= 0.0:
		return false
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if horiz.length() < 0.25:
		return false
	var direction := horiz.normalized()
	var motion := horiz * delta
	# Kante früh erkennen (stair_probe), damit man nicht erst abgebremst wird. Bewegt wird nur motion.
	var probe := direction * maxf(motion.length(), stair_probe * 0.25)
	var unstuck := global_transform
	unstuck.origin.y += 0.01
	var wall_hit := KinematicCollision3D.new()
	if not test_move(unstuck, probe, wall_hit):
		return false
	var riser_normal := _riser_normal(wall_hit)
	if riser_normal == Vector3.ZERO:
		return false
	# Rampen und hohe Kanten ausschließen: hinter der Kante muss eine flache Trittfläche in Stufenhöhe
	# liegen. Gesucht wird quer zur Kante, auch wenn man schräg läuft oder schon an ihr entlangrutscht.
	if _find_tread(direction).x < 0.0 and _find_tread(-riser_normal).x < 0.0:
		return false
	var start := global_position
	var up := KinematicCollision3D.new()
	var lift := max_step_height
	if test_move(global_transform, Vector3.UP * lift, up) and up.get_collision_count() > 0:
		lift = up.get_travel().y
	if lift < 0.02:
		return false
	global_position.y += lift
	var forward := KinematicCollision3D.new()
	if test_move(global_transform, motion, forward) and forward.get_collision_count() > 0:
		global_position += forward.get_travel()
	else:
		global_position += motion
	var moved := Vector2(global_position.x - start.x, global_position.z - start.z).length()
	var drop := KinematicCollision3D.new()
	if test_move(global_transform, Vector3.DOWN * (lift + 0.05), drop) and drop.get_collision_count() > 0:
		global_position += drop.get_travel()
	else:
		global_position.y -= lift
	var rise := global_position.y - start.y
	# Kein Höhengewinn oder kein Vorwärtskommen: war keine Stufe, alles zurück.
	if rise < 0.004 or rise > max_step_height + 0.01 or moved < motion.length() * 0.3:
		global_position = start
		return false
	_stair_grace = 0.12
	_add_view_step(rise)
	velocity.y = 0.0
	return true


## Waagerechte Normale der Stufenkante (zeigt zum Spieler) oder ZERO, wenn der Treffer keine Kante ist.
func _riser_normal(hit: KinematicCollision3D) -> Vector3:
	# Kantenkontakt der Kapsel liegt oft bei 40–50°, also noch im begehbaren Winkel.
	var stair_angle := deg_to_rad(36.0)
	for i: int in hit.get_collision_count():
		var normal := hit.get_normal(i)
		if normal.angle_to(Vector3.UP) > stair_angle:
			var flat := Vector3(normal.x, 0.0, normal.z)
			if flat.length() > 0.01:
				return flat.normalized()
	return Vector3.ZERO


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
		# Klein ab 0,004 m: beim Rollen über die Kante ist der Rest der Stufe nur noch wenige mm.
		if rise >= 0.004 and rise <= max_step_height:
			return Vector2(rise, reach)
	return Vector2(-1.0, 0.0)


## Kamera springt bei Stufen nicht mit, sondern federt in step_smooth_speed nach.
func _add_view_step(rise: float) -> void:
	_view_step_offset = clampf(_view_step_offset - rise, -max_step_height * 1.5, max_step_height * 1.5)


func _update_view_step(delta: float) -> void:
	_view_step_offset = move_toward(_view_step_offset, 0.0,
			maxf(absf(_view_step_offset) * step_smooth_speed, 0.4) * delta)
	head.position.y = _head_height + _view_step_offset


func _update_footsteps(delta: float, sprinting: bool, target_speed: float) -> void:
	var horiz := Vector2(velocity.x, velocity.z).length()
	var body := get_node_or_null(^"Body") as PlayerBody
	if horiz < step_speed_epsilon or target_speed <= 0.0:
		_step_timer = 0.0
		if body != null:
			_last_step_count = body.get_step_count()
		return
	if body != null:
		# Im Takt des Körpers: Geräusch, wenn ein Fuß aufsetzt (Beine, Hände und Kamera laufen mit).
		var count := body.get_step_count()
		if count == _last_step_count:
			return
		_last_step_count = count
	else:
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
		stats.damage(amount, PlayerStats.CAUSE_FALL)


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
