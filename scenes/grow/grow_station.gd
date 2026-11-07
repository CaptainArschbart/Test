class_name GrowStation
extends StaticBody3D
## Grundlage der Anbau-Stationen (Topf, Growlampe, Trockengestell, Fermentierglas, Verpackungstisch).
##
## Bedienung über E (ItemUser): Was passiert, hängt vom gewählten Hotbar-Item ab (Erde, Samen,
## Wasserflasche, Dünger, Blüten …), ohne passendes Item zeigt der Hinweis den Zustand oder die
## nächste Aktion. Geduckt + E baut eine leere Station ab (das Item kommt zurück ins Inventar).
## Die Zeit läuft in _process (nur offline und beim Host); Tests rufen simulate(sekunden).
## Multiplayer und Spielstand: GrowSync. Der Zustand jeder Station sind die Variablen aus
## _net_vars() (net_state / net_apply).

const Models := preload("res://scenes/grow/grow_models.gd")
const GROUP := &"grow_station"
const SCRIPTS := {
	&"pot": "res://scenes/grow/grow_pot.gd",
	&"lamp": "res://scenes/grow/grow_lamp.gd",
	&"rack": "res://scenes/grow/drying_rack.gd",
	&"jar": "res://scenes/grow/curing_jar.gd",
	&"table": "res://scenes/grow/packing_table.gd",
}
const ITEM := "res://scenes/items/data/%s.tres"
## Längster Schritt, in dem simulate() rechnet (s).
const STEP := 0.5

var kind := &"pot"
## Item, das beim Abbauen zurückkommt.
var source: ItemData

## Kennung im Netz und im Spielstand (GrowSync.placed), Revision zählt jede Bedienung.
var net_id := ""
var net_rev := 0

var _model: Node3D


## Station zu `kind` anlegen (noch nicht im Baum).
static func create(station_kind: StringName, item: ItemData = null) -> Node:
	var script: GDScript = load(SCRIPTS.get(station_kind, SCRIPTS[&"pot"]))
	var station: Node = script.new()
	station.kind = station_kind
	station.source = item
	return station


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 1
	collision_mask = 0
	var size := Models.footprint(kind)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	add_child(shape)
	_refresh()


func _process(delta: float) -> void:
	if GrowSync.simulates():
		_tick(delta)


## Zeit vorspulen (Tests): in Schritten von höchstens STEP Sekunden.
func simulate(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var dt := minf(left, STEP)
		_tick(dt)
		left -= dt


func get_interact_text(player: Player) -> String:
	if _crouching(player) and can_dismantle():
		return "Abbauen: %s" % (source.display_name if source != null else "Station")
	return _text(player)


func interact(player: Player) -> void:
	if _crouching(player) and can_dismantle():
		_dismantle(player)
		return
	_act(player)
	if not is_queued_for_deletion():
		GrowSync.changed(self)


# --- Zustand (Netz, Spielstand) ------------------------------------------------------------------

## Namen der Variablen, die den Zustand ausmachen.
func _net_vars() -> Array:
	return []


func net_state() -> Dictionary:
	var state := {"rev": net_rev}
	for key: String in _net_vars():
		state[key] = get(key)
	return state


## Zustand übernehmen. Ohne `force` nur, wenn die Revision nicht älter ist als die eigene.
func net_apply(state: Dictionary, force := false) -> void:
	var rev := int(state.get("rev", net_rev))
	if not force and rev < net_rev:
		return
	var before := _model_key()
	for key: String in _net_vars():
		if state.has(key):
			set(key, state[key])
	net_rev = rev
	if _model_key() != before:
		_refresh()


## Ändert sich dieser Schlüssel, wird das Modell neu gebaut.
func _model_key() -> String:
	return ""


# --- Für die Stationen ---------------------------------------------------------------------------

func _tick(_dt: float) -> void:
	pass


func _text(_player: Player) -> String:
	return ""


func _act(_player: Player) -> void:
	pass


func can_dismantle() -> bool:
	return true


## Modell neu bauen (nach Zustandswechsel).
func _refresh() -> void:
	if _model != null:
		_model.queue_free()
	_model = _build_model()
	if _model != null:
		add_child(_model)


func _build_model() -> Node3D:
	return Models.station(kind)


func _selected(player: Player) -> ItemData:
	return player.inventory.get_selected_item() if player != null and player.inventory != null else null


func _selected_is(player: Player, ids: Array) -> bool:
	var item := _selected(player)
	return item != null and ids.has(item.id)


static func item(id: String) -> ItemData:
	return load(ITEM % id) as ItemData


## Gibt `count` Stück von `id` ins Inventar, den Rest legt es als Pickup vor die Station.
func _give(player: Player, id: String, count: int) -> void:
	if count <= 0:
		return
	var left := player.inventory.add_item(item(id), count)
	if left > 0:
		WorldSync.spawn_pickup(item(id), left, global_position + Vector3.UP * 0.6, Vector3.UP, 0.4)


func _say(player: Player, text: String, good := true) -> void:
	if player != null and player.item_user != null:
		player.item_user.show_message(text, Color(0.4, 1.0, 0.6) if good else Color(1.0, 0.5, 0.3))


func _crouching(player: Player) -> bool:
	return player != null and player.movement != null and player.movement.crouching


func _dismantle(player: Player) -> void:
	if source != null:
		var left := player.inventory.add_item(source, 1)
		if left > 0:
			_say(player, player.inventory.full_message(source), false)
			return
	_say(player, "%s abgebaut" % (source.display_name if source != null else "Station"))
	GrowSync.removed(self)
	queue_free()


static func pct(value: float) -> String:
	return "%d %%" % int(round(clampf(value, 0.0, 9.99) * 100.0))
