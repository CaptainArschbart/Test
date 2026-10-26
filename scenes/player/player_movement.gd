class_name PlayerMovement
extends Node
## Erweiterte Bewegung für den Player: Hocken, Rutschen und Klettern an Kanten.
##
## Hängt als Kind %PlayerMovement am Player. player.gd fragt pro Physik-Frame
## `physics_step()`: Gibt das true zurück (Klettern oder Rutschen läuft), hat dieser
## Knoten die Bewegung schon erledigt und player.gd macht nichts mehr.
## Sonst ändert er nur die Laufgeschwindigkeit (`adjust_speed`) und sperrt das Sprinten im Hocken.
##
## - "crouch" (Strg / C) halten: Hocken. Kleinere Kapsel, Kamera tiefer, langsam, leise.
##   Aufstehen nur, wenn über dem Kopf Platz ist.
## - Beim Sprinten "crouch" drücken: Rutschen. Erst schneller, dann bremst es ab, bergab länger.
##   "jump" während des Rutschens springt mit Schwung ab.
## - "jump" vor einer Kante (Mauer, Kiste, Dachrand) bis climb_max_height: hochziehen.
##   In der Luft reicht es, "jump" zu halten und auf die Kante zuzulaufen.
## Noclip, Fallschaden und Treppen bleiben in player.gd. Nach dem Klettern zählt kein Fall.

signal mantle_started(height: float)
signal mantle_finished
signal slide_started
signal slide_finished

enum State { NORMAL, SLIDE, MANTLE }

@export_group("Hocken")
@export var crouch_speed := 2.4
## Kapselhöhe im Hocken (stehend 1,8 m).
@export var crouch_height := 1.1
## Wie weit die Kamera beim Hocken sinkt.
@export var crouch_camera_drop := 0.62
## Wie schnell Kamera und Kapsel umschalten (höher = schneller).
@export var crouch_blend_speed := 10.0
## Halten statt Umschalten. false = einmal drücken hockt, nochmal drücken steht auf.
@export var crouch_hold := true
## Lautstärke-Deckel für Schritte im Hocken.
@export var crouch_step_max_db := -14.0

@export_group("Rutschen")
## Mindestgeschwindigkeit (waagerecht), ab der Hocken zum Rutschen wird.
@export var slide_min_speed := 6.0
## Geschwindigkeit direkt nach dem Start.
@export var slide_start_speed := 10.5
## Abbremsen pro Sekunde auf ebenem Boden.
@export var slide_friction := 7.0
## Zusätzlicher Schub bergab (Anteil der Schwerkraft entlang der Schräge).
@export var slide_slope_gain := 0.85
## Darunter endet das Rutschen.
@export var slide_end_speed := 3.0
## Wie stark man beim Rutschen lenken kann (Grad pro Sekunde).
@export var slide_steer_degrees := 50.0
@export var slide_cooldown := 0.6
@export var slide_camera_tilt_degrees := 4.0

@export_group("Klettern")
## Kanten darunter steigt man einfach hoch (Stufen) oder springt.
@export var climb_min_height := 0.55
## Höchste Kante vom Boden aus (Hände über dem Kopf).
@export var climb_max_height := 2.3
## Höchste Kante über den Füßen, wenn man in der Luft ist.
@export var climb_air_reach := 1.9
## So weit vor dem Spieler wird nach einer Wand gesucht.
@export var climb_reach := 0.75
## Schneller als das nach unten fallend greift man nicht mehr (sonst Fallschaden-Trick).
@export var climb_max_fall_speed := 9.0
## Dauer pro Meter Höhe plus Grundzeit.
@export var climb_time_per_meter := 0.22
@export var climb_base_time := 0.22

var state: State = State.NORMAL
var crouching := false
## 0 = steht, 1 = hockt ganz (Kamera und Kapsel folgen weich).
var crouch_amount := 0.0

var _player: Player
var _shape: CapsuleShape3D
var _stand_height := 1.8
var _camera_base_y := 0.0
var _body_base_scale := Vector3.ONE
var _crouch_toggled := false
var _slide_velocity := Vector3.ZERO
var _slide_cooldown_left := 0.0
var _mantle_from := Vector3.ZERO
var _mantle_up := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_time := 0.0
var _mantle_duration := 0.0
var _mantle_crouch := false
var _camera_tilt := 0.0


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_error("PlayerMovement muss ein Kind des Players sein.")
		set_physics_process(false)
		return
	# Die @onready-Felder des Players gibt es erst nach seinem _ready (Kinder sind vorher dran).
	if not _player.is_node_ready():
		await _player.ready
	# Eigene Kopie, damit Kapsel-Änderungen keine anderen Instanzen treffen.
	_shape = _player.collision_shape.shape.duplicate()
	_player.collision_shape.shape = _shape
	_stand_height = _shape.height
	_camera_base_y = _player.camera.position.y
	var body := _player.get_node_or_null("Body") as Node3D
	if body != null:
		_body_base_scale = body.scale
	_player.stats.died.connect(cancel)


## Läuft vor der normalen Bewegung. true = Bewegung ist für diesen Frame erledigt.
func physics_step(delta: float, sprinting: bool) -> bool:
	_slide_cooldown_left = maxf(_slide_cooldown_left - delta, 0.0)
	if _player.noclip or Input.is_action_just_pressed("noclip"):
		cancel()
		_update_crouch_visuals(delta)
		return false
	if state == State.MANTLE:
		_mantle_step(delta)
		_update_crouch_visuals(delta)
		return true

	_update_crouch_wish()
	if state == State.NORMAL and not _player.input_locked and _try_start_mantle():
		_update_crouch_visuals(delta)
		return true
	if state == State.NORMAL and crouching and sprinting and _player.is_on_floor() \
			and _slide_cooldown_left <= 0.0 and _just_crouched():
		_start_slide()
	if state == State.SLIDE:
		var handled := _slide_step(delta)
		_update_crouch_visuals(delta)
		return handled
	_update_crouch_visuals(delta)
	return false


## Hocken und Rutschen bremsen den Sprint.
func blocks_sprint() -> bool:
	return crouching or state != State.NORMAL


func adjust_speed(speed: float) -> float:
	if crouching:
		return minf(speed, crouch_speed)
	return speed


func is_sliding() -> bool:
	return state == State.SLIDE


func is_mantling() -> bool:
	return state == State.MANTLE


## Bricht Klettern und Rutschen ab (Tod, Respawn, Noclip). Hocken bleibt, wenn kein Platz ist.
func cancel() -> void:
	if state == State.MANTLE:
		mantle_finished.emit()
	elif state == State.SLIDE:
		slide_finished.emit()
	state = State.NORMAL
	_crouch_toggled = false
	if _player != null and (_player.noclip or _can_stand()):
		_set_crouching(false)


# --- Hocken -------------------------------------------------------------------------------

var _crouch_was_pressed := false
var _crouch_pressed_now := false


func _update_crouch_wish() -> void:
	var pressed := Input.is_action_pressed("crouch") and not _player.input_locked
	_crouch_pressed_now = pressed and not _crouch_was_pressed
	_crouch_was_pressed = pressed
	var wants: bool
	if crouch_hold:
		wants = pressed
	else:
		if _crouch_pressed_now:
			_crouch_toggled = not _crouch_toggled
		wants = _crouch_toggled
	if state == State.SLIDE:
		return
	if wants:
		_set_crouching(true)
	elif crouching and _can_stand():
		_set_crouching(false)


func _just_crouched() -> bool:
	return _crouch_pressed_now


func _set_crouching(value: bool) -> void:
	if crouching == value:
		return
	crouching = value
	var height := crouch_height if value else _stand_height
	_shape.height = height
	_player.collision_shape.position.y = height * 0.5
	if _player.footsteps != null:
		_player.footsteps.max_db = crouch_step_max_db if value else 3.0


## Passt die stehende Kapsel an die aktuelle Stelle?
func _can_stand() -> bool:
	if not crouching:
		return true
	var query := PhysicsShapeQueryParameters3D.new()
	var probe := CapsuleShape3D.new()
	probe.radius = _shape.radius * 0.95
	probe.height = _stand_height - 0.04
	query.shape = probe
	query.transform = Transform3D(Basis.IDENTITY, _player.global_position + Vector3.UP * (_stand_height * 0.5 + 0.03))
	query.collision_mask = _player.collision_mask
	query.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _update_crouch_visuals(delta: float) -> void:
	var target := 1.0 if crouching else 0.0
	crouch_amount = move_toward(crouch_amount, target, delta * crouch_blend_speed * 0.6)
	var eased := crouch_amount * crouch_amount * (3.0 - 2.0 * crouch_amount)
	_player.camera.position.y = _camera_base_y - crouch_camera_drop * eased
	var tilt_target := deg_to_rad(slide_camera_tilt_degrees) if state == State.SLIDE else 0.0
	_camera_tilt = lerpf(_camera_tilt, tilt_target, minf(delta * 8.0, 1.0))
	_player.camera.rotation.z = _camera_tilt
	# Beim Hochziehen kurz nach unten auf die Kante schauen (Kamera, nicht Kopf: Zielen bleibt).
	var heave := 0.0
	if state == State.MANTLE and _mantle_duration > 0.0:
		heave = -sin(clampf(_mantle_time / _mantle_duration, 0.0, 1.0) * PI) * deg_to_rad(9.0)
	_player.camera.rotation.x = lerpf(_player.camera.rotation.x, heave, minf(delta * 14.0, 1.0))
	var body := _player.get_node_or_null("Body") as Node3D
	if body != null:
		body.scale = Vector3(_body_base_scale.x, _body_base_scale.y * lerpf(1.0, 0.62, eased), _body_base_scale.z)


# --- Rutschen -----------------------------------------------------------------------------

func _start_slide() -> void:
	var horiz := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	if horiz.length() < slide_min_speed:
		return
	state = State.SLIDE
	_set_crouching(true)
	_slide_velocity = horiz.normalized() * maxf(horiz.length(), slide_start_speed)
	slide_started.emit()


func _slide_step(delta: float) -> bool:
	var player := _player
	var released := not Input.is_action_pressed("crouch") and crouch_hold
	if Input.is_action_just_pressed("jump") and player.is_on_floor() and not player.input_locked:
		# Absprung mit Schwung: die normale Bewegung übernimmt ab hier.
		_end_slide()
		player.velocity.x = _slide_velocity.x
		player.velocity.z = _slide_velocity.z
		if _can_stand():
			_set_crouching(false)
		player.velocity.y = player.jump_velocity
		player.move_and_slide()
		return true
	if not player.is_on_floor():
		# Über eine Kante gerutscht: normal weiterfallen, Schwung bleibt.
		_end_slide()
		return false

	var floor_normal := player.get_floor_normal()
	var speed := _slide_velocity.length()
	# Bergab Schub, bergauf und eben Reibung.
	var downhill := Vector3.DOWN.slide(floor_normal)
	var slope_push := 0.0
	if downhill.length() > 0.01 and speed > 0.01:
		slope_push = downhill.dot(_slide_velocity / speed) * player.gravity * slide_slope_gain
	speed = maxf(speed - slide_friction * delta + slope_push * delta, 0.0)
	var direction := _slide_velocity.normalized() if speed > 0.0 else Vector3.ZERO
	var steer := Input.get_axis("move_right", "move_left")
	if direction != Vector3.ZERO and not player.input_locked:
		direction = direction.rotated(Vector3.UP, steer * deg_to_rad(slide_steer_degrees) * delta)
	_slide_velocity = direction * speed

	player.velocity.x = _slide_velocity.x
	player.velocity.z = _slide_velocity.z
	player.velocity.y = -0.5
	player.move_and_slide()
	var after := Vector3(player.velocity.x, 0.0, player.velocity.z)
	# An einer Wand bleibt nur der Anteil entlang der Wand.
	if after.length() < _slide_velocity.length() * 0.6:
		_slide_velocity = after

	if _slide_velocity.length() < slide_end_speed or released:
		_end_slide()
		# Weiter hocken, wenn die Taste noch gedrückt ist oder kein Platz zum Aufstehen ist.
		if released and _can_stand():
			_set_crouching(false)
	return true


func _end_slide() -> void:
	if state != State.SLIDE:
		return
	state = State.NORMAL
	_slide_cooldown_left = slide_cooldown
	slide_finished.emit()


# --- Klettern -----------------------------------------------------------------------------

func _try_start_mantle() -> bool:
	var player := _player
	var on_floor := player.is_on_floor()
	var wants: bool
	if on_floor:
		wants = Input.is_action_just_pressed("jump")
	else:
		wants = Input.is_action_pressed("jump") and player.velocity.y > -climb_max_fall_speed
	if not wants:
		return false
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Nur wenn man auf die Kante zuläuft (vorwärts gedrückt).
	if input_dir.y > -0.3:
		return false
	var forward := -player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var ledge := find_ledge(forward, on_floor)
	if ledge.is_empty():
		return false
	_start_mantle(ledge)
	return true


## Sucht vor dem Spieler eine Kante, auf die er sich hochziehen kann.
## Leer, wenn keine da ist. Sonst: top (Punkt auf der Kante), height (über den Füßen), crouch (nur hockend Platz).
func find_ledge(forward: Vector3, on_floor: bool) -> Dictionary:
	var player := _player
	var space := player.get_world_3d().direct_space_state
	var feet := player.global_position
	var mask := player.collision_mask
	var exclude := [player.get_rid()]
	var max_h := climb_max_height if on_floor else climb_air_reach
	# In der Luft zählen auch Kanten knapp über den Füßen, aber nicht der Boden selbst.
	var min_h := climb_min_height if on_floor else 0.3

	# 1. Wand vor der Brust oder den Knien.
	var wall_dist := -1.0
	var wall_normal := Vector3.ZERO
	for h: float in [0.4, 0.95, 1.4]:
		var from := feet + Vector3.UP * h
		var query := PhysicsRayQueryParameters3D.create(from, from + forward * (_shape.radius + climb_reach), mask, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.normal
		# Nur steile Flächen sind Wände.
		if absf(normal.y) > 0.35:
			continue
		var d := Vector2(hit.position.x - feet.x, hit.position.z - feet.z).length()
		if wall_dist < 0.0 or d < wall_dist:
			wall_dist = d
			wall_normal = normal
	if wall_dist < 0.0:
		return {}

	# 2. Von oben auf die Mauerkrone schauen.
	var into := forward
	if wall_normal != Vector3.ZERO:
		into = -Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
	var probe_xz := feet + into * (wall_dist + 0.3)
	var top_from := Vector3(probe_xz.x, feet.y + max_h + 0.1, probe_xz.z)
	var down := PhysicsRayQueryParameters3D.create(top_from, Vector3(probe_xz.x, feet.y + min_h - 0.05, probe_xz.z), mask, exclude)
	# Steckt der Startpunkt in einem Haus, darf die Unterseite von innen nicht als Kante zählen.
	down.hit_back_faces = false
	var top := space.intersect_ray(down)
	if top.is_empty():
		return {}
	var top_normal: Vector3 = top.normal
	if top_normal.angle_to(Vector3.UP) > deg_to_rad(30.0):
		return {}
	var top_point: Vector3 = top.position
	var height := top_point.y - feet.y
	if height < min_h or height > max_h:
		return {}
	# Kommt der Sprung ohnehin hoch genug, nicht hochziehen (sonst klebt jeder kleine Hüpfer).
	if not on_floor and player.velocity.y > 0.0:
		var apex := player.velocity.y * player.velocity.y / (2.0 * player.gravity)
		if apex > height + 0.15:
			return {}
	# Über dem Kopf muss bis zur Kante Platz sein (keine Decke, kein Balkon).
	var head_check := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.5, Vector3(feet.x, top_point.y + 1.0, feet.z), mask, exclude)
	if not space.intersect_ray(head_check).is_empty():
		return {}

	# 3. Passt die Kapsel oben hin? Erst stehend, sonst hockend.
	var land := top_point + into * maxf(_shape.radius * 0.6, 0.18) + Vector3.UP * 0.02
	var crouch_only := false
	if not _capsule_fits(land, _stand_height):
		if not _capsule_fits(land, crouch_height):
			return {}
		crouch_only = true
	return {"top": land, "height": height, "crouch": crouch_only, "into": into}


func _capsule_fits(feet: Vector3, height: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var probe := CapsuleShape3D.new()
	probe.radius = _shape.radius * 0.95
	probe.height = height - 0.04
	query.shape = probe
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (height * 0.5 + 0.03))
	query.collision_mask = _player.collision_mask
	query.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _start_mantle(ledge: Dictionary) -> void:
	var height: float = ledge.height
	state = State.MANTLE
	_mantle_crouch = ledge.crouch
	_mantle_from = _player.global_position
	_mantle_to = ledge.top
	# Erst senkrecht hoch bis knapp über die Kante, dann nach vorn darauf.
	_mantle_up = Vector3(_mantle_from.x, _mantle_to.y + 0.05, _mantle_from.z)
	_mantle_time = 0.0
	_mantle_duration = climb_base_time + absf(height) * climb_time_per_meter
	# Während des Hochziehens hockend, sonst stößt die Kapsel an die Kante.
	_set_crouching(true)
	_player.velocity = Vector3.ZERO
	mantle_started.emit(height)


func _mantle_step(delta: float) -> void:
	_mantle_time += delta
	var t := clampf(_mantle_time / _mantle_duration, 0.0, 1.0)
	# 65 % der Zeit hoch, Rest nach vorn. Beides weich.
	var up_part := 0.65
	var pos: Vector3
	if t < up_part:
		var k := t / up_part
		k = 1.0 - (1.0 - k) * (1.0 - k)
		pos = _mantle_from.lerp(_mantle_up, k)
	else:
		var k := (t - up_part) / (1.0 - up_part)
		k = k * k * (3.0 - 2.0 * k)
		pos = _mantle_up.lerp(_mantle_to, k)
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	# Kein Fallschaden für den Fall vor dem Greifen.
	_player._fall_speed = 0.0
	if t >= 1.0:
		state = State.NORMAL
		_player.velocity = Vector3.ZERO
		_player.apply_floor_snap()
		if not _mantle_crouch and not Input.is_action_pressed("crouch") and _can_stand():
			_set_crouching(false)
		_crouch_toggled = crouching and not crouch_hold
		mantle_finished.emit()
