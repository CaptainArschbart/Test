extends "res://scenes/grow/grow_station.gd"
## Trockengestell: frische Blüten hängen, bis sie trocken sind (DRY_TIME), und verlieren dabei rund
## 75 % ihres Gewichts (Wasser). Bleiben sie zu lange hängen (ab 160 %), werden sie brüchig: Premium
## wird zu Standard. Nur eine Sorte auf einmal (Standard oder Premium).

const CAPACITY := 120
const DRY_TIME := 180.0
const DRY_RATIO := 0.25
const OVERDRY := 1.6

var grams := 0
var premium := false
var dry := 0.0


func can_dismantle() -> bool:
	return grams == 0


func _tick(dt: float) -> void:
	if grams <= 0:
		return
	var before := int(dry * 10.0)
	dry = minf(dry + dt / DRY_TIME, 2.0)
	if int(dry * 10.0) != before:
		_refresh()


func _net_vars() -> Array:
	return ["grams", "premium", "dry"]


func _model_key() -> String:
	return "%d|%d" % [grams, int(minf(dry, 1.0) * 10.0)]


func dried_grams() -> int:
	return maxi(int(round(grams * DRY_RATIO)), 1)


func _text(player: Player) -> String:
	var item := _selected(player)
	if item != null and (item.id == "weed_wet" or item.id == "weed_wet_premium"):
		if grams > 0 and (dry > 0.05 or (item.id == "weed_wet_premium") != premium):
			return "Gestell belegt – erst abnehmen"
		return "Aufhängen (%d / %d g)" % [grams, CAPACITY]
	if grams <= 0:
		return "Trockengestell – frische Blüten wählen"
	if dry >= 1.0:
		return "Abnehmen: %d g getrocknet%s" % [dried_grams(), " (brüchig)" if dry >= OVERDRY else ""]
	return "Trocknet: %s (%d g frisch)" % [pct(dry), grams]


func _act(player: Player) -> void:
	var item := _selected(player)
	if item != null and (item.id == "weed_wet" or item.id == "weed_wet_premium"):
		var is_premium := item.id == "weed_wet_premium"
		if grams > 0 and (dry > 0.05 or is_premium != premium):
			_say(player, "Gestell belegt – erst abnehmen", false)
			return
		var take := mini(player.inventory.count_item(item), CAPACITY - grams)
		if take <= 0:
			_say(player, "Gestell voll", false)
			return
		grams += player.inventory.remove_item(item, take)
		premium = is_premium
		dry = 0.0
		_refresh()
		_say(player, "%d g aufgehängt" % grams)
		return
	if grams > 0 and dry >= 1.0:
		var out := dried_grams()
		var keep_premium := premium and dry < OVERDRY
		_give(player, "weed_dry_premium" if keep_premium else "weed_dry", out)
		_say(player, "%d g getrocknete Blüten%s" % [out, " – zu trocken, kein Premium mehr" if premium and not keep_premium else ""],
			keep_premium or not premium)
		grams = 0
		dry = 0.0
		_refresh()


func _build_model() -> Node3D:
	return Models.rack(float(grams) / CAPACITY, minf(dry, 1.0))
