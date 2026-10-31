extends Node3D
## Spiel-Logik eines Ladens aus dem Mapkit (SlumBuilding, Stil SHOP).
##
## Einkaufen wie im echten Laden:
##   Ware nehmen  E an einem Regalplatz legt ein Stück ins Inventar. Es ist noch nicht bezahlt
##                (Warenkorb pro Spieler, unpaid). Die Ware in den Regalen ist zufällig, manche Plätze
##                sind leer (EMPTY_CHANCE). Was liegt, hängt am Laden (CATALOG je Ladenschild).
##   Bezahlen     E am Verkäufer öffnet das Ladenfenster (shop_ui.gd): Warenkorb bezahlen,
##                Theken-Ware aus der Vitrine kaufen, beim Hehler (Ladenschild sign_shop) Wertsachen
##                verkaufen.
##   Klauen       Mit unbezahlter Ware den Laden verlassen. Erwischt wird man, wenn
##                  - eine Diebstahlsicherung am Eingang steht (piept immer),
##                  - der Verkäufer einen beim Rausgehen sieht (Regale verdecken, Hocken hilft),
##                  - die Kamera (falls vorhanden und heil) beim Einstecken zugesehen hat: Alarm kommt
##                    kurz nach dem Rausgehen. Eine zerschossene Kamera sieht nichts mehr.
##                Ware aus der Vitrine hinter der Theke zu nehmen, während er hinsieht, ist sofort Alarm.
##   Kasse        E an der Kasse bricht sie auf (ROB_TIME s, man muss daneben stehen bleiben). Sieht der
##                Verkäufer zu, gibt es Alarm. Ergeben oder tot: geht schneller.
##   Überfall     Mit der Waffe im Anschlag auf den Verkäufer zielen. Unbewaffnete heben die Hände und
##                legen das Kassengeld auf die Theke, bewaffnete (ARMED_CHANCE) wehren sich manchmal.
##                Nach ALARM_DELAY gibt es stillen Alarm.
##   Schießen     Der Verkäufer hält KEEPER_HEALTH aus. Tot ist die Kasse frei, nach KEEPER_RESPAWN
##                steht ein neuer da. Die Kamera geht mit einem Treffer kaputt.
## Alarm: Gegner im Umkreis ALARM_RADIUS werden feindlich und laufen zum Täter. Bewaffnete Verkäufer
## schießen auf ihn, unbewaffnete ducken sich hinter die Theke. ALARM_TIME lang wird nichts verkauft.
## Regale füllen sich nach RESTOCK_TIME wieder (wieder zufällig), die Kasse auch.
##
## Leistung: Modelle und Benutzflächen der Ware gibt es nur, solange die eigene Kamera näher als
## GOODS_NEAR ist (41 Läden mit je ~30 Plätzen).
## Multiplayer: Der Host entscheidet (Ware, Warenkorb, Kasse, Verkäufer, Alarm, Rausgehen). Clients
## fragen per RPC an (_request), der Host antwortet mit _give (Item, Geld, Kosten, Meldung). Der
## Zustand läuft über WorldSync (Gruppe net_npc), den eigenen Warenkorb bekommt jeder per _set_unpaid.
## Kein class_name: SlumBuilding legt den Knoten per preload an.

const ShopUIScript := preload("res://scenes/interact/shop_ui.gd")
const SoundGen := preload("res://scenes/enemies/enemy_sounds.gd")
const ITEM := "res://scenes/items/data/%s.tres"
const CREDCHIP_PATH := "res://scenes/items/data/credchip.tres"
const GROUP := &"shop_interior"

## Alle Items, die in Läden liegen können. Der Index ist die Kennung im Netz.
const ITEM_IDS := ["noodles", "onigiri", "soy_bar", "water_bottle", "energy_drink", "beer", "coffee",
	"painkillers", "nano_bandage", "stim_pack", "medkit", "cigarettes", "smartphone", "neuro_chip",
	"gold_watch", "data_shard"]

## Ware je Ladenschild und Platzart: [Item-id, Gewicht]. "default" für unbekannte Schilder und fehlende Arten.
const CATALOG := {
	"sign_ramen": {"shelf": [["noodles", 4], ["onigiri", 3], ["soy_bar", 2]], "cabinet": [["cigarettes", 3], ["beer", 1]]},
	"sign_noodles": {"shelf": [["noodles", 5], ["onigiri", 2], ["soy_bar", 1]], "cabinet": [["cigarettes", 3], ["smartphone", 1]]},
	"sign_pharmacy": {"shelf": [["painkillers", 4], ["nano_bandage", 3], ["soy_bar", 1], ["water_bottle", 1]],
		"cabinet": [["stim_pack", 3], ["medkit", 2], ["painkillers", 1]], "fridge": [["water_bottle", 3], ["energy_drink", 1]]},
	"sign_bar": {"shelf": [["soy_bar", 2], ["cigarettes", 3], ["noodles", 1]], "fridge": [["beer", 4], ["energy_drink", 2], ["water_bottle", 1]],
		"cabinet": [["cigarettes", 3], ["gold_watch", 1]]},
	"sign_24h": {"shelf": [["noodles", 2], ["soy_bar", 3], ["onigiri", 2], ["painkillers", 1], ["nano_bandage", 1], ["coffee", 1]],
		"cabinet": [["cigarettes", 3], ["smartphone", 2], ["stim_pack", 1], ["neuro_chip", 1]]},
	"sign_shop": {"shelf": [["data_shard", 2], ["soy_bar", 1], ["cigarettes", 2], ["smartphone", 1]],
		"cabinet": [["smartphone", 2], ["neuro_chip", 2], ["gold_watch", 2]]},
	"sign_gas": {"shelf": [["soy_bar", 3], ["noodles", 2], ["onigiri", 2], ["cigarettes", 2], ["painkillers", 1]],
		"fridge": [["water_bottle", 3], ["energy_drink", 3], ["beer", 2], ["coffee", 2]],
		"cabinet": [["cigarettes", 3], ["stim_pack", 1], ["smartphone", 1]]},
	"default": {"shelf": [["soy_bar", 3], ["noodles", 2], ["onigiri", 1], ["painkillers", 1]],
		"fridge": [["water_bottle", 3], ["energy_drink", 3], ["beer", 2], ["coffee", 1]],
		"cabinet": [["cigarettes", 3], ["smartphone", 1], ["stim_pack", 1]]},
}
## Aufschlag auf ItemData.value je Ladenschild.
const MARKUP := {"sign_gas": 1.4, "sign_24h": 1.3, "sign_bar": 1.4, "sign_pharmacy": 1.2, "sign_shop": 1.1}
## Hehler zahlt diesen Anteil vom Wert.
const FENCE_RATE := 0.5

const EMPTY_CHANCE := 0.3
const KEEPER_HEALTH := 60.0
const THREAT_RANGE := 9.0
const SIGHT_RANGE := 14.0
## Halber Blickwinkel des Verkäufers bzw. der Kamera in Grad.
const SIGHT_ANGLE := 80.0
const CAMERA_ANGLE := 60.0
const ALARM_RADIUS := 35.0
const ALARM_TIME := 90.0
const ALARM_DELAY := 4.0
const CAMERA_DELAY := 5.0
const SURRENDER_TIME := 12.0
const RESTOCK_TIME := 180.0
const KEEPER_RESPAWN := 240.0
const ROB_TIME := 3.0
const ROB_TIME_FREE := 1.0
const ROB_REACH := 1.9
const CASH_MIN := 40
const CASH_MAX := 160
const ARMED_CHANCE := {"sign_gas": 0.4, "sign_bar": 0.6, "sign_24h": 0.45, "sign_shop": 0.7}
const ARMED_DEFAULT := 0.25
## Bewaffneter Verkäufer: Abstand zwischen Schüssen, Treffer-Wahrscheinlichkeit, Schaden.
const SHOT_INTERVAL := 1.1
const SHOT_CHANCE := 0.45
const SHOT_DAMAGE := 14.0
const BUSY_EVERY := Vector2(14.0, 26.0)
const BUSY_TIME := Vector2(5.0, 8.0)
const GOODS_NEAR := 32.0
const GOODS_FAR := 42.0
const GOODS_SCALE := 1.25

enum Keeper { CALM, SURRENDER, ALARM, DEAD }

# Von SlumBuilding gesetzt (lokale Koordinaten des Gebäudes).
var shop_sign := ""
var floor_y := 0.0
var keeper_at := Vector3.ZERO
var register_at := Vector3.ZERO
var counter_at := Vector3.ZERO
var bounds := AABB()
var camera_at := Vector3.INF
var has_sensor := false
## Plätze für Ware: {"kind": "shelf"/"wall"/"fridge"/"cabinet", "xf": Transform3D}.
var slots: Array = []
var seed_value := 0

## Ware je Platz: ITEM_IDS-Index oder -1 (leer), und Stückzahl.
var slot_item: PackedInt32Array = PackedInt32Array()
var slot_count: PackedInt32Array = PackedInt32Array()
var cash := 0
var keeper_state := Keeper.CALM
var keeper_health := KEEPER_HEALTH
var busy := false
var armed := false
var camera_alive := false
## Eigener Warenkorb (bei Clients vom Host gemeldet).
var my_unpaid := 0
## Schüsse des bewaffneten Verkäufers (für Tests und Anzeige).
var shots_fired := 0

var _rng := RandomNumberGenerator.new()
var _catalog: Dictionary = {}
# Host: Warenkorb, Kamera-Aufnahmen und "war drin" je Peer.
var _unpaid := {}
var _recorded := {}
var _inside := {}
var _reminded := {}
var _alarm_left := 0.0
var _silent_alarm_left := -1.0
var _surrender_left := 0.0
var _restock_left := RESTOCK_TIME
var _respawn_left := 0.0
var _busy_left := 0.0
var _shot_left := 0.0
var _rob_actor: Player
var _rob_left := -1.0
var _last_actor: Player
var _threat_check := 0.0
var _threat_sent := false
var _near := false
var _near_check := 0.0

var _keeper: StaticBody3D
var _model: CivilianModel
var _bark: Label3D
var _voice: AudioStreamPlayer3D
var _gun_audio: AudioStreamPlayer3D
var _muzzle: OmniLight3D
var _register: StaticBody3D
var _camera: StaticBody3D
var _slot_nodes: Array[Node3D] = []
var _keeper_turn := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(WorldSync.NPC_GROUP)
	# Offline fest pro Laden (gleicher Seed = gleiche Ware), online würfelt der Host bei jedem Start neu.
	_rng.seed = seed_value if not WorldSync.is_online() else seed_value ^ randi()
	_catalog = CATALOG.get(shop_sign, CATALOG["default"])
	armed = _rng.randf() < float(ARMED_CHANCE.get(shop_sign, ARMED_DEFAULT))
	cash = _rng.randi_range(CASH_MIN, CASH_MAX)
	_busy_left = _rng.randf_range(BUSY_EVERY.x, BUSY_EVERY.y)
	slot_item.resize(slots.size())
	slot_count.resize(slots.size())
	for i in slots.size():
		_slot_nodes.append(null)
	_build_keeper()
	_build_register()
	_build_camera()
	_restock(true)
	_update_keeper_look()


# --- Abfragen für UI und Tests ---------------------------------------------------------

func load_item(id: String) -> ItemData:
	var path := ITEM % id
	return load(path) as ItemData if ResourceLoader.exists(path) else null


func item_at(slot: int) -> ItemData:
	if slot < 0 or slot >= slot_item.size() or slot_item[slot] < 0 or slot_count[slot] <= 0:
		return null
	return load_item(ITEM_IDS[slot_item[slot]])


## Mit `player` zählt dessen Skill Feilscher (price_mult).
func price_of(item: ItemData, player: Player = null) -> int:
	if item == null:
		return 0
	var skill := player.skill_mult(&"price_mult") if player != null else 1.0
	return maxi(roundi(item.value * float(MARKUP.get(shop_sign, 1.0)) * skill), 1)


## Was der Hehler für `item` zahlt (0 = nimmt er nicht, z. B. Essen). Mit `player` zählt Feilscher (fence_mult).
func fence_price(item: ItemData, player: Player = null) -> int:
	if item == null or item.value < 8:
		return 0
	var skill := player.skill_mult(&"fence_mult") if player != null else 1.0
	return maxi(int(item.value * FENCE_RATE * skill), 1)


func is_fence() -> bool:
	return shop_sign == "sign_shop"


func is_open_for_business() -> bool:
	return keeper_state == Keeper.CALM


func slot_kind(slot: int) -> String:
	return str(slots[slot]["kind"]) if slot >= 0 and slot < slots.size() else ""


## Plätze in der Vitrine mit Ware (für den Theken-Verkauf im Ladenfenster).
func counter_slots() -> Array[int]:
	var list: Array[int] = []
	for i in slots.size():
		if slot_kind(i) == "cabinet" and item_at(i) != null:
			list.append(i)
	return list


func stock_total() -> int:
	var total := 0
	for i in slot_count.size():
		if slot_item[i] >= 0:
			total += slot_count[i]
	return total


func empty_slots() -> int:
	var empty := 0
	for i in slot_item.size():
		if slot_item[i] < 0 or slot_count[i] <= 0:
			empty += 1
	return empty


func keeper_eye() -> Vector3:
	return _keeper.global_position + Vector3.UP * 1.6


func is_inside(player: Node3D) -> bool:
	return bounds.has_point(to_local(player.global_position))


func unpaid_of(player: Player) -> int:
	return int(_unpaid.get(_peer(player), 0))


# --- Takt ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_goods_lod(delta)
	_animate_keeper(delta)
	_check_threat(delta)
	if not WorldSync.has_authority():
		return
	_tick_timers(delta)
	_tick_players()
	_tick_rob(delta)
	_tick_shooting(delta)


func _tick_timers(delta: float) -> void:
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
			_restock(false)


## Host: wer rein- und rausgeht. Mit unbezahlter Ware rausgehen = Diebstahl.
func _tick_players() -> void:
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player.dead:
			continue
		var peer := _peer(player)
		var inside := is_inside(player)
		var was: bool = _inside.get(peer, false)
		_inside[peer] = inside
		var unpaid := int(_unpaid.get(peer, 0))
		if unpaid <= 0:
			continue
		if inside:
			# Kurz vor der Tür erinnert er einmal ans Bezahlen.
			var local := to_local(player.global_position)
			if local.z > bounds.end.z - 1.4 and not _reminded.get(peer, false) and sees(player):
				_reminded[peer] = true
				_say("Vergiss nicht zu bezahlen!")
		elif was:
			_left_with_goods(player, unpaid)


func _left_with_goods(player: Player, unpaid: int) -> void:
	var peer := _peer(player)
	var recorded: bool = _recorded.get(peer, false) and camera_alive
	_set_unpaid(player, 0)
	_recorded.erase(peer)
	_reminded.erase(peer)
	if has_sensor:
		_say("*PIEP PIEP PIEP*")
		_raise_alarm(player, "")
		return
	if sees(player):
		_raise_alarm(player, "Halt! Du hast nicht bezahlt!")
		return
	if recorded and keeper_state == Keeper.CALM:
		_last_actor = player
		_silent_alarm_left = CAMERA_DELAY
		_give(player, "", 0, "Unbemerkt raus … aber die Kamera hat dich gesehen")
		return
	_give(player, "", 0, "Geklaut: Ware für %d ¢" % unpaid)


func _restock(initial: bool) -> void:
	for i in slots.size():
		if not initial and slot_item[i] >= 0 and slot_count[i] > 0:
			continue
		var kind := slot_kind(i)
		var pool: Array = _catalog.get(kind, [])
		if pool.is_empty():
			var fallback: Dictionary = CATALOG["default"]
			pool = fallback.get(kind, fallback["shelf"]) if kind != "wall" else _catalog.get("shelf", fallback["shelf"])
		var empty_chance := EMPTY_CHANCE * (1.6 if kind == "cabinet" else 1.0)
		if _rng.randf() < empty_chance:
			slot_item[i] = -1
			slot_count[i] = 0
			continue
		slot_item[i] = ITEM_IDS.find(_pick(pool))
		slot_count[i] = 1 if kind == "cabinet" else _rng.randi_range(1, 3)
	if cash < 10:
		cash = _rng.randi_range(CASH_MIN, CASH_MAX)
	_refresh_all_slots()


func _pick(pool: Array) -> String:
	var total := 0
	for entry: Array in pool:
		total += int(entry[1])
	var roll := _rng.randi_range(1, maxi(total, 1))
	for entry: Array in pool:
		roll -= int(entry[1])
		if roll <= 0:
			return str(entry[0])
	return str(pool[0][0])


# --- Aktionen (Host bzw. offline) --------------------------------------------------------

## Spieler `player` will etwas tun: take/buy (arg = Platz), pay, rob, threat, hit (arg = Schaden),
## camera_hit.
func request(player: Player, action: StringName, arg := 0) -> void:
	if player == null:
		return
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
		&"take":
			_handle_take(player, arg)
		&"buy":
			_handle_buy(player, arg)
		&"pay":
			_handle_pay(player)
		&"rob":
			_handle_rob(player)
		&"threat":
			_handle_threat(player)
		&"hit":
			_handle_hit(player, float(arg))
		&"camera_hit":
			_handle_camera_hit(player)


func _handle_take(player: Player, slot: int) -> void:
	var item := item_at(slot)
	if item == null:
		_give(player, "", 0, "Schon weg")
		return
	_take_one(slot)
	# Vitrine hinter der Theke: unter seinen Augen sofort Alarm.
	if slot_kind(slot) == "cabinet" and sees(player):
		_give(player, item.resource_path, 1, "Erwischt an der Vitrine!")
		_raise_alarm(player, "Finger weg von der Vitrine!")
		return
	_set_unpaid(player, unpaid_of(player) + price_of(item, player))
	if camera_alive and camera_sees(player):
		_recorded[_peer(player)] = true
	_give(player, item.resource_path, 1, "%s genommen – an der Kasse %d ¢" % [item.display_name, price_of(item, player)])


func _handle_buy(player: Player, slot: int) -> void:
	var item := item_at(slot)
	if item == null or slot_kind(slot) != "cabinet" or not is_open_for_business():
		_give(player, "", 0, "Nicht mehr da")
		return
	_take_one(slot)
	_give(player, item.resource_path, 1, "%s gekauft" % item.display_name, price_of(item, player))


func _handle_pay(player: Player) -> void:
	var amount := unpaid_of(player)
	if amount <= 0 or not is_open_for_business():
		return
	_set_unpaid(player, 0)
	_recorded.erase(_peer(player))
	_reminded.erase(_peer(player))
	_give(player, "", 0, "Bezahlt: %d ¢. Danke!" % amount, amount)


func _handle_rob(player: Player) -> void:
	if cash <= 0:
		_give(player, "", 0, "Kasse ist leer")
		return
	if _rob_left >= 0.0:
		return
	if keeper_state != Keeper.DEAD and keeper_state != Keeper.SURRENDER and sees(player):
		_raise_alarm(player, "Finger weg von der Kasse!")
		return
	_rob_actor = player
	var free := keeper_state == Keeper.DEAD or keeper_state == Keeper.SURRENDER
	# Skill Großer Fang (rob_time_mult).
	_rob_left = (ROB_TIME_FREE if free else ROB_TIME) * player.skill_mult(&"rob_time_mult")
	_give(player, "", 0, "Kasse wird aufgebrochen … stehen bleiben")


func _tick_rob(delta: float) -> void:
	if _rob_left < 0.0:
		return
	var player := _rob_actor
	if player == null or not is_instance_valid(player) or player.dead \
			or player.global_position.distance_to(_register.global_position) > ROB_REACH:
		_rob_left = -1.0
		_give(player, "", 0, "Kasse aufbrechen abgebrochen")
		return
	if keeper_state != Keeper.DEAD and keeper_state != Keeper.SURRENDER and sees(player):
		_rob_left = -1.0
		_raise_alarm(player, "Weg von meiner Kasse!")
		return
	_rob_left -= delta
	if _rob_left > 0.0:
		return
	_rob_left = -1.0
	var amount := cash
	cash = 0
	_give(player, CREDCHIP_PATH, amount, "Kasse geknackt: +%d ¢" % amount)
	if keeper_state != Keeper.DEAD and _silent_alarm_left < 0.0 and _alarm_left <= 0.0:
		_last_actor = player
		_silent_alarm_left = ALARM_DELAY * 2.0


func _handle_threat(player: Player) -> void:
	if keeper_state == Keeper.DEAD or keeper_state == Keeper.SURRENDER:
		return
	_last_actor = player
	# Bewaffnete lassen sich nicht immer einschüchtern.
	if armed and _rng.randf() < 0.5:
		_raise_alarm(player, "Nicht in meinem Laden!")
		return
	_set_keeper(Keeper.SURRENDER)
	_surrender_left = SURRENDER_TIME
	busy = false
	_say("Nicht schießen! Nimm das Geld!")
	if cash > 0:
		var credchip := load(CREDCHIP_PATH) as ItemData
		var push := global_basis * Vector3(1.0, 0.0, 0.0)
		WorldSync.spawn_pickup(credchip, cash, to_global(counter_at) + Vector3.UP * 0.25, push.normalized() * 0.8 + Vector3.UP, 0.4)
		cash = 0
	_silent_alarm_left = ALARM_DELAY


func _handle_hit(player: Player, damage: float) -> void:
	if keeper_state == Keeper.DEAD or damage <= 0.0:
		return
	keeper_health -= damage
	_flash_remote()
	if keeper_health <= 0.0:
		_set_keeper(Keeper.DEAD)
		_respawn_left = KEEPER_RESPAWN
		busy = false
		_raise_alarm(player, "")
		return
	_raise_alarm(player, "Hilfe! Überfall!")


func _handle_camera_hit(player: Player) -> void:
	if not camera_alive:
		return
	camera_alive = false
	_update_camera()
	_recorded.clear()
	if sees(player):
		_raise_alarm(player, "Was soll das?!")
	else:
		_say("Was war das?")


## Alarm: Laden zu, Gegner im Umkreis feindlich und zum Täter, bewaffneter Verkäufer schießt.
func _raise_alarm(player: Player, line: String) -> void:
	_silent_alarm_left = -1.0
	if line != "":
		_say(line)
	_alarm_left = ALARM_TIME
	if player != null:
		_last_actor = player
	if keeper_state == Keeper.CALM:
		_set_keeper(Keeper.ALARM)
	busy = false
	_rob_left = -1.0
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


## Host: bewaffneter Verkäufer schießt im Alarm auf den Täter.
func _tick_shooting(delta: float) -> void:
	if not armed or keeper_state != Keeper.ALARM or _last_actor == null or not is_instance_valid(_last_actor):
		return
	_shot_left -= delta
	if _shot_left > 0.0:
		return
	_shot_left = SHOT_INTERVAL * _rng.randf_range(0.8, 1.3)
	var target := _last_actor
	if target.dead or target.global_position.distance_to(_keeper.global_position) > SIGHT_RANGE + 4.0 or not sees(target, true):
		return
	var chance := SHOT_CHANCE
	if target.movement != null and target.movement.crouching:
		chance *= 0.7
	if Vector2(target.velocity.x, target.velocity.z).length() > 4.0:
		chance *= 0.7
	shots_fired += 1
	var end := target.global_position + Vector3.UP * 1.1
	if _rng.randf() < chance:
		target.apply_damage(SHOT_DAMAGE, &"shopkeeper")
	else:
		end += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 0.8), _rng.randf_range(-1, 1)).normalized() * 0.9
	if WorldSync.is_online():
		_show_shot.rpc(end)
	else:
		_show_shot(end)


## Sieht der Verkäufer diesen Spieler? Blickkegel, Sichtlinie zu Brust oder (stehend) Kopf –
## Regale verdecken, Hocken versteckt den Kopf. `ignore_busy`: auch beim Einräumen (Schießen).
func sees(player: Player, ignore_busy := false) -> bool:
	if player == null or keeper_state == Keeper.DEAD or keeper_state == Keeper.SURRENDER:
		return false
	if busy and not ignore_busy:
		return false
	var forward := _keeper_forward() if not ignore_busy else (player.global_position - _keeper.global_position).normalized()
	return _can_see(keeper_eye(), forward, SIGHT_ANGLE, SIGHT_RANGE, player, [_keeper.get_rid()])


## Hat die Kamera den Spieler im Bild?
func camera_sees(player: Player) -> bool:
	if not camera_alive or _camera == null:
		return false
	# Skill Kamera-Hack (camera_ghost): die Kamera nimmt diesen Spieler nicht auf.
	if player != null and player.has_skill_flag(&"camera_ghost"):
		return false
	var from := _camera.global_position
	var forward := (to_global(bounds.get_center()) - from).normalized()
	return _can_see(from, forward, CAMERA_ANGLE, SIGHT_RANGE, player, [_camera.get_rid()])


func _can_see(eye: Vector3, forward: Vector3, angle: float, reach: float, player: Player, exclude: Array[RID]) -> bool:
	var crouching := player.movement != null and player.movement.crouching
	var points: Array[Vector3] = [player.global_position + Vector3.UP * (0.6 if crouching else 1.0)]
	if not crouching:
		points.append(player.global_position + Vector3.UP * 1.6)
	var visibility := player.stealth.visibility if player.stealth != null else 1.0
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	for point: Vector3 in points:
		var to := point - eye
		var dist := to.length()
		if dist > reach:
			continue
		var flat := Vector3(to.x, 0.0, to.z).normalized()
		if rad_to_deg(flat_forward.angle_to(flat)) > angle:
			continue
		if dist > 3.0 and visibility < 0.2:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, point, 1 | 2, exclude)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == player:
			return true
	return false


func _keeper_forward() -> Vector3:
	var forward := -_keeper.global_basis.z
	return Vector3(forward.x, 0.0, forward.z).normalized()


func _take_one(slot: int) -> void:
	slot_count[slot] -= 1
	if slot_count[slot] <= 0:
		slot_item[slot] = -1
		slot_count[slot] = 0
	_refresh_slot(slot)


func _peer(player: Player) -> int:
	return player.get_multiplayer_authority() if WorldSync.is_online() else 1


func _set_unpaid(player: Player, amount: int) -> void:
	_unpaid[_peer(player)] = amount
	if player.controls_local_body():
		my_unpaid = amount
	else:
		_set_unpaid_remote.rpc_id(player.get_multiplayer_authority(), amount)


@rpc("authority", "reliable", "call_remote")
func _set_unpaid_remote(amount: int) -> void:
	my_unpaid = amount


## Ergebnis an den Spieler: Item bzw. Geld ins Inventar, `cost` vom Bargeld, Meldung.
func _give(player: Player, item_path: String, count: int, message: String, cost := 0) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.controls_local_body():
		_receive(item_path, count, message, cost)
	else:
		_give_remote.rpc_id(player.get_multiplayer_authority(), item_path, count, message, cost)


@rpc("authority", "reliable", "call_remote")
func _give_remote(item_path: String, count: int, message: String, cost: int) -> void:
	_receive(item_path, count, message, cost)


func _receive(item_path: String, count: int, message: String, cost: int) -> void:
	var player := WorldSync.player_of(WorldSync.local_peer())
	if player == null:
		return
	if cost > 0:
		player.inventory.spend_money(mini(cost, player.inventory.money))
	if count > 0 and item_path.begins_with("res://") and ResourceLoader.exists(item_path):
		var item := load(item_path) as ItemData
		var left := player.inventory.add_item(item, count)
		if left > 0:
			WorldSync.spawn_pickup(item, left, player.global_position + Vector3.UP * 0.8, Vector3.UP * 1.5, 0.5)
	if message != "" and player.item_user != null:
		var bad := message.begins_with("ALARM") or message.begins_with("Erwischt") or message.contains("Kamera") \
			or message.ends_with("abgebrochen")
		player.item_user.show_message(message, Color(1.0, 0.25, 0.35) if bad else Color(0.3, 1.0, 0.55))
	var ui := _open_ui()
	if ui != null:
		ui.call("refresh")


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
	var packed := PackedInt32Array()
	packed.resize(slot_item.size())
	for i in slot_item.size():
		packed[i] = slot_item[i] * 4 + slot_count[i] if slot_item[i] >= 0 else -1
	return [packed, cash, int(keeper_state), keeper_health, busy, camera_alive, armed]


func net_apply_state(data: Array) -> void:
	if data.size() < 7:
		return
	var packed: PackedInt32Array = data[0]
	for i in mini(packed.size(), slot_item.size()):
		var item := packed[i] / 4 if packed[i] >= 0 else -1
		var count := packed[i] % 4 if packed[i] >= 0 else 0
		if item != slot_item[i] or count != slot_count[i]:
			slot_item[i] = item
			slot_count[i] = count
			_refresh_slot(i)
	cash = int(data[1])
	keeper_health = float(data[3])
	busy = bool(data[4])
	armed = bool(data[6])
	if bool(data[5]) != camera_alive:
		camera_alive = bool(data[5])
		_update_camera()
	var new_state: Keeper = int(data[2])
	if new_state != keeper_state:
		if keeper_state == Keeper.DEAD:
			_respawn_keeper()
		_set_keeper(new_state)


func _set_keeper(state: Keeper) -> void:
	if keeper_state == state:
		return
	var was := keeper_state
	keeper_state = state
	if state == Keeper.DEAD and was != Keeper.DEAD:
		_model.fall(_keeper_forward())
		_keeper.collision_layer = 0
		_bark.visible = false
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
	# Figuren blicken nach -Z. -PI/2 = Blick nach +X (in den Laden und zur Tür).
	_keeper.rotation.y = -PI * 0.5
	_add_model()
	_bark = Label3D.new()
	_bark.font_size = 40
	_bark.pixel_size = 0.0035
	_bark.outline_size = 10
	_bark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bark.position = Vector3.UP * 2.15
	_bark.visible = false
	_keeper.add_child(_bark)
	_voice = _audio(Vector3.UP * 1.6, 6.0)
	_gun_audio = _audio(Vector3(0.3, 1.3, -0.3), 14.0)
	_muzzle = OmniLight3D.new()
	_muzzle.light_color = Color(1.0, 0.75, 0.4)
	_muzzle.omni_range = 4.0
	_muzzle.position = Vector3(0.3, 1.3, -0.5)
	_muzzle.visible = false
	_keeper.add_child(_muzzle)


func _audio(at: Vector3, unit: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = &"SFX"
	player.unit_size = unit
	player.position = at
	_keeper.add_child(player)
	return player


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
	box.size = Vector3(0.4, 0.3, 0.45)
	shape.shape = box
	shape.position = Vector3.UP * 0.15
	_register.add_child(shape)
	_register.add_child(_mesh(Vector3(0.38, 0.16, 0.42), _material(Color(0.12, 0.12, 0.14), 0.0), Vector3.UP * 0.08))
	_register.add_child(_mesh(Vector3(0.34, 0.05, 0.32), _material(Color(0.2, 0.2, 0.24), 0.0), Vector3(0.0, 0.18, 0.02)))
	var screen := _mesh(Vector3(0.02, 0.14, 0.26), _material(Color(0.2, 1.0, 0.6), 2.5), Vector3(-0.12, 0.3, 0.0))
	screen.rotation_degrees = Vector3(0, 0, 20)
	_register.add_child(screen)
	add_child(_register)
	_register.position = register_at


func _build_camera() -> void:
	if camera_at == Vector3.INF:
		return
	camera_alive = true
	_camera = CameraBody.new()
	_camera.name = "SecurityCamera"
	_camera.set("shop", self)
	_camera.collision_layer = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.16
	shape.shape = sphere
	_camera.add_child(shape)
	var dome := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.2
	mesh.material = _material(Color(0.1, 0.1, 0.12), 0.0)
	dome.mesh = mesh
	_camera.add_child(dome)
	var led := _mesh(Vector3(0.03, 0.03, 0.03), _material(Color(1.0, 0.1, 0.15), 4.0), Vector3(0.0, -0.06, 0.1))
	led.name = "Led"
	_camera.add_child(led)
	add_child(_camera)
	_camera.position = camera_at


func _update_camera() -> void:
	if _camera == null:
		return
	var led := _camera.get_node_or_null(^"Led") as Node3D
	if led != null:
		led.visible = camera_alive
	_camera.rotation_degrees = Vector3.ZERO if camera_alive else Vector3(40, 0, 25)


# --- Ware in den Regalen (nur in der Nähe gebaut) -----------------------------------------

func _update_goods_lod(delta: float) -> void:
	_near_check -= delta
	if _near_check > 0.0:
		return
	_near_check = 0.4
	var cam := get_viewport().get_camera_3d()
	# Ohne Kamera (Map lädt noch, Spieler noch nicht da) wird nichts gebaut, sonst entstünden in allen
	# 41 Läden auf einmal ~1700 Warenmodelle.
	var near := false
	if cam != null:
		var dist := cam.global_position.distance_to(to_global(bounds.get_center()))
		near = dist < GOODS_NEAR or (_near and dist < GOODS_FAR)
	if near != _near:
		_near = near
		_refresh_all_slots()


func _refresh_all_slots() -> void:
	for i in slots.size():
		_refresh_slot(i)


func _refresh_slot(i: int) -> void:
	if i >= _slot_nodes.size():
		return
	if _slot_nodes[i] != null:
		# Erst aus dem Baum, damit der neue Knoten denselben Namen bekommt.
		remove_child(_slot_nodes[i])
		_slot_nodes[i].queue_free()
		_slot_nodes[i] = null
	var item := item_at(i)
	if not _near or item == null:
		return
	var area := GoodsArea.new()
	area.name = "Goods%d" % i
	area.set("shop", self)
	area.set("index", i)
	area.collision_layer = 4
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.42, 0.32, 0.32)
	shape.shape = box
	shape.position = Vector3(0.0, 0.16, 0.0)
	area.add_child(shape)
	var count := slot_count[i]
	for k in count:
		var model: Node3D
		if ConsumableModel.has_model(item.model):
			model = ConsumableModel.build(item.model, item.color)
		else:
			model = _mesh(Vector3(0.08, 0.1, 0.08), _material(item.color, 1.5), Vector3.ZERO)
		model.scale = Vector3.ONE * GOODS_SCALE
		model.position = Vector3((k - (count - 1) * 0.5) * 0.12, -_bottom_of(model) * GOODS_SCALE + 0.002, 0.0)
		model.rotation.y = randf_range(-0.25, 0.25)
		area.add_child(model)
	var tag := Label3D.new()
	tag.text = "%d ¢" % price_of(item)
	tag.font_size = 32
	tag.pixel_size = 0.0018
	tag.outline_size = 6
	tag.modulate = Color(1.0, 0.95, 0.4)
	tag.position = Vector3(0.0, -0.035, 0.2)
	area.add_child(tag)
	add_child(area)
	area.transform = slots[i]["xf"]
	_slot_nodes[i] = area


## Unterkante eines frisch gebauten Modells (für das Hinstellen aufs Regal), im Raum des Modells.
func _bottom_of(root: Node3D) -> float:
	var lowest := INF
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for node: Node in nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var current: Node = mesh_instance
		while current != null and current != root:
			xf = (current as Node3D).transform * xf
			current = current.get_parent()
		lowest = minf(lowest, (xf * mesh_instance.mesh.get_aabb()).position.y)
	return lowest if lowest != INF else 0.0


# --- Verkäufer ------------------------------------------------------------------------------

func _animate_keeper(delta: float) -> void:
	if _model == null:
		return
	if keeper_state == Keeper.DEAD:
		_model.animate(delta)
		return
	# Beim Einräumen dreht er sich zur Vitrine (Rücken zum Laden).
	var target := 1.0 if busy else 0.0
	_keeper_turn = move_toward(_keeper_turn, target, delta * 1.6)
	var yaw := lerp_angle(-PI * 0.5, PI * 0.5, smoothstep(0.0, 1.0, _keeper_turn))
	if keeper_state == Keeper.ALARM and armed and _last_actor != null and is_instance_valid(_last_actor):
		var to := global_basis.inverse() * (_last_actor.global_position - _keeper.global_position)
		yaw = atan2(-to.x, -to.z)
	_keeper.rotation.y = lerp_angle(_keeper.rotation.y, yaw, minf(delta * 8.0, 1.0))
	_model.speed = 0.0
	var duck := keeper_state == Keeper.SURRENDER or (keeper_state == Keeper.ALARM and not armed)
	_model.cower = move_toward(_model.cower, 1.0 if duck else 0.0, delta * 4.0)
	_model.aim = move_toward(_model.aim, 1.0 if keeper_state == Keeper.ALARM and armed else 0.0, delta * 4.0)
	_model.animate(delta)
	if _muzzle.visible:
		_muzzle.light_energy = maxf(_muzzle.light_energy - delta * 60.0, 0.0)
		_muzzle.visible = _muzzle.light_energy > 0.05


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
	_voice.stream = SoundGen.voice(&"alert" if keeper_state != Keeper.SURRENDER else &"hurt", 1.15, randi() % 3)
	_voice.play()
	var shown := text
	get_tree().create_timer(2.6, false).timeout.connect(func() -> void:
		if is_instance_valid(_bark) and _bark.text == shown:
			_bark.visible = false)


@rpc("authority", "unreliable", "call_local")
func _show_shot(end: Vector3) -> void:
	_muzzle.visible = true
	_muzzle.light_energy = 4.0
	_gun_audio.stream = SoundGen.PISTOL_SHOT
	_gun_audio.pitch_scale = randf_range(0.9, 1.05)
	_gun_audio.play()
	var from := _muzzle.global_position
	var length := from.distance_to(end)
	if length < 0.2:
		return
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.02, 0.02, 1.0)
	mesh.material = _material(Color(1.0, 0.85, 0.5), 3.0)
	tracer.mesh = mesh
	get_tree().current_scene.add_child(tracer)
	tracer.global_transform = Transform3D(Basis.looking_at(end - from), (from + end) * 0.5)
	tracer.scale = Vector3(1, 1, length)
	get_tree().create_timer(0.05, false).timeout.connect(tracer.queue_free)


func _flash_remote() -> void:
	if WorldSync.is_online():
		_flash.rpc()
	else:
		_flash()


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


func _mesh(size: Vector3, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = at
	return instance


func _material(color: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


# --- Treff- und Benutzflächen -------------------------------------------------------------

## Verkäufer: E = Kasse (Bezahlen, Theke, Ankauf). Schüsse und Schläge treffen ihn.
class KeeperBody extends StaticBody3D:
	var shop: Node

	func get_interact_text(_player: Player) -> String:
		if not bool(shop.call("is_open_for_business")):
			return ""
		var unpaid := int(shop.get("my_unpaid"))
		return "Bezahlen (%d ¢)" % unpaid if unpaid > 0 else "Verkäufer ansprechen"

	func interact(player: Player) -> void:
		if not bool(shop.call("is_open_for_business")):
			return
		var ui: CanvasLayer = ShopUIScript.for_player(player)
		ui.call("open", shop)

	func take_hit(damage: float, _point: Vector3, _normal: Vector3) -> void:
		var player := WorldSync.player_of(WorldSync.local_peer())
		shop.call("request", player, &"hit", int(ceilf(damage)))

	func melee_hit(damage: float, point: Vector3, normal: Vector3, _push: Vector3, _stun: float) -> void:
		take_hit(damage, point, normal)


## Kasse auf der Theke: E bricht sie auf.
class RegisterBody extends StaticBody3D:
	var shop: Node

	func get_interact_text(_player: Player) -> String:
		var amount := int(shop.get("cash"))
		return "Kasse aufbrechen (%d ¢)" % amount if amount > 0 else "Kasse ist leer"

	func interact(player: Player) -> void:
		if int(shop.get("cash")) > 0:
			shop.call("request", player, &"rob")


## Überwachungskamera: ein Treffer zerstört sie.
class CameraBody extends StaticBody3D:
	var shop: Node

	func take_hit(_damage: float, _point: Vector3, _normal: Vector3) -> void:
		var player := WorldSync.player_of(WorldSync.local_peer())
		shop.call("request", player, &"camera_hit")


## Ware auf einem Platz: E nimmt ein Stück (unbezahlt, bis man an der Kasse zahlt).
class GoodsArea extends Area3D:
	var shop: Node
	var index := 0

	func get_interact_text(_player: Player) -> String:
		var item: ItemData = shop.call("item_at", index)
		if item == null:
			return ""
		var price := int(shop.call("price_of", item))
		if str(shop.call("slot_kind", index)) == "cabinet":
			return "Aus der Vitrine nehmen: %s (%d ¢)" % [item.display_name, price]
		return "Nehmen: %s (%d ¢)" % [item.display_name, price]

	func interact(player: Player) -> void:
		shop.call("request", player, &"take", index)
