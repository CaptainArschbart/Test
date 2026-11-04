class_name EnemyCharacterModel
extends EnemyModel
## Gegner als Quaternius-Figur (assets/characters/quaternius_modular_men/) mit echter Waffe in der
## Hand statt der Klötzchenfigur. Gleiche Schnittstelle wie EnemyModel (speed, aim, attack, flinch,
## stunned, crouch, muzzle, flashlight, laser, set_status_color, fall), Enemy merkt keinen Unterschied.
##
## Figur nach EnemyProfile.look: Gangster Punk/Hoodie/Casual, Sicherheitsdienst Business Man,
## Scharfschütze Adventurer, Polizei Swat. Die Waffe (EnemyProfile.weapon bzw. Pistole, Gewehr oder
## Brechstange nach style) hängt am Handknochen Wrist.R, die Mündung am Lauf. Statusleuchte als Implantat am Kopf, Taschenlampe an der
## Brust. Animationen aus der Figur: Idle/Idle_Gun, Walk, Run, Idle_Gun_Pointing und Run_Shoot beim
## Zielen, Gun_Shoot, Punch/Sword_Slash beim Nahkampf, HitRecieve, Death. Der AnimationPlayer läuft
## nur in animate(), die LOD-Stufen des EnemyDirector bleiben wirksam.

const DIR := "res://assets/characters/quaternius_modular_men/"
const PISTOL_VIEW := preload("res://scenes/weapons/pistol_view.tscn")
const RIFLE_VIEW := preload("res://scenes/weapons/sniper_view.tscn")
const HEIGHT := 1.8
const WALK_SPEED := 1.6
const RUN_SPEED := 4.4
const BLEND := 0.18
const ANIM_PREFIX := "CharacterArmature|"
## Waffe in der Hand: Lauf (Waffe -Z) entlang des Unterarms (Knochen +Y), Waffe oben = Knochen -X.
const GRIP_BASIS := Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
## Griff liegt so weit vor dem Handgelenk (Meter, entlang des Knochens).
const GRIP_OFFSET := 0.07

var look_name := ""

var _anim: AnimationPlayer
var _current := ""
var _hit_left := 0.0
var _armed := false

static var _scenes := {}
static var _heights := {}


func build(profile: EnemyProfile, variant_seed: int) -> void:
	_rng.seed = variant_seed
	_style = profile.style
	_status_mat = StandardMaterial3D.new()
	_status_mat.emission_enabled = true
	_status_mat.emission_energy_multiplier = 3.0
	set_status_color(Color(0.0, 0.95, 1.0))
	look_name = _look_for(profile)
	var scene := _scene(look_name)
	if scene == null:
		super.build(profile, variant_seed)
		return
	var body: Node3D = scene.instantiate()
	body.name = "Character"
	# Die Figuren schauen nach +Z, Gegner nach -Z.
	body.rotation.y = PI
	body.scale = Vector3.ONE * (HEIGHT / _height(look_name, body))
	add_child(body)
	var skeleton := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_armed = profile.style != EnemyProfile.Style.MELEE
	_attach_weapon(profile, skeleton)
	_attach_status(skeleton)
	if profile.look == EnemyProfile.Look.SECURITY:
		_attach_flashlight(skeleton)
	var players := body.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_anim = players[0] as AnimationPlayer
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for name: String in ["Idle", "Idle_Gun", "Walk", "Run", "Run_Shoot", "Idle_Gun_Pointing", "Idle_Neutral"]:
			var a := _anim.get_animation(ANIM_PREFIX + name)
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR
		_play(_idle_name(), 0.0)
		_anim.advance(_rng.randf() * 2.0)


func animate(delta: float) -> void:
	if _anim == null:
		super.animate(delta)
		return
	if _dead:
		_anim.advance(delta)
		return
	flinch = maxf(flinch - delta * 3.5, 0.0)
	_hit_left = maxf(_hit_left - delta, 0.0)
	if flinch > 0.6 and _hit_left <= 0.0:
		_hit_left = 0.45
		_anim.speed_scale = 1.0
		_play("HitRecieve", 0.05)
	elif _hit_left <= 0.0:
		_choose(delta)
	_anim.advance(delta)


func _choose(_delta: float) -> void:
	_anim.speed_scale = 1.0
	if stunned:
		_play("Idle_Neutral")
		_anim.speed_scale = 0.3
	elif _style == EnemyProfile.Style.MELEE and attack > 0.0:
		_play("Punch_Right", 0.08)
		_anim.speed_scale = 1.4
	elif aim > 0.5 and _armed:
		if speed > 0.6:
			_play("Run_Shoot")
			_anim.speed_scale = clampf(speed / RUN_SPEED, 0.6, 1.4)
		else:
			_play("Idle_Gun_Pointing")
	elif speed < 0.25:
		_play(_idle_name())
	elif speed < (WALK_SPEED + RUN_SPEED) * 0.5:
		_play("Walk")
		_anim.speed_scale = clampf(speed / WALK_SPEED, 0.6, 1.8)
	else:
		_play("Run")
		_anim.speed_scale = clampf(speed / RUN_SPEED, 0.7, 1.6)


func fall(direction: Vector3) -> void:
	if _anim == null:
		super.fall(direction)
		return
	_dead = true
	var local := global_basis.inverse() * direction
	local.y = 0.0
	if local.length() > 0.01:
		rotation.y += atan2(-local.x, -local.z)
	_anim.speed_scale = 1.0
	_play("Death", 0.05)
	if laser != null:
		laser.visible = false
	if flashlight != null:
		create_tween().tween_property(flashlight, "light_energy", 0.0, 0.6)


func _idle_name() -> String:
	return "Idle_Gun" if _armed else "Idle"


func _play(name: String, blend := BLEND) -> void:
	if _current == name or _anim == null:
		return
	var full := ANIM_PREFIX + name
	if not _anim.has_animation(full):
		return
	_current = name
	_anim.play(full, blend)


func _look_for(profile: EnemyProfile) -> String:
	match profile.look:
		EnemyProfile.Look.SECURITY:
			return "Business Man"
		EnemyProfile.Look.SNIPER:
			return "Adventurer"
		EnemyProfile.Look.COP:
			return "Swat"
		_:
			return ["Punk", "Hoodie Character", "Casual Character"][_rng.randi() % 3]


## Knoten am Knochen, dessen Kinder in Metern und ohne die Skalierung der Figur liegen.
func _bone_holder(skeleton: Skeleton3D, bone: String) -> Node3D:
	var attach := BoneAttachment3D.new()
	attach.bone_name = bone
	skeleton.add_child(attach)
	var holder := Node3D.new()
	holder.scale = Vector3.ONE / attach.global_basis.get_scale().x
	attach.add_child(holder)
	return holder


func _attach_weapon(profile: EnemyProfile, skeleton: Skeleton3D) -> void:
	var hand := _bone_holder(skeleton, "Wrist.R")
	_weapon = Node3D.new()
	_weapon.name = "Weapon"
	_weapon.transform = Transform3D(GRIP_BASIS, Vector3(0, GRIP_OFFSET, 0))
	hand.add_child(_weapon)
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	match profile.style:
		EnemyProfile.Style.PISTOL, EnemyProfile.Style.RIFLE:
			var scene: PackedScene = RIFLE_VIEW if profile.style == EnemyProfile.Style.RIFLE else PISTOL_VIEW
			if profile.weapon != null and profile.weapon.view_scene != null:
				scene = profile.weapon.view_scene
			var view: Node3D = scene.instantiate()
			view.name = "Gun"
			_weapon.add_child(view)
			# Mündungsfeuer macht Enemy selbst (Licht an der Mündung).
			for flash: String in ["Muzzle/Flash", "Muzzle/FlashLight"]:
				var node := view.get_node_or_null(flash)
				if node != null:
					node.get_parent().remove_child(node)
					node.free()
			var tip := view.get_node_or_null("Muzzle") as Node3D
			muzzle.position = tip.position if tip != null else Vector3(0, 0.05, -0.2)
			if profile.style == EnemyProfile.Style.RIFLE:
				_add_laser()
		_:
			var bar := ConsumableModel.build(ConsumableModel.CROWBAR, profile.accent)
			# Brechstange: Griff in der Hand, Schaft nach vorn-oben (Waffe -Z = Unterarm).
			bar.rotation.x = -PI * 0.5
			bar.position = Vector3(0, 0, 0.08)
			_weapon.add_child(bar)
			muzzle.position = Vector3(0, 0, -0.45)
	_weapon.add_child(muzzle)


func _add_laser() -> void:
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


## Leuchtendes Implantat an der Schläfe in der Statusfarbe (Cyan ruhig, Gelb Verdacht, Rot Kampf).
func _attach_status(skeleton: Skeleton3D) -> void:
	var head := _bone_holder(skeleton, "Head")
	var mesh := MeshInstance3D.new()
	mesh.name = "StatusLight"
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.05, 0.08)
	mesh.mesh = box
	mesh.material_override = _status_mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Kopfknochen: +Y nach oben, +Z nach vorn (die Figur schaut nach +Z).
	mesh.position = Vector3(-0.1, 0.12, 0.05)
	head.add_child(mesh)


func _attach_flashlight(skeleton: Skeleton3D) -> void:
	var chest := _bone_holder(skeleton, "Chest")
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.spot_range = 16.0
	flashlight.spot_angle = 28.0
	flashlight.spot_attenuation = 0.8
	flashlight.light_energy = 2.4
	flashlight.light_color = Color(0.85, 0.95, 1.0)
	flashlight.shadow_enabled = false
	# Leuchtet nach vorn (Brust +Z), leicht nach unten.
	flashlight.position = Vector3(0.15, 0.2, 0.15)
	flashlight.rotation = Vector3(deg_to_rad(10.0), PI, 0)
	chest.add_child(flashlight)


static func _scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		_scenes[name] = load(DIR + name + ".glb")
	return _scenes[name]


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
