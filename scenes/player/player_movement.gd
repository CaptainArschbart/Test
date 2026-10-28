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
## Phase 1: an die Wand ran und die Kante greifen.
@export var climb_grab_time := 0.12
## Phase 2: Hochziehen, Grundzeit plus Zeit pro Meter.
@export var climb_pull_base_time := 0.14
@export var climb_pull_time_per_meter := 0.19
## Phase 3: über die Kante schwingen.
@export var climb_vault_time := 0.26
## Schwung nach vorn, wenn man oben ist.
@export var climb_exit_speed := 1.8

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
var _climb_phase := 0
var _mantle_points: Array = []
var _mantle_phase_times: Array = [0.1, 0.1, 0.1]
var _mantle_into := Vector3.FORWARD
var _mantle_edge := Vector3.ZERO
var _mantle_grab := 0.0
var _mantle_crouch_from := 0.0
var _mantle_entry_speed := 0.0
var _climb_audio: AudioStreamPlayer3D
var _camera_drop := 0.0
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
	if state == State.MANTLE:
		crouch_amount = _climb_crouch()
	else:
		crouch_amount = move_toward(crouch_amount, target, delta * crouch_blend_speed * 0.6)
	var eased := crouch_amount * crouch_amount * (3.0 - 2.0 * crouch_amount)
	_camera_drop = crouch_camera_drop * eased
	_apply_camera_drop()
	var tilt_target := deg_to_rad(slide_camera_tilt_degrees) if state == State.SLIDE else 0.0
	_camera_tilt = lerpf(_camera_tilt, tilt_target, minf(delta * 8.0, 1.0))
	_player.camera.rotation.z = _camera_tilt
	# Beim Klettern nickt die Kamera mit (Kamera, nicht Kopf: Zielen und Mausblick bleiben).
	_player.camera.rotation.x = lerpf(_player.camera.rotation.x, _climb_pitch(), minf(delta * 16.0, 1.0))
	_update_mantle_visuals(delta)
	var body := _player.get_node_or_null("Body") as Node3D
	if body != null:
		body.scale = Vector3(_body_base_scale.x, _body_base_scale.y * lerpf(1.0, 0.62, eased), _body_base_scale.z)


func _process(_delta: float) -> void:
	# Jedes Bild neu, weil sich der Blickwinkel zwischen zwei Physik-Frames ändern kann.
	if _player != null and _player.is_node_ready():
		_apply_camera_drop()


## Die Kamera hängt am nickenden Kopf. Die Absenkung muss senkrecht in der Welt sein,
## also wird sie in den Raum des Kopfes zurückgerechnet (sonst sinkt man beim Runterschauen nach hinten).
func _apply_camera_drop() -> void:
	var head_basis := _player.head.transform.basis
	_player.camera.position = Vector3(0.0, _camera_base_y, 0.0) + head_basis.inverse() * Vector3(0.0, -_camera_drop, 0.0)


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
# Ablauf in vier Phasen, jede Frame-für-Frame mit move_and_collide (keine Positionssprünge):
#   GRAB  an die Wand ran, Hände legen sich auf die Kante, Blick leicht hoch
#   PULL  senkrecht hochziehen bis knapp über die Kante, Kamera sinkt relativ zum Körper (Vorbeugen)
#   VAULT über die Kante nach vorn schwingen, Hände lassen los
#   (danach) normal weiter, Aufstehen über die Hock-Überblendung, etwas Schwung nach vorn

enum Climb { GRAB, PULL, VAULT }


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
	return _start_mantle(ledge)


## Sucht vor dem Spieler eine Kante, auf die er sich hochziehen kann. Leer, wenn keine da ist.
## Sonst: edge (Punkt auf der Kante), top (Landepunkt), hang (Stelle an der Wand, Füße),
## height (über den Füßen), crouch (oben nur hockend Platz), into (waagerecht in die Wand).
func find_ledge(forward: Vector3, on_floor: bool) -> Dictionary:
	var player := _player
	var space := player.get_world_3d().direct_space_state
	var feet := player.global_position
	var mask := player.collision_mask
	var exclude := [player.get_rid()]
	var max_h := climb_max_height if on_floor else climb_air_reach
	# In der Luft zählen auch Kanten knapp über den Füßen, aber nicht der Boden selbst.
	var min_h := climb_min_height if on_floor else 0.3
	var radius := _shape.radius

	# 1. Wand vor Knien, Brust oder Kopf.
	var wall_dist := -1.0
	var wall_normal := Vector3.ZERO
	var wall_point := Vector3.ZERO
	for h: float in [0.4, 0.95, 1.4]:
		var from := feet + Vector3.UP * h
		var query := PhysicsRayQueryParameters3D.create(from, from + forward * (radius + climb_reach), mask, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		# Gegner und lose Gegenstände sind keine Wände (Gegner liegen auf der Welt-Ebene).
		if _is_moving_body(hit.collider):
			continue
		var normal: Vector3 = hit.normal
		# Nur steile Flächen sind Wände.
		if absf(normal.y) > 0.35:
			continue
		var d := Vector2(hit.position.x - feet.x, hit.position.z - feet.z).length()
		if wall_dist < 0.0 or d < wall_dist:
			wall_dist = d
			wall_normal = Vector3(normal.x, 0.0, normal.z).normalized()
			wall_point = hit.position
	if wall_dist < 0.0:
		return {}
	var into := -wall_normal
	# Schräg auf die Wand zu: nur bis 50° Abweichung, sonst rutscht man daran entlang.
	if into.dot(forward) < 0.64:
		return {}

	# 2. Kante: von oben dicht hinter der Wandfläche runterschauen.
	var edge_xz := Vector3(wall_point.x, 0.0, wall_point.z) + into * 0.12
	var top_y := feet.y + max_h + 0.1
	var edge_hit := _ray_down(space, edge_xz, top_y, feet.y + min_h - 0.05, mask, exclude)
	if edge_hit.is_empty():
		return {}
	var edge_y: float = edge_hit.position.y
	var height := edge_y - feet.y
	if height < min_h or height > max_h:
		return {}
	# Kommt der Sprung ohnehin hoch genug, nicht hochziehen (sonst klebt jeder kleine Hüpfer).
	if not on_floor and player.velocity.y > 0.0:
		var apex := player.velocity.y * player.velocity.y / (2.0 * player.gravity)
		if apex > height + 0.15:
			return {}

	# 3. Landefläche weiter hinten muss auf gleicher Höhe liegen (keine dünne Mauer, kein Geländer).
	var land_xz := edge_xz + into * (radius + 0.2)
	var land_hit := _ray_down(space, land_xz, edge_y + 0.6, edge_y - 0.3, mask, exclude)
	if land_hit.is_empty() or absf(land_hit.position.y - edge_y) > 0.2:
		return {}
	# Aufsetzen knapp hinter der Kante (die Kapsel steht dann ganz auf der Fläche).
	var land_at := edge_xz + into * (radius - 0.04)
	var land := Vector3(land_at.x, land_hit.position.y + 0.02, land_at.z)

	# 4. Platz oben: stehend, sonst hockend.
	var crouch_only := false
	if not _capsule_fits(land, _stand_height):
		if not _capsule_fits(land, crouch_height):
			return {}
		crouch_only = true
	var hang := Vector3(wall_point.x, feet.y, wall_point.z) + wall_normal * (radius + 0.05)
	return {
		"edge": Vector3(edge_xz.x - into.x * 0.12, edge_y, edge_xz.z - into.z * 0.12),
		"top": land, "hang": hang, "height": height, "crouch": crouch_only, "into": into,
	}


func _ray_down(space: PhysicsDirectSpaceState3D, xz: Vector3, from_y: float, to_y: float, mask: int, exclude: Array) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(xz.x, from_y, xz.z), Vector3(xz.x, to_y, xz.z), mask, exclude)
	# Steckt der Startpunkt in einem Haus, darf die Unterseite von innen nicht als Kante zählen.
	query.hit_back_faces = false
	var hit := space.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector3).angle_to(Vector3.UP) > deg_to_rad(30.0):
		return {}
	if _is_moving_body(hit.collider):
		return {}
	return hit


func _is_moving_body(collider: Object) -> bool:
	return collider is CharacterBody3D or collider is RigidBody3D


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


## Plant die Wege und prüft sie mit der hockenden Kapsel. false = geht nicht (dann nichts geändert).
func _start_mantle(ledge: Dictionary) -> bool:
	var player := _player
	var was_crouching := crouching
	_set_crouching(true)
	var start := player.global_position
	var edge: Vector3 = ledge.edge
	var hang: Vector3 = ledge.hang
	# Greifpunkt: an der Wand, Füße höchstens so hoch wie jetzt plus etwas Schwung.
	var grab_y := minf(start.y + 0.12, maxf(edge.y - 0.25, start.y))
	var p_grab := Vector3(hang.x, grab_y, hang.z)
	var p_pull := Vector3(hang.x, edge.y + 0.06, hang.z)
	var p_land: Vector3 = ledge.top
	var t := player.global_transform
	var ok := true
	for leg: Array in [[start, p_grab], [p_grab, p_pull], [p_pull, p_land]]:
		t.origin = leg[0]
		if player.test_move(t, (leg[1] as Vector3) - (leg[0] as Vector3), null, 0.001):
			# Ranlaufen an die Wand darf am Ende leicht anstoßen.
			if leg[0] == start:
				continue
			ok = false
			break
	if not ok:
		if not was_crouching:
			_set_crouching(false)
		return false

	state = State.MANTLE
	_climb_phase = Climb.GRAB
	_mantle_crouch = ledge.crouch
	_mantle_points = [start, p_grab, p_pull, p_land]
	_mantle_into = ledge.into
	_mantle_edge = edge
	_mantle_time = 0.0
	var rise := p_pull.y - p_grab.y
	# Ranrücken je nach Abstand zur Wand: die Kurve startet mit doppelter Mittelgeschwindigkeit,
	# die soll unter 5,5 m/s bleiben (langsamer als Sprinten).
	var approach := Vector2(p_grab.x - start.x, p_grab.z - start.z).length()
	_mantle_phase_times = [maxf(climb_grab_time, approach * 2.0 / 5.5), climb_pull_base_time + rise * climb_pull_time_per_meter, climb_vault_time]
	_mantle_duration = 0.0
	for d: float in _mantle_phase_times:
		_mantle_duration += d
	_mantle_crouch_from = crouch_amount
	_mantle_entry_speed = maxf(player.velocity.y, 0.0)
	player.velocity = Vector3.ZERO
	_play_climb_sound(true)
	mantle_started.emit(ledge.height)
	return true


func _mantle_step(delta: float) -> void:
	var player := _player
	# Loslassen: Strg oder rückwärts, solange man noch an der Wand hängt.
	if _climb_phase != Climb.VAULT and _mantle_time > 0.08 \
			and (Input.is_action_just_pressed("crouch") or Input.is_action_pressed("move_back")):
		_release_mantle()
		return
	_mantle_time += delta
	var phase_start := 0.0
	var phase := 0
	for i in 3:
		if _mantle_time < phase_start + _mantle_phase_times[i] or i == 2:
			phase = i
			break
		phase_start += _mantle_phase_times[i]
	_climb_phase = phase
	var k := clampf((_mantle_time - phase_start) / maxf(_mantle_phase_times[phase], 0.001), 0.0, 1.0)
	var a: Vector3 = _mantle_points[phase]
	var b: Vector3 = _mantle_points[phase + 1]
	var target: Vector3
	match _climb_phase:
		Climb.GRAB:
			# Weich ran, Schwung vom Sprung läuft aus.
			var e := 1.0 - (1.0 - k) * (1.0 - k)
			target = a.lerp(b, e)
		Climb.PULL:
			# Weich anziehen, kräftig hoch, oben weich auslaufen.
			var e := k * k * (3.0 - 2.0 * k)
			target = a.lerp(b, e)
			# Ein Hauch Wackeln beim Ziehen.
			target += _mantle_into * sin(k * PI * 2.0) * 0.015
		Climb.VAULT:
			var e := k * k * (3.0 - 2.0 * k)
			target = a.lerp(b, e) + Vector3.UP * sin(k * PI) * 0.06
	_move_to(target)
	if state != State.MANTLE:
		return
	player.velocity = Vector3.ZERO
	# Kein Fallschaden für den Fall vor dem Greifen.
	player._fall_speed = 0.0
	if _mantle_time >= _mantle_duration:
		_finish_mantle()


## Bewegt mit Kollision zum Ziel. Rutscht an kleinen Kontakten entlang, statt durchzugehen.
func _move_to(target: Vector3) -> void:
	var player := _player
	var motion := target - player.global_position
	if motion.length() < 0.0001:
		return
	var hit := player.move_and_collide(motion, false, 0.001)
	if hit != null:
		var rest := hit.get_remainder().slide(hit.get_normal())
		if rest.length() > 0.0001:
			player.move_and_collide(rest, false, 0.001)
	# Bleibt man deutlich hängen (etwas ist im Weg), loslassen statt zu drücken.
	if player.global_position.distance_to(target) > 0.3:
		_release_mantle()


func _finish_mantle() -> void:
	var player := _player
	state = State.NORMAL
	# Etwas Schwung nach vorn, damit man flüssig weiterläuft.
	player.velocity = _mantle_into * climb_exit_speed
	player.apply_floor_snap()
	if not _mantle_crouch and not Input.is_action_pressed("crouch") and _can_stand():
		_set_crouching(false)
	_crouch_toggled = crouching and not crouch_hold
	_mantle_grab = 0.0
	_play_climb_sound(false)
	mantle_finished.emit()


## Hände lösen, man fällt von der Wand weg.
func _release_mantle() -> void:
	state = State.NORMAL
	_player.velocity = -_mantle_into * 1.2 + Vector3.DOWN * 0.5
	if not Input.is_action_pressed("crouch") and _can_stand():
		_set_crouching(false)
	mantle_finished.emit()


## Wie weit die Hände an der Kante liegen (0…1), für PlayerHands.
func get_grab_weight() -> float:
	return _mantle_grab


## Welttransforms der Hände an der Kante (Handgelenk), rechts und links.
func get_grab_transforms() -> Array[Transform3D]:
	var into := _mantle_into
	var right := into.cross(Vector3.UP).normalized()
	# Finger zeigen in die Wand (-Z der Hand), Handrücken nach oben, Finger leicht über die Kante.
	var basis := Basis(right, Vector3.UP, -into).rotated(right, deg_to_rad(-14.0))
	var result: Array[Transform3D] = []
	for side: float in [1.0, -1.0]:
		var wrist := _mantle_edge + right * side * 0.21 - into * 0.05 + Vector3.UP * 0.035
		result.append(Transform3D(basis.rotated(Vector3.UP, -side * deg_to_rad(10.0)), wrist))
	return result


func _update_mantle_visuals(delta: float) -> void:
	# Handgewicht: beim Greifen schnell an, beim Rüberschwingen ab.
	var target := 0.0
	if state == State.MANTLE:
		match _climb_phase:
			Climb.GRAB, Climb.PULL:
				target = 1.0
			Climb.VAULT:
				var vault_start: float = _mantle_phase_times[0] + _mantle_phase_times[1]
				var k := clampf((_mantle_time - vault_start) / maxf(_mantle_phase_times[2], 0.001), 0.0, 1.0)
				target = 1.0 - smoothstep(0.25, 0.85, k)
	_mantle_grab = move_toward(_mantle_grab, target, delta * 9.0)
	var holder := _player.weapon_holder
	if holder != null:
		holder.visible = _mantle_grab < 0.3
	if _player.item_user != null:
		_player.item_user.visible = _mantle_grab < 0.3


func _climb_pitch() -> float:
	if state != State.MANTLE:
		return 0.0
	var grab_end: float = _mantle_phase_times[0]
	var pull_end: float = grab_end + _mantle_phase_times[1]
	if _mantle_time < grab_end:
		# Kurz zur Kante hochschauen.
		return deg_to_rad(5.0) * (_mantle_time / grab_end)
	if _mantle_time < pull_end:
		# Beim Hochziehen nach vorn über die Kante beugen.
		var k: float = (_mantle_time - grab_end) / _mantle_phase_times[1]
		return lerpf(deg_to_rad(5.0), deg_to_rad(-11.0), k * k * (3.0 - 2.0 * k))
	var k := clampf((_mantle_time - pull_end) / _mantle_phase_times[2], 0.0, 1.0)
	return lerpf(deg_to_rad(-11.0), deg_to_rad(-3.0), k)


## Hockanteil der Kamera beim Klettern: unten noch stehend, oben über der Kante gebeugt.
func _climb_crouch() -> float:
	var grab_end: float = _mantle_phase_times[0]
	var pull_end: float = grab_end + _mantle_phase_times[1]
	if _mantle_time < grab_end:
		return _mantle_crouch_from
	if _mantle_time < pull_end:
		var k: float = (_mantle_time - grab_end) / _mantle_phase_times[1]
		return lerpf(_mantle_crouch_from, 1.0, smoothstep(0.2, 1.0, k))
	return 1.0


func _play_climb_sound(grab: bool) -> void:
	if _climb_audio == null:
		_climb_audio = AudioStreamPlayer3D.new()
		_climb_audio.name = "ClimbAudio"
		_climb_audio.bus = &"SFX"
		_climb_audio.unit_size = 12.0
		_climb_audio.max_distance = 24.0
		_climb_audio.position = Vector3.UP * 1.2
		_player.add_child(_climb_audio)
	var streams: Array[AudioStream] = _player.footstep_sounds if grab else _player.land_sounds
	if streams.is_empty():
		return
	_climb_audio.stream = streams[randi() % streams.size()]
	_climb_audio.pitch_scale = randf_range(0.68, 0.76) if grab else randf_range(1.12, 1.2)
	_climb_audio.volume_db = -1.0 if grab else -7.0
	_climb_audio.play()


## Kletterstand für PlayerAvatarSync: -1 = klettert nicht, sonst Phase plus Anteil
## (0…1 Greifen, 1…2 Hochziehen, 2…3 Rüberschwingen).
func get_climb_progress() -> float:
	if state != State.MANTLE:
		return -1.0
	var start := 0.0
	for i in 3:
		var d: float = _mantle_phase_times[i]
		if _mantle_time < start + d or i == 2:
			return float(i) + clampf((_mantle_time - start) / maxf(d, 0.001), 0.0, 1.0)
		start += d
	return 3.0
