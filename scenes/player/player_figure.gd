class_name PlayerFigure
extends EnemyModel
## Fremde Spielerfigur in der Außenansicht (Schedule 1, P5-7): eine Modular-Men-Figur mit Animationen
## aus der UalLibrary statt der Grundformen-Figur. PlayerBody legt sie bei fremden Figuren
## (external_drive) an, blendet die eigenen Teile aus und reicht jedes Bild Tempo, Boden, Hocken,
## Rutschen, Klettern, Blick, Zielen, Nachladen, Tod und das gehaltene Item durch (drive).
##
## Beine: UAL1 Idle, Walk, Jog_Fwd, Sprint, Crouch_Idle/Crouch_Fwd, Jump_Start/Jump/Jump_Land.
## Ohne Zielen dreht sich die Figur in die Laufrichtung; beim Zielen schaut sie in Blickrichtung und
## läuft seitlich bzw. rückwärts mit MM Run_Left/Run_Right/Run_Back.
## Oberkörper (AnimOverlay): Zielen mit Pistol_Aim_* nach Blickhöhe, Pistol_Shoot je Schuss,
## Pistol_Reload beim Nachladen. Schusswaffe in der rechten Hand wie bei den Gegnern.
## Klinge/Granate: Schlag bzw. Wurf mit MM Sword_Slash bzw. Punch_Right.
## Tod: Ragdoll (nah an der Kamera) bzw. UAL1 Death01; Wiederbeleben stellt die Figur sofort hin.

const DIR := "res://assets/characters/quaternius_modular_men/"
## Figuren für Spieler, nach Peer-Nummer gewählt.
const LOOKS := ["Punk", "Hoodie Character", "Swat", "Casual Character", "Business Man", "Worker"]
const HEIGHT := 1.78
const ANIM_PREFIX := "CharacterArmature|"
const BLEND := 0.2
## Tempo (m/s), bei dem die Animation in Originalgeschwindigkeit läuft (am Standfuß gemessen bzw.
## geschätzt; die Abspielgeschwindigkeit folgt dem Tempo, begrenzt).
const WALK_REF := 1.3
const JOG_REF := 3.6
const SPRINT_REF := 5.5
const CROUCH_REF := 1.2
const STRAFE_REF := 3.0
## Ab diesem Tempo joggt bzw. sprintet die Figur.
const JOG_FROM := 2.2
const SPRINT_FROM := 6.5
## So schnell dreht sich die Figur in die Laufrichtung (1/s).
const TURN_RATE := 8.0
## So lange spielt Jump_Land nach der Landung (s), ab so langer Luftzeit gilt es als Sprung.
const LAND_TIME := 0.3
const AIR_MIN := 0.15

## Weltgeschwindigkeit, Boden, Rutschen, Klettern (-1 = nein), Blick (Radiant), Nachladen (-1 = nein).
var velocity := Vector3.ZERO
var on_floor := true
var sliding := false
var climb := -1.0
var look_pitch := 0.0
var reload := -1.0
var look_name := ""

var _anim: AnimationPlayer
var _overlay: AnimOverlay
var _current := ""
var _air := 0.0
var _land_left := 0.0
var _action_left := 0.0
var _yaw := 0.0
var _holder: Node3D
var _held: Node3D
var _armed := false
var _flash: Node3D
var _flash_left := 0.0
var _was_reloading := false

static var _scenes := {}
static var _heights := {}


## Figur und UAL-Bibliothek im Hintergrund laden, damit ein neuer Mitspieler kein Ruckeln auslöst.
static func request_resources(peer: int) -> void:
	for path: String in _paths(peer):
		if not ResourceLoader.has_cached(path):
			ResourceLoader.load_threaded_request(path)


## true, wenn alles geladen ist (oder das Hintergrundladen nicht geht: dann lädt build_player direkt).
static func resources_ready(peer: int) -> bool:
	for path: String in _paths(peer):
		if ResourceLoader.has_cached(path):
			continue
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
	return true


static func _paths(peer: int) -> Array[String]:
	return [DIR + LOOKS[posmod(peer, LOOKS.size())] + ".glb", UalLibrary.PATH]


## Figur nach Peer-Nummer bauen.
func build_player(peer: int) -> void:
	look_name = LOOKS[posmod(peer, LOOKS.size())]
	var scene: PackedScene = _scenes.get(look_name)
	if scene == null:
		scene = load(DIR + look_name + ".glb")
		_scenes[look_name] = scene
	var body: Node3D = scene.instantiate()
	body.name = "Character"
	# Die Figuren schauen nach +Z, der Spieler nach -Z.
	body.rotation.y = PI
	body.scale = Vector3.ONE * (HEIGHT / _height(look_name, body))
	add_child(body)
	ragdoll_skeleton = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_anim = body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	UalLibrary.attach(_anim)
	for name in ["Run_Back", "Run_Left", "Run_Right"]:
		var a := _anim.get_animation(ANIM_PREFIX + name)
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR
	_overlay = AnimOverlay.attach(ragdoll_skeleton, _anim)
	_holder = _bone_holder(ragdoll_skeleton, "Wrist.R")
	_play("ual/Idle", 0.0)


## Gehaltenes Item: Schusswaffe (Modell in der Hand, Zielen), Klinge oder Granate (Leuchtstab bzw.
## Kugel), sonst leere Hände.
func set_held(item: ItemData, held_mesh: Node3D = null) -> void:
	if _held != null:
		_held.queue_free()
		_held = null
	_flash = null
	_armed = false
	var weapon := item as WeaponData
	if weapon != null and weapon.view_scene != null:
		var view: Node3D = weapon.view_scene.instantiate()
		var grip := view.get_node_or_null("HandGripRight") as Node3D
		var grip_pos := grip.position if grip != null else Vector3(0.0, -0.035, 0.0)
		var mount := Node3D.new()
		mount.transform = Transform3D(EnemyCharacterModel.GRIP_BASIS, Vector3(0.0, EnemyCharacterModel.GRIP_OFFSET, 0.0))
		view.position = -grip_pos
		mount.add_child(view)
		_held = mount
		_flash = view.get_node_or_null("Muzzle/Flash")
		_set_flash(false)
		_armed = true
	elif held_mesh != null:
		var mount := Node3D.new()
		mount.position = Vector3(0.0, 0.08, 0.0)
		mount.add_child(held_mesh)
		_held = mount
	if _held != null and _holder != null:
		_holder.add_child(_held)


## Schuss: Rückstoß des Oberkörpers und kurz Mündungsfeuer.
func trigger_fire() -> void:
	if _dead:
		return
	if _armed:
		_overlay.play_action(AnimOverlay.SHOOT, 0.3)
	_set_flash(true)
	_flash_left = 0.06


## Schlag mit der Klinge bzw. Wurf.
func trigger_action() -> void:
	if _dead or _anim == null:
		return
	_action_left = 0.6
	_current = ""
	_play(ANIM_PREFIX + ("Sword_Slash" if _held != null and not _armed else "Punch_Right"), 0.08)


## Tod bzw. Wiederbeleben.
func set_dead(on: bool, push := Vector3.ZERO) -> void:
	if on == _dead:
		return
	if on:
		_dead = true
		_overlay.stop()
		if _held != null:
			_held.visible = false
		if not _ragdoll_fall(push if push.length() > 0.01 else global_basis.z):
			_current = ""
			_play("ual/Death01", 0.1)
		return
	_dead = false
	_reset_rise()
	if ragdoll != null and ragdoll.running:
		ragdoll.blend_out(0.01)
	if _held != null:
		_held.visible = true
	rotation.y = 0.0
	_yaw = 0.0
	_current = ""
	_play("ual/Idle", 0.0)


## Jedes Bild von PlayerBody.animate_remote.
func drive(delta: float) -> void:
	if _anim == null:
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_flash(false)
	if _dead:
		if ragdoll == null or not ragdoll.running:
			_anim.advance(delta)
		return
	var local := get_parent_node_3d().global_basis.orthonormalized().inverse() * velocity if get_parent_node_3d() != null else velocity
	# x = rechts, y = vorwärts (Figur schaut nach -Z).
	var planar := Vector2(local.x, -local.z)
	var speed := planar.length()
	var aiming := aim > 0.5 and _armed
	_overlay.aim_weight = move_toward(_overlay.aim_weight, aim if _armed and _action_left <= 0.0 else 0.0, delta * 6.0)
	_overlay.aim_pitch = look_pitch
	# Nachladen: einmal Pistol_Reload, so lang wie das Nachladen dauert (Fortschritt kommt übers Netz).
	var reloading := reload >= 0.0 and _armed
	if reloading and not _was_reloading:
		_overlay.play_action(AnimOverlay.RELOAD, maxf((1.0 - reload) * 1.6, 0.4))
	_was_reloading = reloading
	# Luft und Landung.
	if on_floor:
		if _air > AIR_MIN:
			_land_left = LAND_TIME
		_air = 0.0
	else:
		_air += delta
	_land_left = maxf(_land_left - delta, 0.0)
	_action_left = maxf(_action_left - delta, 0.0)
	# Richtung: ohne Zielen in Laufrichtung drehen, beim Zielen in Blickrichtung bleiben.
	var target_yaw := 0.0
	if not aiming and speed > 0.5 and climb < 0.0:
		target_yaw = -atan2(planar.x, planar.y)
	_yaw = lerp_angle(_yaw, target_yaw, minf(delta * TURN_RATE, 1.0))
	rotation.y = _yaw
	if _action_left <= 0.0:
		_choose_legs(planar, speed, aiming)
	_anim.advance(delta)


func _choose_legs(planar: Vector2, speed: float, aiming: bool) -> void:
	_anim.speed_scale = 1.0
	if climb >= 0.0 or (not on_floor and _air > AIR_MIN):
		_play("ual/Jump", 0.15)
		return
	if _land_left > 0.0:
		_play("ual/Jump_Land", 0.08)
		return
	if sliding:
		_play("ual/Crouch_Idle", 0.1)
		return
	if crouch > 0.5:
		if speed < 0.3:
			_play("ual/Crouch_Idle")
		else:
			_play("ual/Crouch_Fwd")
			_anim.speed_scale = clampf(speed / CROUCH_REF, 0.6, 2.0)
		return
	if speed < 0.4:
		_play("ual/Idle")
		return
	if aiming:
		# Blick bleibt vorn: seitlich und rückwärts eigene Laufbilder.
		var dir := planar / speed
		if dir.y < -0.5:
			_play(ANIM_PREFIX + "Run_Back")
			_anim.speed_scale = clampf(speed / STRAFE_REF, 0.6, 1.8)
			return
		if absf(dir.x) > 0.6:
			_play(ANIM_PREFIX + ("Run_Right" if dir.x > 0.0 else "Run_Left"))
			_anim.speed_scale = clampf(speed / STRAFE_REF, 0.6, 1.8)
			return
	if speed < JOG_FROM:
		_play("ual/Walk")
		_anim.speed_scale = clampf(speed / WALK_REF, 0.6, 1.8)
	elif speed < SPRINT_FROM:
		_play("ual/Jog_Fwd")
		_anim.speed_scale = clampf(speed / JOG_REF, 0.7, 1.6)
	else:
		_play("ual/Sprint")
		_anim.speed_scale = clampf(speed / SPRINT_REF, 0.8, 1.6)


func _play(name: String, blend := BLEND) -> void:
	if _current == name or _anim == null or not _anim.has_animation(name):
		return
	_current = name
	_anim.play(name, blend)


func _set_flash(on: bool) -> void:
	if _flash != null:
		_flash.visible = on


static func _height(name: String, body: Node3D) -> float:
	if not _heights.has(name):
		var top := 0.0
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D()
			var n: Node = mi
			while n != body and n != null:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var b: AABB = xf * (mi as MeshInstance3D).get_aabb()
			top = maxf(top, b.end.y)
		_heights[name] = top if top > 0.1 else HEIGHT
	return _heights[name]
