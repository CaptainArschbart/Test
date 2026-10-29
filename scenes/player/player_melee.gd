class_name PlayerMelee
extends Node
## Unbewaffneter Nahkampf des Spielers: Boxen und aufgeladener Dash-Schlag.
##
## Boxen: "melee" (F, belegbar) oder "fire" (Linksklick), wenn nichts in der Hand ist. Jeder Druck
## schlägt sofort zu, die Fäuste wechseln sich ab (links, rechts, links …). Jeder dritte Schlag einer
## Kombo ist ein Haken mit mehr Schaden. Treffer: kurzer Hitstop, Kamerastoß, Rückstoß und Taumeln.
## Mit Waffe oder Item in der Hand geht nur "melee": die Waffe wird für den Schlag weggesteckt.
##
## Aufgeladener Angriff: Taste halten. Nach charge_delay zieht die rechte Faust zurück und lädt auf
## (Leuchten an der Faust, Balken unter dem Fadenkreuz, Ton). Loslassen ab charge_min: Dash in
## Blickrichtung (nur am Boden, nicht beim Klettern/Rutschen), am Ende ein schwerer Schlag mit
## Betäubung und kleiner Schockwelle. Der Dash bricht ab, sobald ein Gegner in Reichweite ist (Schlag
## sofort), an Wänden und vor Kanten ohne Boden. In der Luft gibt es den Schlag ohne Dash.
##
## Alle Werte stehen in MeleeTuning (melee_tuning.tres). Der Player legt diesen Knoten im Code an,
## nur für die lokal gesteuerte Figur (Player.melee), und ruft physics_step() für den Dash auf.
## Hitstop setzt kurz Engine.time_scale (nur lokal).

signal punched(side: int, target: Node)
signal power_struck(target: Node, charge: float)
signal dash_ended(reason: StringName, distance: float)

enum State { IDLE, JAB, CHARGE, DASH, POWER }

const DEFAULT_TUNING := preload("res://scenes/player/melee_tuning.tres")
const Sounds := preload("res://scenes/player/melee_sounds.gd")
const LAYER_WORLD := 1
## Dauer, die die Deckung nach dem letzten Schlag oben bleibt.
const GUARD_HOLD := 1.4
const GLOW_COLOR := Color(0.0, 1.0, 0.95)
const GLOW_FULL_COLOR := Color(1.0, 0.15, 0.75)

@export var tuning: MeleeTuning = DEFAULT_TUNING

var state: State = State.IDLE
## Ladung 0–1 während CHARGE (und die Ladung des letzten Powerschlags danach).
var charge := 0.0
## Für Prüfskripte: Grund und Weite des letzten Dashs, Ziel des letzten Schlags.
var last_dash_reason := &""
var last_dash_distance := 0.0
var last_target: Node

var _player: Player
var _t := 0.0
var _holding := false
var _held_action := &"melee"
var _hold_time := 0.0
## Faust des laufenden Schlags: 1 = rechts, -1 = links.
var _side := 1
var _combo := 0
var _since_jab := 99.0
var _hit_done := false
var _cooldown := 0.0
var _power_cooldown := 0.0
var _queued := &""
var _holster := false
var _guard := 0.0
var _idle_time := 99.0
var _fov := 0.0
var _hook := false
var _dash_dir := Vector3.FORWARD
var _dash_left := 0.0
var _dash_start := Vector3.ZERO
static var _hitstop_token := 0
var _audio: AudioStreamPlayer
var _charge_audio: AudioStreamPlayer
var _glow: MeshInstance3D
var _glow_light: OmniLight3D
var _glow_material: StandardMaterial3D
var _bar_root: Control
var _bar_fill: ColorRect


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_error("PlayerMelee gehört unter einen Player.")
		return
	_audio = _make_audio(-2.0)
	_charge_audio = _make_audio(-8.0)
	_create_hud()
	if not _player.is_node_ready():
		await _player.ready
	_create_glow()
	_player.stats.died.connect(cancel)


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or event.is_echo() or not _can_act():
		return
	if event.is_action_pressed("melee"):
		get_viewport().set_input_as_handled()
		press(&"melee")
	elif event.is_action_pressed("fire") and hands_free():
		get_viewport().set_input_as_handled()
		press(&"fire")


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_power_cooldown = maxf(_power_cooldown - delta, 0.0)
	_since_jab += delta
	_t += delta
	if _holding:
		_hold_time += delta
		if not Input.is_action_pressed(_held_action) or _player.dead or _player.noclip or _player.input_locked:
			_holding = false
			_on_release()
	if _queued != &"" and _cooldown <= 0.0 and (state == State.IDLE or state == State.JAB):
		var action := _queued
		_queued = &""
		press(action)
	match state:
		State.JAB:
			if not _hit_done and _t >= tuning.jab_hit_time:
				_hit_done = true
				_jab_hit()
			if _t >= tuning.jab_duration:
				state = State.IDLE
		State.CHARGE:
			charge = clampf((_hold_time - tuning.charge_delay) / maxf(tuning.charge_time, 0.01), 0.0, 1.0)
			if _charge_blocked():
				_stop_charge()
		State.POWER:
			if _t >= tuning.power_duration:
				state = State.IDLE
	# Halten nach dem Schlag geht ins Aufladen über.
	if _holding and _hold_time >= tuning.charge_delay and _power_cooldown <= 0.0 \
			and (state == State.IDLE or state == State.JAB and _hit_done) and not _charge_blocked():
		_start_charge()
	_update_idle(delta)


func _process(delta: float) -> void:
	if _player == null:
		return
	# Sichtfeld-Kick weich rein und raus (Echtzeit, damit der Hitstop ihn nicht einfriert).
	var real := delta / maxf(Engine.time_scale, 0.01)
	var target := tuning.dash_fov_kick if state == State.DASH else 0.0
	_fov = move_toward(_fov, target, (90.0 if target > _fov else 40.0) * real)
	_update_glow()


## Druck auf "melee" oder "fire" (öffentlich für Prüfskripte). Schlägt sofort zu.
func press(action: StringName = &"melee") -> void:
	if state == State.DASH or state == State.POWER or state == State.CHARGE:
		return
	if _cooldown > 0.0:
		# Kurz vor Ende der Pause gemerkt, damit schnelles Klicken im Rhythmus bleibt.
		if _cooldown <= 0.12:
			_queued = action
		return
	_holding = true
	_held_action = action
	_hold_time = 0.0
	if not hands_free():
		_holster = true
	_start_jab()


## Loslassen (öffentlich für Prüfskripte, sonst über Input).
func release() -> void:
	if _holding:
		_holding = false
		_on_release()


## Alles abbrechen (Tod, Respawn, Noclip).
func cancel() -> void:
	state = State.IDLE
	_holding = false
	_queued = &""
	charge = 0.0
	_holster = false
	_fov = 0.0
	_charge_audio.stop()
	_end_hitstop()


## Nichts in der Hand, das selbst auf "fire" reagiert (Schusswaffe, Granate, Klinge).
func hands_free() -> bool:
	if _player.weapon_holder != null and _player.weapon_holder.get_weapon() != null:
		return false
	if _player.item_user != null:
		var item := _player.item_user.get_held_item()
		if item is GrenadeData or item is MeleeData:
			return false
	return true


## Waffe oder Item ist für einen Schlag weggesteckt (WeaponHolder/ItemUser blenden sie aus).
func is_holstering() -> bool:
	return _holster


## Schläge, Aufladen oder Dash laufen gerade.
func is_busy() -> bool:
	return state != State.IDLE


func is_dashing() -> bool:
	return state == State.DASH


func is_charging() -> bool:
	return state == State.CHARGE


## Zuschlag aufs Sichtfeld in Grad (WeaponHolder rechnet ihn ein).
func get_fov_offset() -> float:
	return _fov


## Faktor auf die Laufgeschwindigkeit (Aufladen bremst).
func get_move_factor() -> float:
	return tuning.charge_move_factor if state == State.CHARGE else 1.0


func blocks_sprint() -> bool:
	return state == State.CHARGE or state == State.DASH


## Wie stark die Hände in der Box-Deckung sind (0–1).
func get_guard_weight() -> float:
	return _guard


## Ausstreckung einer Faust (side 1 = rechts, -1 = links), 0 = Deckung, 1 = ganz vorn.
func get_extension(side: int) -> float:
	if state == State.JAB and side == _side:
		return _punch_curve(_t, tuning.jab_hit_time, tuning.jab_duration)
	if state == State.POWER and side == 1:
		return _punch_curve(_t, 0.05, tuning.power_duration)
	return 0.0


## Wie weit die rechte Faust zum Aufladen zurückgezogen ist (0–1).
func get_windup() -> float:
	if state == State.CHARGE:
		return minf(0.35 + charge * 0.65, 1.0)
	if state == State.DASH or state == State.POWER and _t < 0.05:
		return 1.0
	return 0.0


func is_hook() -> bool:
	return _hook and state == State.JAB


func is_power() -> bool:
	return state == State.POWER


## Wird vom Player nach PlayerMovement aufgerufen. true = Bewegung dieses Frames ist erledigt.
func physics_step(delta: float) -> bool:
	if state != State.DASH:
		return false
	if not _can_dash():
		# Klettern, Rutschen oder Noclip hat übernommen: ohne Schlag abbrechen.
		_finish_dash(&"cancel", false)
		return false
	var target := _find_target(_player.global_position + Vector3.UP * 1.0, _dash_dir, tuning.dash_stop_reach, 0.55)
	if not target.is_empty():
		_finish_dash(&"enemy", true)
		return true
	var step := minf(tuning.dash_speed * delta, _dash_left)
	if not _ground_ahead(step):
		_finish_dash(&"edge", true)
		return true
	var start := _player.global_position
	_player.velocity = Vector3(_dash_dir.x * tuning.dash_speed, 0.0, _dash_dir.z * tuning.dash_speed)
	if not _player.is_on_floor():
		_player.velocity.y = -_player.gravity * 0.1
	if not _player._move_with_stairs(delta):
		_player.move_and_slide()
	var moved := Vector2(_player.global_position.x - start.x, _player.global_position.z - start.z).length()
	_dash_left -= moved
	if _hit_wall():
		_finish_dash(&"wall", true)
	elif moved < step * 0.3:
		_finish_dash(&"blocked", true)
	elif _dash_left <= 0.02:
		_finish_dash(&"distance", true)
	return true


# --- Boxen ---------------------------------------------------------------------------------

func _start_jab() -> void:
	_combo = _combo + 1 if _since_jab < tuning.combo_window else 1
	_since_jab = 0.0
	# Links beginnt (Jab), dann rechts (Cross), der dritte ist ein Haken.
	_side = -1 if _combo % 2 == 1 else 1
	_hook = _combo % 3 == 0
	state = State.JAB
	_t = 0.0
	_hit_done = false
	_cooldown = tuning.jab_interval
	_idle_time = 0.0
	_play(_audio, Sounds.whoosh(), randf_range(0.92, 1.12), -6.0)
	_player.hands.wake()


func _jab_hit() -> void:
	var camera := _player.camera
	var forward := -camera.global_basis.z
	var hit := _find_target(camera.global_position, forward, tuning.jab_reach, tuning.jab_radius)
	var factor := tuning.hook_multiplier if _hook else 1.0
	if hit.is_empty():
		var wall := _ray(camera.global_position, forward, tuning.jab_reach)
		if not wall.is_empty():
			_play(_audio, Sounds.wall_hit(), randf_range(0.9, 1.1), -4.0)
			_add_shake(tuning.jab_shake * 0.5)
			_spawn_impact(wall.position, wall.normal, 0.5, GLOW_COLOR)
		punched.emit(_side, null)
		return
	var target: Node = hit.node
	last_target = target
	var push := Vector3(forward.x, 0.0, forward.z).normalized() * tuning.jab_knockback * factor
	_apply_hit(target, tuning.jab_damage * factor, hit.position, hit.normal, push, 0.0)
	_play(_audio, Sounds.punch_hit(), randf_range(0.9, 1.08) * (0.85 if _hook else 1.0), 0.0)
	_add_shake(tuning.jab_shake * factor)
	_hitstop(tuning.jab_hitstop * factor)
	_spawn_impact(hit.position, hit.normal, 0.7 * factor, GLOW_COLOR)
	_make_noise(tuning.jab_noise)
	punched.emit(_side, target)


# --- Aufladen und Dash ---------------------------------------------------------------------

func _start_charge() -> void:
	state = State.CHARGE
	charge = 0.0
	_t = 0.0
	_idle_time = 0.0
	_play(_charge_audio, Sounds.charge(), 1.0, -8.0)


func _stop_charge() -> void:
	state = State.IDLE
	charge = 0.0
	_charge_audio.stop()


func _charge_blocked() -> bool:
	var movement := _player.movement
	if _player.noclip or _player.dead:
		return true
	return movement != null and (movement.is_mantling() or movement.is_sliding() or movement.get_grab_weight() > 0.0)


func _on_release() -> void:
	if state != State.CHARGE:
		return
	_charge_audio.stop()
	if charge < tuning.charge_min:
		_stop_charge()
		return
	_power_cooldown = tuning.power_cooldown
	if _can_dash():
		var flat := -_player.global_basis.z
		flat.y = 0.0
		_dash_dir = flat.normalized()
		var k := inverse_lerp(tuning.charge_min, 1.0, charge)
		_dash_left = lerpf(tuning.dash_min_distance, tuning.dash_distance, clampf(k, 0.0, 1.0))
		_dash_start = _player.global_position
		state = State.DASH
		_t = 0.0
		_play(_audio, Sounds.dash(), 1.0, -2.0)
		_add_shake(tuning.dash_shake)
		_make_noise(tuning.jab_noise)
	else:
		last_dash_reason = &"no_dash"
		last_dash_distance = 0.0
		_start_power()


func _can_dash() -> bool:
	if _player.noclip or _player.dead or not _player.is_on_floor():
		return false
	var movement := _player.movement
	return movement == null or not (movement.is_mantling() or movement.is_sliding() or movement.get_grab_weight() > 0.0)


func _finish_dash(reason: StringName, strike: bool) -> void:
	last_dash_reason = reason
	last_dash_distance = Vector2(_player.global_position.x - _dash_start.x, _player.global_position.z - _dash_start.z).length()
	# Etwas Schwung bleibt, aber nie über die Kante.
	var carry := 1.5 if reason == &"distance" else 0.0
	_player.velocity = Vector3(_dash_dir.x * carry, _player.velocity.y, _dash_dir.z * carry)
	dash_ended.emit(reason, last_dash_distance)
	if strike:
		_start_power()
	else:
		state = State.IDLE


func _start_power() -> void:
	state = State.POWER
	_t = 0.0
	_idle_time = 0.0
	var k := clampf(inverse_lerp(tuning.charge_min, 1.0, charge), 0.0, 1.0)
	var damage := tuning.power_damage * lerpf(0.5, 1.0, k)
	var camera := _player.camera
	var forward := -camera.global_basis.z
	var flat := Vector3(forward.x, 0.0, forward.z).normalized()
	var hit := _find_target(camera.global_position, forward, tuning.power_reach, tuning.power_radius)
	if hit.is_empty() and state == State.POWER and last_dash_reason == &"enemy":
		# Der Dash hat einen Gegner gemeldet: auf Körperhöhe nachsuchen (er kann tiefer stehen).
		hit = _find_target(_player.global_position + Vector3.UP, flat, tuning.power_reach, tuning.power_radius + 0.2)
	var center: Vector3 = camera.global_position + forward * tuning.power_reach * 0.7
	var target: Node = null
	if not hit.is_empty():
		target = hit.node
		last_target = target
		center = hit.position
		var push := flat * tuning.power_knockback * lerpf(0.6, 1.0, k) + Vector3.UP * 1.5
		_apply_hit(target, damage, hit.position, hit.normal, push, tuning.power_stun)
		_hitstop(tuning.power_hitstop)
		_add_shake(tuning.power_shake)
		_play(_audio, Sounds.power_hit(), randf_range(0.95, 1.05), 2.0)
	else:
		var wall := _ray(camera.global_position, forward, tuning.power_reach)
		if not wall.is_empty():
			center = wall.position
			_play(_audio, Sounds.power_hit(), 1.15, -3.0)
			_add_shake(tuning.power_shake * 0.6)
		else:
			_play(_audio, Sounds.whoosh(), 0.7, 0.0)
			_add_shake(tuning.power_shake * 0.3)
	_shockwave(center, target, damage)
	_spawn_impact(center, -forward, 1.6 if target != null else 1.0, GLOW_FULL_COLOR)
	_make_noise(tuning.power_noise)
	power_struck.emit(target, charge)


## Andere Gegner um den Einschlag: Teil des Schadens, weggestoßen, nicht betäubt.
func _shockwave(center: Vector3, primary: Node, damage: float) -> void:
	if tuning.shockwave_radius <= 0.0:
		return
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		if node == primary or not (node is Node3D) or not node.has_method("take_hit"):
			continue
		var body := node as Node3D
		var offset := body.global_position + Vector3.UP - center
		var distance := offset.length()
		if distance > tuning.shockwave_radius:
			continue
		var falloff := 1.0 - distance / tuning.shockwave_radius
		var flat := Vector3(offset.x, 0.0, offset.z)
		var push := (flat.normalized() if flat.length() > 0.01 else -_player.global_basis.z) \
			* tuning.shockwave_knockback * falloff
		_apply_hit(node, damage * tuning.shockwave_damage_factor * falloff, body.global_position + Vector3.UP,
			-push.normalized() if push.length() > 0.01 else Vector3.UP, push, 0.0)


# --- Treffer -------------------------------------------------------------------------------

func _apply_hit(target: Node, damage: float, point: Vector3, normal: Vector3, push: Vector3, stun: float) -> void:
	if target.has_method("melee_hit"):
		target.melee_hit(damage, point, normal, push, stun)
	elif target.has_method("take_hit"):
		target.take_hit(damage, point, normal)


## Sucht einen treffbaren Knoten (mit take_hit) vor `from` in Richtung `dir`: erst ein Strahl, dann
## Kugeln entlang der Strecke. Wände dazwischen blocken. Leer, wenn nichts da ist.
func _find_target(from: Vector3, dir: Vector3, reach: float, radius: float) -> Dictionary:
	var space := _player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [_player.get_rid()]
	var ray := _ray(from, dir, reach)
	if not ray.is_empty():
		var node := _hittable(ray.collider)
		if node != null:
			return {"node": node, "position": ray.position, "normal": ray.normal}
	var wall_distance := reach
	if not ray.is_empty():
		wall_distance = from.distance_to(ray.position)
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = LAYER_WORLD
	query.exclude = exclude
	var best: Dictionary = {}
	var best_distance := INF
	var steps := maxi(ceili(reach / (radius * 1.5)), 2)
	for i in range(1, steps + 1):
		var along := reach * float(i) / steps
		if along > wall_distance + radius:
			break
		query.transform = Transform3D(Basis.IDENTITY, from + dir * along)
		for result: Dictionary in space.intersect_shape(query, 8):
			var node := _hittable(result.collider)
			if node == null or not (node is Node3D):
				continue
			var center := (node as Node3D).global_position + Vector3.UP * 1.0
			var distance := from.distance_to(center)
			if distance < best_distance:
				best_distance = distance
				var point := from + dir * minf(along, distance)
				best = {"node": node, "position": point, "normal": -dir}
		if not best.is_empty():
			break
	return best


func _hittable(collider: Object) -> Node:
	var node := collider as Node
	while node != null and node != get_tree().current_scene:
		if node.has_method("take_hit"):
			return node
		node = node.get_parent()
	return null


func _ray(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach, LAYER_WORLD, [_player.get_rid()])
	return _player.get_world_3d().direct_space_state.intersect_ray(query)


## Boden vor dem Körper (Kante = tiefer als dash_edge_depth). Gegner zählen nicht als Boden.
func _ground_ahead(step: float) -> bool:
	var space := _player.get_world_3d().direct_space_state
	var feet := _player.global_position
	for reach: float in [step + 0.1, step + tuning.dash_edge_probe]:
		var from := feet + _dash_dir * reach + Vector3.UP * 0.6
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (0.6 + tuning.dash_edge_depth),
			LAYER_WORLD, [_player.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty() or _hittable(hit.collider) != null and hit.collider is CharacterBody3D:
			return false
	return true


## Wand in Dash-Richtung berührt (keine Stufe, kein Gegner).
func _hit_wall() -> bool:
	for i in _player.get_slide_collision_count():
		var collision := _player.get_slide_collision(i)
		var normal := collision.get_normal()
		if normal.angle_to(Vector3.UP) < deg_to_rad(50.0):
			continue
		if normal.dot(-_dash_dir) > 0.4:
			return true
	return false


# --- Effekte -------------------------------------------------------------------------------

## Spiel kurz fast anhalten (Echtzeit). Mehrere Treffer hintereinander verlängern nur.
func _hitstop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_hitstop_token += 1
	Engine.time_scale = 0.05
	_schedule_hitstop_end(get_tree(), seconds, _hitstop_token)


## Statisch, damit der Timer auch nach einem Szenenwechsel nicht an einem freigegebenen Knoten hängt.
static func _schedule_hitstop_end(tree: SceneTree, seconds: float, token: int) -> void:
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if token == _hitstop_token:
			Engine.time_scale = 1.0)


static func _end_hitstop() -> void:
	_hitstop_token += 1
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	if Engine.time_scale < 1.0:
		_end_hitstop()


func _add_shake(amount: float) -> void:
	if _player.camera_shake != null and amount > 0.0:
		_player.camera_shake.add_trauma(amount)


func _make_noise(radius: float) -> void:
	if _player.stealth != null:
		_player.stealth.make_noise(radius, StealthNoise.SHOUT)


## Kurzer Lichtblitz mit Ring am Einschlag.
func _spawn_impact(point: Vector3, normal: Vector3, size: float, color: Color) -> void:
	var root := Node3D.new()
	get_tree().current_scene.add_child(root)
	root.global_position = point + normal * 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08 * size
	sphere.height = 0.16 * size
	sphere.material = material
	flash.mesh = sphere
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flash)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.16 * size
	torus.outer_radius = 0.2 * size
	torus.material = material
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	if normal.length() > 0.01 and absf(normal.normalized().dot(Vector3.UP)) < 0.99:
		ring.look_at_from_position(root.global_position, root.global_position + normal, Vector3.UP)
		ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.5 * size
	light.omni_range = 2.0 * size
	root.add_child(light)
	var tween := root.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * (2.5 + size), 0.22)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.1, 0.18)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.22)
	tween.tween_property(light, "light_energy", 0.0, 0.2)
	tween.chain().tween_callback(root.queue_free)


func _create_glow() -> void:
	var fist := _player.hands.get_fist(1)
	if fist == null:
		return
	_glow_material = StandardMaterial3D.new()
	_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_material.albedo_color = GLOW_COLOR
	_glow = MeshInstance3D.new()
	_glow.name = "ChargeGlow"
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.material = _glow_material
	_glow.mesh = sphere
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.layers = 1 | PlayerHands.VIEWMODEL_LAYER
	_glow.position = Vector3(0.0, 0.01, -0.1)
	_glow.visible = false
	fist.add_child(_glow)
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = GLOW_COLOR
	_glow_light.omni_range = 1.2
	_glow_light.light_energy = 0.0
	_glow_light.position = _glow.position
	_glow_light.visible = false
	fist.add_child(_glow_light)


func _update_glow() -> void:
	var amount := 0.0
	if state == State.CHARGE:
		amount = charge
	elif state == State.DASH:
		amount = 1.0
	elif state == State.POWER:
		amount = maxf(1.0 - _t / maxf(tuning.power_duration, 0.01), 0.0)
	var full := state == State.CHARGE and charge >= 1.0 or state == State.DASH
	var color := GLOW_FULL_COLOR if full else GLOW_COLOR.lerp(GLOW_FULL_COLOR, charge * 0.5)
	if _glow != null:
		_glow.visible = amount > 0.01
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.025) * 0.12 * amount
		_glow.scale = Vector3.ONE * (0.5 + amount * 0.6) * pulse
		_glow_material.albedo_color = Color(color, 0.25 + amount * 0.45)
		_glow_light.visible = _glow.visible
		_glow_light.light_color = color
		_glow_light.light_energy = amount * 1.6
	_bar_root.visible = state == State.CHARGE
	if _bar_root.visible:
		_bar_fill.size.x = 160.0 * charge
		var armed := charge >= tuning.charge_min
		_bar_fill.color = GLOW_FULL_COLOR if charge >= 1.0 else (GLOW_COLOR if armed else Color(0.3, 0.5, 0.55))


func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MeleeHud"
	layer.layer = 2
	add_child(layer)
	_bar_root = Control.new()
	_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.anchor_left = 0.5
	_bar_root.anchor_right = 0.5
	_bar_root.anchor_top = 0.5
	_bar_root.anchor_bottom = 0.5
	_bar_root.offset_left = -80.0
	_bar_root.offset_top = 28.0
	_bar_root.visible = false
	layer.add_child(_bar_root)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.0, 0.1, 0.7)
	back.size = Vector2(160.0, 6.0)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.add_child(back)
	# Strich bei charge_min: ab hier löst Loslassen den Dash aus.
	var mark := ColorRect.new()
	mark.color = Color(1.0, 1.0, 1.0, 0.6)
	mark.size = Vector2(2.0, 10.0)
	mark.position = Vector2(160.0 * tuning.charge_min - 1.0, -2.0)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.add_child(mark)
	_bar_fill = ColorRect.new()
	_bar_fill.size = Vector2(0.0, 6.0)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.add_child(_bar_fill)


# --- Hilfen --------------------------------------------------------------------------------

## Deckung hochnehmen, solange gekämpft wird, danach langsam wieder runter.
func _update_idle(delta: float) -> void:
	if state != State.IDLE or _holding:
		_idle_time = 0.0
	else:
		_idle_time += delta
	var active := _idle_time < GUARD_HOLD
	_guard = move_toward(_guard, 1.0 if active else 0.0, delta * (10.0 if active else 3.0))
	if active:
		_player.hands.wake(0.3)
	# Waffe kommt zurück, sobald die Faust wieder in der Deckung ist.
	if _holster and state == State.IDLE and not _holding and _idle_time > 0.15:
		_holster = false


## 0 → 1 bis `hit`, danach zurück bis `duration` (schnell raus, etwas langsamer zurück).
static func _punch_curve(t: float, hit: float, duration: float) -> float:
	if t <= 0.0 or t >= duration:
		return 0.0
	if t < hit:
		var k := t / maxf(hit, 0.001)
		return 1.0 - (1.0 - k) * (1.0 - k)
	var back := (t - hit) / maxf(duration - hit, 0.001)
	return 1.0 - smoothstep(0.0, 1.0, back)


func _can_act() -> bool:
	return _player.controls_local_body() and not _player.input_locked and not _player.noclip \
			and not _player.dead and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused


func _make_audio(volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX"
	player.volume_db = volume
	add_child(player)
	return player


func _play(player: AudioStreamPlayer, stream: AudioStream, pitch: float, volume: float) -> void:
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.volume_db = volume
	player.play()
