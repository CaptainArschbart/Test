class_name Civilian
extends CharacterBody3D
## Ziviler Fußgänger. Läuft auf dem Wegenetz des CrowdDirector (Gehwege, Zebrastreifen, Plätze),
## nicht feindlich, greift nie an.
##
## Laufen: von Knoten zu Knoten. Der Weg dazwischen kommt vom Navmesh der Gegner (EnemyDirector),
## so geht er um Masten, Hydranten und Stände herum. Bewegung wie bei Enemy: „schwebende“ Kapsel mit
## Bodenstrahl (Bordsteine, Stufen), läuft nie über eine Kante.
## Zebrastreifen: wartet am Bordstein, bis kein Auto kommt (TrafficDirector.crossing_clear), und
## beeilt sich, wenn doch eins kommt. Weicht anderen Personen, dem Spieler und Autos aus.
## Schüsse, Explosionen, Treffer und Tote in der Nähe: Panik, entweder sofort weglaufen oder erst
## ducken (Hände über dem Kopf) und dann weglaufen. Danach beruhigt er sich und geht weiter.
## Treffer: take_hit / emp_hit wie bei Gegnern, hit_by_car vom Auto (umfallen, wieder aufstehen).

enum State { WALK, IDLE, WAIT_CROSS, FLEE, COWER, DOWN, DEAD }
enum Lod { FULL, LOW, SLEEP }

const GROUP := &"civilian"
const SoundGen := preload("res://scenes/enemies/enemy_sounds.gd")
const SCREAMS := ["Aaah!", "Hilfe!", "Nicht schießen!", "Weg hier!", "Runter!"]

var crowd: CrowdDirector
var state := State.WALK
var lod := Lod.FULL
var health := 35.0
var walk_speed := 1.4
var run_speed := 4.2
var model: CivilianModel

var _rng := RandomNumberGenerator.new()
var _from := -1
var _to := -1
var _crossing := false
var _path := PackedVector3Array()
var _path_index := 0
var _goal := Vector3.ZERO
var _state_time := 0.0
var _wait_left := 0.0
var _panic_left := 0.0
var _panic_from := Vector3.ZERO
var _low_accum := 0.0
var _wish := Vector3.ZERO
var _hvel := Vector3.ZERO
var _vy := 0.0
var _face_yaw := 0.0
var _look_yaw := 0.0
var _stuck_time := 0.0
var _last_pos := Vector3.ZERO
var _step_timer := 0.0
var _scream_cd := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _shape: CollisionShape3D
var _voice: AudioStreamPlayer3D
var _steps: AudioStreamPlayer3D
var _label: Label3D


func setup(new_crowd: CrowdDirector, node: int, seed_value: int) -> void:
	crowd = new_crowd
	_rng.seed = seed_value
	walk_speed = _rng.randf_range(1.1, 1.75)
	run_speed = _rng.randf_range(3.6, 4.8)
	_to = node
	_from = -1


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(StealthNoise.GROUP)
	collision_layer = 1
	collision_mask = 1 | 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = deg_to_rad(5.0)
	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = 1.2
	_shape.shape = capsule
	_shape.position.y = 1.2
	add_child(_shape)
	var scaler := Node3D.new()
	scaler.name = "Scaler"
	scaler.scale = Vector3.ONE * _rng.randf_range(0.9, 1.06)
	add_child(scaler)
	model = CivilianModel.new()
	model.name = "Model"
	scaler.add_child(model)
	model.build_civilian(_rng.randi())
	model.run_speed = run_speed
	_voice = _audio(-4.0, 35.0)
	_steps = _audio(-16.0, 16.0)
	_label = Label3D.new()
	_label.position.y = 2.3
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.pixel_size = 0.006
	_label.outline_size = 14
	_label.outline_modulate = Color(0.05, 0.0, 0.08)
	_label.modulate = Color(1.0, 0.92, 0.75)
	_label.visibility_range_end = 25.0
	_label.visible = false
	add_child(_label)
	_face_yaw = rotation.y
	_last_pos = global_position
	_choose_leg()


func _audio(db: float, reach: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.volume_db = db
	p.max_distance = reach
	p.unit_size = 4.0
	p.position.y = 1.5
	add_child(p)
	return p


# --- Öffentlich ---------------------------------------------------------------------------

func is_dead() -> bool:
	return state == State.DEAD


func is_panicking() -> bool:
	return state == State.FLEE or state == State.COWER


func set_lod(new_lod: Lod) -> void:
	lod = new_lod


## Vom CrowdDirector: an einen anderen Knoten verlegen (weit weg von der Kamera).
func relocate(pos: Vector3, toward: int) -> void:
	global_position = pos + Vector3.UP * 0.05
	_last_pos = global_position
	_hvel = Vector3.ZERO
	_vy = 0.0
	_from = -1
	_to = toward
	_crossing = false
	_set_state(State.WALK)
	_plan_path(crowd.nodes[_to])
	lod = Lod.LOW


## Schuss, Klinge, Granate.
func take_hit(damage: float, point: Vector3, normal: Vector3) -> void:
	if state == State.DEAD:
		return
	var amount := damage
	if point.y > global_position.y + 1.5:
		amount *= 2.0
	health -= amount
	model.flinch = clampf(amount / 25.0, 0.4, 1.0)
	if health <= 0.0:
		_die(-normal)
		return
	_say_scream(true)
	panic(point - normal * 3.0)


func emp_hit(damage: float, point: Vector3, normal: Vector3) -> void:
	take_hit(damage * 0.5, point, normal)


## Vom Auto: umgestoßen. Schnell = tot, sonst liegen bleiben und wieder aufstehen.
func hit_by_car(push: Vector3, speed: float) -> void:
	if state == State.DEAD or state == State.DOWN:
		return
	if speed > 7.5:
		_die(push)
		return
	health -= speed * 3.0
	if health <= 0.0:
		_die(push)
		return
	_set_state(State.DOWN)
	_wait_left = _rng.randf_range(2.0, 3.2)
	model.fall(push)
	_say_scream(true)
	if crowd != null:
		crowd.panic_at(global_position, 10.0)


## Von StealthNoise (Schüsse, Explosionen).
func hear_noise(position: Vector3, radius: float, _source: Node, kind: StringName) -> void:
	if state == State.DEAD or state == State.DOWN or lod == Lod.SLEEP:
		return
	if kind != StealthNoise.SHOT and kind != StealthNoise.EXPLOSION:
		return
	if global_position.distance_to(position) > radius * 1.1:
		return
	panic(position)


## Panik vor etwas bei `from`.
func panic(from: Vector3) -> void:
	if state == State.DEAD or state == State.DOWN:
		return
	_panic_from = from
	if state == State.FLEE:
		_panic_left = maxf(_panic_left, _rng.randf_range(6.0, 9.0))
		_plan_flee()
		return
	if state == State.COWER:
		return
	_say_scream(false)
	if _rng.randf() < 0.4 and global_position.distance_to(from) > 4.0:
		_set_state(State.COWER)
		_wait_left = _rng.randf_range(1.8, 4.0)
	else:
		_start_flee()


# --- Takt ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if lod == Lod.SLEEP and state != State.FLEE:
		return
	if lod == Lod.LOW:
		_low_accum += delta
		if _low_accum < 0.2:
			return
		delta = minf(_low_accum, 0.25)
		_low_accum = 0.0
	_tick(delta)


func _tick(delta: float) -> void:
	_state_time += delta
	_scream_cd = maxf(_scream_cd - delta, 0.0)
	_wish = Vector3.ZERO
	match state:
		State.WALK: _walk()
		State.IDLE: _idle(delta)
		State.WAIT_CROSS: _wait_cross(delta)
		State.FLEE: _flee(delta)
		State.COWER: _cower(delta)
		State.DOWN: _down(delta)
	if state != State.DOWN:
		_move(delta)
	_animate(delta)


func _walk() -> void:
	var speed := walk_speed
	if _crossing and crowd != null and crowd.traffic != null:
		# Auf dem Zebrastreifen: kommt ein Auto, beeilen.
		var a := crowd.nodes[_from] if _from >= 0 else global_position
		if not crowd.traffic.crossing_clear(a, crowd.nodes[_to], 2.0):
			speed = run_speed * 0.8
	if _go(speed):
		_arrive()
	elif _stuck_time > 4.0:
		# Kommt nicht weiter: Ziel überspringen.
		_stuck_time = 0.0
		_arrive()


func _arrive() -> void:
	var wait := crowd.node_wait[_to] if crowd != null else 0.0
	if wait > 0.0 and _rng.randf() < 0.75:
		_set_state(State.IDLE)
		_wait_left = _rng.randf_range(0.5, 1.0) * wait
	elif _rng.randf() < 0.06:
		_set_state(State.IDLE)
		_wait_left = _rng.randf_range(1.5, 4.0)
	else:
		_choose_leg()


func _idle(delta: float) -> void:
	_wait_left -= delta
	# Umschauen.
	if fmod(_state_time, 2.5) < delta:
		_look_yaw = _face_yaw + _rng.randf_range(-1.2, 1.2)
	_face_yaw = lerp_angle(_face_yaw, _look_yaw, minf(delta * 2.0, 1.0))
	if _wait_left <= 0.0:
		_set_state(State.WALK)
		_choose_leg()


func _wait_cross(delta: float) -> void:
	_wait_left -= delta
	var a := crowd.nodes[_from]
	var b := crowd.nodes[_to]
	var to := b - a
	_face_yaw = lerp_angle(_face_yaw, atan2(-to.x, -to.z), minf(delta * 4.0, 1.0))
	if crowd.traffic == null or crowd.traffic.crossing_clear(a, b) or _wait_left <= 0.0:
		_set_state(State.WALK)
		_crossing = true
		_plan_path(b)


func _flee(delta: float) -> void:
	_panic_left -= delta
	if _go(run_speed) or _stuck_time > 2.0:
		_stuck_time = 0.0
		if _panic_left > 0.0:
			_plan_flee()
		else:
			_calm_down()
	elif _panic_left <= -6.0:
		_calm_down()


func _cower(delta: float) -> void:
	_wait_left -= delta
	model.cower = move_toward(model.cower, 1.0, delta * 5.0)
	model.crouch = move_toward(model.crouch, 1.0, delta * 5.0)
	if _wait_left <= 0.0:
		_start_flee()


func _down(delta: float) -> void:
	_wait_left -= delta
	if _wait_left <= 0.0 and model.is_fallen():
		model.get_up()
		_wait_left = 1.0
	elif _wait_left <= 0.0 and not model.is_fallen():
		_panic_from = global_position - (-global_basis.z) * 3.0
		_start_flee()


func _start_flee() -> void:
	_set_state(State.FLEE)
	_panic_left = _rng.randf_range(6.0, 10.0)
	_plan_flee()


func _calm_down() -> void:
	_set_state(State.WALK)
	if crowd != null:
		_to = crowd.nearest_node(global_position)
		_from = -1
		_crossing = false
		_plan_path(crowd.nodes[_to])


## Fluchtpunkt: am liebsten ein Knoten im Gehweg-Netz, der von der Gefahr weg liegt
## (da ist sicher Platz zum Laufen). Sonst weg von der Gefahr, etwas gestreut, aufs Navmesh gelegt.
func _plan_flee() -> void:
	var away := global_position - _panic_from
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
	away = away.normalized()
	if crowd != null:
		var best := -1
		var best_score := -INF
		for i: int in crowd.nodes.size():
			var to: Vector3 = crowd.nodes[i] - global_position
			to.y = 0.0
			var d := to.length()
			if d < 12.0 or d > 40.0:
				continue
			var score := to.normalized().dot(away) + _rng.randf_range(0.0, 0.5)
			if score > best_score:
				best_score = score
				best = i
		if best >= 0 and best_score > 0.4:
			_plan_path(crowd.nodes[best])
			return
	away = away.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
	var target := global_position + away * _rng.randf_range(16.0, 26.0)
	var nav := EnemyDirector.find(get_tree())
	if nav != null and nav.is_nav_ready:
		target = nav.snap(target)
	_plan_path(target)


## Nächster Abschnitt im Wegenetz. Zebrastreifen: erst warten.
func _choose_leg() -> void:
	if crowd == null:
		return
	var options := crowd.neighbors(_to)
	if options.size() > 1 and _from >= 0:
		var without := PackedInt32Array()
		for n: int in options:
			if n != _from:
				without.append(n)
		options = without
	if options.is_empty():
		return
	var next := options[_rng.randi() % options.size()]
	_from = _to
	_to = next
	_crossing = crowd.is_crossing(_from, _to)
	if _crossing:
		_set_state(State.WAIT_CROSS)
		_wait_left = _rng.randf_range(10.0, 16.0)
		_crossing = false
		return
	_set_state(State.WALK)
	_plan_path(crowd.nodes[_to])


func _plan_path(target: Vector3) -> void:
	_goal = target
	_path_index = 0
	var nav := EnemyDirector.find(get_tree())
	if nav != null and nav.is_nav_ready:
		var map := get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(map, global_position, NavigationServer3D.map_get_closest_point(map, target), true)
	else:
		_path = PackedVector3Array([target])
	if _path.is_empty():
		_path = PackedVector3Array([target])


## Läuft den geplanten Weg entlang. true = angekommen.
func _go(speed: float) -> bool:
	while _path_index < _path.size():
		var p := _path[_path_index]
		if _flat(p, global_position) < 0.45 and absf(p.y - global_position.y) < 1.2:
			_path_index += 1
		else:
			break
	if _path_index >= _path.size():
		return true
	var to := _path[_path_index] - global_position
	to.y = 0.0
	var dir := to.normalized()
	_wish = dir * speed
	_face_yaw = atan2(-dir.x, -dir.z)
	return false


# --- Bewegung (wie Enemy._move, schlanker) ---------------------------------------------

func _move(delta: float) -> void:
	var wish := _wish
	# Abstand zu Personen und Autos; vor nahen, fahrenden Autos zur Seite springen.
	if crowd != null and crowd.traffic != null:
		for o: Array in crowd.traffic.obstacles_near(global_position, 3.5):
			var node: Node = o[2]
			if node == self:
				continue
			var off: Vector3 = global_position - (o[0] as Vector3)
			off.y = 0.0
			var d := off.length()
			if d < 0.01:
				continue
			if o[3] == TrafficDirector.Kind.CAR:
				var car := node as TrafficCar
				if car != null and car.speed > 2.0 and d < 3.2:
					var fwd := -car.global_basis.z
					var side := Vector3(-fwd.z, 0, fwd.x)
					var away := side * signf(off.dot(side) + 0.001)
					wish += away * run_speed
				continue
			var reach := 0.75 + (o[1] as float)
			if d < reach and wish.length() > 0.1:
				wish += off / d * (reach - d) * 2.5
	if _stuck_time > 0.6 and wish.length() > 0.1:
		var side := Vector3(-wish.z, 0.0, wish.x).normalized() * (1.0 if int(_stuck_time / 1.5) % 2 == 0 else -1.0)
		wish += side * wish.length() * 0.8
	_hvel = _hvel.move_toward(wish, (10.0 if wish.length() > _hvel.length() else 14.0) * delta)
	var step_scale := maxf(delta / get_physics_process_delta_time(), 1.0)
	var probe := maxf(0.5, _hvel.length() * delta + 0.3)
	if _hvel.length() > 0.1 and not _ground_below(global_position + _hvel.normalized() * probe, 1.3):
		_hvel = Vector3.ZERO
	velocity = Vector3(_hvel.x, 0.0, _hvel.z) * step_scale
	move_and_slide()
	velocity = Vector3(_hvel.x, 0.0, _hvel.z)
	var ground := _ground_height()
	var y := global_position.y
	if not is_nan(ground) and ground >= y - 0.55 and _vy <= 0.5:
		_vy = 0.0
		global_position.y = lerpf(y, ground, minf(delta * (30.0 if ground > y else 14.0), 1.0))
	else:
		_vy -= _gravity * delta
		var ny := y + _vy * delta
		if not is_nan(ground) and ny <= ground:
			ny = ground
			_vy = 0.0
		global_position.y = ny
	rotation.y = lerp_angle(rotation.y, _face_yaw, minf(delta * 6.0, 1.0))
	var moved := _flat(global_position, _last_pos)
	_last_pos = global_position
	if _wish.length() > 0.5 and moved < _wish.length() * delta * 0.25:
		_stuck_time += delta
		if _stuck_time > 1.2 and int(_stuck_time * 10.0) % 12 == 0:
			_plan_path(_goal)
	else:
		_stuck_time = maxf(_stuck_time - delta * 0.5, 0.0)


func _ground_height() -> float:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.65,
			global_position + Vector3.DOWN * 1.2, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return NAN if hit.is_empty() else (hit.position as Vector3).y


func _ground_below(point: Vector3, depth: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point + Vector3.DOWN * depth, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Aussehen und Ton ---------------------------------------------------------------------

func _animate(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	model.speed = speed
	if state != State.COWER:
		model.cower = move_toward(model.cower, 0.0, delta * 3.0)
		model.crouch = move_toward(model.crouch, 0.0, delta * 3.0)
	model.animate(delta)
	if speed > 0.4 and lod == Lod.FULL:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.6 if speed < 2.5 else 0.34
			_steps.stream = SoundGen.step()
			_steps.pitch_scale = _rng.randf_range(1.0, 1.2)
			_steps.volume_db = -20.0 if speed < 2.5 else -12.0
			_steps.play()


func _set_state(new_state: State) -> void:
	if state == State.DEAD:
		return
	state = new_state
	_state_time = 0.0
	_stuck_time = 0.0


func _say_scream(hurt: bool) -> void:
	if _scream_cd > 0.0 or lod == Lod.SLEEP:
		return
	_scream_cd = 3.0
	if hurt or _rng.randf() < 0.6:
		_voice.stream = SoundGen.voice(&"hurt" if hurt else &"alert", _rng.randf_range(1.25, 1.8), _rng.randi() % 3)
		_voice.play()
	_label.text = SCREAMS[_rng.randi() % SCREAMS.size()]
	_label.visible = true
	var shown := _label.text
	get_tree().create_timer(1.8, false).timeout.connect(func() -> void:
		if is_instance_valid(_label) and _label.text == shown:
			_label.visible = false)


func _die(push: Vector3) -> void:
	_set_state(State.DEAD)
	state = State.DEAD
	_label.visible = false
	model.fall(push if push.length() > 0.01 else -global_basis.z)
	_voice.stream = SoundGen.voice(&"death", _rng.randf_range(1.2, 1.5), 0)
	_voice.play()
	# Kein Hindernis mehr für den Spieler, liegt aber noch (Autos fahren drumherum).
	collision_layer = 0
	collision_mask = 0
	if crowd != null:
		crowd.on_civilian_died(self)
