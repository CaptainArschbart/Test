class_name PlayerBody
extends Node3D
## Körper der Spielfigur im selben Cyberpunk-Look wie die Ego-Hände.
##
## Aufbau aus Grundformen (ProcMesh): Stiefel mit Riemen, Kappe und Profilsohle mit Neonkante,
## Hose mit Knieschützern, Schienbeinplatten und Beinholster, Gürtel mit Taschen, Mantel mit
## Schößen, hohem Kragen und Gurtzeug mit Brustplatte, Akku-Pack am Rücken, zweilagige
## Schulterpanzer, Unterarmschienen (links mit Display), Hände mit Daumen, Kopf mit Kapuze,
## Visier mit Rahmen, Atemmaske mit Filtern und Ohrstück mit Antenne. Füße stehen auf y = 0, Blick nach -Z.
##
## Ego-Sicht: Beine und Stiefel sieht man beim Runterschauen, Becken, Oberkörper, Arme und Kopf
## werfen nur Schatten (sonst steckt die Kamera im Kopf). first_person = false zeigt alles,
## so sehen andere Spieler im Multiplayer die Figur (PlayerAvatarSync schaltet das um).
##
## Ohne external_drive laufen die Beine mit der Geschwindigkeit des Players, die Arme schwingen
## gegengleich, in der Luft werden die Knie angezogen. Mit external_drive setzt PlayerAvatarSync
## die Zustände (Blick, Hocken, Rutschen, Klettern, Waffe, Zielen, Nachladen, Tod) und ruft
## animate() auf. Waffen hängen an einer Halterung am Oberkörper, die Hände greifen sie per
## Zwei-Gelenk-IK. Gelenkwinkel: Hüfte/Schulter +x = nach vorn, Knie -x = Unterschenkel nach hinten,
## Ellbogen +x = Unterarm nach vorn, Wirbelsäule/Kopf +x = nach hinten bzw. hochschauen.

## Was die Figur in der Hand hält (bestimmt Haltung und IK-Griffe).
enum Hold { NONE, PISTOL, RIFLE, MELEE, GRENADE }

## Ein Fuß setzt auf (nur mit external_drive, für Schrittgeräusche fremder Figuren).
signal stepped

@export var first_person := true:
	set(value):
		first_person = value
		_update_visibility()
## Schrittlänge: wie viele Schrittzyklen pro Meter.
@export var stride_rate := 1.45
@export var leg_swing_degrees := 32.0
@export var arm_swing_degrees := 22.0
## In der Ego-Sicht rutschen die Beine so weit nach hinten, damit man beim Runterschauen
## an den Oberschenkeln vorbei auf Knie und Stiefel sieht.
@export var first_person_leg_offset := 0.16

@export_group("Materialien")
@export var jacket_material: Material
@export var pants_material: Material
@export var armor_material: Material
@export var glove_material: Material
@export var skin_material: Material
@export var neon_material: Material
@export var visor_material: Material

const HIP_HEIGHT := 0.95
const THIGH := 0.43
const SHIN := 0.42
## Fußgelenk bis Sohle.
const FOOT := 0.105
const UPPER_ARM := 0.29
## Ellbogen bis Handfläche.
const FOREARM := 0.33
const PALM := Vector3(0.0, -0.33, -0.01)

## true = PlayerAvatarSync steuert (fremde Figur), sonst liest der Körper den Player selbst.
var external_drive := false
## Blick hoch (+) / runter (-) in Radiant, wie Player.head.rotation.x.
var look_pitch := 0.0
## 0 = steht, 1 = hockt.
var crouch := 0.0
var sliding := false
## -1 = klettert nicht. Sonst Phase plus Anteil: 0…1 Greifen, 1…2 Hochziehen, 2…3 Rüberschwingen.
var climb := -1.0
## 0 = Hüfte, 1 = im Anschlag.
var aim := 0.0
## -1 = lädt nicht nach, sonst Fortschritt 0…1.
var reload := -1.0
var dead := false:
	set(value):
		if value == dead:
			return
		dead = value
		if dead:
			_play_death()
		else:
			_reset_death()
var hold: Hold = Hold.NONE

var _player: CharacterBody3D
var _phase := 0.0
var _swing := 0.0
var _air := 0.0
var _upper_parts: Array[GeometryInstance3D] = []
var _legs: Array[Dictionary] = []
var _arms: Array[Dictionary] = []
var _spine: Node3D
var _hips: Node3D
var _head: Node3D
var _strap_material: StandardMaterial3D
var _rubber_material: StandardMaterial3D
var _metal_material: StandardMaterial3D

# Gewichte, weich nachgeführt, damit 20-Hz-Netzwerte nicht ruckeln.
var _crouch_w := 0.0
var _slide_w := 0.0
var _climb_w := 0.0
var _climb_t := 0.0
var _aim_w := 0.0
var _reload_w := 0.0
var _reload_t := 0.0
var _hip_yaw := 0.0
var _recoil := 0.0
## Schlag oder Wurf: 1 beim Start, fällt auf 0.
var _action := 0.0
var _weapon_mount: Node3D
var _weapon_view: Node3D
var _grip_right := Vector3.ZERO
var _grip_left := Vector3(0.0, -0.02, -0.3)
var _flash: Node3D
var _flash_light: Light3D
var _flash_left := 0.0
var _death_tween: Tween
var _rest_transform := Transform3D()


func _ready() -> void:
	_build()
	_update_visibility()
	var node := get_parent()
	while node != null and not node is CharacterBody3D:
		node = node.get_parent()
	_player = node as CharacterBody3D


func _process(delta: float) -> void:
	if external_drive:
		return
	var velocity := Vector3.ZERO
	var on_floor := true
	if _player != null:
		velocity = _player.velocity
		on_floor = _player.is_on_floor()
	animate(delta, velocity, on_floor)


## Zeigt ein Item in der rechten Hand (Schusswaffe, Klinge, Granate) und wählt die Haltung.
## null oder andere Items = leere Hände.
func set_held_item(item: ItemData) -> void:
	if _weapon_view != null:
		_weapon_view.queue_free()
		_weapon_view = null
	_flash = null
	_flash_light = null
	hold = Hold.NONE
	_grip_right = Vector3.ZERO
	_grip_left = Vector3(0.0, -0.02, -0.3)
	if item is WeaponData and item.view_scene != null:
		_weapon_view = item.view_scene.instantiate()
		hold = Hold.RIFLE if item.has_scope else Hold.PISTOL
		var right := _weapon_view.get_node_or_null("HandGripRight") as Node3D
		var left := _weapon_view.get_node_or_null("HandGripLeft") as Node3D
		_grip_right = right.position if right != null else Vector3(0.0, -0.035, 0.0)
		if left != null:
			_grip_left = left.position
		elif hold == Hold.PISTOL:
			_grip_left = _grip_right + Vector3(-0.02, -0.015, 0.0)
		_flash = _weapon_view.get_node_or_null("Muzzle/Flash")
		_flash_light = _weapon_view.get_node_or_null("Muzzle/FlashLight") as Light3D
	elif item is MeleeData:
		hold = Hold.MELEE
		_weapon_view = _held_mesh(item.color, true)
	elif item is GrenadeData:
		hold = Hold.GRENADE
		_weapon_view = _held_mesh(item.color, false)
	if _weapon_view == null:
		return
	_weapon_mount.add_child(_weapon_view)
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if first_person \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for node: Node in _weapon_view.find_children("*", "GeometryInstance3D", true, false):
		var mesh := node as GeometryInstance3D
		if mesh.get_parent() != null and mesh.get_parent().name == "Muzzle":
			continue
		mesh.cast_shadow = mode
	_set_flash(false)


## Schuss: Rückstoß und kurzes Mündungsfeuer.
func trigger_fire() -> void:
	_recoil = 1.0
	_flash_left = 0.06
	_set_flash(true)


## Schlag mit der Klinge oder Granatwurf.
func trigger_action() -> void:
	_action = 1.0


## Zustände in Haltung umsetzen. `velocity` in Weltkoordinaten (m/s).
func animate(delta: float, velocity: Vector3, on_floor: bool) -> void:
	_recoil = move_toward(_recoil, 0.0, delta * 7.0)
	_action = move_toward(_action, 0.0, delta * 2.2)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_flash(false)
	if dead:
		return
	var local := global_basis.orthonormalized().inverse() * velocity
	# x = rechts, y = vorwärts.
	var planar := Vector2(local.x, -local.z)
	var speed := planar.length()
	var k := minf(delta * 10.0, 1.0)
	var climbing := climb >= 0.0
	_climb_w = lerpf(_climb_w, 1.0 if climbing else 0.0, minf(delta * 14.0, 1.0))
	if climbing:
		_climb_t = climb
	_crouch_w = lerpf(_crouch_w, 0.0 if climbing else clampf(crouch, 0.0, 1.0), k)
	_slide_w = lerpf(_slide_w, 1.0 if sliding and not climbing else 0.0, k)
	_aim_w = lerpf(_aim_w, clampf(aim, 0.0, 1.0) if hold != Hold.NONE else 0.0, minf(delta * 16.0, 1.0))
	_reload_w = lerpf(_reload_w, 1.0 if reload >= 0.0 else 0.0, minf(delta * 12.0, 1.0))
	if reload >= 0.0:
		_reload_t = reload
	_air = lerpf(_air, 0.0 if on_floor or climbing else 1.0, minf(6.0 * delta, 1.0))

	# Laufrichtung: Becken dreht mit (seitwärts), rückwärts läuft der Zyklus rückwärts.
	var dir_sign := 1.0
	var yaw_target := 0.0
	if speed > 0.4 and _slide_w < 0.5 and _climb_w < 0.5:
		var angle := atan2(planar.x, planar.y)
		if absf(angle) > PI * 0.6:
			dir_sign = -1.0
			angle = wrapf(angle - PI, -PI, PI)
		yaw_target = -clampf(angle, -0.9, 0.9)
	_hip_yaw = lerp_angle(_hip_yaw, yaw_target, minf(delta * 8.0, 1.0))
	var busy := maxf(_slide_w, _climb_w)
	var target_swing := clampf(speed / 5.0, 0.0, 1.4) * (1.0 - busy) if on_floor else 0.0
	_swing = lerpf(_swing, target_swing, minf(8.0 * delta, 1.0))
	var old_phase := _phase
	_phase = fmod(_phase + delta * speed * stride_rate * PI * dir_sign * (1.0 + 0.5 * _crouch_w) + TAU, TAU)
	if external_drive and on_floor and _swing > 0.15 and signf(sin(old_phase)) != signf(sin(_phase)):
		stepped.emit()
	var sprint := clampf((speed - 5.5) / 2.5, 0.0, 1.0) * (1.0 - busy)

	_animate_legs(on_floor)
	_animate_spine(sprint)
	_animate_arms(delta)


func _animate_legs(on_floor: bool) -> void:
	var leg := deg_to_rad(leg_swing_degrees) * _swing
	var lowest := 0.0
	for i in _legs.size():
		var side := 1.0 if i == 0 else -1.0
		var s := sin(_phase) * side
		var c := cos(_phase) * side
		var hip_x := s * leg + _air * 0.5
		# Das Knie knickt, während das Bein nach vorn schwingt.
		var knee_x := -maxf(0.0, c) * leg * 1.5 - 0.05 - _air * 0.9
		hip_x += 1.25 * _crouch_w
		knee_x -= 2.05 * _crouch_w
		# Rutschen: rechtes Bein gestreckt vorn, linkes untergeschlagen.
		hip_x = lerpf(hip_x, 1.3 if i == 0 else 0.45, _slide_w)
		knee_x = lerpf(knee_x, -0.2 if i == 0 else -1.95, _slide_w)
		var climb_leg := _climb_leg(i)
		hip_x = lerpf(hip_x, climb_leg.x, _climb_w)
		knee_x = lerpf(knee_x, climb_leg.y, _climb_w)
		var hip: Node3D = _legs[i].hip
		var knee: Node3D = _legs[i].knee
		var ankle: Node3D = _legs[i].ankle
		hip.rotation.x = hip_x
		knee.rotation.x = knee_x
		# Fuß bleibt beim Hocken flach, beim Gehen rollt er etwas ab.
		var flat := maxf(_crouch_w, _slide_w)
		ankle.rotation.x = -(hip_x + knee_x) * lerpf(0.45, 0.95, flat)
		lowest = maxf(lowest, THIGH * cos(hip_x) + SHIN * cos(hip_x + knee_x) + FOOT)
	_hips.rotation.y = _hip_yaw
	# Am Boden steht der tiefere Fuß auf (Hocken, Rutschen), sonst Grundhöhe.
	var planted := minf(HIP_HEIGHT, 0.05 + lowest)
	var ground := (1.0 - _air) * (1.0 - _climb_w) if on_floor else 0.0
	_hips.position.y = lerpf(HIP_HEIGHT, planted, ground)


## Beinwinkel (Hüfte, Knie) beim Klettern.
func _climb_leg(i: int) -> Vector2:
	var t := _climb_t
	var right := i == 0
	if t < 1.0:
		return Vector2(0.2, -0.35)
	if t < 2.0:
		var k := smoothstep(0.0, 1.0, t - 1.0)
		return Vector2(0.2, -0.35).lerp(Vector2(1.5, -2.0) if right else Vector2(0.6, -1.2), k)
	var k := smoothstep(0.0, 1.0, minf(t - 2.0, 1.0))
	return (Vector2(1.5, -2.0) if right else Vector2(0.6, -1.2)).lerp(
		Vector2(0.7, -0.7) if right else Vector2(1.3, -1.9), k)


func _animate_spine(sprint: float) -> void:
	var lean := -0.05 * _swing - 0.14 * sprint - 0.32 * _crouch_w - 0.1 * _air
	lean = lerpf(lean, 0.45, _slide_w)
	var climb_lean := 0.1
	if _climb_t >= 1.0:
		climb_lean = lerpf(0.1, -0.55, smoothstep(1.0, 2.0, _climb_t)) + 0.35 * smoothstep(2.3, 3.0, _climb_t)
	lean = lerpf(lean, climb_lean, _climb_w)
	# Oberkörper folgt dem Blick ein Stück, im Anschlag mehr.
	var follow := lerpf(0.25, 0.45, _aim_w) * (1.0 - _climb_w)
	var breath := sin(Time.get_ticks_msec() * 0.0013) * 0.012
	_spine.rotation.x = lean + look_pitch * follow + breath
	_spine.rotation.y = -_hip_yaw * 0.85
	_spine.position.y = 0.075 + absf(sin(_phase)) * 0.015 * _swing
	_head.rotation.x = clampf(look_pitch - _spine.rotation.x, -0.9, 0.9)


func _animate_arms(delta: float) -> void:
	var arm := deg_to_rad(arm_swing_degrees) * _swing
	var mount := _mount_transform()
	_weapon_mount.transform = mount
	var weapon := hold != Hold.NONE
	for i in _arms.size():
		var side := 1.0 if i == 0 else -1.0
		# Frei: Pendeln gegengleich zu den Beinen, beim Rennen mehr Ellbogen.
		var x := -sin(_phase) * side * arm + _air * 0.4 + 0.25 * _crouch_w
		var z := 0.09 + _air * 0.25
		var elbow := 0.25 + _swing * 0.35 + 0.3 * _crouch_w
		# Rutschen: rechts nach vorn, links stützt hinten ab.
		x = lerpf(x, 0.6 if i == 0 else -0.5, _slide_w)
		z = lerpf(z, 0.15 if i == 0 else 0.6, _slide_w)
		elbow = lerpf(elbow, 0.5 if i == 0 else 0.15, _slide_w)
		var climb_arm := _climb_arm()
		x = lerpf(x, climb_arm.x, _climb_w)
		z = lerpf(z, 0.15, _climb_w)
		elbow = lerpf(elbow, climb_arm.y, _climb_w)
		var basis := Basis.from_euler(Vector3(x, 0.0, z * side))
		# Mit Waffe: Hand an den Griff (rechts immer, links im Anschlag, beim Gewehr und Nachladen).
		var grip := 0.0
		var target := Vector3.ZERO
		if weapon:
			if i == 0:
				grip = 1.0
				target = mount * _grip_right
			else:
				grip = _left_grip_weight()
				var left := _grip_left
				if _reload_w > 0.01:
					# Linke Hand holt das Magazin unten raus und schiebt es wieder rein.
					var dip := sin(clampf(_reload_t, 0.0, 1.0) * PI)
					left = left.lerp(_grip_right + Vector3(0.0, -0.09 - dip * 0.18, -0.06), _reload_w)
				target = mount * left
			grip *= 1.0 - _climb_w
			grip *= 1.0 - _slide_w * 0.6
		var shoulder: Node3D = _arms[i].shoulder
		var elbow_node: Node3D = _arms[i].elbow
		if grip > 0.001:
			var ik := _solve_arm(shoulder.position, target, side)
			basis = basis.slerp(ik.basis, grip)
			elbow = lerpf(elbow, ik.elbow, grip)
		shoulder.basis = basis
		elbow_node.rotation.x = elbow
	_weapon_mount.visible = weapon and _climb_w < 0.5


## Arm (Schulter-Basis, Ellbogenwinkel) beim Klettern: über Kopf greifen, hochdrücken, abstützen.
func _climb_arm() -> Vector2:
	var t := _climb_t
	if t < 1.0:
		return Vector2(lerpf(1.2, 2.85, smoothstep(0.0, 1.0, t)), 0.25)
	if t < 2.0:
		var k := t - 1.0
		return Vector2(lerpf(2.85, 0.15, smoothstep(0.0, 1.0, k)), 0.25 + sin(k * PI) * 1.35)
	return Vector2(lerpf(0.15, -0.3, minf(t - 2.0, 1.0)), 0.2)


func _left_grip_weight() -> float:
	match hold:
		Hold.RIFLE:
			return 1.0
		Hold.PISTOL:
			return maxf(_aim_w, _reload_w)
	return 0.0


## Lage der Waffe im Raum des Oberkörpers: Hüfte, Anschlag, Nachladen, Rückstoß, Schlag/Wurf.
func _mount_transform() -> Transform3D:
	var pivot := Vector3(0.0, 0.5, 0.0)
	# Im Anschlag zeigt die Waffe genau in Blickrichtung.
	var aim_pitch := look_pitch - _spine.rotation.x
	var low := Transform3D()
	var aimed := Transform3D()
	match hold:
		Hold.PISTOL:
			low = Transform3D(Basis.from_euler(Vector3(-0.6, 0.15, 0.0)), Vector3(0.17, 0.2, -0.3))
			aimed = Transform3D(Basis(Vector3.RIGHT, aim_pitch),
				pivot + Basis(Vector3.RIGHT, aim_pitch) * Vector3(0.04, 0.2, -0.48))
		Hold.RIFLE:
			low = Transform3D(Basis.from_euler(Vector3(-0.45, 0.55, 0.15)), Vector3(0.14, 0.3, -0.24))
			aimed = Transform3D(Basis(Vector3.RIGHT, aim_pitch),
				pivot + Basis(Vector3.RIGHT, aim_pitch) * Vector3(0.12, 0.13, -0.2))
		Hold.MELEE:
			low = Transform3D(Basis.from_euler(Vector3(0.9, 0.0, 0.0)), Vector3(0.22, 0.22, -0.28))
			aimed = low
		Hold.GRENADE:
			low = Transform3D(Basis(), Vector3(0.2, 0.25, -0.3))
			aimed = low
	var t := ease(_aim_w, -2.0)
	var result := low.interpolate_with(aimed, t)
	if _reload_w > 0.01:
		# Waffe kippt beim Nachladen zur Seite und nach unten.
		var tilt := Transform3D(Basis.from_euler(Vector3(-0.35, 0.3, 0.55)),
			Vector3(0.12, 0.28, -0.3))
		result = result.interpolate_with(tilt, _reload_w)
	if _action > 0.0:
		result = _action_pose(result, 1.0 - _action)
	if _recoil > 0.0:
		result = result.rotated_local(Vector3.RIGHT, 0.3 * _recoil)
		result.origin += result.basis.z * 0.05 * _recoil
	return result


## Schlag (Klinge) oder Wurf (Granate): ausholen, durchziehen, zurück.
func _action_pose(rest: Transform3D, t: float) -> Transform3D:
	var wind: Transform3D
	var strike: Transform3D
	if hold == Hold.MELEE:
		wind = Transform3D(Basis.from_euler(Vector3(1.9, -0.3, 0.0)), Vector3(0.28, 0.7, 0.0))
		strike = Transform3D(Basis.from_euler(Vector3(-0.5, 0.6, 0.0)), Vector3(-0.1, 0.3, -0.45))
	elif hold == Hold.GRENADE:
		wind = Transform3D(Basis(), Vector3(0.3, 0.75, 0.2))
		strike = Transform3D(Basis(), Vector3(0.1, 0.62, -0.52))
	else:
		return rest
	if t < 0.3:
		return rest.interpolate_with(wind, smoothstep(0.0, 0.3, t))
	if t < 0.55:
		return wind.interpolate_with(strike, smoothstep(0.3, 0.55, t))
	return strike.interpolate_with(rest, smoothstep(0.55, 1.0, t))


## Zwei-Gelenk-IK im Raum des Oberkörpers: Schulter-Basis (Arm zeigt entlang -Y) und Ellbogenwinkel,
## damit die Handfläche auf `target` liegt. Der Ellbogen zeigt nach unten außen.
func _solve_arm(shoulder: Vector3, target: Vector3, side: float) -> Dictionary:
	var to_target := target - shoulder
	var dist := clampf(to_target.length(), absf(UPPER_ARM - FOREARM) + 0.02, UPPER_ARM + FOREARM - 0.002)
	var dir := to_target.normalized() if to_target.length() > 0.001 else Vector3.DOWN
	# Winkel zwischen Oberarm und Schulter→Ziel (Kosinussatz), Innenwinkel am Ellbogen.
	var cos_a := (UPPER_ARM * UPPER_ARM + dist * dist - FOREARM * FOREARM) / (2.0 * UPPER_ARM * dist)
	var a := acos(clampf(cos_a, -1.0, 1.0))
	var cos_e := (UPPER_ARM * UPPER_ARM + FOREARM * FOREARM - dist * dist) / (2.0 * UPPER_ARM * FOREARM)
	var bend := PI - acos(clampf(cos_e, -1.0, 1.0))
	var pole := Vector3(0.7 * side, -1.0, 0.25)
	var pole_perp := pole - dir * pole.dot(dir)
	if pole_perp.length() < 0.001:
		pole_perp = Vector3(0.0, 0.0, 1.0)
	pole_perp = pole_perp.normalized()
	var upper := dir * cos(a) + pole_perp * sin(a)
	var elbow_pos := shoulder + upper * UPPER_ARM
	var fore := (target - elbow_pos).normalized()
	var minus_z := fore - upper * fore.dot(upper)
	if minus_z.length() < 0.001:
		minus_z = -pole_perp
	minus_z = minus_z.normalized()
	var y := -upper
	var z := -minus_z
	var x := y.cross(z).normalized()
	return {"basis": Basis(x, y, z).orthonormalized(), "elbow": bend}


## Tod: Knie knicken ein, dann kippt der Körper nach hinten und bleibt liegen.
func _play_death() -> void:
	if _death_tween != null:
		_death_tween.kill()
	_set_flash(false)
	_rest_transform = transform
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	for i in _legs.size():
		_death_tween.tween_property(_legs[i].knee, "rotation:x", -1.3, 0.25)
		_death_tween.tween_property(_legs[i].hip, "rotation:x", 0.7, 0.25)
	for i in _arms.size():
		var side := 1.0 if i == 0 else -1.0
		_death_tween.tween_property(_arms[i].shoulder, "rotation", Vector3(0.4, 0.0, 0.9 * side), 0.4)
		_death_tween.tween_property(_arms[i].elbow, "rotation:x", 0.3, 0.4)
	_death_tween.tween_property(_hips, "position:y", 0.62, 0.25)
	_death_tween.tween_property(_spine, "rotation:x", -0.35, 0.25)
	_death_tween.tween_property(_head, "rotation:x", -0.4, 0.4)
	var lying := _rest_transform.basis * Basis(Vector3.RIGHT, PI * 0.5)
	var ground := _rest_transform.origin + _rest_transform.basis * Vector3(0.0, 0.16, 0.3)
	_death_tween.chain().tween_property(self, "basis", lying, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(self, "position", ground, 0.5)
	for i in _legs.size():
		_death_tween.parallel().tween_property(_legs[i].knee, "rotation:x", -0.25, 0.5)
		_death_tween.parallel().tween_property(_legs[i].hip, "rotation:x", 0.15 * (i * 2 - 1), 0.5)
	_death_tween.parallel().tween_property(_spine, "rotation:x", 0.0, 0.5)
	_death_tween.chain().tween_property(self, "position:y", ground.y + 0.06, 0.08)
	_death_tween.chain().tween_property(self, "position:y", ground.y, 0.12)


func _reset_death() -> void:
	if _death_tween != null:
		_death_tween.kill()
		_death_tween = null
	transform = _rest_transform


func _set_flash(on: bool) -> void:
	if _flash != null:
		_flash.visible = on
	if _flash_light != null:
		_flash_light.visible = on


## Klinge (Griff, Parierstange, leuchtende Schneide entlang -Z) oder Granate.
func _held_mesh(color: Color, blade: bool) -> Node3D:
	var root := Node3D.new()
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 2.0
	if blade:
		_part(root, ProcMesh.tube(0.016, 0.016, 0.12), _rubber_material, Vector3(0.0, 0.0, 0.0),
			Vector3(PI * 0.5, 0.0, 0.0))
		_part(root, ProcMesh.rounded_box(Vector3(0.07, 0.025, 0.02), 0.3), _metal_material,
			Vector3(0.0, 0.0, -0.07))
		_part(root, ProcMesh.rounded_box(Vector3(0.012, 0.03, 0.46), 0.2), glow, Vector3(0.0, 0.0, -0.31))
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.045
		sphere.height = 0.09
		_part(root, sphere, glow, Vector3(0.0, 0.0, -0.02))
		_part(root, ProcMesh.tube(0.012, 0.012, 0.03), _metal_material, Vector3(0.0, 0.05, -0.02))
	return root


func _update_visibility() -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if first_person \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for part in _upper_parts:
		part.cast_shadow = mode
	if _hips != null:
		_hips.position.z = first_person_leg_offset if first_person else 0.0
	if _weapon_view != null:
		for node: Node in _weapon_view.find_children("*", "GeometryInstance3D", true, false):
			(node as GeometryInstance3D).cast_shadow = mode


func _build() -> void:
	_ensure_materials()
	var hips := Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0.0, 0.95, 0.0)
	add_child(hips)
	_hips = hips
	# Becken, Gürtel mit Schnalle und Taschen. Gehört zum Oberkörper: von oben würde es die
	# Beine verdecken.
	var pelvis := [
		_part(hips, ProcMesh.rounded_box(Vector3(0.34, 0.2, 0.21), 0.4), pants_material,
			Vector3(0.0, 0.0, 0.0)),
		_part(hips, ProcMesh.rounded_box(Vector3(0.355, 0.045, 0.225), 0.25), _strap_material,
			Vector3(0.0, 0.08, 0.0)),
		_part(hips, ProcMesh.rounded_box(Vector3(0.07, 0.05, 0.022), 0.3), armor_material,
			Vector3(0.0, 0.08, -0.114)),
		_part(hips, ProcMesh.rounded_box(Vector3(0.04, 0.012, 0.01), 0.4), neon_material,
			Vector3(0.0, 0.08, -0.126)),
	]
	for side: float in [1.0, -1.0]:
		# Gürteltaschen vorn seitlich und eine flache am Rücken.
		pelvis.append(_part(hips, ProcMesh.rounded_box(Vector3(0.07, 0.08, 0.045), 0.35), armor_material,
			Vector3(0.12 * side, 0.05, -0.1), Vector3(0.0, 0.25 * side, 0.0)))
		pelvis.append(_part(hips, ProcMesh.rounded_box(Vector3(0.072, 0.02, 0.048), 0.3), _strap_material,
			Vector3(0.12 * side, 0.085, -0.1), Vector3(0.0, 0.25 * side, 0.0)))
	pelvis.append(_part(hips, ProcMesh.rounded_box(Vector3(0.16, 0.07, 0.045), 0.35), armor_material,
		Vector3(0.0, 0.05, 0.12)))
	# Mantelschöße: hinten zwei Bahnen, an den Seiten je eine, bis knapp übers Knie.
	for i in 4:
		var angle := [0.42, -0.42, 1.65, -1.65][i] as float
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var flap := _part(hips, ProcMesh.rounded_box(Vector3(0.15, 0.42, 0.018), 0.2), jacket_material,
			dir * 0.125 + Vector3(0.0, -0.17, 0.0), Vector3(0.1, angle, 0.0))
		pelvis.append(flap)
	for side: float in [1.0, -1.0]:
		_legs.append(_build_leg(hips, side))

	_spine = Node3D.new()
	_spine.name = "Spine"
	_spine.position = Vector3(0.0, 0.075, 0.0)
	hips.add_child(_spine)
	var upper := pelvis.duplicate()
	# Jacke: Bauch, Brust (oben breiter), Kragen hoch und offen, Reißverschluss mit Leuchtlinie.
	upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.32, 0.24, 0.2), 0.45), jacket_material,
		Vector3(0.0, 0.14, 0.0)))
	upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.44, 0.3, 0.24), 0.4), jacket_material,
		Vector3(0.0, 0.38, 0.0)))
	upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.48, 0.1, 0.22), 0.5), jacket_material,
		Vector3(0.0, 0.5, 0.005)))
	upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.008, 0.4, 0.008), 0.5), neon_material,
		Vector3(-0.03, 0.27, -0.121)))
	for side: float in [1.0, -1.0]:
		upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.11, 0.12, 0.022), 0.3), jacket_material,
			Vector3(0.075 * side, 0.6, -0.065), Vector3(-0.25, 0.45 * side, 0.12 * side)))
		upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.12, 0.022, 0.15), 0.3), jacket_material,
			Vector3(0.09 * side, 0.59, 0.03), Vector3(0.0, 0.0, -0.3 * side)))
		# Brusttaschen mit Klappe.
		upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.09, 0.07, 0.025), 0.3), jacket_material,
			Vector3(0.1 * side, 0.18, -0.104)))
		upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.095, 0.02, 0.03), 0.3), _strap_material,
			Vector3(0.1 * side, 0.215, -0.106)))
	# Brustplatte am Gurtzeug: Schultergurte, Querriemen, Platte mit zwei Leuchtschlitzen.
	upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.24, 0.17, 0.045), 0.3), armor_material,
		Vector3(0.05, 0.39, -0.122), Vector3(0.08, 0.0, 0.0)))
	for x: float in [0.0, 0.1]:
		upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.01, 0.12, 0.01), 0.5), neon_material,
			Vector3(x, 0.39, -0.148)))
	for side: float in [1.0, -1.0]:
		upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.045, 0.32, 0.012), 0.3), _strap_material,
			Vector3(0.13 * side, 0.4, -0.118), Vector3(0.05, 0.0, 0.0)))
		upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.045, 0.3, 0.012), 0.3), _strap_material,
			Vector3(0.13 * side, 0.4, 0.122)))
		upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.045, 0.014, 0.25), 0.3), _strap_material,
			Vector3(0.13 * side, 0.545, 0.0)))
	upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.4, 0.04, 0.012), 0.3), _strap_material,
		Vector3(0.0, 0.25, -0.112)))
	# Rücken: Akku-Pack mit Leuchtzellen und zwei Kabeln zum Nacken.
	upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.22, 0.26, 0.08), 0.3), armor_material,
		Vector3(0.0, 0.33, 0.15)))
	for i in 3:
		upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.05, 0.012, 0.01), 0.5), neon_material,
			Vector3(0.0, 0.26 + i * 0.05, 0.193)))
	for side: float in [1.0, -1.0]:
		upper.append(_part(_spine, ProcMesh.tube(0.009, 0.009, 0.2), _rubber_material,
			Vector3(0.07 * side, 0.52, 0.15), Vector3(-0.35, 0.0, 0.0)))
		upper.append(_part(_spine, ProcMesh.tube(0.03, 0.03, 0.025), _metal_material,
			Vector3(0.07 * side, 0.45, 0.193), Vector3(PI * 0.5, 0.0, 0.0)))
	# Kopf: Hals, Gesicht, Kapuze mit Schirm, Visier mit Rahmen, Atemmaske, Ohrstück mit Antenne.
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.6, 0.0)
	_spine.add_child(head)
	_head = head
	upper.append(_part(head, ProcMesh.tube(0.05, 0.055, 0.1), skin_material, Vector3(0.0, 0.02, 0.0)))
	upper.append(_part(head, ProcMesh.rounded_box(Vector3(0.17, 0.23, 0.2), 0.62), skin_material,
		Vector3(0.0, 0.16, -0.01)))
	upper.append(_part(head, ProcMesh.rounded_box(Vector3(0.23, 0.27, 0.25), 0.62), jacket_material,
		Vector3(0.0, 0.18, 0.03)))
	upper.append(_part(head, ProcMesh.rounded_box(Vector3(0.21, 0.03, 0.09), 0.4), jacket_material,
		Vector3(0.0, 0.29, -0.08), Vector3(-0.2, 0.0, 0.0)))
	upper.append(_part(head, ProcMesh.rounded_box(Vector3(0.205, 0.055, 0.07), 0.35), armor_material,
		Vector3(0.0, 0.185, -0.085)))
	upper.append(_part(head, ProcMesh.rounded_box(Vector3(0.18, 0.036, 0.02), 0.35), visor_material,
		Vector3(0.0, 0.185, -0.118)))
	upper.append(_part(head, ProcMesh.rounded_box(Vector3(0.12, 0.08, 0.07), 0.5), armor_material,
		Vector3(0.0, 0.085, -0.095), Vector3(0.15, 0.0, 0.0)))
	upper.append(_part(head, ProcMesh.rounded_box(Vector3(0.06, 0.03, 0.02), 0.4), _rubber_material,
		Vector3(0.0, 0.09, -0.132)))
	for side: float in [1.0, -1.0]:
		upper.append(_part(head, ProcMesh.tube(0.022, 0.024, 0.04), _metal_material,
			Vector3(0.055 * side, 0.07, -0.115), Vector3(PI * 0.5, 0.0, 0.6 * side)))
		upper.append(_part(head, ProcMesh.tube(0.016, 0.016, 0.006), _rubber_material,
			Vector3(0.066 * side, 0.066, -0.132), Vector3(PI * 0.5, 0.0, 0.6 * side)))
	upper.append(_part(head, ProcMesh.tube(0.028, 0.028, 0.03), armor_material,
		Vector3(0.118, 0.17, -0.02), Vector3(0.0, 0.0, PI * 0.5)))
	upper.append(_part(head, ProcMesh.tube(0.004, 0.003, 0.16), _metal_material,
		Vector3(0.13, 0.25, -0.0), Vector3(0.1, 0.0, -0.15)))
	upper.append(_part(head, ProcMesh.rounded_box(Vector3(0.012, 0.012, 0.012), 0.6), visor_material,
		Vector3(0.142, 0.33, 0.008)))
	for side: float in [1.0, -1.0]:
		var arm := _build_arm(_spine, side)
		_arms.append(arm)
		upper.append_array(arm.parts)
	for part in upper:
		_upper_parts.append(part)
	# Halterung für Waffe oder Item in der Hand, Lage setzt _mount_transform().
	_weapon_mount = Node3D.new()
	_weapon_mount.name = "WeaponMount"
	_weapon_mount.visible = false
	_spine.add_child(_weapon_mount)


func _build_leg(hips: Node3D, side: float) -> Dictionary:
	var hip := Node3D.new()
	hip.position = Vector3(0.095 * side, -0.05, 0.0)
	hips.add_child(hip)
	_part(hip, ProcMesh.capsule(0.078, 0.48), pants_material, Vector3(0.0, -0.21, 0.0))
	if side > 0.0:
		# Rechts: Beinholster mit Pistolengriff und zwei Riemen.
		_part(hip, ProcMesh.rounded_box(Vector3(0.05, 0.17, 0.1), 0.3), armor_material,
			Vector3(0.078, -0.21, 0.0))
		_part(hip, ProcMesh.rounded_box(Vector3(0.035, 0.08, 0.04), 0.35), _rubber_material,
			Vector3(0.08, -0.09, 0.03), Vector3(0.0, 0.0, 0.1))
		_part(hip, ProcMesh.rounded_box(Vector3(0.008, 0.06, 0.008), 0.5), neon_material,
			Vector3(0.105, -0.21, 0.0))
	else:
		# Links: Oberschenkeltasche.
		_part(hip, ProcMesh.rounded_box(Vector3(0.045, 0.11, 0.09), 0.35), pants_material,
			Vector3(-0.078, -0.24, 0.0))
		_part(hip, ProcMesh.rounded_box(Vector3(0.05, 0.03, 0.095), 0.3), _strap_material,
			Vector3(-0.079, -0.18, 0.0))
	for y: float in [-0.16, -0.3]:
		_part(hip, ProcMesh.tube(0.083 - y * 0.03, 0.083 - y * 0.03, 0.022), _strap_material,
			Vector3(0.0, y, 0.0))
	var knee := Node3D.new()
	knee.position = Vector3(0.0, -0.43, 0.0)
	hip.add_child(knee)
	_part(knee, ProcMesh.capsule(0.062, 0.46), pants_material, Vector3(0.0, -0.2, 0.0))
	# Knieschützer, Schienbeinplatte mit Leuchtstreifen.
	_part(knee, ProcMesh.rounded_box(Vector3(0.1, 0.11, 0.05), 0.35), armor_material,
		Vector3(0.0, -0.03, -0.055))
	_part(knee, ProcMesh.rounded_box(Vector3(0.05, 0.012, 0.012), 0.5), neon_material,
		Vector3(0.0, -0.03, -0.082))
	_part(knee, ProcMesh.rounded_box(Vector3(0.075, 0.2, 0.03), 0.3), armor_material,
		Vector3(0.0, -0.2, -0.058), Vector3(0.06, 0.0, 0.0))
	_part(knee, ProcMesh.rounded_box(Vector3(0.008, 0.12, 0.008), 0.5), neon_material,
		Vector3(0.0, -0.2, -0.075), Vector3(0.06, 0.0, 0.0))
	var ankle := Node3D.new()
	ankle.position = Vector3(0.0, -0.42, 0.0)
	knee.add_child(ankle)
	# Stiefel: Schaft mit Riemen und Schnallen, Kappe, dicke Profilsohle mit Leuchtkante.
	_part(ankle, ProcMesh.tube(0.068, 0.072, 0.15), armor_material, Vector3(0.0, 0.04, 0.0))
	for y: float in [0.08, 0.02]:
		_part(ankle, ProcMesh.tube(0.075, 0.075, 0.018), _strap_material, Vector3(0.0, y, 0.0))
		_part(ankle, ProcMesh.rounded_box(Vector3(0.012, 0.024, 0.02), 0.3), _metal_material,
			Vector3(0.074 * side, y, -0.01))
	_part(ankle, ProcMesh.rounded_box(Vector3(0.12, 0.09, 0.27), 0.35), armor_material,
		Vector3(0.0, -0.04, -0.05))
	_part(ankle, ProcMesh.rounded_box(Vector3(0.1, 0.03, 0.12), 0.3), _strap_material,
		Vector3(0.0, 0.0, -0.1), Vector3(0.35, 0.0, 0.0))
	_part(ankle, ProcMesh.rounded_box(Vector3(0.112, 0.06, 0.07), 0.5), _metal_material,
		Vector3(0.0, -0.05, -0.16))
	_part(ankle, ProcMesh.rounded_box(Vector3(0.13, 0.03, 0.285), 0.25), _rubber_material,
		Vector3(0.0, -0.095, -0.05))
	_part(ankle, ProcMesh.rounded_box(Vector3(0.132, 0.008, 0.287), 0.3), neon_material,
		Vector3(0.0, -0.083, -0.05))
	return {"hip": hip, "knee": knee, "ankle": ankle}


func _build_arm(spine: Node3D, side: float) -> Dictionary:
	var parts := []
	var shoulder := Node3D.new()
	shoulder.position = Vector3(0.25 * side, 0.48, 0.0)
	spine.add_child(shoulder)
	# Zweilagiger Schulterpanzer mit Leuchtkante.
	parts.append(_part(shoulder, ProcMesh.rounded_box(Vector3(0.15, 0.07, 0.16), 0.45), armor_material,
		Vector3(0.018 * side, 0.035, 0.0), Vector3(0.0, 0.0, -0.25 * side)))
	parts.append(_part(shoulder, ProcMesh.rounded_box(Vector3(0.12, 0.05, 0.14), 0.45), armor_material,
		Vector3(0.05 * side, -0.02, 0.0), Vector3(0.0, 0.0, -0.55 * side)))
	parts.append(_part(shoulder, ProcMesh.rounded_box(Vector3(0.11, 0.008, 0.008), 0.5), neon_material,
		Vector3(0.04 * side, 0.025, -0.081), Vector3(0.0, 0.0, -0.3 * side)))
	parts.append(_part(shoulder, ProcMesh.capsule(0.058, 0.33), jacket_material, Vector3(0.0, -0.14, 0.0)))
	parts.append(_part(shoulder, ProcMesh.tube(0.063, 0.063, 0.025), _strap_material, Vector3(0.0, -0.12, 0.0)))
	var elbow := Node3D.new()
	elbow.position = Vector3(0.0, -0.29, 0.0)
	shoulder.add_child(elbow)
	parts.append(_part(elbow, ProcMesh.rounded_box(Vector3(0.07, 0.07, 0.05), 0.5), armor_material,
		Vector3(0.0, 0.0, 0.045)))
	parts.append(_part(elbow, ProcMesh.capsule(0.05, 0.3), jacket_material, Vector3(0.0, -0.13, 0.0)))
	# Unterarmschiene, links mit Handgelenk-Display.
	parts.append(_part(elbow, ProcMesh.rounded_box(Vector3(0.075, 0.13, 0.08), 0.35), armor_material,
		Vector3(0.0, -0.17, 0.0)))
	if side < 0.0:
		parts.append(_part(elbow, ProcMesh.rounded_box(Vector3(0.012, 0.07, 0.05), 0.3), visor_material,
			Vector3(-0.04, -0.18, 0.0)))
	else:
		parts.append(_part(elbow, ProcMesh.rounded_box(Vector3(0.008, 0.09, 0.008), 0.5), neon_material,
			Vector3(0.039, -0.17, -0.02)))
	parts.append(_part(elbow, ProcMesh.tube(0.042, 0.042, 0.05), armor_material, Vector3(0.0, -0.25, 0.0)))
	parts.append(_part(elbow, ProcMesh.tube(0.044, 0.044, 0.006), neon_material, Vector3(0.0, -0.235, 0.0)))
	# Hand: Handfläche, Finger als ein gekrümmter Block, Daumen.
	parts.append(_part(elbow, ProcMesh.rounded_box(Vector3(0.035, 0.085, 0.08), 0.4), glove_material,
		Vector3(0.0, -0.315, -0.005)))
	parts.append(_part(elbow, ProcMesh.rounded_box(Vector3(0.03, 0.07, 0.075), 0.5), glove_material,
		Vector3(-0.004 * side, -0.38, -0.008), Vector3(0.25, 0.0, 0.0)))
	parts.append(_part(elbow, ProcMesh.capsule(0.012, 0.06), glove_material,
		Vector3(-0.01 * side, -0.33, -0.05), Vector3(0.6, 0.0, 0.0)))
	parts.append(_part(elbow, ProcMesh.rounded_box(Vector3(0.012, 0.04, 0.05), 0.3), armor_material,
		Vector3(0.019 * side, -0.31, -0.005)))
	return {"shoulder": shoulder, "elbow": elbow, "parts": parts}


func _part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance


func _ensure_materials() -> void:
	# Riemen, Gummisohlen und blankes Metall (Schnallen, Filter) kommen aus dem Code.
	_strap_material = _flat(Color(0.035, 0.032, 0.03), 0.0, 0.6)
	_rubber_material = _flat(Color(0.02, 0.02, 0.022), 0.0, 0.92)
	_metal_material = _flat(Color(0.5, 0.52, 0.56), 0.9, 0.32)
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.1, 0.1, 0.12)
	for property in ["jacket_material", "pants_material", "armor_material", "glove_material",
			"skin_material", "neon_material", "visor_material"]:
		if get(property) == null:
			set(property, fallback)


static func _flat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
