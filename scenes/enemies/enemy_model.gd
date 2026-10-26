class_name EnemyModel
extends Node3D
## Low-Poly-Körper eines Gegners aus Code, mit einfachen, etwas klobigen Animationen.
##
## Knochen sind Node3D-Gelenke (Becken, Wirbel, Kopf, Schultern, Ellbogen, Hüften, Knie). Alle Teile
## eines Gelenks werden zu einem Mesh zusammengefasst (eine Fläche pro Material), damit ein Gegner
## nur gut ein Dutzend Draw-Calls kostet.
##
## Aussehen nach EnemyProfile.look: GANGSTER (Kapuze oder Irokese, Maske, Kette, Kabelschlauch),
## SECURITY (Helm mit Visier, Weste mit Streifen, Schulterlampe), SNIPER (Mantel, Gasmaske, rote
## Brillengläser, Gewehr mit Laser), COP (Mütze, Uniform, Abzeichen).
## Die „Statusfarbe“ (Visier, Brille, Augenimplantat, LED) zeigt den Zustand: Cyan ruhig, Gelb Verdacht,
## Rot Kampf.
##
## Animation: Enemy setzt jedes Frame speed / run_speed / aim / attack / flinch / stunned und ruft
## animate(delta). fall(direction) spielt den Tod.

var speed := 0.0
var run_speed := 4.4
## 0 = Waffe unten, 1 = im Anschlag.
var aim := 0.0
## Blick nach oben/unten beim Zielen (Radiant).
var aim_pitch := 0.0
## Nahkampf: 0 = ruhig, steigt bis 1 während des Schlags.
var attack := 0.0
## Trefferreaktion, fällt von 1 auf 0.
var flinch := 0.0
var stunned := false
var crouch := 0.0

var muzzle: Node3D
var flashlight: SpotLight3D
var laser: MeshInstance3D

var _status_mat: StandardMaterial3D
var _time := randf() * 10.0
var _walk_phase := 0.0
var _dead := false
var _style: EnemyProfile.Style = EnemyProfile.Style.MELEE

var _pelvis: Node3D
var _spine: Node3D
var _head: Node3D
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _weapon: Node3D
## Pro Gelenk gesammelte Teile: Gelenk → {Material: SurfaceTool}.
var _parts := {}
var _mats := {}
var _rng := RandomNumberGenerator.new()


## Baut den Körper. variant_seed sorgt für Abwechslung (Farben, Frisur, Maske).
func build(profile: EnemyProfile, variant_seed: int) -> void:
	_rng.seed = variant_seed
	_style = profile.style
	_status_mat = StandardMaterial3D.new()
	_status_mat.emission_enabled = true
	_status_mat.emission_energy_multiplier = 3.0
	set_status_color(Color(0.0, 0.95, 1.0))
	_skeleton()
	match profile.look:
		EnemyProfile.Look.SECURITY:
			_build_security(profile)
		EnemyProfile.Look.SNIPER:
			_build_sniper(profile)
		EnemyProfile.Look.COP:
			_build_cop(profile)
		_:
			_build_gangster(profile)
	_build_weapon(profile)
	_commit()


func set_status_color(color: Color) -> void:
	if _status_mat == null:
		return
	_status_mat.albedo_color = color
	_status_mat.emission = color


func flash_white() -> void:
	if _status_mat != null:
		_status_mat.emission = Color.WHITE


# --- Animation ----------------------------------------------------------------------------

func animate(delta: float) -> void:
	if _dead:
		return
	_time += delta
	var move := clampf(speed / maxf(run_speed, 0.1), 0.0, 1.0)
	_walk_phase += delta * (1.5 + speed * 2.3)
	var swing := move * 0.75
	var s := sin(_walk_phase)
	var c := cos(_walk_phase)
	flinch = maxf(flinch - delta * 3.5, 0.0)

	# Beine: schwingen, Knie knicken in der Rückphase. Hocken = Knie gebeugt.
	var bend := crouch * 0.9 + (0.55 if stunned else 0.0)
	for i: int in 2:
		var sign := 1.0 if i == 0 else -1.0
		_hips[i].rotation.x = s * swing * sign + bend * 0.6
		_knees[i].rotation.x = -(maxf(0.0, -c * sign) * swing * 1.1 + bend * 1.2)
	# Becken wippt beim Laufen, sinkt beim Hocken / Betäuben.
	_pelvis.position.y = 0.95 + absf(c) * 0.04 * move - bend * 0.32
	_pelvis.rotation.y = s * 0.12 * move

	# Oberkörper: beim Rennen nach vorn, Treffer drückt nach hinten, Betäubt sackt zusammen.
	var lean := move * 0.18 - flinch * 0.45 + (0.5 if stunned else 0.0)
	_spine.rotation.x = lerp_angle(_spine.rotation.x, -lean, minf(delta * 10.0, 1.0))
	_spine.rotation.y = -_pelvis.rotation.y * 0.8 + sin(_time * 0.7) * 0.03 * (1.0 - move)
	_spine.rotation.z = sin(_time * 1.3) * 0.02 + flinch * 0.12
	# Atmen im Stehen.
	_spine.scale = Vector3.ONE * (1.0 + sin(_time * 1.8) * 0.008 * (1.0 - move))
	_head.rotation.x = clampf(aim_pitch * aim, -0.6, 0.6) - (0.45 if stunned else 0.0)
	_head.rotation.y = sin(_time * 0.35) * 0.25 * (1.0 - aim) * (1.0 - move)

	# Arme: pendeln, im Anschlag nach vorn, Nahkampf holt aus und schlägt.
	for i: int in 2:
		var sign := 1.0 if i == 0 else -1.0
		var idle_x := -s * swing * 0.8 * sign
		var arm_x := idle_x
		var arm_z := -0.08 * sign
		var elbow := 0.25 + move * 0.6
		if _style != EnemyProfile.Style.MELEE and aim > 0.0:
			# Pistole/Gewehr: rechter Arm gestreckt, linker stützt.
			var aim_x := PI * 0.5 + aim_pitch
			var aim_z := -0.05 if i == 1 else 0.35
			if _style == EnemyProfile.Style.RIFLE:
				aim_z = -0.12 if i == 1 else 0.5
			arm_x = lerpf(idle_x, aim_x, aim)
			arm_z = lerpf(arm_z, aim_z, aim)
			elbow = lerpf(elbow, 0.1 if i == 1 else 0.7, aim)
		if i == 1 and _style == EnemyProfile.Style.MELEE and attack > 0.0:
			# Ausholen (bis 0,45), dann durchziehen.
			var up := clampf(attack / 0.45, 0.0, 1.0)
			var down := clampf((attack - 0.45) / 0.3, 0.0, 1.0)
			arm_x = lerpf(2.6 * up, 0.4, down)
			elbow = lerpf(1.2 * up, 0.1, down)
		if stunned:
			arm_x = 0.15
			elbow = 0.2
		_shoulders[i].rotation.x = lerp_angle(_shoulders[i].rotation.x, arm_x, minf(delta * 14.0, 1.0))
		_shoulders[i].rotation.z = lerp_angle(_shoulders[i].rotation.z, arm_z, minf(delta * 14.0, 1.0))
		_elbows[i].rotation.x = lerp_angle(_elbows[i].rotation.x, elbow, minf(delta * 14.0, 1.0))


## Tod: Knie knicken ein, dann kippt der Körper in `direction` (Welt, waagerecht) und bleibt liegen.
func fall(direction: Vector3) -> void:
	_dead = true
	var local := global_basis.inverse() * direction
	local.y = 0.0
	if local.length() < 0.01:
		local = Vector3(0, 0, 1)
	local = local.normalized()
	# Kippachse senkrecht zur Fallrichtung.
	var axis := Vector3.UP.cross(local).normalized()
	var end_basis := Basis(axis, PI * 0.5)
	var tween := create_tween()
	tween.set_parallel(true)
	for i: int in 2:
		tween.tween_property(_knees[i], "rotation:x", -1.1, 0.25)
		tween.tween_property(_hips[i], "rotation:x", 0.5, 0.25)
		tween.tween_property(_shoulders[i], "rotation:x", 0.6 + 0.4 * i, 0.4)
		tween.tween_property(_shoulders[i], "rotation:z", -0.9 * (1.0 if i == 0 else -1.0), 0.5)
	tween.tween_property(_pelvis, "position:y", 0.7, 0.25)
	tween.tween_property(_head, "rotation:x", 0.5, 0.4)
	tween.chain().tween_property(self, "basis", end_basis, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "position", position + local * 0.25 + Vector3.UP * 0.18, 0.5)
	# Beine strecken sich im Liegen.
	for i: int in 2:
		tween.parallel().tween_property(_knees[i], "rotation:x", -0.25, 0.5)
		tween.parallel().tween_property(_hips[i], "rotation:x", 0.15 * (i * 2 - 1), 0.5)
	# Kleiner Aufpraller.
	tween.chain().tween_property(self, "position:y", position.y + 0.24, 0.08)
	tween.chain().tween_property(self, "position:y", position.y + 0.18, 0.12)
	if laser != null:
		laser.visible = false
	if flashlight != null:
		# Lampe flackert aus.
		tween.chain().tween_property(flashlight, "light_energy", 0.0, 0.6)


func is_fallen() -> bool:
	return _dead


# --- Skelett ------------------------------------------------------------------------------

func _skeleton() -> void:
	_pelvis = _joint(self, Vector3(0, 0.95, 0))
	_spine = _joint(_pelvis, Vector3(0, 0.05, 0))
	_head = _joint(_spine, Vector3(0, 0.66, 0))
	for side: float in [-1.0, 1.0]:
		var shoulder := _joint(_spine, Vector3(0.25 * side, 0.55, 0))
		_shoulders.append(shoulder)
		_elbows.append(_joint(shoulder, Vector3(0, -0.3, 0)))
		var hip := _joint(_pelvis, Vector3(0.11 * side, -0.02, 0))
		_hips.append(hip)
		_knees.append(_joint(hip, Vector3(0, -0.44, 0)))


func _joint(parent: Node3D, offset: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = offset
	parent.add_child(j)
	return j


# --- Typen --------------------------------------------------------------------------------

func _skin() -> StandardMaterial3D:
	var tones := [Color(0.85, 0.66, 0.52), Color(0.62, 0.44, 0.32), Color(0.4, 0.27, 0.2), Color(0.92, 0.76, 0.64),
			Color(0.75, 0.6, 0.45)]
	return _mat("skin", tones[_rng.randi() % tones.size()], 0.8)


func _build_gangster(profile: EnemyProfile) -> void:
	var jackets := [Color(0.12, 0.12, 0.14), Color(0.25, 0.08, 0.12), Color(0.08, 0.14, 0.2), Color(0.3, 0.26, 0.2),
			Color(0.16, 0.2, 0.12)]
	var jacket := _mat("jacket", jackets[_rng.randi() % jackets.size()], 0.85)
	var pants := _mat("pants", Color(0.1, 0.1, 0.11).lerp(Color(0.2, 0.18, 0.15), _rng.randf()), 0.9)
	var skin := _skin()
	var accent := _emit("accent", profile.accent, 2.2)
	var metal := _mat("metal", Color(0.55, 0.55, 0.6), 0.35, 0.8)
	var shoe := _mat("shoe", Color(0.85, 0.85, 0.82), 0.6)
	_legs(pants, shoe, 0.18, accent)
	# Kapuzenjacke, offen, mit LED-Streifen am Saum.
	_box(_spine, Vector3(0.48, 0.58, 0.28), jacket, Vector3(0, 0.3, 0), 0.4)
	_box(_spine, Vector3(0.44, 0.16, 0.26), jacket, Vector3(0, -0.02, 0), 0.4)
	_box(_spine, Vector3(0.2, 0.42, 0.02), _mat("shirt", Color(0.6, 0.58, 0.55), 0.9), Vector3(0, 0.28, -0.142), 0.2)
	_box(_spine, Vector3(0.46, 0.025, 0.02), accent, Vector3(0, 0.06, -0.15), 0.2)
	# Kette.
	_tube(_spine, 0.008, 0.25, metal, Vector3(0, 0.44, -0.15), Vector3(0, 0, PI * 0.5))
	_box(_spine, Vector3(0.05, 0.06, 0.02), metal, Vector3(0, 0.36, -0.155), 0.3)
	_arms(jacket, skin, 0.13, accent)
	# Kopf.
	_box(_head, Vector3(0.11, 0.1, 0.11), skin, Vector3(0, -0.04, 0), 0.6)
	_box(_head, Vector3(0.22, 0.26, 0.24), skin, Vector3(0, 0.1, 0), 0.6)
	# Augenimplantat rechts in Statusfarbe.
	_box(_head, Vector3(0.05, 0.03, 0.02), _status_mat, Vector3(0.05, 0.13, -0.12), 0.3)
	_box(_head, Vector3(0.04, 0.02, 0.01), _mat("eye", Color(0.05, 0.05, 0.05), 0.5), Vector3(-0.05, 0.13, -0.12), 0.3)
	# Maske oder Tuch vor dem Mund.
	if _rng.randf() < 0.65:
		var bandana := _mat("bandana", [Color(0.6, 0.05, 0.1), Color(0.05, 0.05, 0.06), profile.accent.darkened(0.4)][_rng.randi() % 3], 0.9)
		_box(_head, Vector3(0.24, 0.12, 0.2), bandana, Vector3(0, 0.03, -0.04), 0.5)
	else:
		_box(_head, Vector3(0.16, 0.08, 0.06), metal, Vector3(0, 0.03, -0.12), 0.4)
		_box(_head, Vector3(0.04, 0.04, 0.03), accent, Vector3(0.06, 0.03, -0.15), 0.4)
	match _rng.randi() % 3:
		0:
			# Kapuze.
			_box(_head, Vector3(0.28, 0.3, 0.3), jacket, Vector3(0, 0.14, 0.03), 0.7)
			_box(_head, Vector3(0.26, 0.04, 0.08), jacket, Vector3(0, 0.27, -0.11), 0.5)
		1:
			# Irokese in Akzentfarbe.
			_box(_head, Vector3(0.05, 0.12, 0.24), accent, Vector3(0, 0.27, 0.0), 0.5)
		_:
			# Cap verkehrt herum.
			var cap := _mat("cap", Color(0.1, 0.1, 0.1), 0.7)
			_box(_head, Vector3(0.24, 0.08, 0.25), cap, Vector3(0, 0.24, 0), 0.6)
			_box(_head, Vector3(0.18, 0.02, 0.1), cap, Vector3(0, 0.21, 0.15), 0.3)
	# Kabelschlauch vom Nacken zum Rücken.
	_tube(_spine, 0.018, 0.4, _mat("cable", Color(0.08, 0.08, 0.1), 0.6), Vector3(0.06, 0.48, 0.16), Vector3(0.4, 0, 0))


func _build_security(profile: EnemyProfile) -> void:
	var uniform := _mat("uniform", Color(0.14, 0.16, 0.2), 0.85)
	var armor := _mat("armor", Color(0.26, 0.28, 0.33), 0.5, 0.4)
	var stripe := _emit("stripe", profile.accent, 1.6)
	var boot := _mat("boot", Color(0.06, 0.06, 0.07), 0.6)
	var skin := _skin()
	_legs(uniform, boot, 0.2, null, armor)
	# Weste mit Platten und Warnstreifen.
	_box(_spine, Vector3(0.5, 0.58, 0.3), uniform, Vector3(0, 0.28, 0), 0.35)
	_box(_spine, Vector3(0.46, 0.4, 0.07), armor, Vector3(0, 0.34, -0.16), 0.3)
	_box(_spine, Vector3(0.44, 0.36, 0.06), armor, Vector3(0, 0.32, 0.16), 0.3)
	_box(_spine, Vector3(0.47, 0.035, 0.02), stripe, Vector3(0, 0.22, -0.2), 0.2)
	_box(_spine, Vector3(0.45, 0.035, 0.02), stripe, Vector3(0, 0.22, 0.2), 0.2)
	# Bruststreifen in Statusfarbe (wie die Test-Wachen).
	_box(_spine, Vector3(0.22, 0.04, 0.02), _status_mat, Vector3(0, 0.44, -0.2), 0.2)
	_box(_spine, Vector3(0.5, 0.1, 0.3), _mat("belt", Color(0.08, 0.08, 0.08), 0.6), Vector3(0, -0.02, 0), 0.3)
	for x: float in [-0.15, 0.0, 0.15]:
		_box(_spine, Vector3(0.08, 0.1, 0.06), armor, Vector3(x, -0.02, -0.17), 0.3)
	_arms(uniform, _mat("glove", Color(0.05, 0.05, 0.06), 0.7), 0.14, null, armor)
	# Helm mit Visier.
	_box(_head, Vector3(0.11, 0.1, 0.11), skin, Vector3(0, -0.04, 0), 0.6)
	_box(_head, Vector3(0.22, 0.24, 0.24), skin, Vector3(0, 0.09, 0), 0.6)
	_box(_head, Vector3(0.28, 0.2, 0.3), armor, Vector3(0, 0.18, 0.01), 0.55)
	_box(_head, Vector3(0.25, 0.08, 0.04), _status_mat, Vector3(0, 0.12, -0.13), 0.4)
	_box(_head, Vector3(0.18, 0.06, 0.05), armor, Vector3(0, 0.0, -0.11), 0.4)
	# Schulterlampe links.
	_box(_shoulders[0], Vector3(0.09, 0.08, 0.12), armor, Vector3(-0.02, 0.07, -0.04), 0.3)
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.position = Vector3(-0.25, 1.68, -0.2)
	flashlight.rotation.x = deg_to_rad(-10.0)
	flashlight.spot_range = 16.0
	flashlight.spot_angle = 28.0
	flashlight.spot_attenuation = 0.8
	flashlight.light_energy = 2.4
	flashlight.light_color = Color(0.85, 0.95, 1.0)
	flashlight.shadow_enabled = false
	_spine_attach(flashlight)
	_box(_head, Vector3(0.01, 0.12, 0.01), stripe, Vector3(0.11, 0.3, 0.06), 0.2)


func _build_sniper(profile: EnemyProfile) -> void:
	var coat := _mat("coat", Color(0.1, 0.09, 0.1), 0.8)
	var dark := _mat("dark", Color(0.06, 0.06, 0.07), 0.6)
	var accent := _emit("accent", profile.accent, 2.0)
	var metal := _mat("metal", Color(0.3, 0.3, 0.33), 0.4, 0.7)
	_legs(_mat("pants", Color(0.13, 0.12, 0.12), 0.9), dark, 0.19, null)
	# Langer Mantel: Oberteil am Rücken, Schöße an den Hüften.
	_box(_spine, Vector3(0.5, 0.6, 0.3), coat, Vector3(0, 0.28, 0), 0.35)
	_box(_spine, Vector3(0.12, 0.26, 0.32), coat, Vector3(0, 0.62, 0.02), 0.5)
	for i: int in 2:
		_box(_hips[i], Vector3(0.24, 0.62, 0.32), coat, Vector3(0.03 * (1 - 2 * i) * -1, -0.3, 0.02), 0.25)
	_box(_spine, Vector3(0.52, 0.06, 0.3), _mat("belt", Color(0.2, 0.14, 0.08), 0.7), Vector3(0, 0.0, 0), 0.3)
	_box(_spine, Vector3(0.06, 0.4, 0.02), accent, Vector3(-0.12, 0.32, -0.16), 0.2)
	_arms(coat, dark, 0.135, null)
	# Kapuze, Gasmaske, runde rote Gläser.
	_box(_head, Vector3(0.11, 0.1, 0.11), dark, Vector3(0, -0.04, 0), 0.6)
	_box(_head, Vector3(0.23, 0.26, 0.25), dark, Vector3(0, 0.1, 0), 0.6)
	_box(_head, Vector3(0.3, 0.32, 0.31), coat, Vector3(0, 0.15, 0.03), 0.7)
	for side: float in [-1.0, 1.0]:
		_tube(_head, 0.035, 0.03, metal, Vector3(0.055 * side, 0.13, -0.13), Vector3(PI * 0.5, 0, 0))
		_tube(_head, 0.028, 0.012, _status_mat, Vector3(0.055 * side, 0.13, -0.147), Vector3(PI * 0.5, 0, 0))
		_tube(_head, 0.03, 0.05, metal, Vector3(0.06 * side, 0.0, -0.13), Vector3(PI * 0.5, 0, 0.5 * side))
	_box(_head, Vector3(0.12, 0.08, 0.06), metal, Vector3(0, 0.02, -0.13), 0.4)


func _build_cop(profile: EnemyProfile) -> void:
	var blue := _mat("uniform", Color(0.1, 0.14, 0.28), 0.8)
	var dark := _mat("dark", Color(0.05, 0.05, 0.07), 0.6)
	var stripe := _emit("stripe", profile.accent, 1.8)
	var skin := _skin()
	_legs(blue, dark, 0.19, null)
	_box(_spine, Vector3(0.48, 0.58, 0.28), blue, Vector3(0, 0.3, 0), 0.4)
	_box(_spine, Vector3(0.06, 0.06, 0.02), _mat("badge", Color(0.9, 0.75, 0.3), 0.3, 0.9), Vector3(-0.12, 0.42, -0.15), 0.3)
	_box(_spine, Vector3(0.48, 0.03, 0.02), stripe, Vector3(0, 0.5, -0.145), 0.2)
	_box(_spine, Vector3(0.5, 0.08, 0.3), dark, Vector3(0, -0.02, 0), 0.3)
	_arms(blue, skin, 0.13, stripe)
	_box(_head, Vector3(0.11, 0.1, 0.11), skin, Vector3(0, -0.04, 0), 0.6)
	_box(_head, Vector3(0.22, 0.26, 0.24), skin, Vector3(0, 0.1, 0), 0.6)
	_box(_head, Vector3(0.2, 0.04, 0.03), _status_mat, Vector3(0, 0.13, -0.12), 0.3)
	_box(_head, Vector3(0.25, 0.08, 0.27), blue, Vector3(0, 0.25, 0), 0.5)
	_box(_head, Vector3(0.22, 0.02, 0.1), dark, Vector3(0, 0.22, -0.15), 0.3)


func _legs(cloth: Material, shoe: Material, width: float, accent: Material, pads: Material = null) -> void:
	for i: int in 2:
		_box(_hips[i], Vector3(width, 0.46, width + 0.03), cloth, Vector3(0, -0.22, 0), 0.4)
		_box(_knees[i], Vector3(width - 0.02, 0.42, width), cloth, Vector3(0, -0.22, 0), 0.4)
		_box(_knees[i], Vector3(width + 0.01, 0.12, 0.3), shoe, Vector3(0, -0.45, -0.05), 0.35)
		if accent != null:
			_box(_knees[i], Vector3(width + 0.02, 0.025, 0.31), accent, Vector3(0, -0.5, -0.05), 0.2)
		if pads != null:
			_box(_knees[i], Vector3(width - 0.02, 0.14, 0.06), pads, Vector3(0, -0.02, -0.1), 0.4)


func _arms(sleeve: Material, hand: Material, width: float, accent: Material, pads: Material = null) -> void:
	for i: int in 2:
		_box(_shoulders[i], Vector3(width, 0.32, width), sleeve, Vector3(0, -0.14, 0), 0.4)
		_box(_elbows[i], Vector3(width - 0.015, 0.28, width - 0.015), sleeve, Vector3(0, -0.13, 0), 0.4)
		_box(_elbows[i], Vector3(0.09, 0.1, 0.1), hand, Vector3(0, -0.32, 0), 0.5)
		if accent != null:
			_box(_elbows[i], Vector3(width - 0.005, 0.02, width - 0.005), accent, Vector3(0, -0.24, 0), 0.2)
		if pads != null:
			_box(_shoulders[i], Vector3(width + 0.06, 0.12, width + 0.06), pads, Vector3(0.02 * (1 - 2 * i) * -1, 0.02, 0), 0.45)


## Waffe in der rechten Hand (Ellbogen 1). Mündung zeigt nach unten (Arm hängt), im Anschlag nach vorn.
func _build_weapon(profile: EnemyProfile) -> void:
	_weapon = _joint(_elbows[1], Vector3(0, -0.34, -0.02))
	var gun := _mat("gun", Color(0.08, 0.08, 0.09), 0.5, 0.6)
	var metal := _mat("metal", Color(0.45, 0.45, 0.5), 0.35, 0.8)
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	match profile.style:
		EnemyProfile.Style.PISTOL:
			# Lauf zeigt nach -Z der Waffe = Unterarm-Richtung, Griff nach unten.
			_box(_weapon, Vector3(0.04, 0.1, 0.045), gun, Vector3(0, -0.05, 0.03), 0.3)
			_box(_weapon, Vector3(0.045, 0.05, 0.2), gun, Vector3(0, 0.0, -0.02), 0.3)
			_weapon.rotation.x = -PI * 0.5
			muzzle.position = Vector3(0, 0.0, -0.13)
		EnemyProfile.Style.RIFLE:
			_box(_weapon, Vector3(0.05, 0.07, 0.95), gun, Vector3(0, 0.0, -0.15), 0.25)
			_box(_weapon, Vector3(0.05, 0.12, 0.2), gun, Vector3(0, -0.05, 0.25), 0.3)
			_tube(_weapon, 0.03, 0.22, metal, Vector3(0, 0.07, -0.05), Vector3(PI * 0.5, 0, 0))
			_box(_weapon, Vector3(0.02, 0.02, 0.4), metal, Vector3(0, 0.0, -0.75), 0.2)
			_weapon.rotation.x = -PI * 0.5
			muzzle.position = Vector3(0, 0.0, -0.95)
			laser = MeshInstance3D.new()
			var beam := BoxMesh.new()
			beam.size = Vector3(0.012, 0.012, 1.0)
			laser.mesh = beam
			var lm := StandardMaterial3D.new()
			lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			lm.albedo_color = Color(1.0, 0.1, 0.15, 0.55)
			lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			lm.disable_receive_shadows = true
			laser.material_override = lm
			laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			laser.visible = false
			laser.top_level = true
			add_child(laser)
		_:
			# Rohr / Schlagstock mit Klebeband und Nägeln.
			var pipe := _mat("pipe", Color(0.35, 0.3, 0.26), 0.5, 0.6)
			_tube(_weapon, 0.025, 0.7, pipe, Vector3(0, -0.25, 0), Vector3.ZERO)
			_tube(_weapon, 0.03, 0.12, _mat("tape", Color(0.1, 0.1, 0.1), 0.9), Vector3(0, 0.02, 0), Vector3.ZERO)
			_box(_weapon, Vector3(0.09, 0.08, 0.09), metal, Vector3(0, -0.56, 0), 0.2)
			_weapon.rotation.x = 0.6
			muzzle.position = Vector3(0, -0.55, 0)
	_weapon.add_child(muzzle)


## Licht hängt am Oberkörper, nicht im zusammengefassten Mesh.
func _spine_attach(node: Node3D) -> void:
	node.position -= Vector3(0, 1.0, 0)
	_spine.add_child(node)


# --- Bauteile -----------------------------------------------------------------------------

func _mat(key: String, color: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var full := "%s_%s" % [key, color.to_html()]
	if _mats.has(full):
		return _mats[full]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mats[full] = m
	return m


func _emit(key: String, color: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(key, color, 0.4)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _box(joint: Node3D, size: Vector3, mat: Material, offset: Vector3, roundness := 0.4) -> void:
	_add(joint, ProcMesh.rounded_box(size, roundness), mat, Transform3D(Basis(), offset))


func _tube(joint: Node3D, radius: float, length: float, mat: Material, offset: Vector3, rot: Vector3) -> void:
	_add(joint, ProcMesh.tube(radius, radius, length), mat, Transform3D(Basis.from_euler(rot), offset))


func _add(joint: Node3D, mesh: Mesh, mat: Material, xform: Transform3D) -> void:
	if not _parts.has(joint):
		_parts[joint] = {}
	var table: Dictionary = _parts[joint]
	if not table.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		table[mat] = st
	(table[mat] as SurfaceTool).append_from(mesh, 0, xform)


func _commit() -> void:
	for joint: Node3D in _parts:
		var mesh := ArrayMesh.new()
		var table: Dictionary = _parts[joint]
		for mat: Material in table:
			(table[mat] as SurfaceTool).commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.visibility_range_end = 120.0
		joint.add_child(mi)
	_parts.clear()
