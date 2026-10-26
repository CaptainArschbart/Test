class_name StealthGuard
extends CharacterBody3D
## Einfacher Test-Gegner fürs Schleichen: sieht und hört den Spieler.
##
## Sehen: Blickkegel (view_angle) bis view_distance, Sichtlinie zu Brust oder Kopf des Spielers.
## Wie schnell er den Spieler bemerkt, hängt an PlayerStealth.visibility (Licht, Hocken, Bewegung)
## und an der Entfernung. Der Wert `awareness` steigt dabei bis 1.
## Hören: Geräusche über StealthNoise (Schritte, Landungen, Schüsse …). Durch Wände nur gut halb so weit.
## Hören allein macht misstrauisch, aber nie ganz sicher.
##
## Zustände: PATROL (läuft patrol_points ab oder schaut sich um) → SUSPICIOUS ("?", dreht sich hin)
## → INVESTIGATE (geht zur Stelle, schaut sich um) → zurück. Bei awareness 1: ALERT ("!", rot),
## ruft andere Wachen in shout_radius, läuft zum Spieler und schlägt zu. Sieht er ihn
## lose_sight_time lang nicht, sucht er an der letzten Stelle (SEARCH).
## Treffer (take_hit) machen sofort ALERT. Bei 0 HP fällt er um (DOWN).
## Liegt auf Layer world, damit Waffen, Klinge und Granate ihn treffen.

enum State { PATROL, SUSPICIOUS, INVESTIGATE, ALERT, SEARCH, DOWN }

const STATE_COLORS := {
	State.PATROL: Color(0.0, 0.95, 1.0),
	State.SUSPICIOUS: Color(1.0, 0.78, 0.2),
	State.INVESTIGATE: Color(1.0, 0.78, 0.2),
	State.ALERT: Color(1.0, 0.16, 0.3),
	State.SEARCH: Color(1.0, 0.5, 0.15),
	State.DOWN: Color(0.15, 0.15, 0.2),
}

@export_group("Sehen")
@export var view_distance := 20.0
## Halber Öffnungswinkel des Blickkegels in Grad.
@export var view_angle := 55.0
## So nah merkt er auch hinter sich etwas, wenn man nicht hockt.
@export var close_sense := 1.8
## awareness pro Sekunde bei voller Sichtbarkeit aus mittlerer Entfernung.
@export var sight_gain := 1.4
@export var awareness_decay := 0.12
@export var lose_sight_time := 4.0

@export_group("Hören")
## Faktor auf den Radius jedes Geräuschs.
@export var hearing_scale := 1.0
## Andere Wachen in diesem Radius werden bei ALERT gerufen.
@export var shout_radius := 18.0

@export_group("Bewegung")
@export var walk_speed := 1.7
@export var run_speed := 4.2
@export var turn_speed := 5.0
## Punkte (lokal zum Elternknoten), die er abläuft. Leer = steht und schaut hin und her.
@export var patrol_points: PackedVector3Array = PackedVector3Array()
@export var patrol_wait := 2.5

@export_group("Kampf")
@export var max_health := 100.0
@export var attack_damage := 12.0
@export var attack_range := 1.7
@export var attack_interval := 1.2

var state: State = State.PATROL
var awareness := 0.0
var health := 100.0
## Letzte Stelle, an der er den Spieler gesehen oder etwas gehört hat.
var target_position := Vector3.ZERO

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _player: Player
var _state_time := 0.0
var _unseen_time := 0.0
var _patrol_index := 0
var _wait_left := 0.0
var _home_yaw := 0.0
var _home_position := Vector3.ZERO
var _attack_cooldown := 0.0
var _stuck_time := 0.0
var _anim_time := 0.0
var _sees_player := false

var _visor_material: StandardMaterial3D
var _flashlight: SpotLight3D
var _mark: Label3D
var _model: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []


func _ready() -> void:
	add_to_group(StealthNoise.GROUP)
	add_to_group("stealth_guard")
	collision_layer = 1
	collision_mask = 1 | 2
	health = max_health
	_home_yaw = rotation.y
	_home_position = global_position
	target_position = global_position
	_build()
	_apply_state_look()


func _physics_process(delta: float) -> void:
	if state == State.DOWN:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_state_time += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_update_sight(delta)
	_think(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	_animate(delta)
	if _player != null and _player.stealth != null and awareness > 0.01:
		var shown := 1.0 if state == State.ALERT else minf(awareness, 0.99)
		_player.stealth.report_awareness(self, shown)


# --- Wahrnehmung --------------------------------------------------------------------------

func eye_position() -> Vector3:
	return global_position + Vector3.UP * 1.62


## 0 = sieht den Spieler nicht, sonst wie deutlich (Entfernung × Sichtbarkeit).
func sight_of_player() -> float:
	if _player == null or _player.noclip or not _player.stats.is_alive():
		return 0.0
	var eye := eye_position()
	var chest := _player.global_position + Vector3.UP * 0.7
	var to_player := chest - eye
	var dist := to_player.length()
	if dist > view_distance:
		return 0.0
	var forward := -global_basis.z
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	var angle := rad_to_deg(forward.angle_to(flat)) if flat.length() > 0.01 else 0.0
	var crouching := _player.movement != null and _player.movement.crouching
	var in_cone := angle <= view_angle
	if not in_cone and not (dist < close_sense and not crouching):
		return 0.0
	if not _has_line_of_sight(eye, chest) and not _has_line_of_sight(eye, _player.camera.global_position):
		return 0.0
	var vis := _player.stealth.visibility if _player.stealth != null else 1.0
	var near := 1.0 - dist / view_distance
	# Rand des Blickfelds sieht schlechter.
	var edge := 1.0 - clampf((angle - view_angle * 0.5) / (view_angle * 0.5), 0.0, 0.6) if in_cone else 0.5
	var amount := vis * (0.25 + 1.5 * near * near) * edge
	if dist < 4.0:
		amount += 0.6 * vis
	return amount


func _has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _player


func _update_sight(delta: float) -> void:
	var seen := sight_of_player()
	_sees_player = seen > 0.0
	if _sees_player:
		_unseen_time = 0.0
		awareness = minf(awareness + sight_gain * seen * delta, 1.2)
		if awareness >= 0.35:
			target_position = _player.global_position
	else:
		_unseen_time += delta
		if state != State.ALERT:
			var hold := state == State.INVESTIGATE or state == State.SUSPICIOUS or state == State.SEARCH
			awareness = maxf(awareness - awareness_decay * (0.5 if hold else 1.0) * delta, 0.0)


## Von StealthNoise aufgerufen.
func hear_noise(position: Vector3, radius: float, source: Node, kind: StringName) -> void:
	if state == State.DOWN:
		return
	var effective := radius * hearing_scale
	var eye := eye_position()
	var dist := eye.distance_to(position)
	if dist > effective:
		return
	# Durch Wände gedämpft.
	var query := PhysicsRayQueryParameters3D.create(eye, position + Vector3.UP * 0.2, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider != source:
		effective *= 0.55
		if dist > effective:
			return
	var loudness := 1.0 - dist / effective
	if kind == StealthNoise.SHOUT:
		if state != State.ALERT:
			target_position = position
			awareness = maxf(awareness, 0.7)
			_set_state(State.SEARCH)
		return
	target_position = position
	if state == State.ALERT:
		return
	var gain := 0.25 + 0.45 * loudness
	if kind == StealthNoise.SHOT or kind == StealthNoise.EXPLOSION:
		gain += 0.4
	awareness = minf(maxf(awareness, 0.0) + gain, 0.95)
	if awareness >= 0.35 and state == State.PATROL:
		_set_state(State.SUSPICIOUS)
	elif state == State.INVESTIGATE or state == State.SEARCH:
		# Neues Geräusch: neues Ziel, von vorn anfangen.
		_state_time = 0.0


## Von Waffen, Klinge und Granate.
func take_hit(damage: float, _point: Vector3, _normal: Vector3) -> void:
	if state == State.DOWN:
		return
	health -= damage
	_flash_hit()
	if health <= 0.0:
		_go_down()
		return
	if _player != null:
		target_position = _player.global_position
	awareness = 1.0
	_set_state(State.ALERT)


# --- Verhalten ----------------------------------------------------------------------------

func _think(delta: float) -> void:
	if awareness >= 1.0 and state != State.ALERT:
		_set_state(State.ALERT)
		StealthNoise.emit(get_tree(), global_position, shout_radius, self, StealthNoise.SHOUT)
	match state:
		State.PATROL:
			if awareness >= 0.35:
				_set_state(State.SUSPICIOUS)
			else:
				_patrol(delta)
		State.SUSPICIOUS:
			_stop(delta)
			_turn_towards(target_position, delta)
			if _state_time > 1.4:
				_set_state(State.INVESTIGATE)
			elif awareness < 0.1:
				_set_state(State.PATROL)
		State.INVESTIGATE, State.SEARCH:
			_investigate(delta)
		State.ALERT:
			_alert(delta)


func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		# Wachposten: zurück zum Platz, dann langsam hin und her schauen.
		if _flat_distance(global_position, _home_position) > 0.6:
			_walk_to(_home_position, walk_speed, delta)
			return
		_stop(delta)
		var yaw := _home_yaw + sin(_state_time * 0.45) * deg_to_rad(40.0)
		rotation.y = lerp_angle(rotation.y, yaw, minf(turn_speed * 0.4 * delta, 1.0))
		return
	var parent := get_parent() as Node3D
	var point := patrol_points[_patrol_index % patrol_points.size()]
	var target := parent.to_global(point) if parent != null else point
	if _flat_distance(global_position, target) < 0.5:
		_stop(delta)
		_wait_left -= delta
		if _wait_left <= 0.0:
			_patrol_index = (_patrol_index + 1) % patrol_points.size()
			_wait_left = patrol_wait
		return
	_walk_to(target, walk_speed, delta)


func _investigate(delta: float) -> void:
	var speed := walk_speed * 1.4 if state == State.SEARCH else walk_speed * 1.15
	if _flat_distance(global_position, target_position) > 0.9 and _stuck_time < 1.5:
		_walk_to(target_position, speed, delta)
		return
	# Angekommen: umschauen.
	_stop(delta)
	rotation.y += sin(_state_time * 1.3) * delta * 1.4
	if awareness < 0.05 or _state_time > 12.0:
		awareness = 0.0
		_set_state(State.PATROL)


func _alert(delta: float) -> void:
	if _sees_player:
		target_position = _player.global_position
		var dist := _flat_distance(global_position, target_position)
		_turn_towards(target_position, delta)
		if dist > attack_range * 0.85:
			_walk_to(target_position, run_speed, delta)
		else:
			_stop(delta)
			if _attack_cooldown <= 0.0 and absf(target_position.y - global_position.y) < 1.4:
				_attack()
		return
	if _unseen_time > lose_sight_time:
		awareness = 0.75
		_set_state(State.SEARCH)
		return
	# Zur letzten bekannten Stelle rennen.
	if _flat_distance(global_position, target_position) > 0.8:
		_walk_to(target_position, run_speed, delta)
	else:
		_stop(delta)
		rotation.y += delta * 1.8


func _attack() -> void:
	_attack_cooldown = attack_interval
	_player.stats.damage(attack_damage)
	if _arms.size() > 1:
		var arm := _arms[1]
		var tween := create_tween()
		tween.tween_property(arm, "rotation:x", -1.5, 0.12)
		tween.tween_property(arm, "rotation:x", 0.0, 0.3)


func _walk_to(target: Vector3, speed: float, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.05:
		_stop(delta)
		return
	var dir := to.normalized()
	_turn_towards(target, delta)
	# Erst laufen, wenn er ungefähr in die Richtung schaut.
	var facing := (-global_basis.z).dot(dir)
	var k := clampf((facing + 0.2) / 1.2, 0.0, 1.0)
	var wanted := dir * speed * k
	velocity.x = move_toward(velocity.x, wanted.x, 12.0 * delta)
	velocity.z = move_toward(velocity.z, wanted.z, 12.0 * delta)
	if k > 0.6 and Vector2(get_real_velocity().x, get_real_velocity().z).length() < speed * 0.2:
		_stuck_time += delta
	else:
		_stuck_time = maxf(_stuck_time - delta, 0.0)


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)


func _turn_towards(target: Vector3, delta: float) -> void:
	var to := target - global_position
	if Vector2(to.x, to.z).length() < 0.05:
		return
	var yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, yaw, minf(turn_speed * delta, 1.0))


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_state_time = 0.0
	_stuck_time = 0.0
	_apply_state_look()


func _go_down() -> void:
	_set_state(State.DOWN)
	awareness = 0.0
	velocity = Vector3.ZERO
	remove_from_group(StealthNoise.GROUP)
	_mark.visible = false
	_flashlight.visible = false
	var tween := create_tween()
	tween.tween_property(_model, "rotation:x", -PI * 0.5, 0.45).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_model, "position:y", 0.25, 0.45)


# --- Aussehen -----------------------------------------------------------------------------

func _apply_state_look() -> void:
	if _visor_material == null:
		return
	var color: Color = STATE_COLORS[state]
	_visor_material.albedo_color = color
	_visor_material.emission = color
	_flashlight.light_color = color.lerp(Color.WHITE, 0.55)
	_flashlight.light_energy = 3.0 if state == State.ALERT else 2.0
	match state:
		State.SUSPICIOUS, State.INVESTIGATE, State.SEARCH:
			_mark.text = "?"
			_mark.modulate = Color(1.0, 0.78, 0.2)
			_mark.visible = true
		State.ALERT:
			_mark.text = "!"
			_mark.modulate = Color(1.0, 0.2, 0.3)
			_mark.visible = true
		_:
			_mark.visible = false


func _flash_hit() -> void:
	if _visor_material == null:
		return
	_visor_material.emission = Color.WHITE
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(_apply_state_look)


func _animate(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	_anim_time += delta * (2.0 + speed * 2.2)
	var swing := clampf(speed / run_speed, 0.0, 1.0) * 0.7
	for i in _legs.size():
		var sign := 1.0 if i == 0 else -1.0
		_legs[i].rotation.x = sin(_anim_time) * swing * sign
	if _arms.size() > 1 and _attack_cooldown < attack_interval - 0.45:
		_arms[0].rotation.x = -sin(_anim_time) * swing * 0.8
		_arms[1].rotation.x = sin(_anim_time) * swing * 0.8
	if _mark.visible:
		_mark.position.y = 2.25 + sin(Time.get_ticks_msec() * 0.006) * 0.05


func _build() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	var armor := StandardMaterial3D.new()
	armor.albedo_color = Color(0.24, 0.26, 0.32)
	armor.roughness = 0.55
	armor.metallic = 0.4
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.1, 0.1, 0.13)
	cloth.roughness = 0.9
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Color(1.0, 0.45, 0.1)
	stripe.emission_enabled = true
	stripe.emission = Color(1.0, 0.45, 0.1)
	stripe.emission_energy_multiplier = 1.5
	_visor_material = StandardMaterial3D.new()
	_visor_material.emission_enabled = true
	_visor_material.emission_energy_multiplier = 3.0

	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.13 * side, 0.92, 0.0)
		_model.add_child(hip)
		_part(hip, ProcMesh.rounded_box(Vector3(0.17, 0.5, 0.2), 0.4), cloth, Vector3(0, -0.25, 0))
		_part(hip, ProcMesh.rounded_box(Vector3(0.15, 0.42, 0.17), 0.4), cloth, Vector3(0, -0.66, 0))
		_part(hip, ProcMesh.rounded_box(Vector3(0.18, 0.12, 0.3), 0.3), armor, Vector3(0, -0.86, -0.04))
		_part(hip, ProcMesh.rounded_box(Vector3(0.12, 0.14, 0.06), 0.5), armor, Vector3(0, -0.46, -0.11))
		_legs.append(hip)
	_part(_model, ProcMesh.rounded_box(Vector3(0.44, 0.2, 0.26), 0.4), cloth, Vector3(0, 0.98, 0))
	_part(_model, ProcMesh.rounded_box(Vector3(0.5, 0.56, 0.3), 0.35), armor, Vector3(0, 1.32, 0))
	_part(_model, ProcMesh.rounded_box(Vector3(0.36, 0.3, 0.06), 0.3), armor, Vector3(0, 1.38, -0.16))
	# Bruststreifen in der Zustandsfarbe, damit man auf Distanz sieht, was die Wache denkt.
	_part(_model, ProcMesh.rounded_box(Vector3(0.3, 0.05, 0.02), 0.2), _visor_material, Vector3(0, 1.26, -0.195))
	for side: float in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.31 * side, 1.52, 0.0)
		_model.add_child(shoulder)
		_part(shoulder, ProcMesh.rounded_box(Vector3(0.2, 0.14, 0.26), 0.45), armor, Vector3(0.02 * side, 0.03, 0))
		_part(shoulder, ProcMesh.rounded_box(Vector3(0.12, 0.6, 0.13), 0.4), cloth, Vector3(0, -0.32, 0))
		_part(shoulder, ProcMesh.rounded_box(Vector3(0.13, 0.13, 0.14), 0.5), armor, Vector3(0, -0.66, 0))
		_arms.append(shoulder)
	_part(_model, ProcMesh.tube(0.08, 0.09, 0.1), cloth, Vector3(0, 1.64, 0))
	_part(_model, ProcMesh.rounded_box(Vector3(0.26, 0.28, 0.28), 0.55), armor, Vector3(0, 1.8, 0))
	_part(_model, ProcMesh.rounded_box(Vector3(0.24, 0.09, 0.05), 0.4), _visor_material, Vector3(0, 1.82, -0.13))
	# Antenne am Helm, damit man die Wache auf Distanz erkennt.
	_part(_model, ProcMesh.tube(0.008, 0.01, 0.3), stripe, Vector3(0.1, 2.0, 0.06))

	_flashlight = SpotLight3D.new()
	_flashlight.name = "Flashlight"
	_flashlight.position = Vector3(0.0, 1.78, -0.18)
	_flashlight.rotation.x = deg_to_rad(-12.0)
	_flashlight.spot_range = 13.0
	_flashlight.spot_angle = 30.0
	_flashlight.spot_attenuation = 0.8
	_flashlight.shadow_enabled = false
	add_child(_flashlight)

	_mark = Label3D.new()
	_mark.name = "Mark"
	_mark.position = Vector3(0.0, 2.25, 0.0)
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.no_depth_test = true
	_mark.font_size = 96
	_mark.pixel_size = 0.007
	_mark.outline_size = 18
	_mark.outline_modulate = Color(0.05, 0.0, 0.08)
	_mark.visible = false
	add_child(_mark)


func _part(parent: Node3D, mesh: Mesh, material: Material, offset: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	parent.add_child(instance)
	return instance
