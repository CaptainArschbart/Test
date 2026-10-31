class_name CivilianCrime
extends Node
## Taschendiebstahl, bewaffneter Raub, Fesseln und Ausrauben für einen Civilian.
##
## Friedlich, solange niemand zielt, schlägt oder einbricht.
## Taschendiebstahl (leise): von hinten, im Hocken, langsam. E startet den Griff (PICK_TIME). Dabei
## steigt der Verdacht, schneller bei Licht und Lärm. Die Person bleibt solange stehen (Civilian fragt
## is_being_picked), läuft also nicht aus der Reichweite. Erreicht der Verdacht 100 %,
## merkt sie es: „Dieb!“, Flucht, Fahndung. Bleibt er darunter, keine Fahndung. Hocke verlassen,
## zu schnell oder nicht mehr hinter ihr: abgebrochen, ohne Beute. Beides sieht der Dieb als
## Doppel-Slider (PickpocketBar im ItemUser-HUD); laufende Griffe stehen in PICKING_GROUP.
## Bewaffneter Raub (laut): Waffe auf eine isolierte Person zielen, sie hebt die Hände, E fordert die
## Tasche. Ziel halten (ROB_TIME), dann gibt sie alles her. Waffe runter, bevor sie fertig ist:
## sie rennt weg. Lässt man sie nach dem Raub laufen, ruft sie die Polizei (eine Stufe mehr).
## Gefesselt wird sie nicht mehr gemeldet. Fesseln wie bisher: Hände oben oder ahnungslos.

const CUFFS := "handcuffs"
const TIES := "zipties"
const JEWELRY := preload("res://scenes/items/data/jewelry.tres")
const PHONE := preload("res://scenes/items/data/smartphone.tres")
const WATCH := preload("res://scenes/items/data/gold_watch.tres")
const QUIET_NOISE := 0.35
const QUIET_SPEED := 2.2
const PICK_TIME := 1.2
const PICK_REACH := 2.6
const ROB_TIME := 1.6
const PICKING_GROUP := &"pickpocket_running"

var held_up := false
var restrained := false
var pocket_cents := 0
var robbed := false
## Laufender Griff in die Tasche: 0–1, sonst -1.
var pick_progress := -1.0
## Verdacht beim Taschendiebstahl: ab 1 erwischt.
var suspicion := 0.0
## Laufende Übergabe beim bewaffneten Raub: 0–1, sonst -1.
var rob_progress := -1.0
var _threat_sent := false
var _aim_tick := 0.0
var _jewelry := false
var _phone := false
var _watch := false
var _armed_robbed := false
var _alert := 1.0
var _thief: Player
var _robber: Player
var _rng := RandomNumberGenerator.new()

var _body: Civilian


func _ready() -> void:
	_body = get_parent() as Civilian
	if _body == null:
		return
	pocket_cents = 2 + (_body.net_seed % 17)
	_jewelry = _body.net_seed % 3 == 0
	_rng.seed = _body.net_seed + 7
	_phone = _rng.randf() < 0.3
	_watch = _rng.randf() < 0.1


func prompt(player: Player) -> String:
	if _body == null or _body.is_dead():
		return ""
	if pick_progress >= 0.0:
		return "Klauen …"
	if rob_progress >= 0.0:
		return "Tasche her! … %d %%" % int(rob_progress * 100.0)
	if restrained and not robbed and not _pocket_empty():
		return "Ausrauben"
	if held_up and not restrained and not _armed_robbed:
		return "Ausrauben (bedroht)"
	if held_up and not restrained and _holding_restraint(player):
		return "Fesseln"
	if not restrained and _holding_restraint(player) and _unaware(player):
		return "Fesseln"
	if _can_pickpocket(player):
		return "Taschendiebstahl"
	return ""


func interact(player: Player) -> void:
	if _body == null or _body.is_dead() or WorldSync.is_client():
		return
	if pick_progress >= 0.0 or rob_progress >= 0.0:
		return
	if restrained and not robbed and not _pocket_empty():
		_rob(player)
		return
	if held_up and not restrained and not _armed_robbed:
		rob_progress = 0.0
		_robber = player
		_body.show_line("Okay, okay …")
		return
	if not restrained and _holding_restraint(player) and (held_up or _unaware(player)) and _consume_restraint(player):
		restrained = true
		_body.hold_up()
		player.item_user.show_message("Gefesselt.", Color(0.5, 0.9, 1.0))
		return
	if _can_pickpocket(player):
		pick_progress = 0.0
		suspicion = 0.0
		_alert = _rng.randf_range(0.6, 1.1)
		_thief = player
		add_to_group(PICKING_GROUP)


## Läuft gerade ein Griff in die Tasche? Dann bleibt die Person stehen.
func is_being_picked() -> bool:
	return pick_progress >= 0.0


## Der laufende Griff dieses Spielers, sonst null (für die Anzeige).
static func picked_by(player: Player) -> CivilianCrime:
	if player == null or not player.is_inside_tree():
		return null
	for node in player.get_tree().get_nodes_in_group(PICKING_GROUP):
		var crime := node as CivilianCrime
		if crime != null and crime.pick_progress >= 0.0 and crime._thief == player and not crime._body.is_dead():
			return crime
	return null


func _end_pick() -> void:
	pick_progress = -1.0
	_thief = null
	remove_from_group(PICKING_GROUP)


func on_burglary() -> void:
	if _body == null or _body.is_dead() or restrained:
		return
	_body.panic(_body.global_position)
	_body.show_line("Polizei!")
	_call_police(&"burglary")


func _physics_process(delta: float) -> void:
	if _body == null or _body.is_dead() or WorldSync.is_client():
		return
	if restrained:
		held_up = true
		if pick_progress >= 0.0:
			_end_pick()
		rob_progress = -1.0
		_body.hold_up()
		return
	if pick_progress >= 0.0:
		_pick_tick(delta)
	if rob_progress >= 0.0:
		var rob_time := ROB_TIME
		if _robber != null and is_instance_valid(_robber):
			rob_time *= _robber.skill_mult(&"rob_time_mult")
		rob_progress = minf(rob_progress + delta / rob_time, 1.0)
		if rob_progress >= 1.0:
			_hand_over()
	_aim_tick -= delta
	if _aim_tick > 0.0:
		return
	_aim_tick = 0.2
	var player := _aimed_player()
	if player == null:
		if held_up:
			_release()
		return
	if _isolated():
		held_up = true
		_body.hold_up()
		if not _threat_sent:
			_threat_sent = true
			_call_police(&"threat")
			_body.show_line("Hände hoch …")
	else:
		if rob_progress >= 0.0:
			_cancel_rob()
		held_up = false
		_body.panic(player.global_position)
		if not _threat_sent:
			_threat_sent = true
			_call_police(&"threat")


## Waffe runter: Raub abbrechen oder, nach dem Raub, die Polizei rufen. Danach weglaufen.
func _release() -> void:
	held_up = false
	_threat_sent = false
	if rob_progress >= 0.0:
		_cancel_rob()
	elif _armed_robbed:
		_body.show_line("Polizei!")
		_call_police(&"robbery")
	else:
		return
	_body.panic(_body.global_position)


func _cancel_rob() -> void:
	rob_progress = -1.0
	if _robber != null and is_instance_valid(_robber):
		_robber.item_user.show_message("Raub abgebrochen.", Color(0.8, 0.8, 0.8))
	_robber = null


func _hand_over() -> void:
	rob_progress = -1.0
	_armed_robbed = true
	var player := _robber
	_robber = null
	if player == null or not is_instance_valid(player):
		return
	var got := _empty_pocket(player)
	if got == "":
		_body.show_line("Ich hab nichts!")
		player.item_user.show_message("Nichts zu holen.", Color(0.8, 0.8, 0.8))
		return
	_body.show_line("Nimm's, nimm's!")
	player.item_user.show_message("Geraubt: " + got, Color(0.95, 0.85, 0.3))


func _pick_tick(delta: float) -> void:
	var player := _thief
	if player == null or not is_instance_valid(player) or player.dead or not _pick_ok(player):
		_end_pick()
		if player != null and is_instance_valid(player):
			player.item_user.show_message("Abgebrochen.", Color(0.8, 0.8, 0.8))
		return
	var light := player.stealth.visibility if player.stealth != null else 0.5
	var noise := player.stealth.noise_level if player.stealth != null else 0.0
	var rate := 0.08 + light * 0.5 + noise * 0.9
	# Skills Flinke Finger (pick_time_mult, suspicion_mult). Der Host kennt sie auch bei fremden Dieben.
	suspicion += rate * _alert * player.skill_mult(&"suspicion_mult") * delta
	pick_progress = minf(pick_progress + delta / (PICK_TIME * player.skill_mult(&"pick_time_mult")), 1.0)
	if suspicion >= 1.0:
		_end_pick()
		player.item_user.show_message("Erwischt!", Color(1.0, 0.35, 0.3))
		_caught(player, &"pickpocket")
	elif pick_progress >= 1.0:
		_end_pick()
		var got := _empty_pocket(player)
		player.item_user.show_message("Geklaut: " + got if got != "" else "Tasche leer.", Color(0.95, 0.85, 0.3))


func _aimed_player() -> Player:
	var found: Player = null
	for node in get_tree().get_nodes_in_group(&"player"):
		var player := node as Player
		if player == null or player.dead or not player.controls_local_body():
			continue
		if player.weapon_holder == null or player.weapon_holder.get_weapon() == null:
			continue
		if player.weapon_holder.get_aim() < 0.65:
			continue
		var camera := player.camera
		var from := camera.global_position
		var to := from - camera.global_basis.z * 14.0
		var query := PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()])
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider := hit.collider as Node
		if collider == _body or _body.is_ancestor_of(collider):
			found = player
			break
	return found


func _can_pickpocket(player: Player) -> bool:
	if player == null or held_up or restrained or _pocket_empty():
		return false
	return _quiet(player) and _behind(player, 2.0)


## Während des Griffs etwas mehr Abstand erlaubt, damit man einer gehenden Person folgen kann.
func _pick_ok(player: Player) -> bool:
	if held_up or restrained or _body.is_panicking():
		return false
	return _quiet(player) and _behind(player, PICK_REACH, -0.1)


func _quiet(player: Player) -> bool:
	if not player.movement.crouching:
		return false
	if player.stealth != null and player.stealth.noise_level > QUIET_NOISE:
		return false
	return player.velocity.length() <= QUIET_SPEED


func _behind(player: Player, reach := 1.8, cone := -0.35) -> bool:
	var forward := -_body.global_basis.z
	forward.y = 0.0
	var to_player := player.global_position - _body.global_position
	to_player.y = 0.0
	if forward.length() < 0.01 or to_player.length() < 0.2 or to_player.length() > reach:
		return false
	return forward.normalized().dot(to_player.normalized()) < cone


func _isolated() -> bool:
	var home := _body.get_parent()
	for node in get_tree().get_nodes_in_group(Civilian.GROUP):
		var other := node as Node3D
		if other == null or other == _body:
			continue
		if home != null and other.get_parent() == home:
			continue
		if other.get("state") == Civilian.State.DEAD:
			continue
		if other.global_position.distance_to(_body.global_position) < 8.0:
			return false
	return true


func _unaware(player: Player) -> bool:
	if player == null or held_up or restrained or not _isolated():
		return false
	return _quiet(player) and _behind(player)


func _caught(player: Player, kind: StringName) -> void:
	_body.panic(player.global_position)
	_body.show_line("Dieb!")
	_call_police(kind)


func _rob(player: Player) -> void:
	robbed = true
	var got := _empty_pocket(player)
	if got == "":
		player.item_user.show_message("Nichts mehr zu holen.", Color(0.8, 0.8, 0.8))
		return
	player.item_user.show_message("Durchsucht: " + got, Color(0.95, 0.85, 0.3))


func _pocket_empty() -> bool:
	return pocket_cents <= 0 and not _jewelry and not _phone and not _watch


## Gibt dem Spieler Bargeld und Wertsachen. Was nicht ins Inventar passt, bleibt in der Tasche.
## Ergebnis: Text für die Meldung, leer, wenn nichts da war.
func _empty_pocket(player: Player) -> String:
	var parts: PackedStringArray = []
	if pocket_cents > 0:
		# Skill Großer Fang (loot_cash_mult).
		var cents := roundi(pocket_cents * player.skill_mult(&"loot_cash_mult"))
		player.inventory.add_money(cents)
		parts.append("%d ¢" % cents)
		pocket_cents = 0
	if _jewelry and _give(player, JEWELRY):
		_jewelry = false
		parts.append(JEWELRY.display_name)
	if _phone and _give(player, PHONE):
		_phone = false
		parts.append(PHONE.display_name)
	if _watch and _give(player, WATCH):
		_watch = false
		parts.append(WATCH.display_name)
	return ", ".join(parts)


func _give(player: Player, item: ItemData) -> bool:
	return player.inventory.add_item(item, 1) == 0


func _call_police(kind: StringName) -> void:
	var token := _body.get_instance_id()
	if kind == &"burglary":
		var home := _body.get_parent()
		if home != null:
			token = home.get_instance_id()
	WantedManager.report(kind, _body.global_position, token)


func _holding_restraint(player: Player) -> bool:
	return _count(player, CUFFS) > 0 or _count(player, TIES) > 0


func _consume_restraint(player: Player) -> bool:
	if _take(player, CUFFS):
		return true
	return _take(player, TIES)


func _count(player: Player, id: String) -> int:
	var total := 0
	var inventory := player.inventory
	for i in inventory.get_size():
		var item := inventory.get_item(i)
		if item != null and item.id == id:
			total += inventory.get_count(i)
	return total


func _take(player: Player, id: String) -> bool:
	var inventory := player.inventory
	for i in inventory.get_size():
		var item := inventory.get_item(i)
		if item != null and item.id == id and inventory.get_count(i) > 0:
			inventory.remove_at(i, 1)
			return true
	return false
