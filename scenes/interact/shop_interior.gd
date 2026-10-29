extends Node3D
## Spiel-Logik eines Ladens aus dem Mapkit (SlumBuilding, Stil SHOP): Verkäufer hinter der Theke,
## Kasse, Ware in den Regalen und im Kühlschrank.
##
## Was man tun kann:
##   Einkaufen    E am Verkäufer öffnet das Ladenfenster (shop_ui.gd), bezahlt wird mit Bargeld.
##   Klauen       E an einer leuchtenden Ware im Regal. Sieht der Verkäufer zu, gibt es Alarm.
##   Kasse        E an der Kasse räumt sie aus. Klappt nur, wenn der Verkäufer nicht hinsieht
##                (er räumt ab und zu hinten Ware ein und dreht dem Laden den Rücken zu), sich ergeben
##                hat oder tot ist. Sonst schlägt er Alarm.
##   Überfall     Mit einer Schusswaffe im Anschlag auf den Verkäufer zielen (bis THREAT_RANGE):
##                Er hebt die Hände, legt das Kassengeld auf die Theke und löst nach ALARM_DELAY
##                einen stillen Alarm aus.
##   Schießen     Der Verkäufer hält KEEPER_HEALTH aus. Treffer lösen Alarm aus, tot liegt er da
##                und die Kasse ist frei.
## Alarm: Gegner im Umkreis ALARM_RADIUS werden feindlich und kommen zum Täter, der Verkäufer
## verkauft ALARM_TIME Sekunden nichts. Ware füllt sich nach RESTOCK_TIME auf, die Kasse auch,
## ein toter Verkäufer kommt nach KEEPER_RESPAWN wieder.
##
## Multiplayer: Der Host entscheidet (Ware, Kasse, Verkäufer, Alarm). Clients fragen per RPC an
## (_request), der Host antwortet mit _give. Der Zustand läuft über WorldSync (Gruppe net_npc,
## net_get_state / net_apply_state). Einkaufen bleibt lokal, weil Geld und Inventar lokal sind.
## Kein class_name: SlumBuilding legt den Knoten per preload an.

const ShopUIScript := preload("res://scenes/interact/shop_ui.gd")
const SoundGen := preload("res://scenes/enemies/enemy_sounds.gd")
const ITEM := "res://scenes/items/data/%s.tres"
const CREDCHIP_PATH := "res://scenes/items/data/credchip.tres"
const GROUP := &"shop_interior"

## Angebot je Ladenschild: [Item-id, Preis]. Unbekannte Schilder bekommen DEFAULT_OFFERS.
const OFFERS := {
	"sign_ramen": [["noodles", 3], ["energy_drink", 2]],
	"sign_noodles": [["noodles", 3], ["energy_drink", 2]],
	"sign_pharmacy": [["nano_bandage", 5], ["stim_pack", 7], ["energy_drink", 2]],
	"sign_bar": [["energy_drink", 2], ["noodles", 4]],
	"sign_24h": [["energy_drink", 2], ["noodles", 3], ["nano_bandage", 6], ["data_shard", 9]],
}
const DEFAULT_OFFERS := [["energy_drink", 2], ["noodles", 3], ["nano_bandage", 6]]

const KEEPER_HEALTH := 60.0
const THREAT_RANGE := 9.0
const SIGHT_RANGE := 13.0
## Halber Blickwinkel des Verkäufers in Grad.
const SIGHT_ANGLE := 75.0
const ALARM_RADIUS := 35.0
const ALARM_TIME := 90.0
## Nach dem Überfall so viele Sekunden bis zum stillen Alarm.
const ALARM_DELAY := 4.0
const SURRENDER_TIME := 12.0
const RESTOCK_TIME := 150.0
const KEEPER_RESPAWN := 240.0
const CASH_MIN := 40
const CASH_MAX := 140
## Abstand zwischen zwei Gängen nach hinten (Sekunden) und wie lange er hinten bleibt.
const BUSY_EVERY := Vector2(14.0, 26.0)
const BUSY_TIME := Vector2(5.0, 8.0)

enum Keeper { CALM, SURRENDER, ALARM, DEAD }

# Von SlumBuilding gesetzt (lokale Koordinaten des Gebäudes).
var shop_sign := ""
var floor_y := 0.0
var keeper_at := Vector3.ZERO
var register_at := Vector3.ZERO
var counter_at := Vector3.ZERO
var slots: Array[Transform3D] = []
var seed_value := 0

## Ware je Platz noch da.
var stock: Array[bool] = []
var slot_items: Array[ItemData] = []
var cash := 0
var keeper_state := Keeper.CALM
var keeper_health := KEEPER_HEALTH
## Verkäufer ist hinten und dreht dem Laden den Rücken zu.
var busy := false

var _rng := RandomNumberGenerator.new()
var _offers: Array = []
var _alarm_left := 0.0
var _silent_alarm_left := -1.0
var _surrender_left := 0.0
var _restock_left := RESTOCK_TIME
var _respawn_left := 0.0
var _busy_left := 0.0
var _last_actor: Player
var _threat_check := 0.0
var _threat_sent := false

var _keeper: StaticBody3D
var _model: CivilianModel
var _bark: Label3D
var _voice: AudioStreamPlayer3D
var _register: StaticBody3D
var _goods: Array[Area3D] = []
var _keeper_pos := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(WorldSync.NPC_GROUP)
	_rng.seed = seed_value
	_offers = OFFERS.get(shop_sign, DEFAULT_OFFERS)
	cash = _rng.randi_range(CASH_MIN, CASH_MAX)
	_busy_left = _rng.randf_range(BUSY_EVERY.x, BUSY_EVERY.y)
	_build_keeper()
	_build_register()
	_build_goods()
	_update_keeper_look()


# --- Abfragen für UI und Tests ---------------------------------------------------------

func get_offers() -> Array:
	return _offers


func load_item(id: String) -> ItemData:
	var path := ITEM % id
	return load(path) as ItemData if ResourceLoader.exists(path) else null


func is_open_for_business() -> bool:
	return keeper_state == Keeper.CALM


func stock_left() -> int:
	return stock.count(true)


## Weltposition von Kopf und Blickrichtung des Verkäufers.
func keeper_eye() -> Vector3:
	return _keeper.global_position + Vector3.UP * 1.6


# --- Takt ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_animate_keeper(delta)
	_check_threat(delta)
	if not WorldSync.has_authority():
		return
	if _silent_alarm_left >= 0.0:
		_silent_alarm_left -= delta
		if _silent_alarm_left < 0.0:
			_raise_alarm(_last_actor, "")
	match keeper_state:
		Keeper.SURRENDER:
			_surrender_left -= delta
			if _surrender_left <= 0.0:
				_set_keeper(Keeper.ALARM if _alarm_left > 0.0 else Keeper.CALM)
		Keeper.ALARM:
			_alarm_left -= delta
			if _alarm_left <= 0.0:
				_set_keeper(Keeper.CALM)
		Keeper.DEAD:
			_respawn_left -= delta
			if _respawn_left <= 0.0:
				_respawn_keeper()
		Keeper.CALM:
			_busy_left -= delta
			if _busy_left <= 0.0:
				busy = not busy
				_busy_left = _rng.randf_range(BUSY_TIME.x, BUSY_TIME.y) if busy \
					else _rng.randf_range(BUSY_EVERY.x, BUSY_EVERY.y)
	_restock_left -= delta
	if _restock_left <= 0.0:
		_restock_left = RESTOCK_TIME
		if keeper_state == Keeper.CALM:
			_restock()


func _restock() -> void:
	for i in stock.size():
		stock[i] = true
	if cash < 10:
		cash = _rng.randi_range(CASH_MIN, CASH_MAX)
	_update_goods()


# --- Aktionen (Host bzw. offline) --------------------------------------------------------

## Spieler `player` will etwas tun: steal (arg = Platz), rob, threat, hit (arg = Schaden).
func request(player: Player, action: StringName, arg := 0) -> void:
	if WorldSync.has_authority():
		_handle(player, action, arg)
	else:
		_request.rpc_id(1, action, arg)


@rpc("any_peer", "reliable", "call_remote")
func _request(action: StringName, arg: int) -> void:
	if not multiplayer.is_server():
		return
	var player := WorldSync.player_of(multiplayer.get_remote_sender_id())
	if player != null:
		_handle(player, action, arg)


func _handle(player: Player, action: StringName, arg: int) -> void:
	match action:
		&"steal":
			_handle_steal(player, arg)
		&"rob":
			_handle_rob(player)
		&"threat":
			_handle_threat(player)
		&"hit":
			_handle_hit(player, float(arg))


func _handle_steal(player: Player, index: int) -> void:
	if index < 0 or index >= stock.size() or not stock[index]:
		_give(player, "", 0, "Schon weg")
		return
	stock[index] = false
	_update_goods()
	var seen := sees(player)
	_give(player, slot_items[index].resource_path, 1,
		"Geklaut: %s" % slot_items[index].display_name if not seen else "Erwischt!")
	if seen:
		_raise_alarm(player, "Hey! Das wird bezahlt!")


func _handle_rob(player: Player) -> void:
	if cash <= 0:
		_give(player, "", 0, "Kasse ist leer")
		return
	var free := keeper_state == Keeper.DEAD or keeper_state == Keeper.SURRENDER or not sees(player)
	if not free:
		_raise_alarm(player, "Finger weg von der Kasse!")
		_give(player, "", 0, "Der Verkäufer hat dich gesehen!")
		return
	var amount := cash
	cash = 0
	_give(player, CREDCHIP_PATH, amount, "Kasse ausgeräumt: +%d ¢" % amount)
	# Lebt der Verkäufer, merkt er es kurz danach.
	if keeper_state != Keeper.DEAD and _silent_alarm_left < 0.0:
		_last_actor = player
		_silent_alarm_left = ALARM_DELAY * 2.0


func _handle_threat(player: Player) -> void:
	if keeper_state == Keeper.DEAD or keeper_state == Keeper.SURRENDER:
		return
	_last_actor = player
	_set_keeper(Keeper.SURRENDER)
	_surrender_left = SURRENDER_TIME
	_say("Nicht schießen! Nimm das Geld!")
	if cash > 0:
		var credchip := load(CREDCHIP_PATH) as ItemData
		WorldSync.spawn_pickup(credchip, cash, to_global(counter_at) + Vector3.UP * 0.25,
			(to_global(counter_at + Vector3(0, 0, 1)) - to_global(counter_at)).normalized() * 0.8 + Vector3.UP, 0.4)
		cash = 0
	_silent_alarm_left = ALARM_DELAY


func _handle_hit(player: Player, damage: float) -> void:
	if keeper_state == Keeper.DEAD or damage <= 0.0:
		return
	keeper_health -= damage
	if WorldSync.is_online():
		_flash.rpc()
	else:
		_flash()
	if keeper_health <= 0.0:
		_set_keeper(Keeper.DEAD)
		_respawn_left = KEEPER_RESPAWN
		busy = false
		_raise_alarm(player, "")
		return
	_raise_alarm(player, "Hilfe! Überfall!")


## Alarm: Verkäufer schließt, Gegner im Umkreis werden feindlich und kommen zum Täter.
func _raise_alarm(player: Player, line: String) -> void:
	_silent_alarm_left = -1.0
	if line != "":
		_say(line)
	_alarm_left = ALARM_TIME
	if keeper_state == Keeper.CALM:
		_set_keeper(Keeper.ALARM)
	busy = false
	var center := _keeper.global_position
	StealthNoise.emit(get_tree(), center, 30.0, _keeper, StealthNoise.SHOUT)
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node3D
		if enemy == null or enemy.global_position.distance_to(center) > ALARM_RADIUS:
			continue
		if enemy.has_method("become_hostile"):
			enemy.call("become_hostile")
		if player != null:
			if enemy.has_method("net_set_attacker"):
				enemy.call("net_set_attacker", player)
			if enemy.has_method("hear_noise"):
				enemy.call("hear_noise", player.global_position, ALARM_RADIUS + 10.0, null, StealthNoise.SHOT)
	if player != null:
		_give(player, "", 0, "ALARM! Der Laden hat Verstärkung gerufen")


## Sieht der Verkäufer diesen Spieler? (Blickkegel, Sichtlinie, Schleichen)
func sees(player: Player) -> bool:
	if player == null or keeper_state == Keeper.DEAD or keeper_state == Keeper.SURRENDER or busy:
		return false
	var eye := keeper_eye()
	var chest := player.global_position + Vector3.UP * 1.0
	var to := chest - eye
	var dist := to.length()
	if dist > SIGHT_RANGE:
		return false
	var forward := -_keeper.global_basis.z
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	if rad_to_deg(forward.angle_to(flat)) > SIGHT_ANGLE:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, chest, 1 | 2, [_keeper.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != player:
		return false
	var visibility := player.stealth.visibility if player.stealth != null else 1.0
	return dist < 3.0 or visibility > 0.25


## Ergebnis an den Spieler: Item bzw. Geld ins Inventar und eine Meldung.
func _give(player: Player, item_path: String, count: int, message: String) -> void:
	if player == null:
		return
	if player.controls_local_body():
		_receive(item_path, count, message)
	else:
		_give_remote.rpc_id(player.get_multiplayer_authority(), item_path, count, message)


@rpc("authority", "reliable", "call_remote")
func _give_remote(item_path: String, count: int, message: String) -> void:
	_receive(item_path, count, message)


func _receive(item_path: String, count: int, message: String) -> void:
	var player := WorldSync.player_of(WorldSync.local_peer())
	if player == null:
		return
	if count > 0 and item_path.begins_with("res://") and ResourceLoader.exists(item_path):
		var item := load(item_path) as ItemData
		var left := player.inventory.add_item(item, count)
		if left > 0:
			WorldSync.spawn_pickup(item, left, player.global_position + Vector3.UP * 0.8, Vector3.UP * 1.5, 0.5)
	if message != "" and player.item_user != null:
		var bad := message.begins_with("ALARM") or message.begins_with("Erwischt") or message.begins_with("Der Verkäufer")
		player.item_user.show_message(message, Color(1.0, 0.25, 0.35) if bad else Color(0.3, 1.0, 0.55))


# --- Bedrohung mit der Waffe (lokaler Spieler) -------------------------------------------

func _check_threat(delta: float) -> void:
	_threat_check -= delta
	if _threat_check > 0.0:
		return
	_threat_check = 0.2
	if keeper_state == Keeper.DEAD or keeper_state == Keeper.SURRENDER:
		_threat_sent = false
		return
	var player := WorldSync.player_of(WorldSync.local_peer())
	if player == null or player.dead or player.weapon_holder == null or _threat_sent:
		return
	if player.weapon_holder.get_weapon() == null or player.weapon_holder.get_aim() < 0.6:
		return
	if aims_at_keeper(player):
		_threat_sent = true
		request(player, &"threat")


## Zielt der Spieler mit der Kamera auf den Verkäufer (in Reichweite, freie Sicht)?
func aims_at_keeper(player: Player) -> bool:
	var eye := player.camera.global_position
	var target := _keeper.global_position + Vector3.UP * 1.2
	if eye.distance_to(target) > THREAT_RANGE:
		return false
	var forward := -player.camera.global_basis.z
	if forward.dot((target - eye).normalized()) < 0.97:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _keeper


# --- Multiplayer-Zustand (WorldSync) ------------------------------------------------------

func net_get_state() -> Array:
	var bits := 0
	for i in stock.size():
		if stock[i]:
			bits |= 1 << i
	return [bits, cash, int(keeper_state), keeper_health, busy]


func net_apply_state(data: Array) -> void:
	if data.size() < 5:
		return
	var bits := int(data[0])
	var changed := false
	for i in stock.size():
		var has := bits & (1 << i) != 0
		if stock[i] != has:
			stock[i] = has
			changed = true
	if changed:
		_update_goods()
	cash = int(data[1])
	keeper_health = float(data[3])
	busy = bool(data[4])
	var new_state: Keeper = int(data[2])
	if new_state != keeper_state:
		if keeper_state == Keeper.DEAD and new_state != Keeper.DEAD:
			_respawn_keeper()
		_set_keeper(new_state)


func _set_keeper(state: Keeper) -> void:
	if keeper_state == state:
		return
	var was := keeper_state
	keeper_state = state
	if state == Keeper.DEAD and was != Keeper.DEAD:
		_model.fall(-_keeper.global_basis.z)
		_keeper.collision_layer = 0
		_bark.visible = false
	if state != Keeper.CALM:
		var ui := _open_ui()
		if ui != null:
			ui.call("refresh")
	_update_keeper_look()


func _respawn_keeper() -> void:
	keeper_health = KEEPER_HEALTH
	busy = false
	_model.queue_free()
	_add_model()
	_keeper.collision_layer = 1
	_keeper_pos = 0.0
	if WorldSync.has_authority():
		_set_keeper(Keeper.CALM)


# --- Aufbau und Anzeige -------------------------------------------------------------------

func _build_keeper() -> void:
	_keeper = KeeperBody.new()
	_keeper.name = "Keeper"
	_keeper.set("shop", self)
	_keeper.collision_layer = 1
	_keeper.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position = Vector3.UP * 0.9
	_keeper.add_child(shape)
	add_child(_keeper)
	_keeper.position = keeper_at
	_add_model()
	_bark = Label3D.new()
	_bark.font_size = 40
	_bark.pixel_size = 0.0035
	_bark.outline_size = 10
	_bark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bark.modulate = Color(1.0, 0.85, 0.4)
	_bark.position = Vector3.UP * 2.15
	_bark.visible = false
	_keeper.add_child(_bark)
	_voice = AudioStreamPlayer3D.new()
	_voice.bus = &"SFX"
	_voice.unit_size = 6.0
	_voice.position = Vector3.UP * 1.6
	_keeper.add_child(_voice)


func _add_model() -> void:
	_model = CivilianModel.new()
	_model.name = "Model"
	_keeper.add_child(_model)
	_model.build_civilian(seed_value)


func _build_register() -> void:
	_register = RegisterBody.new()
	_register.name = "Register"
	_register.set("shop", self)
	_register.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.3, 0.4)
	shape.shape = box
	shape.position = Vector3.UP * 0.15
	_register.add_child(shape)
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.42, 0.18, 0.38)
	mesh.material = _material(Color(0.12, 0.12, 0.14), 0.0)
	body.mesh = mesh
	body.position = Vector3.UP * 0.09
	_register.add_child(body)
	var screen := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.3, 0.16, 0.02)
	screen_mesh.material = _material(Color(0.2, 1.0, 0.6), 2.5)
	screen.mesh = screen_mesh
	screen.position = Vector3(0, 0.3, -0.1)
	screen.rotation_degrees = Vector3(-20, 0, 0)
	_register.add_child(screen)
	add_child(_register)
	_register.position = register_at


func _build_goods() -> void:
	for i in slots.size():
		var item: ItemData = null
		# Kühlschrank (letzter Platz) hat Getränke, sonst etwas aus dem Angebot.
		if i == slots.size() - 1:
			item = load_item("energy_drink")
		if item == null:
			var offer: Array = _offers[_rng.randi() % _offers.size()]
			item = load_item(str(offer[0]))
		if item == null:
			continue
		var goods := GoodsArea.new()
		goods.name = "Goods%d" % i
		goods.set("shop", self)
		goods.set("index", slot_items.size())
		goods.collision_layer = 4
		goods.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.5, 0.35, 0.3)
		shape.shape = box
		goods.add_child(shape)
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.36, 0.22, 0.16)
		mesh.material = _material(item.color, 1.8)
		mesh_instance.mesh = mesh
		goods.add_child(mesh_instance)
		add_child(goods)
		goods.transform = slots[i]
		_goods.append(goods)
		slot_items.append(item)
		stock.append(true)


func _update_goods() -> void:
	for i in _goods.size():
		_goods[i].visible = stock[i]
		_goods[i].collision_layer = 4 if stock[i] else 0


func _animate_keeper(delta: float) -> void:
	if _model == null or keeper_state == Keeper.DEAD:
		if _model != null:
			_model.animate(delta)
		return
	# Hinten Ware einräumen: 1,1 m nach hinten gehen und zur Rückwand drehen.
	var target := 1.0 if busy else 0.0
	var before := _keeper_pos
	_keeper_pos = move_toward(_keeper_pos, target, delta * 0.9)
	_keeper.position = keeper_at + Vector3(0, 0, -1.1 * _keeper_pos)
	var want_yaw := PI if busy and _keeper_pos > 0.95 else 0.0
	_keeper.rotation.y = lerp_angle(_keeper.rotation.y, want_yaw, minf(delta * 5.0, 1.0))
	_model.speed = absf(_keeper_pos - before) / maxf(delta, 0.001) * 1.1
	_model.cower = move_toward(_model.cower, 1.0 if keeper_state == Keeper.SURRENDER else 0.0, delta * 4.0)
	_model.animate(delta)


func _update_keeper_look() -> void:
	if _bark == null:
		return
	match keeper_state:
		Keeper.ALARM:
			_bark.modulate = Color(1.0, 0.25, 0.3)
		Keeper.SURRENDER:
			_bark.modulate = Color(0.7, 0.8, 1.0)
		_:
			_bark.modulate = Color(1.0, 0.85, 0.4)


## Ruf über dem Kopf, im Multiplayer bei allen.
func _say(text: String) -> void:
	if WorldSync.is_online() and multiplayer.is_server():
		_show_say.rpc(text)
	else:
		_show_say(text)


@rpc("authority", "reliable", "call_local")
func _show_say(text: String) -> void:
	if _bark == null:
		return
	_bark.text = text
	_bark.visible = true
	_voice.stream = SoundGen.voice(&"alert" if keeper_state != Keeper.SURRENDER else &"hurt", 1.15, _rng.randi() % 3)
	_voice.play()
	var shown := text
	get_tree().create_timer(2.6, false).timeout.connect(func() -> void:
		if is_instance_valid(_bark) and _bark.text == shown:
			_bark.visible = false)


@rpc("authority", "unreliable", "call_local")
func _flash() -> void:
	if _model != null:
		_model.flash_white()
		_model.flinch = 1.0


func _open_ui() -> Node:
	var player := WorldSync.player_of(WorldSync.local_peer())
	if player == null:
		return null
	var ui := player.get_node_or_null(^"ShopUI")
	if ui != null and ui.get("shop") == self and bool(ui.call("is_open")):
		return ui
	return null


func _material(color: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


# --- Treff- und Benutzflächen -------------------------------------------------------------

## Verkäufer: E = Einkaufen, Schüsse und Schläge treffen ihn.
class KeeperBody extends StaticBody3D:
	var shop: Node

	func get_interact_text(_player: Player) -> String:
		match int(shop.get("keeper_state")):
			0:
				return "Einkaufen"
			1:
				return ""
			_:
				return ""

	func interact(player: Player) -> void:
		if not bool(shop.call("is_open_for_business")):
			return
		var ui: CanvasLayer = ShopUIScript.call("for_player", player)
		ui.call("open", shop)

	func take_hit(damage: float, _point: Vector3, _normal: Vector3) -> void:
		var player := WorldSync.player_of(WorldSync.local_peer())
		shop.call("request", player, &"hit", int(ceilf(damage)))

	func melee_hit(damage: float, point: Vector3, normal: Vector3, _push: Vector3, _stun: float) -> void:
		take_hit(damage, point, normal)


## Kasse auf der Theke: E räumt sie aus.
class RegisterBody extends StaticBody3D:
	var shop: Node

	func get_interact_text(_player: Player) -> String:
		var amount := int(shop.get("cash"))
		return "Kasse ausräumen (%d ¢)" % amount if amount > 0 else "Kasse ist leer"

	func interact(player: Player) -> void:
		if int(shop.get("cash")) > 0:
			shop.call("request", player, &"rob")


## Ware im Regal oder Kühlschrank: E klaut sie.
class GoodsArea extends Area3D:
	var shop: Node
	var index := 0

	func get_interact_text(_player: Player) -> String:
		var items: Array = shop.get("slot_items")
		if index >= items.size() or not visible:
			return ""
		return "Klauen: %s" % (items[index] as ItemData).display_name

	func interact(player: Player) -> void:
		shop.call("request", player, &"steal", index)
