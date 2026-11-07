extends "res://scenes/grow/grow_station.gd"
## Verpackungstisch mit Feinwaage: fermentierte Blüten abwiegen und verpacken.
##   - Modus Tütchen: 1 g in ein leeres Zip-Tütchen.
##   - Modus Glas: 7 g in ein leeres Einmachglas (luftdicht, hält das Aroma).
## Fermentierte Blüten wählen + E verpackt eine Einheit (Standard oder Premium bleibt erhalten).
## Ohne Blüten in der Hand schaltet E den Modus um.

const UNITS := {
	"bag": {"grams": 1, "container": "baggie_empty", "product": "weed_baggie", "name": "Tütchen"},
	"jar": {"grams": 7, "container": "jar_empty", "product": "weed_jar", "name": "Glas"},
}

var mode := "bag"


func _net_vars() -> Array:
	return ["mode"]


func _text(player: Player) -> String:
	var unit: Dictionary = UNITS[mode]
	var buds := _selected(player)
	if buds != null and (buds.id == "weed_cured" or buds.id == "weed_cured_premium"):
		return "Verpacken: %d g ins %s (Waage %d,00 g)" % [unit.grams, unit.name, unit.grams]
	return "Modus %s %d g – auf %s umstellen" % [unit.name, unit.grams, "Glas 7 g" if mode == "bag" else "Tütchen 1 g"]


func _act(player: Player) -> void:
	var buds := _selected(player)
	if buds == null or not (buds.id == "weed_cured" or buds.id == "weed_cured_premium"):
		mode = "jar" if mode == "bag" else "bag"
		_say(player, "Verpacken in %s" % UNITS[mode].name)
		return
	var unit: Dictionary = UNITS[mode]
	var container := item(unit.container)
	if player.inventory.count_item(buds) < int(unit.grams):
		_say(player, "Zu wenig Blüten (%d g nötig)" % unit.grams, false)
		return
	if player.inventory.count_item(container) < 1:
		_say(player, "Kein leeres %s im Inventar" % unit.name, false)
		return
	var product: String = unit.product + ("_premium" if buds.id == "weed_cured_premium" else "")
	if player.inventory.space_for(item(product)) < 1:
		_say(player, "Inventar voll", false)
		return
	player.inventory.remove_item(buds, int(unit.grams))
	player.inventory.remove_item(container, 1)
	player.inventory.add_item(item(product), 1)
	_say(player, "%d g ins %s verpackt" % [unit.grams, unit.name])


func _build_model() -> Node3D:
	return Models.table()
