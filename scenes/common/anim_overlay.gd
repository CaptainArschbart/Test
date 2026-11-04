class_name AnimOverlay
extends SkeletonModifier3D
## Oberkörper-Ebene über der laufenden Animation (Schedule 1, P4-6 und P5-7).
##
## Die Beine bleiben bei dem, was der AnimationPlayer spielt (Stehen, Gehen, Laufen, Hocken); Bauch,
## Brust, Kopf, Arme und Finger kommen aus Animationen der UalLibrary:
##   - Zielen: UAL1 Pistol_Aim_Neutral, nach Blickhöhe zu Pistol_Aim_Up bzw. Pistol_Aim_Down gemischt.
##     Stärke aim_weight (0 = aus), Blickhöhe aim_pitch (Radiant, + = hoch).
##   - Aktion: einmal abspielen, z. B. Pistol_Shoot (Rückstoß) oder Pistol_Reload, blendet über das
##     Zielen und danach wieder aus.
##   - Haltung (P5-8): eine Animation in Schleife unter dem Zielen, z. B. UAL2 Idle_TalkingPhone
##     (telefonieren im Gehen) oder Walk_Carry (Kiste tragen). Stärke pose_weight.
## Gemischt wird je Knochen die lokale Drehung (slerp). Läuft als Modifier am Skelett nach dem
## AnimationPlayer und vor Ragdoll und GroundClamp (Reihenfolge der Kinder am Skelett).
## Ohne Zielen und ohne Aktion tut er nichts.

const AIM_NEUTRAL := "ual/Pistol_Aim_Neutral"
const AIM_UP := "ual/Pistol_Aim_Up"
const AIM_DOWN := "ual/Pistol_Aim_Down"
const SHOOT := "ual/Pistol_Shoot"
const RELOAD := "ual/Pistol_Reload"
## Wurzel des Oberkörpers; alle Knochen darunter gehören dazu.
const UPPER_ROOT := "Abdomen"
## Blickhöhe (Radiant), bei der ganz nach Pistol_Aim_Up bzw. _Down gemischt ist.
const AIM_RANGE := 1.2
## Ein- und Ausblenden einer Aktion (s).
const ACTION_FADE_IN := 0.06
const ACTION_FADE_OUT := 0.15

## 0 = kein Zielen, 1 = voll im Anschlag. Setzt der Besitzer jedes Bild.
var aim_weight := 0.0
## Blickhöhe beim Zielen (Radiant, + = hoch).
var aim_pitch := 0.0
## Haltung in Schleife (Name in der UalLibrary, leer = keine) und ihre Stärke.
var pose_name := ""
var pose_weight := 0.0

var _player: AnimationPlayer
var _bones := PackedInt32Array()
## Je Animation: Spur-Index je Oberkörperknochen (-1 = keine Spur).
var _tracks := {}
var _action := ""
var _action_t := 0.0
var _action_end := 0.0
var _action_speed := 1.0
var _action_w := 0.0
var _pose_t := 0.0


## Hängt die Ebene ans Skelett. `player` muss die UalLibrary tragen (UalLibrary.attach).
static func attach(skeleton: Skeleton3D, player: AnimationPlayer) -> AnimOverlay:
	var overlay := AnimOverlay.new()
	overlay.name = "AnimOverlay"
	overlay._player = player
	skeleton.add_child(overlay)
	var root := skeleton.find_bone(UPPER_ROOT)
	if root >= 0:
		overlay._collect(skeleton, root)
	return overlay


## Einmal abspielen, `seconds` lang (die Animation wird dafür gestreckt), -1 = Originallänge.
func play_action(anim_name: String, seconds := -1.0) -> void:
	var anim := _animation(anim_name)
	if anim == null:
		return
	_action = anim_name
	_action_t = 0.0
	_action_speed = anim.length / seconds if seconds > 0.0 else 1.0
	_action_end = anim.length
	if _action_w <= 0.0:
		_action_w = 0.001


## Alles aus (Tod, Umfallen).
func stop() -> void:
	aim_weight = 0.0
	pose_weight = 0.0
	_action = ""
	_action_w = 0.0


func is_busy() -> bool:
	return _action != ""


func _process_modification_with_delta(delta: float) -> void:
	_step_action(delta)
	var pose := _animation(pose_name) if pose_weight > 0.001 else null
	if pose != null:
		_pose_t = fmod(_pose_t + delta, maxf(pose.length, 0.01))
	if aim_weight <= 0.001 and _action_w <= 0.001 and pose == null:
		return
	var skeleton := get_skeleton()
	if skeleton == null or _bones.is_empty():
		return
	var k := clampf(aim_pitch / AIM_RANGE, -1.0, 1.0)
	var neutral := _animation(AIM_NEUTRAL)
	var tilt := _animation(AIM_UP if k > 0.0 else AIM_DOWN)
	var action := _animation(_action) if _action != "" else null
	var action_time := minf(_action_t, _action_end)
	for i in _bones.size():
		var bone := _bones[i]
		var q := skeleton.get_bone_pose_rotation(bone)
		if pose != null:
			q = q.slerp(_sample(pose, pose_name, i, _pose_t, q), clampf(pose_weight, 0.0, 1.0))
		if aim_weight > 0.001 and neutral != null:
			var aim_q := _sample(neutral, AIM_NEUTRAL, i, 0.0, q)
			if tilt != null and absf(k) > 0.001:
				aim_q = aim_q.slerp(_sample(tilt, AIM_UP if k > 0.0 else AIM_DOWN, i, 0.0, aim_q), absf(k))
			q = q.slerp(aim_q, clampf(aim_weight, 0.0, 1.0))
		if action != null and _action_w > 0.001:
			q = q.slerp(_sample(action, _action, i, action_time, q), _action_w)
		skeleton.set_bone_pose_rotation(bone, q)


func _step_action(delta: float) -> void:
	if _action == "":
		_action_w = maxf(_action_w - delta / ACTION_FADE_OUT, 0.0)
		return
	_action_t += delta * _action_speed
	if _action_t >= _action_end:
		_action = ""
		return
	_action_w = minf(_action_w + delta / ACTION_FADE_IN, 1.0)


func _sample(anim: Animation, anim_name: String, i: int, time: float, fallback: Quaternion) -> Quaternion:
	var tracks: PackedInt32Array = _tracks.get(anim_name, PackedInt32Array())
	if i >= tracks.size() or tracks[i] < 0:
		return fallback
	return anim.rotation_track_interpolate(tracks[i], time)


func _animation(anim_name: String) -> Animation:
	if _player == null or anim_name == "" or not _player.has_animation(anim_name):
		return null
	var anim := _player.get_animation(anim_name)
	if not _tracks.has(anim_name):
		var skeleton := get_skeleton()
		var prefix := str(_player.get_node(_player.root_node).get_path_to(skeleton)) if skeleton != null else ""
		var tracks := PackedInt32Array()
		for bone in _bones:
			tracks.append(anim.find_track(NodePath("%s:%s" % [prefix, skeleton.get_bone_name(bone)]), Animation.TYPE_ROTATION_3D) if skeleton != null else -1)
		_tracks[anim_name] = tracks
	return anim


func _collect(skeleton: Skeleton3D, bone: int) -> void:
	_bones.append(bone)
	for child in skeleton.get_bone_children(bone):
		_collect(skeleton, child)
