extends "res://scenes/grow/grow_station.gd"
## Fermentierglas (Curing, 2 l): getrocknete Blüten reifen im verschlossenen Glas nach (CURE_TIME).
## Die Restfeuchte steigt in den Glas-Luft (Hygrometer). Regelmäßig lüften („burpen“) senkt sie auf
## 58 %. Über 75 % leidet das Aroma (Premium wird Standard), ab 85 % für MOLD_TIME Sekunden schimmeln
## die Blüten (verloren). Nach vollem Curing: fermentierte Blüten herausnehmen.

const CAPACITY := 28
const CURE_TIME := 240.0
## Feuchte-Anstieg pro Sekunde zu Beginn; sinkt mit fortschreitendem Curing.
const HUMIDITY_RISE := 0.12 / 30.0
const BURPED := 0.58
const START := 0.66
const AROMA_LOSS := 0.75
const MOLD := 0.85
const MOLD_TIME := 20.0

var grams := 0
var premium := false
var cure := 0.0
var humidity := 0.0
var moldy := false

var _mold_left := MOLD_TIME
var _peak := 0.0


func can_dismantle() -> bool:
	return grams == 0


func _tick(dt: float) -> void:
	if grams <= 0 or moldy:
		return
	cure = minf(cure + dt / CURE_TIME, 1.0)
	humidity = minf(humidity + HUMIDITY_RISE * dt * (1.0 - cure * 0.7), 1.0)
	_peak = maxf(_peak, humidity)
	if humidity >= MOLD:
		_mold_left -= dt
		if _mold_left <= 0.0:
			moldy = true
			_refresh()
	else:
		_mold_left = MOLD_TIME


func _net_vars() -> Array:
	return ["grams", "premium", "cure", "humidity", "moldy", "_mold_left", "_peak"]


func _model_key() -> String:
	return "%d|%s" % [grams, moldy]


func keeps_premium() -> bool:
	return premium and _peak <= AROMA_LOSS


func _text(player: Player) -> String:
	var item := _selected(player)
	if moldy:
		return "Verschimmelt – ausleeren"
	if item != null and (item.id == "weed_dry" or item.id == "weed_dry_premium"):
		if grams > 0 and (cure > 0.05 or (item.id == "weed_dry_premium") != premium):
			return "Glas belegt"
		return "Einfüllen (%d / %d g)" % [grams, CAPACITY]
	if grams <= 0:
		return "Fermentierglas – getrocknete Blüten wählen"
	if cure >= 1.0:
		return "Herausnehmen: %d g fermentiert (Feuchte %s)" % [grams, pct(humidity)]
	return "Lüften – Curing %s, Feuchte %s%s" % [pct(cure), pct(humidity), " (zu feucht!)" if humidity > AROMA_LOSS else ""]


func _act(player: Player) -> void:
	var item := _selected(player)
	if moldy:
		grams = 0
		moldy = false
		cure = 0.0
		_refresh()
		_say(player, "Verschimmelte Blüten entsorgt", false)
		return
	if item != null and (item.id == "weed_dry" or item.id == "weed_dry_premium"):
		var is_premium := item.id == "weed_dry_premium"
		if grams > 0 and (cure > 0.05 or is_premium != premium):
			_say(player, "Glas belegt", false)
			return
		var take := mini(player.inventory.count_item(item), CAPACITY - grams)
		if take <= 0:
			_say(player, "Glas voll", false)
			return
		if grams == 0:
			humidity = START
			_peak = START
			_mold_left = MOLD_TIME
		grams += player.inventory.remove_item(item, take)
		premium = is_premium
		cure = 0.0
		_refresh()
		_say(player, "%d g eingefüllt – täglich lüften" % grams)
		return
	if grams <= 0:
		return
	if cure >= 1.0:
		var keep := keeps_premium()
		_give(player, "weed_cured_premium" if keep else "weed_cured", grams)
		_say(player, "%d g fermentierte Blüten%s" % [grams, " – Premium" if keep else (" – Aroma gelitten" if premium else "")],
			keep or not premium)
		grams = 0
		cure = 0.0
		humidity = 0.0
		_refresh()
		return
	humidity = minf(humidity, BURPED)
	_say(player, "Gelüftet (Feuchte %s)" % pct(humidity))


func _build_model() -> Node3D:
	return Models.jar(float(grams) / CAPACITY, moldy)
