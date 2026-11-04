class_name CharacterModel
extends CivilianModel
## Fußgänger und Verkäufer als Quaternius-Figur (assets/characters/quaternius_modular_men/) mit
## deren eigenen Animationen statt der Klötzchenfigur. Gleiche Schnittstelle wie CivilianModel
## (speed, cower, crouch, flinch, aim, animate, fall, get_up), Civilian und ShopInterior merken
## keinen Unterschied.
##
## Die Animation läuft nur in animate() (AnimationPlayer im manuellen Modus): Fußgänger, die der
## CrowdDirector weit weg schlafen legt, kosten nichts. Idle, Walk und Run folgen dem Tempo, die
## Abspielgeschwindigkeit passt sich an, damit die Füße nicht rutschen.
##
## Umgeworfen (Auto) und wieder auf: Ragdoll, dann UAL2 LayToIdle aus der Bibliothek "ual" (UalLibrary).
## Liegt die Figur auf dem Bauch, dreht der Ragdoll sie erst auf den Rücken.
##
## Alltag (Schedule 1, P5-8), Animationen aus der UalLibrary:
##   - Gewohnheit (set_habit): telefonieren (UAL2 Idle_TalkingPhone mit Handy am Ohr) oder eine Kiste
##     tragen (Walk_Carry), als Oberkörper-Ebene (AnimOverlay) über Stehen und Gehen.
##   - talk: im Stehen mit jemandem reden (UAL1 Idle_Talking).
##   - sit(true/false): hinsetzen (Sitting_Enter, dann Sitting_Idle bzw. Sitting_Talking) und
##     aufstehen (Sitting_Exit). sit_offset() sagt, wo das Becken beim Sitzen relativ zur Figur liegt.
## Frauen (P5-9): zwei Figuren aus dem City Pack (Quaternius, CC0), gleiches Skelett wie Modular
## Men, mit eigener UAL-Bibliothek (andere Proportionen).

const DIR := "res://assets/characters/quaternius_modular_men/"
## König und Astronaut passen nicht auf die Straße. Einträge mit Pfad sind Frauenfiguren (je zweimal,
## damit etwa ein Drittel der Fußgänger Frauen sind).
const LOOKS := ["Adventurer", "Beach Character", "Business Man", "Casual Character", "Farmer",
	"Hoodie Character", "Punk", "Swat", "Worker",
	"res://assets/props/city_pack/Animated Woman-nIItLV9nxS.glb",
	"res://assets/props/city_pack/Animated Woman-qJ2gsTUBHL.glb",
	"res://assets/props/city_pack/Animated Woman-nIItLV9nxS.glb",
	"res://assets/props/city_pack/Animated Woman-qJ2gsTUBHL.glb"]
const HEIGHT := 1.75
## Frauen etwas kleiner.
const WOMAN_HEIGHT := 1.68
## Gewohnheiten (Civilian.habit).
enum Habit { NONE, PHONE, CARRY }
const PHONE_POSE := "ual/Idle_TalkingPhone"
const CARRY_POSE := "ual/Walk_Carry"
const TALK := "ual/Idle_Talking"
const SIT_ENTER := "ual/Sitting_Enter"
const SIT_IDLE := "ual/Sitting_Idle"
const SIT_TALK := "ual/Sitting_Talking"
const SIT_EXIT := "ual/Sitting_Exit"
## In Sitting_Idle liegt das Gesäß so weit unter dem Knochen Hips (an der Haut gemessen, Maße der Figur
## vor dem Skalieren): Männer 0,037, Frauen 0,122.
const SIT_DEPTH_MAN := 0.037
const SIT_DEPTH_WOMAN := 0.122
## Tempo (m/s), bei dem Walk bzw. Run in Originalgeschwindigkeit läuft.
const WALK_SPEED := 1.4
const RUN_SPEED := 4.0
const BLEND := 0.2
const ANIM_PREFIX := "CharacterArmature|"
## Welche Figur (Name aus LOOKS), leer = per Seed.
var look := ""
## Im Stehen mit jemandem reden (setzt Civilian).
var talk := false
## Beim Sitzen reden statt still sitzen.
var sit_talk := false

var _habit: Habit = Habit.NONE
var _overlay: AnimOverlay
var _prop: Node3D
## Sitzen: 0 nein, 1 setzt sich, 2 sitzt, 3 steht auf; Restzeit der Ein- bzw. Ausstiegsanimation.
var _seat_phase := 0
var _seat_left := 0.0

var _anim: AnimationPlayer
var _current := ""
var _hit_left := 0.0

static var _scenes := {}
static var _heights := {}


func build_civilian(variant_seed: int) -> void:
	_rng.seed = variant_seed
	if look == "":
		look = LOOKS[_rng.randi() % LOOKS.size()]
	var scene := _scene(look)
	if scene == null:
		# Fallback: die alte Figur, falls das Modell fehlt.
		super.build_civilian(variant_seed)
		return
	var body: Node3D = scene.instantiate()
	body.name = "Character"
	# Die Figuren schauen nach +Z, Fußgänger nach -Z (wie EnemyModel).
	body.rotation.y = PI
	body.scale = Vector3.ONE * ((WOMAN_HEIGHT if is_woman() else HEIGHT) / _height(look, body))
	add_child(body)
	for mi in body.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).visibility_range_end = 90.0
	var skeletons := body.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		ragdoll_skeleton = skeletons[0] as Skeleton3D
	var players := body.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_anim = players[0] as AnimationPlayer
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		UalLibrary.attach(_anim, is_woman())
		for name: String in ["Idle", "Walk", "Run", "Idle_Neutral", "Idle_Gun_Pointing"]:
			var a := _anim.get_animation(ANIM_PREFIX + name)
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR
		# Jede Figur beginnt an einer anderen Stelle, sonst laufen alle im Gleichschritt.
		_play("Idle", 0.0)
		_anim.advance(_rng.randf() * 2.0)


func is_woman() -> bool:
	return look.begins_with("res://")


func animate(delta: float) -> void:
	if _anim == null:
		super.animate(delta)
		return
	flinch = maxf(flinch - delta * 3.5, 0.0)
	_hit_left = maxf(_hit_left - delta, 0.0)
	_rise_step(delta, _anim)
	if _overlay != null:
		# Gewohnheit nur im ruhigen Alltag: nicht auf der Flucht, geduckt, sitzend oder am Boden.
		var calm := not _dead and _seat_phase == 0 and cower < 0.3 and crouch < 0.3 and aim < 0.3 \
			and speed < 3.0 and _hit_left <= 0.0
		_overlay.pose_weight = move_toward(_overlay.pose_weight, 1.0 if calm else 0.0, delta * 4.0)
		if _prop != null:
			_prop.visible = _overlay.pose_weight > 0.5
	if not _dead and _seat_phase != 0:
		_seat_step(delta)
	elif not _dead:
		if flinch > HIT_FLINCH and _hit_left <= 0.0:
			var reaction := _hit_reaction(_anim)
			_hit_left = _anim.get_animation(reaction).length if reaction.begins_with(UalLibrary.NAME + "/") else 0.5
			_current = ""
			_anim.speed_scale = 1.0
			_play(reaction, 0.05)
		elif _hit_left <= 0.0:
			_choose_loop()
	_anim.advance(delta)


func _choose_loop() -> void:
	if cower > 0.5 or crouch > 0.5:
		_play("Idle_Neutral")
		_anim.speed_scale = 0.4
	elif aim > 0.5:
		_play("Idle_Gun_Pointing")
		_anim.speed_scale = 1.0
	elif speed < 0.25 and talk and _habit == Habit.NONE and _anim.has_animation(TALK):
		_play(TALK)
		_anim.speed_scale = 1.0
	elif speed < 0.25:
		_play("Idle")
		_anim.speed_scale = 1.0
	elif speed < (WALK_SPEED + RUN_SPEED) * 0.5:
		_play("Walk")
		_anim.speed_scale = clampf(speed / WALK_SPEED, 0.6, 1.8)
	else:
		_play("Run")
		_anim.speed_scale = clampf(speed / RUN_SPEED, 0.7, 1.6)


## Tod bzw. vom Auto umgeworfen: nah an der Kamera als Ragdoll, sonst endet die Todesanimation liegend.
func fall(direction: Vector3) -> void:
	if _anim == null:
		super.fall(direction)
		return
	_dead = true
	_reset_rise()
	_seat_phase = 0
	# Nah an der Kamera: Ragdoll, weit weg: Todesanimation.
	if _ragdoll_fall(direction):
		return
	# In Fallrichtung drehen (Welt, waagerecht), dann umfallen.
	var local := global_basis.inverse() * direction
	local.y = 0.0
	if local.length() > 0.01:
		rotation.y += atan2(-local.x, -local.z)
	_anim.speed_scale = 1.0
	_play("Death", 0.05)


func get_up(time := 0.9) -> void:
	if _anim == null:
		super.get_up(time)
		return
	# Steht schon auf oder wartet darauf.
	if is_rising():
		return
	if ragdoll != null and ragdoll.running:
		_rise(_anim, false)
		return
	# Todesanimation (weit weg): zurück zu Idle blenden.
	rotation.y = 0.0
	_play("Idle", 0.3)
	_rise_left = time


## Gewohnheit (Civilian, aus dem Seed): Handy am Ohr oder Kiste in den Händen, als Oberkörper-Ebene.
func set_habit(habit: int) -> void:
	if _anim == null or ragdoll_skeleton == null or habit == Habit.NONE or _overlay != null:
		return
	var pose := PHONE_POSE if habit == Habit.PHONE else CARRY_POSE
	if not _anim.has_animation(pose):
		return
	_habit = habit as Habit
	_overlay = AnimOverlay.attach(ragdoll_skeleton, _anim)
	_overlay.pose_name = pose
	_prop = _make_prop(pose)


## Wo das Becken beim Sitzen liegt, im Raum der Figur darüber (CharacterBody3D): x/z waagerecht
## (Knochen Hips), y Höhe der Gesäß-Unterseite über den Füßen. Spielt dafür kurz Bild 0 von Sitting_Idle.
func sit_offset() -> Vector3:
	if _anim == null or ragdoll_skeleton == null or not _anim.has_animation(SIT_IDLE):
		return Vector3.INF
	var host := _host_body()
	if host == null:
		return Vector3.INF
	var keep := _anim.current_animation
	var keep_pos := _anim.current_animation_position if keep != "" else 0.0
	var sk := ragdoll_skeleton
	rotation.y = 0.0
	_anim.play(SIT_IDLE, 0.0)
	_anim.seek(0.0, true)
	var hips := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin
	# Gesäß unter dem Beckenknochen (an der Haut gemessen, in Maßen der Figur vor dem Skalieren).
	var character := get_node_or_null("Character") as Node3D
	var scale_now := character.global_basis.get_scale().x if character != null else 1.0
	hips.y -= (SIT_DEPTH_WOMAN if is_woman() else SIT_DEPTH_MAN) * scale_now
	var offset := host.global_transform.affine_inverse() * hips
	if keep != "":
		_anim.play(keep, 0.0)
		_anim.seek(keep_pos, true)
	return offset


## Hinsetzen (die Figur steht dann schon richtig, siehe Civilian) bzw. aufstehen.
func sit(on: bool) -> void:
	if _anim == null or _dead:
		return
	if on:
		if _seat_phase != 0:
			return
		_seat_phase = 1
		_seat_left = _anim.get_animation(SIT_ENTER).length if _anim.has_animation(SIT_ENTER) else 0.0
		_current = ""
		_anim.speed_scale = 1.0
		_play(SIT_ENTER, 0.25)
	elif _seat_phase == 1 or _seat_phase == 2:
		_seat_phase = 3
		_seat_left = _anim.get_animation(SIT_EXIT).length if _anim.has_animation(SIT_EXIT) else 0.0
		_current = ""
		_anim.speed_scale = 1.0
		_play(SIT_EXIT, 0.2)


func is_seated() -> bool:
	return _seat_phase == 1 or _seat_phase == 2


func _seat_step(delta: float) -> void:
	if _seat_phase == 2:
		_play(SIT_TALK if sit_talk else SIT_IDLE, 0.3)
		return
	_seat_left -= delta
	if _seat_left > 0.0:
		return
	if _seat_phase == 1:
		_seat_phase = 2
	else:
		_seat_phase = 0


## Handy bzw. Kiste an der Hand, die in der Haltung dafür zuständig ist (gemessen in der Haltungs-
## Animation: Handy bei 40 % der Länge, Kiste in Bild 0).
func _make_prop(pose: String) -> Node3D:
	var sk := ragdoll_skeleton
	var keep := _anim.current_animation
	_anim.play(pose, 0.0)
	_anim.seek(_anim.get_animation(pose).length * (0.4 if pose == PHONE_POSE else 0.0), true)
	var world := func(bone: String) -> Transform3D:
		return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone))
	var left: Transform3D = world.call("Wrist.L")
	var right: Transform3D = world.call("Wrist.R")
	var head: Transform3D = world.call("Head")
	var prop := MeshInstance3D.new()
	var box := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	var hand := "Wrist.R"
	var place: Transform3D
	if pose == PHONE_POSE:
		# Hand am Ohr: die, die näher am Kopf ist. Handy zwischen Handgelenk und Kopf, hochkant.
		var use_left := left.origin.distance_to(head.origin) < right.origin.distance_to(head.origin)
		hand = "Wrist.L" if use_left else "Wrist.R"
		var wrist: Transform3D = left if use_left else right
		box.size = Vector3(0.07, 0.15, 0.012)
		mat.albedo_color = Color(0.05, 0.05, 0.08)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.7, 1.0)
		mat.emission_energy_multiplier = 0.6
		var center := wrist.origin.lerp(head.origin, 0.35)
		var up := (head.origin - wrist.origin).normalized()
		var side := up.cross(Vector3.UP)
		side = side.normalized() if side.length() > 0.1 else Vector3.RIGHT
		place = Transform3D(Basis(side, up, side.cross(up)), center)
	else:
		# Kiste zwischen den Händen, so breit wie der Abstand der Hände.
		var width := clampf(left.origin.distance_to(right.origin) - 0.04, 0.28, 0.55)
		box.size = Vector3(width, 0.28, 0.32)
		mat.albedo_color = Color(0.55, 0.4, 0.25)
		var center := (left.origin + right.origin) * 0.5 + Vector3.UP * 0.05
		var across := left.origin - right.origin
		across.y = 0.0
		across = across.normalized() if across.length() > 0.01 else Vector3.RIGHT
		place = Transform3D(Basis(across, Vector3.UP, across.cross(Vector3.UP)), center)
	box.material = mat
	prop.mesh = box
	prop.visibility_range_end = 40.0
	var holder := _bone_holder(sk, hand)
	holder.add_child(prop)
	var hand_world: Transform3D = world.call(hand)
	var holder_world := Transform3D(hand_world.basis.orthonormalized(), hand_world.origin)
	prop.transform = holder_world.affine_inverse() * place
	if keep != "":
		_anim.play(keep, 0.0)
	_current = ""
	return prop


func _rise_started(name: String) -> void:
	_current = name


func _rise_fallback() -> void:
	_play("Idle", 0.3)


func _play(name: String, blend := BLEND) -> void:
	if _current == name or _anim == null:
		return
	var full := name if name.begins_with(UalLibrary.NAME + "/") else ANIM_PREFIX + name
	if not _anim.has_animation(full):
		return
	_current = name
	_anim.play(full, blend)


static func _scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		_scenes[name] = load(name if name.begins_with("res://") else DIR + name + ".glb")
	return _scenes[name]


## Höhe der Figur in der Ruhepose (Hülle der Meshes), gecacht je Figur.
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
