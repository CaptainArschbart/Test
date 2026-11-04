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

const DIR := "res://assets/characters/quaternius_modular_men/"
## König und Astronaut passen nicht auf die Straße.
const LOOKS := ["Adventurer", "Beach Character", "Business Man", "Casual Character", "Farmer",
	"Hoodie Character", "Punk", "Swat", "Worker"]
const HEIGHT := 1.75
## Tempo (m/s), bei dem Walk bzw. Run in Originalgeschwindigkeit läuft.
const WALK_SPEED := 1.4
const RUN_SPEED := 4.0
const BLEND := 0.2
const ANIM_PREFIX := "CharacterArmature|"
## So lange wartet das Aufstehen höchstens darauf, dass der Ragdoll still liegt.
const RISE_WAIT := 1.6

## Welche Figur (Name aus LOOKS), leer = per Seed.
var look := ""

var _anim: AnimationPlayer
var _current := ""
var _hit_left := 0.0
var _rise_left := 0.0
## Wartet aufs Aufstehen (Ragdoll rutscht noch oder dreht sich aus der Bauchlage), höchstens so lange.
var _rise_wait := 0.0
## Aufstehen: Animation steht auf Bild 0, bis der Ragdoll hineingefahren ist.
var _rise_hold := false

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
	body.scale = Vector3.ONE * (HEIGHT / _height(look, body))
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
		UalLibrary.attach(_anim)
		for name: String in ["Idle", "Walk", "Run", "Idle_Neutral", "Idle_Gun_Pointing"]:
			var a := _anim.get_animation(ANIM_PREFIX + name)
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR
		# Jede Figur beginnt an einer anderen Stelle, sonst laufen alle im Gleichschritt.
		_play("Idle", 0.0)
		_anim.advance(_rng.randf() * 2.0)


func animate(delta: float) -> void:
	if _anim == null:
		super.animate(delta)
		return
	flinch = maxf(flinch - delta * 3.5, 0.0)
	_hit_left = maxf(_hit_left - delta, 0.0)
	if _rise_wait > 0.0:
		_rise_wait -= delta
		var rolling := ragdoll != null and ragdoll.running and ragdoll.is_rolling()
		var calm := ragdoll == null or not ragdoll.running or ragdoll.max_speed() < RISE_MAX_SPEED
		# Nach dem Umdrehen gleich weiter, sonst erst nach kurzer Ruhe.
		if not rolling and (_rise_wait <= 0.0 or _rolls > 0 or calm and _rise_wait < RISE_WAIT - 0.5):
			_rise(_rise_wait <= 0.0)
	if _rise_hold:
		# Animation steht auf Bild 0, bis der Ragdoll hineingefahren ist (Physik-Takt).
		_rise_hold = ragdoll != null and ragdoll.is_matching()
		_anim.speed_scale = 0.0 if _rise_hold else 1.0
	if _rise_left > 0.0 and not _rise_hold:
		_rise_left -= delta
		if _rise_left <= 0.0:
			_dead = false
			if ground_clamp != null:
				ground_clamp.release()
	if not _dead:
		if flinch > 0.6 and _hit_left <= 0.0:
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
	_rise_left = 0.0
	_rise_wait = 0.0
	_rise_hold = false
	_rolls = 0
	if ground_clamp != null:
		ground_clamp.release()
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
	if _rise_left > 0.0 or _rise_wait > 0.0:
		return
	if ragdoll != null and ragdoll.running:
		_rise(false)
		return
	# Todesanimation (weit weg): zurück zu Idle blenden.
	rotation.y = 0.0
	_play("Idle", 0.3)
	_rise_left = time


## Aus dem Ragdoll aufstehen (LayToIdle). Rutscht er noch oder liegt auf dem Bauch: warten bzw. erst
## umdrehen (animate() ruft wieder). Ohne Animation: zurück zu Idle blenden.
func _rise(force: bool) -> void:
	_rise_wait = 0.0
	var length := _ragdoll_rise(_anim, force)
	if length < 0.0:
		_rise_wait = RISE_WAIT
		return
	if length > 0.0:
		_current = UalLibrary.GET_UP
		_anim.speed_scale = 0.0
		_rise_hold = true
		_rise_left = length
		return
	if ragdoll != null and ragdoll.running:
		ragdoll.blend_out(RISE_BLEND)
	rotation.y = 0.0
	_play("Idle", 0.3)
	_rise_left = 0.9


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
		_scenes[name] = load(DIR + name + ".glb")
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
