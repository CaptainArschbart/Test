class_name Enemy
extends CharacterBody3D
## Gegner mit Navmesh-Navigation, Zustandsautomat, Nah-/Fernkampf, Tod und Beute.
##
## Typ und Werte kommen aus `profile` (EnemyProfile, scenes/enemies/profiles/*.tres).
## Streife: `route` zeigt auf eine PatrolRoute (Marker3D-Kinder). Ohne Route = Wachposten.
##
## Zustände
##   PATROL       läuft die Route ab / steht Wache und schaut sich um
##   SUSPICIOUS   „?“ – bleibt stehen, dreht sich zur Quelle (Sicht oder Geräusch)
##   INVESTIGATE  geht zur letzten Quelle und schaut sich dort um
##   COMBAT       „!“ – Alarm, ruft andere, kämpft (Nahkampf: hinlaufen und zuschlagen; Fernkampf:
##                Abstand halten, Salven, nachladen in Deckung, bei wenig Leben Deckung suchen)
##   SEARCH       Spur verloren: zur letzten bekannten Stelle, dann mehrere Punkte drumherum absuchen
##   RETURN       zurück zur Route / zum Posten
##   STUNNED      betäubt (EMP, Hinterhalt-Treffer)
##   DEAD         liegt, hat Beute fallen lassen
##
## Wahrnehmung nutzt das Schleich-System aus PR #26: Sichtbarkeit des Spielers aus
## PlayerStealth.visibility (Licht, Hocken, Bewegung), Geräusche über StealthNoise (Gruppe noise_listener).
## Gefundene Leichen machen misstrauisch. Treffer: take_hit(damage, point, normal); EMP: emp_hit().
##
## Bewegung: „schwebende“ Kapsel (unten 0,6 m frei) plus Bodenstrahl. Stufen bis 0,6 m (Treppen,
## Bordsteine) geht er so einfach hoch, und er läuft nie über eine Kante, unter der kein Boden ist.
## Wege kommen vom NavigationAgent3D auf dem Navmesh des EnemyDirector.

signal died(enemy: Enemy)
signal state_changed(enemy: Enemy, state: State)

enum State { PATROL, SUSPICIOUS, INVESTIGATE, COMBAT, SEARCH, RETURN, STUNNED, DEAD }
enum Lod { FULL, LOW, SLEEP }

const GROUP := &"enemy"
const CORPSE_GROUP := &"enemy_corpse"
const SoundGen := preload("res://scenes/enemies/enemy_sounds.gd")
const PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")
const CREDCHIP := preload("res://scenes/items/data/credchip.tres")

const STATE_COLORS := {
	State.PATROL: Color(0.0, 0.95, 1.0),
	State.RETURN: Color(0.0, 0.95, 1.0),
	State.SUSPICIOUS: Color(1.0, 0.78, 0.2),
	State.INVESTIGATE: Color(1.0, 0.78, 0.2),
	State.SEARCH: Color(1.0, 0.5, 0.15),
	State.COMBAT: Color(1.0, 0.16, 0.3),
	State.STUNNED: Color(0.6, 0.4, 1.0),
	State.DEAD: Color(0.05, 0.05, 0.07),
}

## Was über dem Kopf steht, wenn er ruft (passend zur Funk-Stimme aus EnemySounds).
const BARKS := {
	&"suspicious": ["Hm?", "Was war das?", "Hallo?"],
	&"investigate": ["Wer ist da?", "Ich seh mal nach.", "Komm raus!"],
	&"alert": ["Da ist er!", "Hey! Stehen bleiben!", "Eindringling!"],
	&"search": ["Wo bist du?", "Sucht ihn!", "Der ist noch hier."],
	&"lost": ["Weg.", "Einbildung …", "Zurück auf Posten."],
	&"body": ["Mann am Boden!", "Die haben ihn erwischt!", "Alarm! Einer liegt hier!"],
	&"cover": ["Deckung!", "Lade nach!", "Gib mir Deckung!"],
	&"hurt": ["Argh!", "Ugh!", "Verdammt!"],
	&"death": ["…"],
}

@export var profile: EnemyProfile
## PatrolRoute, die er abläuft. Leer = Wachposten an der Startposition.
@export var route: NodePath
## Abwechslung im Aussehen. 0 = aus dem Namen.
@export var variant_seed := 0
## Fängt bei diesem Wegpunkt an.
@export var start_point := 0
## Sekunden, bis eine Leiche verschwindet (nur wenn der Spieler weit weg ist).
@export var corpse_time := 240.0

var state: State = State.PATROL
var awareness := 0.0
var health := 80.0
## Letzte Stelle, an der er den Spieler gesehen oder etwas gehört hat.
var target_position := Vector3.ZERO
var lod: Lod = Lod.FULL
var model: EnemyModel

var _player: Player
var _director: EnemyDirector
var _route: PatrolRoute
## Aktueller Weg (Navmesh-Punkte) und wohin er gerade führt.
var _path := PackedVector3Array()
var _path_index := 0
var _path_target := Vector3.INF
var _path_age := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rng := RandomNumberGenerator.new()

var _state_time := 0.0
var _unseen_time := 0.0
var _sees_player := false
var _sight_amount := 0.0
var _perceive_timer := 0.0
var _corpse_timer := 0.0
var _low_accum := 0.0
var _home_position := Vector3.ZERO
var _home_yaw := 0.0
var _patrol_index := 0
var _patrol_dir := 1
var _wait_left := 0.0
var _search_points: Array[Vector3] = []
var _arrived := false

var _wish := Vector3.ZERO
var _hvel := Vector3.ZERO
var _vy := 0.0
var _face_yaw := 0.0
var _face_set := false
var _stuck_time := 0.0
var _last_pos := Vector3.ZERO
var _repath_left := 0.0

var _cooldown := 0.0
var _attack_t := -1.0
var _attack_hit_done := false
var _aim_t := 0.0
var _burst_left := 0
var _ammo := 12
var _reload_left := 0.0
var _has_token := false
var _cover_point := Vector3.INF
var _cover_left := 0.0
var _cover_search := 0.0
var _strafe_point := Vector3.INF
var _strafe_timer := 0.0
var _stun_left := 0.0
var _stagger := 0.0
var _step_timer := 0.0
var _bark_cooldown := 0.0
var _flash_left := 0.0

var _shape: CollisionShape3D
var _mark: Label3D
var _bark_label: Label3D
var _voice: AudioStreamPlayer3D
var _sfx: AudioStreamPlayer3D
var _steps: AudioStreamPlayer3D
var _muzzle_light: OmniLight3D
var _flashlight_allowed := true

static var _tracer_mesh: BoxMesh
static var _tracer_mat: StandardMaterial3D


func _ready() -> void:
	if profile == null:
		profile = EnemyProfile.new()
	add_to_group(GROUP)
	add_to_group(StealthNoise.GROUP)
	collision_layer = 1
	collision_mask = 1 | 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = deg_to_rad(5.0)
	_rng.seed = variant_seed if variant_seed != 0 else hash(String(get_path()))
	health = profile.max_health
	_ammo = profile.magazine
	_home_position = global_position
	_home_yaw = rotation.y
	_face_yaw = rotation.y
	target_position = global_position
	_last_pos = global_position
	_route = get_node_or_null(route) as PatrolRoute if not route.is_empty() else null
	if _route != null and _route.point_count() > 0:
		_patrol_index = clampi(start_point, 0, _route.point_count() - 1)
	_build()
	_apply_state_look()


func _build() -> void:
	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	# Schmaler als der Navmesh-Rand (0,25 m), sonst bleibt er an Feuertreppen und Stegen hängen.
	capsule.radius = 0.2
	capsule.height = 1.25
	_shape.shape = capsule
	# Unten 0,6 m frei: Stufen, steile Hüttentreppen und Bordsteine gehen unter der Kapsel durch.
	_shape.position.y = 1.225
	add_child(_shape)

	model = EnemyModel.new()
	model.name = "Model"
	add_child(model)
	model.build(profile, _rng.randi())
	model.run_speed = profile.run_speed


	_mark = _label(96, 0.007, 2.3)
	_bark_label = _label(40, 0.006, 2.62)
	_bark_label.visibility_range_end = 25.0
	_bark_label.modulate = Color(0.85, 0.95, 1.0)

	_voice = _audio(-2.0, 45.0)
	_sfx = _audio(2.0, 120.0)
	_steps = _audio(-9.0, 22.0)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.omni_range = 5.0
	_muzzle_light.light_color = Color(1.0, 0.75, 0.4)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.visible = false
	model.muzzle.add_child(_muzzle_light)


func _label(size: int, pixel: float, height: float) -> Label3D:
	var l := Label3D.new()
	l.position = Vector3(0, height, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = size
	l.pixel_size = pixel
	l.outline_size = 14
	l.outline_modulate = Color(0.05, 0.0, 0.08)
	l.visible = false
	add_child(l)
	return l


func _audio(db: float, reach: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.volume_db = db
	p.max_distance = reach
	p.unit_size = 5.0
	p.position.y = 1.5
	add_child(p)
	return p


# --- Öffentlich ---------------------------------------------------------------------------

func is_dead() -> bool:
	return state == State.DEAD


## Kämpft, sucht oder geht einer Sache nach (wird auch weit weg weiter berechnet).
func is_engaged() -> bool:
	return state == State.COMBAT or state == State.SEARCH or state == State.INVESTIGATE


func is_attacking() -> bool:
	return state == State.COMBAT and _has_token


func eye_position() -> Vector3:
	return global_position + Vector3.UP * (1.62 - model.crouch * 0.3)


## Vom EnemyDirector: wie oft er denkt und ob die Taschenlampe an sein darf.
func set_lod(new_lod: Lod, lights: bool) -> void:
	lod = new_lod
	_flashlight_allowed = lights and new_lod != Lod.SLEEP
	_update_flashlight()


## Von Waffen, Klinge und Granate.
func take_hit(damage: float, point: Vector3, normal: Vector3) -> void:
	if state == State.DEAD:
		return
	_find_player()
	var amount := damage
	if point.y > global_position.y + 1.55 - model.crouch * 0.3:
		amount *= profile.headshot_multiplier
	var unaware := state != State.COMBAT and state != State.STUNNED and awareness < 1.0
	var close := _player != null and _player.global_position.distance_to(global_position) < 2.5
	var sneak := unaware and close
	if sneak:
		amount *= profile.sneak_multiplier
	health -= amount
	model.flinch = clampf(amount / 30.0, 0.4, 1.0)
	_flash()
	if health <= 0.0:
		var push := -normal
		if _player != null:
			push = global_position - _player.global_position
		_die(push)
		return
	if amount >= 35.0:
		_stagger = 0.5
	if sneak:
		# Niedergeschlagen: länger betäubt, wacht misstrauisch auf.
		_stun(profile.stun_time * 2.0)
		return
	_say(&"hurt")
	if _player != null:
		target_position = _player.global_position
	awareness = 1.0
	if state != State.STUNNED:
		_enter_combat(false)


## EMP-Granate: Schaden und Betäubung (Elektronik, Lampe, Implantate fallen aus).
func emp_hit(damage: float, point: Vector3, normal: Vector3) -> void:
	if state == State.DEAD:
		return
	take_hit(damage * 0.5, point, normal)
	if state != State.DEAD:
		_stun(profile.stun_time)
		_sfx.stream = SoundGen.zap()
		_sfx.play()


## Spieler ist nach dem Tod respawnt: vergessen, was war, und zurück auf Streife.
func reset_alert() -> void:
	if state == State.DEAD:
		return
	awareness = 0.0
	_sees_player = false
	_stun_left = 0.0
	_release_token()
	_set_state(State.RETURN)


## Von StealthNoise aufgerufen.
func hear_noise(position: Vector3, radius: float, source: Node, kind: StringName) -> void:
	if state == State.DEAD or state == State.STUNNED or lod == Lod.SLEEP and not is_engaged():
		return
	var effective := radius * profile.hearing_scale
	var eye := eye_position()
	var dist := eye.distance_to(position)
	if dist > effective:
		return
	var query := PhysicsRayQueryParameters3D.create(eye, position + Vector3.UP * 0.2, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider != source:
		effective *= 0.55
		if dist > effective:
			return
	# Rufe und Schüsse von Kollegen: dorthin, wo der Kollege den Spieler vermutet.
	if source is Enemy or source is StealthGuard or kind == StealthNoise.SHOUT:
		if state == State.COMBAT:
			return
		var where := position
		if source is Enemy:
			where = (source as Enemy).target_position
		target_position = where
		awareness = maxf(awareness, 0.75)
		_begin_search(where)
		return
	var loudness := 1.0 - dist / effective
	target_position = position
	if state == State.COMBAT:
		return
	var gain := 0.25 + 0.45 * loudness
	if kind == StealthNoise.SHOT or kind == StealthNoise.EXPLOSION:
		gain += 0.45
	awareness = minf(maxf(awareness, 0.0) + gain, 0.95)
	if awareness >= 0.35 and (state == State.PATROL or state == State.RETURN):
		_set_state(State.SUSPICIOUS)
	elif state == State.INVESTIGATE or state == State.SEARCH:
		_state_time = 0.0
		_arrived = false


# --- Takt ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_corpse_tick(delta)
		return
	if lod == Lod.SLEEP:
		return
	if lod == Lod.LOW:
		_low_accum += delta
		if _low_accum < 0.2:
			return
		delta = minf(_low_accum, 0.25)
		_low_accum = 0.0
	_tick(delta)


func _tick(delta: float) -> void:
	_find_player()
	if _director == null:
		_director = EnemyDirector.find(get_tree())
	_state_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_bark_cooldown = maxf(_bark_cooldown - delta, 0.0)
	_stagger = maxf(_stagger - delta, 0.0)
	_update_muzzle_flash(delta)
	_perceive(delta)
	_wish = Vector3.ZERO
	_face_set = false
	_think(delta)
	if _stagger > 0.0:
		_wish *= 0.2
	_move(delta)
	_animate(delta)
	if _player != null and _player.stealth != null and awareness > 0.01 and state != State.STUNNED:
		var shown := 1.0 if state == State.COMBAT else minf(awareness, 0.99)
		_player.stealth.report_awareness(self, shown)


func _find_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	# Im Multiplayer gibt es mehrere Spielerfiguren; Gegner laufen pro Rechner und jagen die eigene.
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is Player and (not node.has_method("controls_local_body") or node.call("controls_local_body")):
			_player = node
			return


# --- Wahrnehmung --------------------------------------------------------------------------

func _perceive(delta: float) -> void:
	_perceive_timer -= delta
	if _perceive_timer <= 0.0:
		# Sicht 10× pro Sekunde, leicht versetzt, damit nicht alle im selben Frame rechnen.
		_perceive_timer = 0.1 + _rng.randf() * 0.02
		_sight_amount = _sight_of_player()
		_sees_player = _sight_amount > 0.0
	if state == State.STUNNED:
		return
	if _sees_player:
		_unseen_time = 0.0
		awareness = minf(awareness + profile.sight_gain * _sight_amount * delta, 1.2)
		if awareness >= 0.35:
			target_position = _player.global_position
	else:
		_unseen_time += delta
		if state != State.COMBAT:
			var hold := state == State.INVESTIGATE or state == State.SUSPICIOUS or state == State.SEARCH
			awareness = maxf(awareness - profile.awareness_decay * (0.5 if hold else 1.0) * delta, 0.0)
	_corpse_timer -= delta
	if _corpse_timer <= 0.0:
		_corpse_timer = 0.8
		_look_for_corpses()


## 0 = sieht den Spieler nicht, sonst wie deutlich (Entfernung × Sichtbarkeit).
func _sight_of_player() -> float:
	if _player == null or _player.noclip or _player.dead or not _player.stats.is_alive():
		return 0.0
	var eye := eye_position()
	var crouching := _player.movement != null and _player.movement.crouching
	var chest := _player.global_position + Vector3.UP * (0.55 if crouching else 0.9)
	var to_player := chest - eye
	var dist := to_player.length()
	if dist > profile.view_distance:
		return 0.0
	var forward := -global_basis.z
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	var angle := rad_to_deg(forward.angle_to(flat)) if flat.length() > 0.01 else 0.0
	var in_cone := angle <= profile.view_angle
	if not in_cone and not (dist < 1.8 and not crouching):
		return 0.0
	if not _line_to_player(eye, chest) and not _line_to_player(eye, _player.camera.global_position):
		return 0.0
	var vis := _player.stealth.visibility if _player.stealth != null else 1.0
	var near := 1.0 - dist / profile.view_distance
	var edge := 1.0 - clampf((angle - profile.view_angle * 0.5) / (profile.view_angle * 0.5), 0.0, 0.6) if in_cone else 0.5
	var amount := vis * (0.25 + 1.5 * near * near) * edge
	if dist < 4.0:
		amount += 0.6 * vis
	# Im Kampf verliert er den Spieler nicht so schnell aus dem Blick.
	if state == State.COMBAT:
		amount = maxf(amount, 0.3)
	return amount


func _line_to_player(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _player


func _look_for_corpses() -> void:
	if state == State.COMBAT or lod != Lod.FULL:
		return
	var eye := eye_position()
	var forward := -global_basis.z
	for node: Node in get_tree().get_nodes_in_group(CORPSE_GROUP):
		var body := node as Node3D
		if body == null or body.get_meta(&"found", false):
			continue
		var spot := body.global_position + Vector3.UP * 0.3
		var to := spot - eye
		if to.length() > minf(profile.view_distance, 16.0):
			continue
		if rad_to_deg(forward.angle_to(Vector3(to.x, 0.0, to.z))) > profile.view_angle:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, spot, 1, [get_rid(), (body as CollisionObject3D).get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		body.set_meta(&"found", true)
		_say(&"body", true)
		StealthNoise.emit(get_tree(), global_position, profile.shout_radius, self, StealthNoise.SHOUT)
		target_position = body.global_position
		awareness = maxf(awareness, 0.8)
		_begin_search(body.global_position)
		return


# --- Verhalten ----------------------------------------------------------------------------

func _think(delta: float) -> void:
	if state == State.STUNNED:
		_stun_left -= delta
		if _stun_left <= 0.0:
			model.stunned = false
			_update_flashlight()
			if awareness >= 1.0:
				_enter_combat(true)
			else:
				awareness = 0.6
				_begin_search(target_position)
		return
	if awareness >= 1.0 and state != State.COMBAT:
		_enter_combat(true)
	if _director != null and not _director.is_nav_ready:
		# Navmesh noch nicht fertig: stehen und schauen.
		if state == State.COMBAT and _sees_player:
			_face(target_position)
		return
	match state:
		State.PATROL:
			if awareness >= 0.35:
				_set_state(State.SUSPICIOUS)
			else:
				_patrol(delta)
		State.SUSPICIOUS:
			_face(target_position)
			if _state_time > 1.3:
				_say(&"investigate")
				_set_state(State.INVESTIGATE)
			elif awareness < 0.1:
				_set_state(State.RETURN)
		State.INVESTIGATE:
			_investigate(delta)
		State.SEARCH:
			_search(delta)
		State.RETURN:
			_return(delta)
		State.COMBAT:
			_combat(delta)


func _patrol(delta: float) -> void:
	if _route == null or _route.point_count() == 0:
		# Wachposten: zurück zum Platz, dann langsam hin und her schauen.
		if _flat(global_position, _home_position) > 0.7:
			_go(_home_position, profile.walk_speed)
			return
		var yaw := _home_yaw + sin(_state_time * 0.45) * deg_to_rad(40.0)
		_face_yaw_to(yaw)
		return
	var points := _route.get_points()
	var marker := points[_patrol_index % points.size()]
	if not _arrived:
		if _flat(global_position, marker.global_position) > 0.7 and not _give_up(4.0):
			_go(marker.global_position, profile.walk_speed)
			return
		# Angekommen (oder kommt nicht hin): warten, dann nächster Punkt.
		_arrived = true
		_stuck_time = 0.0
		_wait_left = _route.wait_at(_patrol_index)
	if _route.looks_at(_patrol_index):
		_face_yaw_to(marker.global_rotation.y + sin(_state_time * 0.5) * 0.35)
	_wait_left -= delta
	if _wait_left <= 0.0:
		var next := _route.next_index(_patrol_index, _patrol_dir)
		_patrol_index = next.x
		_patrol_dir = next.y
		_arrived = false


func _investigate(delta: float) -> void:
	if not _arrived:
		if _flat(global_position, target_position) > 1.0 and not _give_up(3.0) and _state_time < 20.0:
			_go(target_position, profile.walk_speed * 1.2)
			return
		_arrived = true
		_state_time = 0.0
	# Umschauen.
	_face_yaw_to(rotation.y + delta * 1.6 * sin(_state_time * 0.9))
	if awareness < 0.05 or _state_time > 6.0:
		awareness = minf(awareness, 0.2)
		_say(&"lost")
		_set_state(State.RETURN)


func _begin_search(where: Vector3) -> void:
	if state == State.COMBAT or state == State.STUNNED or state == State.DEAD:
		return
	target_position = where
	_search_points.clear()
	_search_points.append(where)
	for i: int in 3:
		var a := _rng.randf() * TAU
		var p := where + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(3.0, 8.0)
		if _director != null:
			p = _director.snap(p)
		_search_points.append(p)
	if state != State.SEARCH:
		_say(&"search")
	_set_state(State.SEARCH)
	_arrived = false


func _search(delta: float) -> void:
	if _search_points.is_empty():
		awareness = minf(awareness, 0.2)
		_say(&"lost")
		_set_state(State.RETURN)
		return
	var point := _search_points[0]
	if not _arrived:
		if _flat(global_position, point) > 1.0 and not _give_up(3.0) and _state_time < 40.0:
			_go(point, profile.run_speed * 0.6)
			return
		_arrived = true
		_state_time = 0.0
	_face_yaw_to(rotation.y + delta * 2.0 * sin(_state_time * 1.2))
	if _state_time > 2.6:
		_search_points.remove_at(0)
		_arrived = false
		_state_time = 0.0
		_stuck_time = 0.0
	awareness = maxf(awareness - 0.02 * delta, 0.36 if not _search_points.is_empty() else 0.0)


func _return(_delta: float) -> void:
	if awareness >= 0.35:
		_set_state(State.SUSPICIOUS)
		return
	var goal := _home_position
	if _route != null and _route.point_count() > 0:
		_patrol_index = _route.closest_index(global_position)
		goal = _route.get_points()[_patrol_index].global_position
	if _flat(global_position, goal) > 0.8 and not _give_up(5.0):
		_go(goal, profile.walk_speed)
		return
	_set_state(State.PATROL)


func _enter_combat(shout: bool) -> void:
	if state == State.COMBAT or state == State.DEAD:
		return
	awareness = 1.0
	_aim_t = 0.0
	_unseen_time = 0.0
	_burst_left = profile.burst
	_set_state(State.COMBAT)
	if shout:
		_say(&"alert", true)
		StealthNoise.emit(get_tree(), global_position, profile.shout_radius, self, StealthNoise.SHOUT)


func _combat(delta: float) -> void:
	if _player == null or _player.dead or not _player.stats.is_alive():
		_release_token()
		awareness = 0.3
		_set_state(State.RETURN)
		return
	if _sees_player:
		target_position = _player.global_position
	elif _unseen_time > (7.0 if profile.hold_position else 5.0):
		_release_token()
		awareness = 0.8
		_set_state(State.PATROL)
		_begin_search(target_position)
		return
	if profile.style == EnemyProfile.Style.MELEE:
		_combat_melee(delta)
	else:
		_combat_ranged(delta)


func _combat_melee(delta: float) -> void:
	var dist := _flat(global_position, target_position)
	var dy := absf(target_position.y - global_position.y)
	if _attack_t >= 0.0:
		# Ausholen (0,45 s), Treffer, ausschwingen.
		_attack_t += delta
		model.attack = _attack_t / 0.75
		_face(target_position)
		if _attack_t >= 0.45 and not _attack_hit_done:
			_attack_hit_done = true
			var to := _player.global_position - global_position
			var front := (-global_basis.z).dot(Vector3(to.x, 0, to.z).normalized())
			if _sees_player and to.length() < profile.attack_range + 0.5 and front > 0.3 and absf(to.y) < 1.4:
				_player.stats.damage(profile.damage, profile.death_cause)
				_sfx.stream = SoundGen.thud()
				_sfx.play()
		if _attack_t >= 0.75:
			_attack_t = -1.0
			model.attack = 0.0
			_cooldown = profile.attack_interval
		return
	if _sees_player and dist <= profile.attack_range and dy < 1.4:
		_face(target_position)
		if _cooldown <= 0.0:
			_attack_t = 0.0
			_attack_hit_done = false
			_sfx.stream = SoundGen.swing()
			_sfx.pitch_scale = _rng.randf_range(0.9, 1.1)
			_sfx.play()
		return
	if _flat(global_position, target_position) > 0.9:
		_go(target_position, profile.run_speed)
		if not _sees_player:
			return
		_face(target_position)
	else:
		_face_yaw_to(rotation.y + delta * 2.0)


func _combat_ranged(delta: float) -> void:
	var dist := global_position.distance_to(target_position)
	_reload_left = maxf(_reload_left - delta, 0.0)
	_cover_left = maxf(_cover_left - delta, 0.0)
	_cover_search = maxf(_cover_search - delta, 0.0)
	_strafe_timer -= delta
	var aiming := false

	# Deckung: beim Nachladen und mit wenig Leben (immer wieder kurz).
	var wants_cover := _reload_left > 0.0 or (health < profile.max_health * 0.4 and _cover_left > 0.0)
	if wants_cover and not profile.hold_position:
		if _cover_point == Vector3.INF and _cover_search <= 0.0 and _director != null:
			_cover_search = 1.5
			_cover_point = _director.find_cover(global_position, _player.camera.global_position, 7.0, [get_rid(), _player.get_rid()])
		if _cover_point != Vector3.INF and _flat(global_position, _cover_point) > 0.6:
			_go(_cover_point, profile.run_speed)
		else:
			model.crouch = move_toward(model.crouch, 1.0, delta * 4.0)
			_face(target_position)
	else:
		_cover_point = Vector3.INF
		model.crouch = move_toward(model.crouch, 0.0, delta * 4.0)
		if _sees_player and dist <= profile.attack_range:
			aiming = true
			_face(target_position)
			if not profile.hold_position:
				if dist > profile.preferred_distance * 1.35:
					_go(target_position, profile.walk_speed * 1.3)
				elif dist < profile.preferred_distance * 0.45:
					var away := global_position + (global_position - target_position).normalized() * 3.0
					_go(away, profile.walk_speed)
				else:
					# Seitlich versetzen, damit er kein stehendes Ziel ist.
					if _strafe_timer <= 0.0 and _director != null:
						_strafe_timer = _rng.randf_range(2.0, 3.5)
						var side := global_basis.x * (1.0 if _rng.randf() < 0.5 else -1.0)
						_strafe_point = _director.snap(global_position + side * _rng.randf_range(1.5, 3.0))
					if _strafe_point != Vector3.INF and _flat(global_position, _strafe_point) > 0.5:
						_go(_strafe_point, profile.walk_speed * 0.8)
			_shoot_logic(delta)
		elif not profile.hold_position:
			_go(target_position, profile.run_speed * 0.85)
			if _sees_player:
				_face(target_position)
		else:
			_face(target_position)
	if not aiming:
		_aim_t = maxf(_aim_t - delta * 2.0, 0.0)
		_release_token()
	model.aim = move_toward(model.aim, 1.0 if aiming or _aim_t > 0.0 else 0.0, delta * 4.0)
	_update_laser(aiming)


func _shoot_logic(delta: float) -> void:
	if _reload_left > 0.0:
		return
	if not _has_token:
		_has_token = _director == null or _director.request_attack(self)
		if not _has_token:
			return
	_aim_t += delta
	if _aim_t < profile.aim_time or _cooldown > 0.0:
		return
	_fire()
	_burst_left -= 1
	_ammo -= 1
	_cooldown = profile.attack_interval
	if _ammo <= 0:
		_ammo = profile.magazine
		_reload_left = profile.reload_time
		_cover_point = Vector3.INF
		_cover_left = profile.reload_time
		_say(&"cover")
		_sfx.stream = SoundGen.RELOAD
		_sfx.pitch_scale = 0.9
		_sfx.play()
		_release_token()
		_aim_t = 0.0
		_burst_left = profile.burst
	elif _burst_left <= 0:
		_burst_left = profile.burst
		_cooldown = profile.burst_pause * _rng.randf_range(0.8, 1.3)
		_release_token()
		if health < profile.max_health * 0.4:
			_cover_left = 2.5
		# Scharfschütze: neu zielen (Laser) vor jedem Schuss.
		if profile.style == EnemyProfile.Style.RIFLE:
			_aim_t = 0.0


func _fire() -> void:
	var from := model.muzzle.global_position
	var eye := eye_position()
	var crouching := _player.movement != null and _player.movement.crouching
	var chest := _player.global_position + Vector3.UP * (0.6 if crouching else 1.05)
	var dist := eye.distance_to(chest)
	var chance := profile.accuracy * clampf(pow(10.0 / maxf(dist, 3.0), 0.6), 0.2, 1.4)
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if speed > 5.5:
		chance *= 0.55
	elif speed > 3.0:
		chance *= 0.8
	if crouching:
		chance *= 0.8
	if _player.stealth != null:
		chance *= lerpf(0.65, 1.0, _player.stealth.visibility)
	if model.flinch > 0.2:
		chance *= 0.5
	chance = clampf(chance, 0.03, 0.95)
	var end := chest
	if _line_to_player(eye, chest) and _rng.randf() < chance:
		_player.stats.damage(profile.damage, profile.death_cause)
	else:
		# Daneben: knapp vorbei, bis zur nächsten Wand.
		var miss := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 0.8), _rng.randf_range(-1, 1)).normalized()
		var aim_point := chest + miss * _rng.randf_range(0.5, 1.3)
		var far := from + (aim_point - from).normalized() * (dist + 30.0)
		var query := PhysicsRayQueryParameters3D.create(from, far, 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		end = hit.position if not hit.is_empty() else far
	_spawn_tracer(from, end)
	_flash_left = 0.06
	_muzzle_light.visible = true
	_muzzle_light.light_energy = 4.0
	_sfx.stream = SoundGen.RIFLE_SHOT if profile.style == EnemyProfile.Style.RIFLE else SoundGen.PISTOL_SHOT
	_sfx.pitch_scale = _rng.randf_range(0.85, 0.97)
	_sfx.play()
	StealthNoise.emit(get_tree(), global_position, 35.0, self, StealthNoise.SHOT)


func _update_muzzle_flash(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_muzzle_light.visible = false


func _update_laser(aiming: bool) -> void:
	if model.laser == null:
		return
	var on := aiming and _sees_player and _reload_left <= 0.0 and lod == Lod.FULL
	model.laser.visible = on
	if not on:
		return
	var from := model.muzzle.global_position
	var to := _player.global_position + Vector3.UP * 1.0
	# Laser zittert, bis er „steht“ (Zielzeit).
	var settle := clampf(_aim_t / profile.aim_time, 0.0, 1.0)
	to += Vector3(sin(_state_time * 7.0), cos(_state_time * 5.0), 0.0) * (1.0 - settle) * 0.6
	var length := from.distance_to(to)
	if length < 0.1:
		return
	model.laser.global_transform = Transform3D(Basis.looking_at(to - from), (from + to) * 0.5)
	model.laser.scale = Vector3(1, 1, length)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	if _tracer_mesh == null:
		_tracer_mesh = BoxMesh.new()
		_tracer_mesh.size = Vector3(0.025, 0.025, 1.0)
		_tracer_mat = StandardMaterial3D.new()
		_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_mat.albedo_color = Color(1.0, 0.85, 0.5)
		_tracer_mesh.material = _tracer_mat
	var length := from.distance_to(to)
	if length < 0.2:
		return
	var tracer := MeshInstance3D.new()
	tracer.mesh = _tracer_mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	holder.add_child(tracer)
	tracer.global_transform = Transform3D(Basis.looking_at(to - from), (from + to) * 0.5)
	tracer.scale = Vector3(1, 1, length)
	get_tree().create_timer(0.05, false).timeout.connect(tracer.queue_free)


func _release_token() -> void:
	if _has_token:
		_has_token = false
		if _director != null:
			_director.release_attack(self)


func _stun(time: float) -> void:
	_release_token()
	_attack_t = -1.0
	model.attack = 0.0
	model.aim = 0.0
	model.stunned = true
	_stun_left = time
	if model.laser != null:
		model.laser.visible = false
	_set_state(State.STUNNED)
	_update_flashlight()


func _die(push: Vector3) -> void:
	_release_token()
	_set_state(State.DEAD)
	awareness = 0.0
	remove_from_group(GROUP)
	remove_from_group(StealthNoise.GROUP)
	add_to_group(CORPSE_GROUP)
	collision_layer = 0
	collision_mask = 0
	_shape.set_deferred("disabled", true)
	_mark.visible = false
	_bark_label.visible = false
	_muzzle_light.visible = false
	model.stunned = false
	model.fall(push)
	_say(&"death", true)
	get_tree().create_timer(0.75, false).timeout.connect(func() -> void:
		if is_inside_tree():
			_steps.stream = SoundGen.thud()
			_steps.volume_db = 0.0
			_steps.play())
	_drop_loot()
	died.emit(self)


func _drop_loot() -> void:
	var drops: Array = []
	if profile.credits_max > 0:
		drops.append([CREDCHIP, _rng.randi_range(profile.credits_min, profile.credits_max)])
	for i: int in profile.loot_items.size():
		var chance := profile.loot_chances[i] if i < profile.loot_chances.size() else 0.3
		if profile.loot_items[i] != null and _rng.randf() < chance:
			drops.append([profile.loot_items[i], 1])
	var parent := get_parent()
	for i: int in drops.size():
		var item: ItemData = drops[i][0]
		var count: int = drops[i][1]
		if count <= 0:
			continue
		var pickup: ItemPickup = PICKUP_SCENE.instantiate()
		pickup.item = item
		pickup.count = count
		parent.add_child(pickup)
		var angle := i * 2.39996 + _rng.randf()
		var spread := Vector3(cos(angle), 0.0, sin(angle))
		pickup.global_position = global_position + Vector3.UP * 0.9 + spread * 0.2
		pickup.throw(spread * 1.6 + Vector3.UP * 2.2, 0.6)


func _corpse_tick(delta: float) -> void:
	corpse_time -= delta
	if corpse_time > 0.0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(global_position) > 35.0:
		queue_free()
	else:
		corpse_time = 20.0


# --- Bewegung -----------------------------------------------------------------------------

## Läuft per Navmesh zu `target`.
func _go(target: Vector3, speed: float) -> void:
	var next := target
	if _director != null and _director.is_nav_ready:
		next = _next_path_point(target)
	var to := next - global_position
	to.y = 0.0
	if to.length() < 0.05:
		to = target - global_position
		to.y = 0.0
		if to.length() < 0.3:
			return
	var dir := to.normalized()
	# Erst laufen, wenn er ungefähr in die Richtung schaut (klobig, aber lesbar).
	var facing := (-global_basis.z).dot(dir)
	var k := clampf((facing + 0.3) / 1.0, 0.15, 1.0)
	_wish = dir * speed * k
	if not _face_set:
		_face_yaw_to(atan2(-dir.x, -dir.z))
		_face_set = false


## Nächster Wegpunkt auf dem Navmesh-Weg zu `target`. Der Weg wird neu geplant, wenn sich das Ziel
## bewegt (höchstens alle 0,3 s) oder er feststeckt. Ein Punkt gilt als erreicht, wenn er waagerecht
## nah ist und höchstens ein Stockwerk-Bruchteil darüber oder darunter liegt (Feuertreppen liegen
## übereinander, das Navmesh liegt etwas über dem Boden).
func _next_path_point(target: Vector3) -> Vector3:
	_path_age += get_physics_process_delta_time()
	var moved := target.distance_to(_path_target) if _path_target != Vector3.INF else INF
	if moved > 0.5 and (_path_age > 0.3 or moved > 3.0 or _path.is_empty()):
		var map := get_world_3d().navigation_map
		var goal := NavigationServer3D.map_get_closest_point(map, target)
		_path = NavigationServer3D.map_get_path(map, global_position, goal, true)
		_path_index = 0
		_path_target = target
		_path_age = 0.0
	while _path_index < _path.size():
		var p := _path[_path_index]
		if _flat(p, global_position) < 0.4 and absf(p.y - global_position.y) < 1.2:
			_path_index += 1
		else:
			break
	if _path_index < _path.size():
		return _path[_path_index]
	return target


## true, wenn er zu lange feststeckt: Ziel aufgeben.
func _give_up(limit: float) -> bool:
	return _stuck_time > limit


func _face(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() < 0.05:
		return
	_face_yaw_to(atan2(-to.x, -to.z))
	_face_set = true
	if model != null:
		var horizontal := Vector2(to.x, to.z).length()
		model.aim_pitch = clampf(atan2(to.y - 0.6, horizontal), -0.8, 0.8)


func _face_yaw_to(yaw: float) -> void:
	_face_yaw = yaw


func _move(delta: float) -> void:
	var wish := _wish
	# Abstand zu anderen Gegnern.
	if wish.length() > 0.1:
		for node: Node in get_tree().get_nodes_in_group(GROUP):
			if node == self:
				continue
			var other := node as Node3D
			var off := global_position - other.global_position
			off.y = 0.0
			var d := off.length()
			if d < 1.1 and d > 0.01:
				wish += off / d * (1.1 - d) * 2.0
	# Steckt er fest (meist ein anderer Gegner im Weg), seitlich ausweichen.
	if _stuck_time > 0.5 and wish.length() > 0.1:
		var side := Vector3(-wish.z, 0.0, wish.x).normalized() * (1.0 if int(_stuck_time / 1.5) % 2 == 0 else -1.0)
		wish += side * wish.length() * 0.8
	_hvel = _hvel.move_toward(wish, (14.0 if wish.length() > _hvel.length() else 18.0) * delta)
	# move_and_slide() rechnet immer mit einem Physik-Frame. Bei LOD LOW läuft _tick nur alle
	# 0,2 s, also muss die Geschwindigkeit für diesen einen Schritt hochskaliert werden, sonst
	# kommen entfernte Gegner nur mit 1/12 des Tempos voran und wirken eingefroren.
	var step_scale := maxf(delta / get_physics_process_delta_time(), 1.0)
	# Nie über eine Kante ohne Boden darunter.
	var probe := maxf(0.55, _hvel.length() * delta + 0.3)
	if _hvel.length() > 0.1 and not _ground_below(global_position + _hvel.normalized() * probe, 1.3):
		_hvel = Vector3.ZERO
	velocity = Vector3(_hvel.x, 0.0, _hvel.z) * step_scale
	move_and_slide()
	velocity = Vector3(_hvel.x, 0.0, _hvel.z)
	# Senkrecht: Bodenstrahl, Stufen bis 0,6 m hoch und runter weich.
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
	rotation.y = lerp_angle(rotation.y, _face_yaw, minf(delta * 7.0, 1.0))
	# Feststecken: will laufen, kommt aber kaum voran.
	var moved := _flat(global_position, _last_pos)
	_last_pos = global_position
	if _wish.length() > 0.5 and moved < _wish.length() * delta * 0.25:
		_stuck_time += delta
		_repath_left -= delta
		if _stuck_time > 0.8 and _repath_left <= 0.0:
			# Neu planen.
			_repath_left = 1.0
			_path_target = Vector3.INF
	else:
		_stuck_time = maxf(_stuck_time - delta * 0.5, 0.0)


func _ground_height() -> float:
	var from := global_position + Vector3.UP * 0.65
	var query := PhysicsRayQueryParameters3D.create(from, global_position + Vector3.DOWN * 1.2, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return NAN
	return hit.position.y


func _ground_below(point: Vector3, depth: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point + Vector3.DOWN * depth, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Aussehen und Ton ---------------------------------------------------------------------

func _animate(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	model.speed = speed
	if state != State.COMBAT and state != State.STUNNED:
		model.aim = move_toward(model.aim, 0.0, delta * 3.0)
		model.crouch = move_toward(model.crouch, 0.0, delta * 3.0)
		if model.laser != null:
			model.laser.visible = false
	model.animate(delta)
	# Schritte.
	if speed > 0.4 and lod == Lod.FULL:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.62 if speed < 2.5 else 0.36
			_steps.stream = SoundGen.step()
			_steps.pitch_scale = _rng.randf_range(0.8, 0.95)
			_steps.volume_db = -14.0 if speed < 2.5 else -6.0
			_steps.play()
	if _mark.visible:
		_mark.position.y = 2.3 + sin(Time.get_ticks_msec() * 0.006) * 0.05


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	if state == State.DEAD:
		return
	state = new_state
	_state_time = 0.0
	_stuck_time = 0.0
	_arrived = false
	if new_state != State.COMBAT:
		model.attack = 0.0
		_attack_t = -1.0
	_apply_state_look()
	if new_state == State.SUSPICIOUS:
		_say(&"suspicious")
	state_changed.emit(self, new_state)


func _apply_state_look() -> void:
	if model == null:
		return
	model.set_status_color(STATE_COLORS[state])
	match state:
		State.SUSPICIOUS, State.INVESTIGATE, State.SEARCH:
			_mark.text = "?"
			_mark.modulate = Color(1.0, 0.78, 0.2)
			_mark.visible = true
		State.COMBAT:
			_mark.text = "!"
			_mark.modulate = Color(1.0, 0.2, 0.3)
			_mark.visible = true
		State.STUNNED:
			_mark.text = "~"
			_mark.modulate = Color(0.65, 0.45, 1.0)
			_mark.visible = true
		_:
			_mark.visible = false
	_update_flashlight()


func _update_flashlight() -> void:
	if model == null or model.flashlight == null:
		return
	var on := _flashlight_allowed and state != State.STUNNED and state != State.DEAD
	model.flashlight.visible = on
	model.flashlight.light_energy = 3.2 if state == State.COMBAT else 2.4
	model.flashlight.light_color = (STATE_COLORS[state] as Color).lerp(Color.WHITE, 0.7)


func _flash() -> void:
	model.flash_white()
	get_tree().create_timer(0.08, false).timeout.connect(_apply_state_look)


## Ruf mit Funk-Stimme und Text über dem Kopf. force übergeht die Pause zwischen Rufen.
func _say(line: StringName, force := false) -> void:
	if _bark_cooldown > 0.0 and not force:
		return
	_bark_cooldown = 2.5
	var variant := _rng.randi() % 3
	_voice.stream = SoundGen.voice(line, profile.voice_pitch, variant)
	_voice.pitch_scale = _rng.randf_range(0.95, 1.05)
	_voice.play()
	var texts: Array = BARKS.get(line, [])
	if texts.is_empty() or line == &"death":
		return
	_bark_label.text = texts[variant % texts.size()]
	_bark_label.visible = true
	var shown := _bark_label.text
	get_tree().create_timer(2.2, false).timeout.connect(func() -> void:
		if is_instance_valid(_bark_label) and _bark_label.text == shown:
			_bark_label.visible = false)
