class_name CivilianCrime
extends Node
## Taschendiebstahl, Bedrohung, Fesseln und Ausrauben für einen Civilian.
##
## Friedlich, solange niemand zielt, schlägt oder einbricht. Taschendiebstahl nur
## von hinten, im Hocken und bei wenig Lärm. Fesseln nur, wenn die Person schon
## die Hände oben hat (isoliert und bedroht).

const CUFFS := "handcuffs"
const TIES := "zipties"
const QUIET_NOISE := 0.35
const QUIET_SPEED := 2.2

var held_up := false
var restrained := false
var pocket_cents := 0
var robbed := false
var _threat_sent := false
var _aim_tick := 0.0

var _body: Civilian


func _ready() -> void:
	_body = get_parent() as Civilian
	if _body == null:
		return
	pocket_cents = 2 + (_body.net_seed % 17)


func prompt(player: Player) -> String:
	if _body == null or _body.is_dead():
		return ""
	if restrained and not robbed:
		return "Ausrauben"
	if held_up and not restrained and _holding_restraint(player):
		return "Fesseln"
	if _can_pickpocket(player):
		return "Tasche durchsuchen"
	return ""


func interact(player: Player) -> void:
	if _body == null or _body.is_dead() or WorldSync.is_client():
		return
	if restrained and not robbed:
		_rob(player)
		return
	if held_up and not restrained and _consume_restraint(player):
		restrained = true
		_body.hold_up()
		player.item_user.show_message("Gefesselt.", Color(0.5, 0.9, 1.0))
		return
	if _can_pickpocket(player):
		_pickpocket(player)
		return
	if player.movement.crouching:
		_caught(player, &"pickpocket")


func on_burglary() -> void:
	if _body == null or _body.is_dead() or restrained:
		return
	_body.panic(_body.global_position)
	_body.show_line("Polizei!")


func _physics_process(delta: float) -> void:
	if _body == null or _body.is_dead() or WorldSync.is_client():
		return
	if restrained:
		held_up = true
		_body.hold_up()
		return
	_aim_tick -= delta
	if _aim_tick > 0.0:
		return
	_aim_tick = 0.2
	var player := _aimed_player()
	if player == null:
		if held_up and not restrained:
			held_up = false
			_threat_sent = false
		return
	if _isolated():
		held_up = true
		_body.hold_up()
		if not _threat_sent:
			_threat_sent = true
			_call_police(&"threat")
			_body.show_line("Hände hoch …")
	else:
		held_up = false
		_body.panic(player.global_position)
		if not _threat_sent:
			_threat_sent = true
			_call_police(&"threat")


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
	if player == null or held_up or restrained or robbed or pocket_cents <= 0:
		return false
	if not player.movement.crouching:
		return false
	if player.stealth != null and player.stealth.noise_level > QUIET_NOISE:
		return false
	if player.velocity.length() > QUIET_SPEED:
		return false
	return _behind(player)


func _behind(player: Player) -> bool:
	var forward := -_body.global_basis.z
	forward.y = 0.0
	var to_player := player.global_position - _body.global_position
	to_player.y = 0.0
	if forward.length() < 0.01 or to_player.length() < 0.2 or to_player.length() > 1.8:
		return false
	return forward.normalized().dot(to_player.normalized()) < -0.35


func _isolated() -> bool:
	var near := 0
	for node in get_tree().get_nodes_in_group(Civilian.GROUP):
		var other := node as Node3D
		if other == null or other == _body:
			continue
		if other.get("state") == Civilian.State.DEAD:
			continue
		if other.global_position.distance_to(_body.global_position) < 8.0:
			near += 1
	return near == 0


func _pickpocket(player: Player) -> void:
	var seen := player.stealth != null and player.stealth.visibility > 0.72
	var amount := pocket_cents
	pocket_cents = 0
	player.inventory.add_money(amount)
	player.item_user.show_message("Geklaut: %d ¢" % amount, Color(0.95, 0.85, 0.3))
	if seen:
		_caught(player, &"pickpocket")
	else:
		WantedManager.report(&"pickpocket", _body.global_position, _body.get_instance_id())


func _caught(player: Player, kind: StringName) -> void:
	_body.panic(player.global_position)
	_body.show_line("Dieb!")
	_call_police(kind)


func _rob(player: Player) -> void:
	if pocket_cents <= 0:
		robbed = true
		player.item_user.show_message("Nichts mehr zu holen.", Color(0.8, 0.8, 0.8))
		return
	var amount := pocket_cents
	pocket_cents = 0
	robbed = true
	player.inventory.add_money(amount)
	player.item_user.show_message("Ausgeraubt: %d ¢" % amount, Color(0.95, 0.85, 0.3))
	WantedManager.report(&"pickpocket", _body.global_position, _body.get_instance_id())


func _call_police(kind: StringName) -> void:
	WantedManager.report(kind, _body.global_position, _body.get_instance_id())


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
