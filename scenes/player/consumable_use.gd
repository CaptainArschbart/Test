class_name ConsumableUse
extends Node
## Benutz-Animation für Verbrauchsitems in der Ego-Sicht (Injizieren, Trinken, Essen, Verband).
##
## Ablauf: Ziehen (draw) → Benutzen (use, Dauer aus ConsumableData.use_time) → Wegstecken (stow).
## Der Effekt (ItemUser.apply_consumable) greift erst am Ende von "use". Davor bricht die Animation
## ab, ohne etwas zu verbrauchen: Slot- oder Waffenwechsel (sofort), Schaden, Sprint, Klettern,
## Rutschen, Tod, Noclip, Inventar/Pause-Sperre (Item geht weich zurück in die Haltepose).
##
## Das Modell kommt aus ConsumableModel und liegt während der Animation im Raum des %ItemUser.
## Die rechte Hand greift es (ConsumableModel.GRIPS), die linke Hand folgt LEFT_POSES (z. B. Unterarm
## hinhalten, Lasche ziehen). PlayerHands fragt beides über ItemUser ab, die Hände bleiben dabei
## immer sichtbar. Sounds aus consumable_sounds.gd, Partikel und Bildschirm-Tönung hier im Code.
##
## Nur für die eigene Figur. Fremde Spieler (Multiplayer) sehen die Animation noch nicht.

signal finished(completed: bool)

const SOUNDS := preload("res://scenes/items/consumable_sounds.gd")

## Haltepose minus diesem Versatz = „unten aus dem Bild“ (Wegstecken, neues Item ziehen).
const LOW_OFFSET := Vector3(0.02, -0.3, 0.1)
const LOW_TILT := Vector3(35.0, 0.0, 0.0)
## Weiches Zurückgehen nach einem Abbruch.
const RETURN_TIME := 0.22

## Linke Hand (Format wie PlayerHands.POSE_*). "space": hands = Raum der Hände, item = Raum des Modells,
## Teilname (z. B. "Lid") = Raum dieses Modellteils. "follow" = Mindest-Überblendung pro Frame.
## "aim_arm": Unterarm zeigt zur linken Schulter statt mit der Hand mitzudrehen.
const LEFT_POSES := {
	# Unterarm quer vor dem Körper, Handfläche nach oben (Innenseite zeigt zur Kamera).
	&"arm": {
		"space": &"hands",
		"follow": 0.0,
		"pose": {
			"pos": Vector3(0.0, -0.165, -0.36),
			"fingers": Vector3(1.0, 0.2, -0.5),
			"back": Vector3(0.1, -1.0, 0.3),
			"curl": [[12.0, 14.0, 8.0], [14.0, 16.0, 8.0], [18.0, 18.0, 10.0], [22.0, 20.0, 10.0]],
			"spread": 6.0,
			"thumb": Vector3(-8.0, 38.0, 55.0),
			"thumb_curl": [6.0, 6.0],
		},
	},
	# Zeigefinger hakt oben an der Lasche der Dose ein.
	&"tab": {
		"space": &"item",
		"follow": 0.45,
		"aim_arm": true,
		"pose": {
			"pos": Vector3(-0.09, 0.085, 0.035),
			"fingers": Vector3(1.0, -0.3, -0.25),
			"back": Vector3(0.1, 1.0, 0.35),
			"curl": [[42.0, 58.0, 34.0], [62.0, 70.0, 36.0], [70.0, 74.0, 38.0], [74.0, 74.0, 38.0]],
			"spread": 1.5,
			"thumb": Vector3(-26.0, 20.0, 55.0),
			"thumb_curl": [20.0, 16.0],
		},
	},
	# Daumen und Zeigefinger kneifen die Lasche des Deckels (Raum des Deckels, Lasche bei z −0,096).
	&"lid": {
		"space": &"Lid",
		"follow": 0.45,
		"aim_arm": true,
		"pose": {
			"pos": Vector3(-0.075, 0.03, -0.14),
			"fingers": Vector3(0.65, -0.2, 0.55),
			"back": Vector3(-0.2, 0.9, 0.1),
			"curl": [[36.0, 40.0, 22.0], [56.0, 64.0, 32.0], [64.0, 68.0, 34.0], [68.0, 70.0, 34.0]],
			"spread": 2.0,
			"thumb": Vector3(-36.0, 8.0, 55.0),
			"thumb_curl": [16.0, 10.0],
		},
	},
}

## Animationen. Zeiten: [Phase, Anteil 0–1 der Phase]. Item-Schlüssel (Raum des %ItemUser):
##   {"pos", "rot"} feste Lage (Grad), {"hold": true} Haltepose, {"low": true} unten aus dem Bild,
##   {"at": "arm", "lift": m, "rot"} Nadelspitze auf dem linken Unterarm (lift = Abstand),
##   {"orbit": Grad} Rolle kreist um den linken Unterarm (Verband).
## Linke Hand: Schlüssel aus LEFT_POSES oder "rest" (locker unten), gilt ab ihrer Zeit.
## Ereignisse: ["sound", Name], ["show"/"hide", Teil], ["part", Teil, Eigenschaft, Wert, Dauer],
##   ["fx", Name]. Ein Ereignis feuert einmal, sobald seine Zeit erreicht ist.
const ANIMATIONS := {
	&"inject": {
		"label": "INJIZIEREN",
		"draw": 0.3, "use": 1.2, "stow": 0.3,
		"items": [
			[&"draw", 0.0, {"hold": true}],
			[&"draw", 1.0, {"pos": Vector3(-0.07, 0.035, 0.02), "rot": Vector3(5.0, 0.0, -22.0)}],
			[&"use", 0.16, {"pos": Vector3(-0.1, 0.06, 0.03), "rot": Vector3(0.0, 0.0, -40.0)}],
			[&"use", 0.42, {"at": &"arm", "lift": 0.07, "rot": Vector3(0.0, 0.0, -40.0)}],
			[&"use", 0.5, {"at": &"arm", "lift": 0.0, "rot": Vector3(0.0, 0.0, -40.0)}],
			[&"use", 0.88, {"at": &"arm", "lift": 0.0, "rot": Vector3(0.0, 0.0, -40.0)}],
			[&"use", 1.0, {"at": &"arm", "lift": 0.08, "rot": Vector3(0.0, 0.0, -34.0)}],
			[&"stow", 1.0, {"low": true}],
		],
		"left": [[&"draw", 0.0, &"arm"], [&"stow", 0.0, &"rest"]],
		"events": [
			[&"draw", 0.0, ["sound", &"rustle"]],
			[&"use", 0.1, ["sound", &"cap"]],
			[&"use", 0.1, ["hide", "Cap"]],
			[&"use", 0.1, ["fx", &"cap"]],
			[&"use", 0.5, ["sound", &"hiss"]],
			[&"use", 0.5, ["fx", &"inject"]],
			[&"use", 0.5, ["part", "Plunger", "position:y", -0.009, 0.36]],
			[&"use", 0.5, ["part", "Fluid", "scale:y", 0.04, 0.38]],
			[&"use", 0.88, ["sound", &"click"]],
			[&"stow", 0.0, ["sound", &"stow"]],
		],
	},
	&"drink": {
		"label": "TRINKEN",
		"draw": 0.3, "use": 1.7, "stow": 0.35,
		"items": [
			[&"draw", 0.0, {"hold": true}],
			[&"draw", 1.0, {"pos": Vector3(-0.09, 0.03, 0.0), "rot": Vector3(12.0, -10.0, 0.0)}],
			[&"use", 0.22, {"pos": Vector3(-0.09, 0.03, 0.0), "rot": Vector3(12.0, -10.0, 0.0)}],
			[&"use", 0.27, {"pos": Vector3(-0.09, 0.036, 0.0), "rot": Vector3(16.0, -10.0, 0.0)}],
			[&"use", 0.47, {"pos": Vector3(-0.175, 0.1, 0.21), "rot": Vector3(100.0, -4.0, -6.0)}],
			[&"use", 0.62, {"pos": Vector3(-0.18, 0.108, 0.225), "rot": Vector3(110.0, -4.0, -6.0)}],
			[&"use", 0.78, {"pos": Vector3(-0.18, 0.112, 0.228), "rot": Vector3(118.0, -4.0, -6.0)}],
			[&"use", 0.94, {"pos": Vector3(-0.18, 0.116, 0.23), "rot": Vector3(126.0, -4.0, -6.0)}],
			[&"use", 1.0, {"pos": Vector3(-0.16, 0.07, 0.17), "rot": Vector3(80.0, -5.0, -8.0)}],
			[&"stow", 1.0, {"low": true}],
		],
		"left": [[&"draw", 0.0, &"tab"], [&"use", 0.34, &"rest"]],
		"events": [
			[&"draw", 0.0, ["sound", &"rustle"]],
			[&"use", 0.22, ["sound", &"can_open"]],
			[&"use", 0.22, ["part", "Tab", "rotation:x", 1.25, 0.08]],
			[&"use", 0.22, ["show", "Mouth"]],
			[&"use", 0.22, ["fx", &"fizz"]],
			[&"use", 0.3, ["part", "Tab", "rotation:x", 0.2, 0.2]],
			[&"use", 0.58, ["sound", &"gulp"]],
			[&"use", 0.73, ["sound", &"gulp"]],
			[&"use", 0.88, ["sound", &"gulp"]],
			[&"stow", 0.0, ["sound", &"stow"]],
		],
	},
	&"eat": {
		"label": "ESSEN",
		"draw": 0.3, "use": 2.4, "stow": 0.35,
		"items": [
			[&"draw", 0.0, {"hold": true}],
			[&"draw", 1.0, {"pos": Vector3(-0.1, 0.0, -0.02), "rot": Vector3(32.0, -5.0, 0.0)}],
			[&"use", 0.34, {"pos": Vector3(-0.1, 0.005, -0.02), "rot": Vector3(34.0, -5.0, 0.0)}],
			[&"use", 0.46, {"pos": Vector3(-0.155, 0.04, 0.12), "rot": Vector3(52.0, 0.0, -5.0)}],
			[&"use", 0.6, {"pos": Vector3(-0.16, 0.05, 0.135), "rot": Vector3(64.0, 0.0, -5.0)}],
			[&"use", 0.7, {"pos": Vector3(-0.155, 0.04, 0.12), "rot": Vector3(54.0, 0.0, -5.0)}],
			[&"use", 0.84, {"pos": Vector3(-0.16, 0.05, 0.135), "rot": Vector3(66.0, 0.0, -5.0)}],
			[&"use", 0.95, {"pos": Vector3(-0.16, 0.052, 0.135), "rot": Vector3(72.0, 0.0, -5.0)}],
			[&"use", 1.0, {"pos": Vector3(-0.15, 0.05, 0.14), "rot": Vector3(55.0, 0.0, -5.0)}],
			[&"stow", 1.0, {"low": true}],
		],
		"left": [[&"draw", 0.0, &"lid"], [&"use", 0.36, &"rest"]],
		"events": [
			[&"draw", 0.0, ["sound", &"rustle"]],
			[&"use", 0.1, ["sound", &"foil"]],
			[&"use", 0.1, ["part", "Lid", "rotation:x", 2.5, 0.26]],
			[&"use", 0.3, ["fx", &"steam"]],
			[&"use", 0.52, ["sound", &"slurp"]],
			[&"use", 0.78, ["sound", &"slurp"]],
			[&"use", 0.96, ["hide", "Noodles"]],
			[&"stow", 0.0, ["sound", &"stow"]],
		],
	},
	&"bandage": {
		"label": "VERBINDEN",
		"draw": 0.3, "use": 3.0, "stow": 0.35,
		"items": [
			[&"draw", 0.0, {"hold": true}],
			[&"draw", 1.0, {"pos": Vector3(-0.08, 0.02, 0.0), "rot": Vector3(0.0, 0.0, -10.0)}],
			[&"use", 0.1, {"pos": Vector3(-0.1, 0.035, 0.0), "rot": Vector3(0.0, 20.0, 30.0)}],
			[&"use", 0.2, {"orbit": 0.0}],
			[&"use", 0.86, {"orbit": 900.0}],
			[&"use", 0.93, {"orbit": 900.0}],
			[&"use", 1.0, {"pos": Vector3(-0.09, 0.03, 0.0), "rot": Vector3(0.0, 0.0, -10.0)}],
			[&"stow", 1.0, {"low": true}],
		],
		"left": [[&"draw", 0.0, &"arm"], [&"stow", 0.0, &"rest"]],
		"events": [
			[&"draw", 0.0, ["sound", &"rustle"]],
			[&"use", 0.06, ["sound", &"tear"]],
			[&"use", 0.2, ["fx", &"wrap"]],
			[&"use", 0.24, ["sound", &"wrap"]],
			[&"use", 0.46, ["sound", &"wrap"]],
			[&"use", 0.68, ["sound", &"wrap"]],
			[&"use", 0.9, ["sound", &"click"]],
			[&"use", 0.9, ["fx", &"nano"]],
			[&"stow", 0.0, ["sound", &"stow"]],
		],
	},
}

## Einstichstelle auf dem linken Unterarm (Raum des Unterarms der Hände: +Z Richtung Ellbogen,
## −Y = Innenseite, die beim Hinhalten nach oben zeigt).
const ARM_INJECT_POINT := Vector3(0.0, -0.046, 0.052)
## Verband: Mitte und Radius der Wickelbahn um den Unterarm.
const ARM_WRAP_CENTER := Vector3(0.0, 0.0, 0.035)
const ORBIT_RADIUS := 0.075

enum State { IDLE, ACTIVE, RETURN }

var _player: Player
var _item_user: ItemUser
var _state := State.IDLE
var _item: ConsumableData
var _slot := -1
var _anim: Dictionary
var _time := 0.0
var _draw_end := 0.0
var _use_end := 0.0
var _total := 0.0
var _applied := false
var _fired: Array[bool] = []
var _view: Node3D
var _left_key: StringName = &"rest"
var _return_from: Transform3D
var _last_hp := 0.0
var _wrap: MeshInstance3D
var _audio: AudioStreamPlayer
var _hud: CanvasLayer
var _bar_back: ColorRect
var _bar_fill: ColorRect
var _bar_label: Label
var _tint: ColorRect
var _tint_tween: Tween


func setup(player: Player, item_user: ItemUser) -> void:
	_player = player
	_item_user = item_user
	_audio = AudioStreamPlayer.new()
	_audio.name = "ConsumableAudio"
	_audio.bus = &"SFX"
	_audio.max_polyphony = 4
	_audio.volume_db = -4.0
	add_child(_audio)
	_create_hud()
	_player.stats.stat_changed.connect(_on_stat_changed)
	_last_hp = _player.stats.hp


static func has_animation(name: StringName) -> bool:
	return ANIMATIONS.has(name)


func is_active() -> bool:
	return _state != State.IDLE


## Noch vor dem Effekt (Abbrechen möglich).
func is_using() -> bool:
	return _state == State.ACTIVE and not _applied


## Startet die Animation für `item` aus Slot `slot`. false, wenn schon eine läuft.
func start(item: ConsumableData, slot: int) -> bool:
	if is_active() or not has_animation(item.use_animation):
		return false
	_item = item
	_slot = slot
	_anim = ANIMATIONS[item.use_animation]
	var use_time: float = item.use_time if item.use_time > 0.0 else _anim.use
	_draw_end = _anim.draw
	_use_end = _draw_end + use_time
	_total = _use_end + _anim.stow
	_time = 0.0
	_applied = false
	_fired.clear()
	_fired.resize((_anim.events as Array).size())
	_fired.fill(false)
	_left_key = &"rest"
	_last_hp = _player.stats.hp
	_view = ConsumableModel.build(item.model, item.color, true)
	_view.name = "UseView"
	_item_user.add_child(_view)
	_view.transform = _item_transform(0.0)
	_state = State.ACTIVE
	_bar_label.text = _anim.label
	_bar_fill.color = item.color
	_hud.visible = true
	_update_bar()
	return true


func get_item() -> ConsumableData:
	return _item


## Modell während der Animation (für die Griffpose der Hände), sonst null.
func get_view() -> Node3D:
	return _view if is_active() else null


## Ziel der linken Hand: {"pose", "space" (Raum der Hände), "follow"} oder leer = locker.
func get_left_target() -> Dictionary:
	if _state != State.ACTIVE or not LEFT_POSES.has(_left_key):
		return {}
	var entry: Dictionary = LEFT_POSES[_left_key]
	var space := Transform3D.IDENTITY
	match entry.space:
		&"hands":
			space = Transform3D.IDENTITY
		&"item":
			space = _item_user.transform * _view.transform
		_:
			var part := _view.get_node_or_null(NodePath(String(entry.space))) as Node3D
			space = _item_user.transform * _view.transform
			if part != null:
				space = space * part.transform
	return {"pose": entry.pose, "space": space, "follow": entry.follow, "aim_arm": entry.get("aim_arm", false)}


## Bricht ab, solange der Effekt noch nicht gegriffen hat. `instant` = Modell sofort weg
## (Slotwechsel), sonst geht es weich zurück in die Haltepose.
func cancel(reason := "", instant := false) -> void:
	if not is_using():
		return
	_hud.visible = false
	_play(&"cancel")
	if reason != "":
		_item_user.show_message("%s abgebrochen: %s" % [_item.display_name, reason], Color(1.0, 0.35, 0.3))
	if instant or _view == null:
		_finish(false)
		return
	_state = State.RETURN
	_time = 0.0
	_return_from = _view.transform


func _process(delta: float) -> void:
	match _state:
		State.ACTIVE:
			_step(delta)
		State.RETURN:
			_time += delta
			var t := smoothstep(0.0, 1.0, minf(_time / RETURN_TIME, 1.0))
			var hold := ConsumableModel.hold_transform(_item.model)
			_view.transform = _blend(_return_from, hold, t)
			if _time >= RETURN_TIME:
				_finish(false)


func _step(delta: float) -> void:
	if not _applied:
		var reason := _cancel_reason()
		if reason != "":
			cancel(reason, reason == "Wechsel")
			return
	_time += delta
	_view.transform = _item_transform(_time)
	_left_key = _left_at(_time)
	_fire_events()
	_update_wrap()
	if not _applied and _time >= _use_end:
		_apply()
	if _hud.visible:
		_update_bar()
	if _time >= _total:
		_finish(true)


func _apply() -> void:
	_applied = true
	_hud.visible = false
	if not _item_user.apply_consumable(_item, _slot):
		return
	_play(&"heal")
	_flash_tint(_item.color)


func _finish(completed: bool) -> void:
	_state = State.IDLE
	_hud.visible = false
	_left_key = &"rest"
	if _view != null:
		_view.queue_free()
		_view = null
	if _wrap != null:
		var wrap := _wrap
		_wrap = null
		var tween := wrap.create_tween()
		tween.tween_property(wrap, "scale", Vector3(1.0, 0.01, 1.0), 0.25)
		tween.tween_callback(wrap.queue_free)
	finished.emit(completed)


## Grund zum Abbrechen, leer = weiter. "Wechsel" bricht ohne Rückweg ab.
func _cancel_reason() -> String:
	var inventory := _player.inventory
	if inventory.selected != _slot or not _item.is_same(inventory.get_item(_slot)):
		return "Wechsel"
	if not _player.stats.is_alive() or _player.dead:
		return "Wechsel"
	if _player.noclip:
		return "Wechsel"
	if _player.stats.is_sprinting():
		return "Sprint"
	var movement := _player.movement
	if movement != null and (movement.is_mantling() or movement.get_grab_weight() > 0.0):
		return "Klettern"
	if movement != null and movement.is_sliding():
		return "Rutschen"
	if _player.input_locked:
		return "Unterbrochen"
	return ""


func _on_stat_changed(stat_name: String, current: float, _maximum: float) -> void:
	if stat_name != PlayerStats.STAT_HP:
		return
	var lost := current < _last_hp - 0.01
	_last_hp = current
	# Hunger und Durst ziehen jedes Frame ein bisschen HP ab; das soll Essen nicht verhindern.
	var cause := _player.stats.last_damage_cause
	if lost and cause != PlayerStats.CAUSE_HUNGER and cause != PlayerStats.CAUSE_THIRST:
		cancel("Treffer")


# --- Zeitleiste ----------------------------------------------------------------

func _time_of(phase: StringName, fraction: float) -> float:
	match phase:
		&"draw":
			return _draw_end * fraction
		&"use":
			return _draw_end + (_use_end - _draw_end) * fraction
		_:
			return _use_end + (_total - _use_end) * fraction


func _item_transform(time: float) -> Transform3D:
	var keys: Array = _anim.items
	var prev: Array = keys[0]
	for i in keys.size():
		var key: Array = keys[i]
		var key_time := _time_of(key[0], key[1])
		if time <= key_time or i == keys.size() - 1:
			if i == 0:
				return _resolve(key[2])
			var prev_time := _time_of(prev[0], prev[1])
			var t := clampf((time - prev_time) / maxf(key_time - prev_time, 0.0001), 0.0, 1.0)
			var a: Dictionary = prev[2]
			var b: Dictionary = key[2]
			if a.has("orbit") and b.has("orbit"):
				# Gleichmäßig im Kreis, nicht von Punkt zu Punkt.
				return _orbit_transform(lerpf(a.orbit, b.orbit, t))
			return _blend(_resolve(a), _resolve(b), smoothstep(0.0, 1.0, t))
		prev = key
	return _resolve(prev[2])


func _resolve(key: Dictionary) -> Transform3D:
	var hold := ConsumableModel.hold_transform(_item.model)
	if key.has("hold"):
		return hold
	if key.has("low"):
		return Transform3D(hold.basis * ConsumableModel.euler_basis(LOW_TILT), hold.origin + LOW_OFFSET)
	if key.has("orbit"):
		return _orbit_transform(key.orbit)
	var basis := ConsumableModel.euler_basis(key.get("rot", Vector3.ZERO))
	if key.get("at", &"") == &"arm":
		# Nadelspitze auf die Einstichstelle, `lift` Meter darüber (entlang der Arm-Oberfläche).
		var arm := _arm_transform()
		var point := arm * ARM_INJECT_POINT
		var up := (arm.basis * Vector3.DOWN).normalized()
		var tip := basis * ConsumableModel.INJECTOR_TIP
		return Transform3D(basis, point + up * float(key.get("lift", 0.0)) - tip)
	return Transform3D(basis, key.get("pos", Vector3.ZERO))


## Rolle auf der Kreisbahn um den linken Unterarm, Achse parallel zum Arm. 0° = oben.
func _orbit_transform(degrees: float) -> Transform3D:
	var arm := _arm_transform()
	var angle := deg_to_rad(degrees)
	var local := ARM_WRAP_CENTER + Vector3(sin(angle), -cos(angle), 0.0) * ORBIT_RADIUS
	var basis := arm.basis * Basis(Vector3.RIGHT, PI * 0.5)
	return Transform3D(basis.orthonormalized(), arm * local)


## Linker Unterarm im Raum des %ItemUser (so wie er gerade wirklich steht).
func _arm_transform() -> Transform3D:
	var arm := _player.hands.get_arm_node(-1.0)
	var hands_space := arm.transform if arm != null else Transform3D.IDENTITY
	return _item_user.transform.affine_inverse() * hands_space


func _left_at(time: float) -> StringName:
	var result: StringName = &"rest"
	for key: Array in _anim.left:
		if time >= _time_of(key[0], key[1]):
			result = key[2]
	return result


func _fire_events() -> void:
	var events: Array = _anim.events
	for i in events.size():
		if _fired[i]:
			continue
		var event: Array = events[i]
		if _time < _time_of(event[0], event[1]):
			continue
		_fired[i] = true
		_run_event(event[2])


func _run_event(action: Array) -> void:
	match action[0]:
		"sound":
			_play(action[1])
		"show", "hide":
			var node := _view.get_node_or_null(NodePath(action[1])) as Node3D
			if node != null:
				node.visible = action[0] == "show"
		"part":
			var node := _view.get_node_or_null(NodePath(action[1])) as Node3D
			if node != null:
				var tween := node.create_tween()
				tween.set_trans(Tween.TRANS_SINE)
				tween.tween_property(node, NodePath(action[2]), action[3], action[4])
		"fx":
			_spawn_fx(action[1])


func _play(sound: StringName) -> void:
	var stream := SOUNDS.get_sound(sound)
	if stream == null or _audio == null:
		return
	_audio.stream = stream
	_audio.pitch_scale = randf_range(0.95, 1.05)
	_audio.play()


static func _blend(a: Transform3D, b: Transform3D, t: float) -> Transform3D:
	var q := Quaternion(a.basis.orthonormalized()).slerp(Quaternion(b.basis.orthonormalized()), t)
	return Transform3D(Basis(q), a.origin.lerp(b.origin, t))


# --- Effekte -------------------------------------------------------------------

func _spawn_fx(name: StringName) -> void:
	var color := _item.color
	match name:
		&"cap":
			_burst(_view, Vector3(0.0, -0.075, 0.0), color, 10, 0.25, 0.35, Vector3(0.0, -0.8, 0.0), 0.004)
		&"inject":
			# Feiner Nebel an der Nadel, dann leuchtende Funken, die den Arm hochwandern.
			_burst(_view, ConsumableModel.INJECTOR_TIP, Color(0.85, 1.0, 0.9), 24, 0.12, 0.5, Vector3(0.0, 0.25, 0.0), 0.006)
			var arm := _player.hands.get_arm_node(-1.0)
			if arm != null:
				_burst(arm, ARM_INJECT_POINT + Vector3(0.0, 0.0, 0.03), color, 30, 0.08, 0.9, Vector3(0.0, 0.0, 0.25), 0.004)
		&"fizz":
			_burst(_view, Vector3(0.0, 0.065, -0.01), Color(1.0, 0.85, 0.6), 26, 0.35, 0.45, Vector3(0.0, -1.2, 0.0), 0.003)
		&"steam":
			_steam(_view, Vector3(0.0, 0.05, 0.0))
		&"wrap":
			_start_wrap()
		&"nano":
			var arm := _player.hands.get_arm_node(-1.0)
			if arm != null:
				_burst(arm, ARM_WRAP_CENTER, Color(0.2, 1.0, 0.95), 40, 0.14, 0.8, Vector3.ZERO, 0.004)


## Einmaliger Partikelstoß (CPU, läuft in Forward+ und Compatibility).
func _burst(parent: Node3D, pos: Vector3, color: Color, amount: int, speed: float, lifetime: float,
		gravity: Vector3, size: float) -> CPUParticles3D:
	var particles := _particles(color, size)
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.85
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = gravity
	particles.position = pos
	parent.add_child(particles)
	particles.emitting = true
	get_tree().create_timer(lifetime + 0.3).timeout.connect(particles.queue_free)
	return particles


## Dampf über dem Nudelbecher, bis das Modell weg ist.
func _steam(parent: Node3D, pos: Vector3) -> void:
	var particles := _particles(Color(1.0, 1.0, 1.0, 0.35), 0.018)
	particles.amount = 18
	particles.lifetime = 1.1
	particles.direction = Vector3.UP
	particles.spread = 12.0
	particles.initial_velocity_min = 0.03
	particles.initial_velocity_max = 0.07
	particles.gravity = Vector3(0.0, 0.03, 0.0)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.03
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	particles.local_coords = false
	particles.position = pos
	parent.add_child(particles)
	particles.emitting = true


func _particles(color: Color, size: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 1.0, 1.0)
	mesh.material = material
	particles.mesh = mesh
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, color.a))
	ramp.set_color(1, Color(color, 0.0))
	particles.color_ramp = ramp
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.layers = 1 | PlayerHands.VIEWMODEL_LAYER
	return particles


## Verband um den linken Unterarm, wächst mit jeder Runde der Rolle.
func _start_wrap() -> void:
	var arm := _player.hands.get_arm_node(-1.0)
	if arm == null:
		return
	_wrap = MeshInstance3D.new()
	_wrap.name = "BandageWrap"
	_wrap.mesh = ProcMesh.tube(0.058, 0.06, 0.05)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.92, 0.95)
	material.roughness = 0.95
	material.emission_enabled = true
	material.emission = Color(0.2, 1.0, 0.95)
	material.emission_energy_multiplier = 0.15
	_wrap.material_override = material
	_wrap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wrap.layers = 1 | PlayerHands.VIEWMODEL_LAYER
	_wrap.position = ARM_WRAP_CENTER
	_wrap.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_wrap.scale = Vector3(1.0, 0.02, 1.0)
	arm.add_child(_wrap)


func _update_wrap() -> void:
	if _wrap == null or _applied:
		return
	var start := _time_of(&"use", 0.2)
	var end := _time_of(&"use", 0.86)
	var t := clampf((_time - start) / maxf(end - start, 0.01), 0.0, 1.0)
	_wrap.scale = Vector3(1.0, lerpf(0.02, 1.0, t), 1.0)


func _flash_tint(color: Color) -> void:
	if _tint_tween:
		_tint_tween.kill()
	_tint.color = Color(color, 0.0)
	_tint_tween = create_tween()
	_tint_tween.tween_property(_tint, "color:a", 0.2, 0.1)
	_tint_tween.tween_property(_tint, "color:a", 0.0, 0.9)


# --- Anzeige -------------------------------------------------------------------

func _update_bar() -> void:
	var length := _use_end
	var ratio := clampf(_time / maxf(length, 0.01), 0.0, 1.0)
	_bar_fill.size.x = _bar_back.size.x * ratio
	_bar_label.text = "%s  %.1fs" % [_anim.label, maxf(length - _time, 0.0)]


func _create_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "ConsumableHud"
	_hud.layer = 2
	_hud.visible = false
	add_child(_hud)
	var tint_layer := CanvasLayer.new()
	tint_layer.name = "ConsumableTint"
	tint_layer.layer = 1
	add_child(tint_layer)
	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = Color(0.0, 0.0, 0.0, 0.0)
	tint_layer.add_child(_tint)
	var width := 240.0
	_bar_back = ColorRect.new()
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.color = Color(0.02, 0.0, 0.06, 0.75)
	_bar_back.anchor_left = 0.5
	_bar_back.anchor_right = 0.5
	_bar_back.anchor_top = 0.5
	_bar_back.anchor_bottom = 0.5
	_bar_back.offset_left = -width * 0.5
	_bar_back.offset_right = width * 0.5
	_bar_back.offset_top = 112.0
	_bar_back.offset_bottom = 118.0
	_hud.add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.size = Vector2(0.0, 6.0)
	_bar_back.add_child(_bar_fill)
	_bar_label = Label.new()
	_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_label.anchor_left = 0.5
	_bar_label.anchor_right = 0.5
	_bar_label.anchor_top = 0.5
	_bar_label.anchor_bottom = 0.5
	_bar_label.offset_left = -200.0
	_bar_label.offset_right = 200.0
	_bar_label.offset_top = 86.0
	_bar_label.offset_bottom = 110.0
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_label.add_theme_font_size_override("font_size", 15)
	_bar_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.95))
	_bar_label.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.2))
	_bar_label.add_theme_constant_override("outline_size", 5)
	_hud.add_child(_bar_label)
