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
## Laufzyklus: Die Beine laufen im Takt der Schritte des Players (Schrittlänge wie bei den
## Schrittgeräuschen, Player.walk_step_interval × walk_speed). Ein Zyklus = zwei Schritte;
## get_stride_phase() liefert ihn auch für Ego-Hände, Kamerawippen und Schrittgeräusche, damit alles
## zusammen auftritt (rechter Fuß setzt bei Phase π/2 auf, linker bei 3π/2).
## Pro Bein: Oberschenkel pendelt, das Knie knickt in der Schwungphase stark (Ferse zum Gesäß) und
## federt im Stand leicht, der Fuß rollt ab (Ferse auf, Spitze ab). Das Becken sinkt so weit, wie
## das längere Bein kürzer wird: der Standfuß bleibt auf dem Boden, nichts schwebt.
## Arme schwingen gegengleich, beim Sprint stärker angewinkelt, Oberkörper neigt sich vor.
## In der Luft werden die Knie angezogen, beim Landen federn sie kurz ein.
## Ohne Player darüber bleibt die Grundhaltung.
##
## Fremde Figur (external_drive): PlayerAvatarSync setzt die Zustände (Blick, Hocken, Rutschen,
## Klettern, Waffe, Zielen, Nachladen, Tod) und ruft animate_remote() auf. Das legt Hocken, Rutschen,
## Klettern und Waffenhaltung über den Laufzyklus, das Becken dreht in die Laufrichtung, Kopf und
## Oberkörper folgen dem Blick. Waffen hängen an einer Halterung am Oberkörper, die Hände greifen sie
## per Zwei-Gelenk-IK. Für die eigene Figur bleiben diese Gewichte 0, dort ändert sich nichts.
## Gelenkwinkel: Hüfte/Schulter +x = nach vorn, Knie -x = gebeugt, Ellbogen +x = Unterarm nach vorn,
## Wirbelsäule/Kopf +x = nach hinten bzw. hochschauen.

## Was die Figur in der Hand hält (bestimmt Haltung und IK-Griffe).
enum Hold { NONE, PISTOL, RIFLE, MELEE, GRENADE }

## Ein Fuß setzt auf (nur mit external_drive, für Schrittgeräusche fremder Figuren).
signal stepped

@export var first_person := true:
	set(value):
		first_person = value
		_update_visibility()
## Schrittlänge in Metern, wenn kein Player darüber ist (sonst wie die Schrittgeräusche).
@export var fallback_step_length := 2.3
## Ab dieser Geschwindigkeit (m/s) volle Schrittweite, darunter kleiner.
@export var full_gait_speed := 8.0
## Oberschenkel nach vorn/hinten bei voller Schrittweite.
@export var leg_swing_degrees := 44.0
## Knieknick in der Schwungphase und Einfedern im Stand bei voller Schrittweite.
@export var knee_swing_degrees := 100.0
@export var knee_stance_degrees := 16.0
@export var arm_swing_degrees := 30.0
## Oberkörper-Neigung nach vorn beim Sprint.
@export var sprint_lean_degrees := 7.0
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

var _player: CharacterBody3D
var _phase := 0.0
## Phase ohne Umbruch (zählt die Schritte).
var _stride_total := PI * 0.5 - 0.01
var _gait := 0.0
var _sprint := 0.0
var _air := 0.0
var _land := 0.0
var _was_on_floor := true
## Oberschenkel, Unterschenkel und Knöchel bis Sohle (siehe _build_leg), für das Absenken des Beckens.
const THIGH := 0.43
const SHIN := 0.42
const FOOT_DROP := 0.11
const HIPS_Y := 0.95
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
## Render-Ebene 19: nur die Beine. Ein schwaches Fülllicht (nur in der Ego-Sicht) wirkt allein darauf,
## damit Knie und Stiefel beim Runterschauen auch in dunklen Gassen lesbar sind (wie bei den Ego-Händen).
const LEGS_LAYER := 1 << 18

var _upper_parts: Array[GeometryInstance3D] = []
var _legs: Array[Dictionary] = []
var _arms: Array[Dictionary] = []
var _spine: Node3D
var _hips: Node3D
var _strap_material: StandardMaterial3D
var _rubber_material: StandardMaterial3D
var _metal_material: StandardMaterial3D
var _leg_light: OmniLight3D
var _head: Node3D
## +1 vorwärts, -1 rückwärts (nur fremde Figur).
var _stride_dir := 1.0

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
	var speed := 0.0
	var on_floor := true
	var sprinting := false
	if _player != null:
		speed = Vector2(_player.velocity.x, _player.velocity.z).length()
		on_floor = _player.is_on_floor()
		if _player is Player and (_player as Player).stats != null:
			sprinting = (_player as Player).stats.is_sprinting()
	animate(delta, speed, on_floor, sprinting)


## Lauf-, Steh- und Sprunghaltung. `speed` in Metern pro Sekunde.
func animate(delta: float, speed: float, on_floor: bool, sprinting := false) -> void:
	_update_overlays(delta)
	var target_gait := clampf(speed / full_gait_speed, 0.0, 1.1) if on_floor else 0.0
	_gait = lerpf(_gait, target_gait, minf(8.0 * delta, 1.0))
	_sprint = move_toward(_sprint, 1.0 if sprinting and on_floor and speed > 1.0 else 0.0, 4.0 * delta)
	_air = lerpf(_air, 0.0 if on_floor else 1.0, minf(6.0 * delta, 1.0))
	if on_floor and not _was_on_floor:
		_land = 1.0
	_was_on_floor = on_floor
	_land = move_toward(_land, 0.0, 4.0 * delta)
	if on_floor and speed > 0.3:
		_stride_total += delta * get_cadence(speed, sprinting) * PI * _stride_dir
	_phase = fmod(_stride_total, TAU)

	var leg := deg_to_rad(leg_swing_degrees) * _gait
	var knee_swing := deg_to_rad(knee_swing_degrees) * pow(minf(_gait, 1.0), 0.8)
	var knee_stance := deg_to_rad(knee_stance_degrees) * _gait
	var reach := 0.0
	for i in _legs.size():
		var p := _phase + (0.0 if i == 0 else PI)
		var swing := maxf(0.0, cos(p + 0.35))
		swing = swing * swing * (3.0 - 2.0 * swing)
		var stance := maxf(0.0, -cos(p))
		var hip_angle := sin(p) * leg + _air * 0.5 + _land * 0.2
		var knee_flex := swing * knee_swing + stance * knee_stance + _air * 1.1 + _land * 0.45 + 0.06
		# Fuß: Ferse setzt mit leicht angehobener Spitze auf, hinten drückt die Spitze ab.
		var foot := (0.22 * sin(p) - 0.3 * swing) * _gait - _air * 0.25
		# Fremde Figur: Hocken, Rutschen (rechts gestreckt, links untergeschlagen), Klettern.
		hip_angle += 1.25 * _crouch_w
		knee_flex += 2.05 * _crouch_w
		hip_angle = lerpf(hip_angle, 1.3 if i == 0 else 0.45, _slide_w)
		knee_flex = lerpf(knee_flex, 0.2 if i == 0 else 1.95, _slide_w)
		var climb_leg := _climb_leg(i)
		hip_angle = lerpf(hip_angle, climb_leg.x, _climb_w)
		knee_flex = lerpf(knee_flex, -climb_leg.y, _climb_w)
		foot *= 1.0 - maxf(_crouch_w, _slide_w)
		var shin := hip_angle - knee_flex
		var hip: Node3D = _legs[i].hip
		var knee: Node3D = _legs[i].knee
		var ankle: Node3D = _legs[i].ankle
		hip.rotation.x = hip_angle
		knee.rotation.x = -knee_flex
		ankle.rotation.x = foot - shin
		reach = maxf(reach, THIGH * cos(hip_angle) + SHIN * cos(shin) + FOOT_DROP * cos(foot))
	# Das längere Bein steht auf dem Boden: Becken sinkt um das, was ihm zur geraden Länge fehlt.
	var straight := THIGH + SHIN * cos(0.06) + FOOT_DROP
	if _hips != null:
		_hips.position.y = HIPS_Y - (straight - reach) * (1.0 - _air) * (1.0 - _climb_w)
		_hips.rotation.y = _hip_yaw

	var arm := deg_to_rad(arm_swing_degrees) * _gait
	for i in _arms.size():
		var side := 1.0 if i == 0 else -1.0
		var shoulder: Node3D = _arms[i].shoulder
		var elbow: Node3D = _arms[i].elbow
		shoulder.rotation = Vector3(-sin(_phase) * side * arm + _air * 0.4, 0.0, (0.09 + _air * 0.25) * side)
		elbow.rotation.x = 0.25 + _gait * 0.35 + _sprint * 0.6 + maxf(0.0, -sin(_phase) * side) * arm * 0.6
	var breath := sin(Time.get_ticks_msec() * 0.0013) * 0.012
	_spine.rotation.x = -0.04 * _gait - deg_to_rad(sprint_lean_degrees) * _sprint + breath
	_spine.position.y = 0.075
	_apply_overlays()


## Fremde Figur. `velocity` in Weltkoordinaten (m/s): das Becken dreht in die Laufrichtung
## (seitwärts bis 50°), rückwärts läuft der Zyklus rückwärts. Meldet Schritte über `stepped`.
func animate_remote(delta: float, velocity: Vector3, on_floor: bool) -> void:
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
	_stride_dir = 1.0
	var yaw_target := 0.0
	if speed > 0.4 and not sliding and climb < 0.0:
		var angle := atan2(planar.x, planar.y)
		if absf(angle) > PI * 0.6:
			_stride_dir = -1.0
			angle = wrapf(angle - PI, -PI, PI)
		yaw_target = -clampf(angle, -0.9, 0.9)
	_hip_yaw = lerp_angle(_hip_yaw, yaw_target, minf(delta * 8.0, 1.0))
	var steps := get_step_count()
	var sprinting := speed > 6.0 and crouch < 0.5
	animate(delta, 0.0 if sliding or climb >= 0.0 else speed, on_floor, sprinting)
	if on_floor and get_step_count() != steps:
		stepped.emit()


## Schritte pro Sekunde bei `speed` (wie die Schrittgeräusche des Players, 0,16–0,75 s je Schritt).
func get_cadence(speed: float, sprinting: bool) -> float:
	var step_length := fallback_step_length
	if _player is Player:
		var player := _player as Player
		step_length = player.sprint_step_interval * player.sprint_speed if sprinting \
			else player.walk_step_interval * player.walk_speed
	return clampf(speed / maxf(step_length, 0.1), 1.0 / 0.75, 1.0 / 0.16)


## Laufzyklus 0–2π. Rechter Fuß setzt bei π/2 auf, linker bei 3π/2.
func get_stride_phase() -> float:
	return _phase


## Wie viele Schritte bisher (wächst bei jedem Auftritt um eins).
func get_step_count() -> int:
	return floori((_stride_total - PI * 0.5) / PI)


## Schrittweite 0 (Stand) bis ~1 (Sprint), weich überblendet.
func get_gait() -> float:
	return _gait


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


## Gewichte für Hocken, Rutschen, Klettern, Zielen und Nachladen weich nachführen
## (20-Hz-Netzwerte sollen nicht ruckeln). Für die eigene Figur bleiben sie 0.
func _update_overlays(delta: float) -> void:
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


## Oberkörper, Kopf und Arme der fremden Figur über den Laufzyklus legen.
func _apply_overlays() -> void:
	var lean := _spine.rotation.x - 0.32 * _crouch_w
	lean = lerpf(lean, 0.45, _slide_w)
	var climb_lean := 0.1
	if _climb_t >= 1.0:
		climb_lean = lerpf(0.1, -0.55, smoothstep(1.0, 2.0, _climb_t)) + 0.35 * smoothstep(2.3, 3.0, _climb_t)
	lean = lerpf(lean, climb_lean, _climb_w)
	# Oberkörper folgt dem Blick ein Stück, im Anschlag mehr.
	var follow := lerpf(0.25, 0.45, _aim_w) * (1.0 - _climb_w)
	_spine.rotation.x = lean + look_pitch * follow if external_drive else lean
	_spine.rotation.y = -_hip_yaw * 0.85
	if external_drive:
		_head.rotation.x = clampf(look_pitch - _spine.rotation.x, -0.9, 0.9)
	var mount := _mount_transform()
	_weapon_mount.transform = mount
	var weapon := hold != Hold.NONE
	for i in _arms.size():
		var side := 1.0 if i == 0 else -1.0
		var shoulder: Node3D = _arms[i].shoulder
		var elbow_node: Node3D = _arms[i].elbow
		var x := shoulder.rotation.x + 0.25 * _crouch_w
		var z := shoulder.rotation.z * side
		var elbow := elbow_node.rotation.x + 0.3 * _crouch_w
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
			grip *= (1.0 - _climb_w) * (1.0 - _slide_w * 0.6)
		if grip > 0.001:
			var ik := _solve_arm(shoulder.position, target, side)
			basis = basis.slerp(ik.basis, grip)
			elbow = lerpf(elbow, ik.elbow, grip)
		shoulder.basis = basis
		elbow_node.rotation.x = elbow
	_weapon_mount.visible = weapon and _climb_w < 0.5


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
			low = Transform3D(Basis.from_euler(Vector3(-0.75, 0.15, 0.0)), Vector3(0.15, 0.24, -0.24))
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
	if _leg_light != null:
		_leg_light.visible = first_person
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
		var leg := _build_leg(hips, side)
		_set_layer(leg.hip, LEGS_LAYER)
		_legs.append(leg)
	_leg_light = OmniLight3D.new()
	_leg_light.name = "LegFillLight"
	_leg_light.light_color = Color(0.75, 0.85, 1.0)
	_leg_light.light_energy = 0.9
	_leg_light.light_specular = 0.4
	_leg_light.omni_range = 1.5
	_leg_light.shadow_enabled = false
	_leg_light.light_cull_mask = LEGS_LAYER
	_leg_light.position = Vector3(0.0, -0.05, -0.55)
	hips.add_child(_leg_light)

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


func _set_layer(node: Node, layer: int) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers |= layer
	for child in node.get_children():
		_set_layer(child, layer)


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
