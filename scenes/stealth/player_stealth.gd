class_name PlayerStealth
extends Node
## Schleichen: Wie gut ist der Spieler zu sehen, wie laut ist er?
##
## Hängt als Kind %PlayerStealth am Player.
## - `visibility` (0…1): Licht an der Stelle des Spielers (Lampen in Reichweite mit Sichtlinie,
##   Mond nur unter freiem Himmel), mal Haltung (Hocken, Rutschen) und Bewegung.
##   Gegner multiplizieren damit, wie schnell sie den Spieler bemerken.
## - Geräusche: Schritte (Hocken leise, Sprinten laut), Landungen (je tiefer, desto lauter),
##   Rutschen, Klettern. Gehen über StealthNoise an alle Gegner in Hörweite.
##   Waffen und Granaten melden sich über `make_noise()` bzw. StealthNoise selbst.
## - Kleine Anzeige unter den Vitals: SICHT, LÄRM und der Status der Gegner.

## Meter Hörweite pro Schritt.
@export var crouch_step_radius := 2.5
@export var walk_step_radius := 7.0
@export var sprint_step_radius := 14.0
@export var slide_radius := 8.0
@export var climb_radius := 4.0
## Landung: ab dieser Aufprallgeschwindigkeit hörbar, Radius wächst bis land_max_radius.
@export var land_min_speed := 3.5
@export var land_max_radius := 22.0
## Grundhelligkeit der Nacht (ohne Lampe).
@export var ambient_light := 0.06
## Wie oft das Licht neu gemessen wird (pro Sekunde).
@export var light_updates_per_second := 8.0
@export var show_hud := true

## 0 = unsichtbar, 1 = voll beleuchtet und auffällig.
var visibility := 0.0
## Nur das Licht an der Stelle (0…1), ohne Haltung und Bewegung.
var light_level := 0.0
## Für die Anzeige: letzter Lärm, klingt ab.
var noise_level := 0.0
## Höchster Wert, den ein Gegner gerade meldet (0 = keiner, 0,35 = Verdacht, 1 = entdeckt).
var detection := 0.0

var _player: Player
var _lights: Array[Light3D] = []
var _light_timer := 0.0
var _rescan_timer := 0.0
var _step_timer := 0.0
var _slide_timer := 0.0
var _was_on_floor := true
var _air_speed := 0.0
var _reports := {}
var _hud: StealthHud


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_error("PlayerStealth muss ein Kind des Players sein.")
		set_physics_process(false)
		return
	var movement := _player.get_node_or_null("%PlayerMovement") as PlayerMovement
	if movement != null:
		movement.mantle_started.connect(func(_h: float) -> void: make_noise(climb_radius, StealthNoise.CLIMB))
		movement.slide_started.connect(func() -> void: make_noise(slide_radius, StealthNoise.SLIDE))
	if show_hud:
		var layer := CanvasLayer.new()
		layer.name = "StealthHudLayer"
		layer.layer = 2
		add_child(layer)
		_hud = StealthHud.new()
		_hud.stealth = self
		layer.add_child(_hud)
	_rescan_lights.call_deferred()


func _physics_process(delta: float) -> void:
	noise_level = maxf(noise_level - delta * 0.6, 0.0)
	_update_reports(delta)
	if _player.noclip:
		_was_on_floor = true
		_air_speed = 0.0
		visibility = 0.0
		return
	_update_steps(delta)
	_update_landing()
	_rescan_timer -= delta
	if _rescan_timer <= 0.0:
		_rescan_timer = 3.0
		_rescan_lights()
	_light_timer -= delta
	if _light_timer <= 0.0:
		_light_timer = 1.0 / maxf(light_updates_per_second, 1.0)
		light_level = measure_light(_player.global_position + Vector3.UP * 0.9)
	visibility = _compute_visibility()


## Ein Geräusch des Spielers (auch für Waffen). radius in Metern.
func make_noise(radius: float, kind: StringName = StealthNoise.STEP) -> void:
	if radius <= 0.0 or _player == null:
		return
	noise_level = maxf(noise_level, clampf(radius / 20.0, 0.0, 1.0))
	StealthNoise.emit(get_tree(), _player.global_position + Vector3.UP * 0.3, radius, _player, kind)


## Gegner melden, wie weit sie den Spieler bemerkt haben (0…1). Ohne Meldung fällt es ab.
func report_awareness(watcher: Node, amount: float) -> void:
	_reports[watcher.get_instance_id()] = [amount, 0.3]


func _update_reports(delta: float) -> void:
	detection = 0.0
	for id: int in _reports.keys():
		var entry: Array = _reports[id]
		entry[1] -= delta
		if entry[1] <= 0.0 or not is_instance_id_valid(id):
			_reports.erase(id)
			continue
		detection = maxf(detection, entry[0])


func _update_steps(delta: float) -> void:
	var movement := _player.movement
	if movement != null and movement.is_sliding():
		_slide_timer -= delta
		if _slide_timer <= 0.0:
			_slide_timer = 0.35
			make_noise(slide_radius * 0.6, StealthNoise.SLIDE)
		return
	if not _player.is_on_floor():
		_step_timer = 0.0
		return
	var horiz := Vector2(_player.velocity.x, _player.velocity.z).length()
	if horiz < 0.6:
		_step_timer = 0.0
		return
	var crouching := movement != null and movement.crouching
	var sprinting := _player.stats.is_sprinting()
	var interval := 0.62 if crouching else (0.3 if sprinting else 0.46)
	_step_timer += delta
	if _step_timer < interval:
		return
	_step_timer = 0.0
	var radius := walk_step_radius
	if crouching:
		radius = crouch_step_radius
	elif sprinting:
		radius = sprint_step_radius
	else:
		# Langsames Gehen ist leiser.
		radius *= clampf(horiz / _player.walk_speed, 0.5, 1.0)
	make_noise(radius, StealthNoise.STEP)


func _update_landing() -> void:
	var on_floor := _player.is_on_floor()
	if not on_floor:
		_air_speed = minf(_air_speed, _player.velocity.y)
	elif not _was_on_floor:
		var speed := -_air_speed
		if speed >= land_min_speed:
			var t := clampf((speed - land_min_speed) / 12.0, 0.0, 1.0)
			var radius := lerpf(6.0, land_max_radius, t)
			if _player.movement != null and _player.movement.crouching:
				radius *= 0.7
			make_noise(radius, StealthNoise.LAND)
		_air_speed = 0.0
	_was_on_floor = on_floor


func _compute_visibility() -> float:
	var v := 0.08 + 0.92 * light_level
	var movement := _player.movement
	if movement != null:
		if movement.is_sliding():
			v *= 0.8
		elif movement.crouching:
			v *= 0.55
	var horiz := Vector2(_player.velocity.x, _player.velocity.z).length()
	if horiz < 0.3:
		v *= 0.75
	elif _player.stats.is_sprinting():
		v *= 1.25
	return clampf(v, 0.0, 1.0)


func _rescan_lights() -> void:
	_lights.clear()
	# Die Szene, in der der Player steckt (Testmap), sonst die aktuelle.
	var scene := _player.owner if _player.owner != null else get_tree().current_scene
	if scene == null:
		return
	for node: Node in scene.find_children("*", "Light3D", true, false):
		# Das Fülllicht der Hände zählt nicht.
		if _player.is_ancestor_of(node):
			continue
		_lights.append(node as Light3D)


## Helligkeit (0…1) an einem Punkt aus allen Lampen mit Sichtlinie.
func measure_light(point: Vector3) -> float:
	var space := _player.get_world_3d().direct_space_state
	var total := ambient_light
	for light: Light3D in _lights:
		if not is_instance_valid(light) or not light.is_visible_in_tree() or light.light_energy <= 0.0:
			continue
		var color := light.light_color
		var strength := light.light_energy * (color.r * 0.3 + color.g * 0.55 + color.b * 0.15)
		if light is DirectionalLight3D:
			# Mond/Sonne: nur unter freiem Himmel.
			var to_sky := light.global_basis.z.normalized()
			var query := PhysicsRayQueryParameters3D.create(point, point + to_sky * 80.0, 1, [_player.get_rid()])
			if space.intersect_ray(query).is_empty():
				total += strength * 0.12
			continue
		var reach: float = 0.0
		if light is OmniLight3D:
			reach = (light as OmniLight3D).omni_range
		elif light is SpotLight3D:
			reach = (light as SpotLight3D).spot_range
		var offset := point - light.global_position
		var d := offset.length()
		if d >= reach or reach <= 0.0:
			continue
		if light is SpotLight3D:
			var spot := light as SpotLight3D
			var angle := rad_to_deg((-light.global_basis.z).angle_to(offset))
			if angle > spot.spot_angle:
				continue
			strength *= 1.0 - smoothstep(spot.spot_angle * 0.7, spot.spot_angle, angle)
		var falloff := pow(1.0 - d / reach, 1.6)
		if falloff * strength < 0.01:
			continue
		var occlude := PhysicsRayQueryParameters3D.create(light.global_position, point, 1, [_player.get_rid()])
		var hit := space.intersect_ray(occlude)
		# Der Gegner selbst (Taschenlampe am Kopf) verdeckt nichts.
		if not hit.is_empty() and not light.is_ancestor_of(hit.collider) and hit.collider != light.get_parent():
			if not (hit.collider is Node and (hit.collider as Node).is_ancestor_of(light)):
				continue
		total += strength * falloff * 0.6
	return clampf(1.0 - exp(-total * 1.4), 0.0, 1.0)
