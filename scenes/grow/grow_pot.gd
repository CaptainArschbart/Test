extends "res://scenes/grow/grow_station.gd"
## Pflanztopf mit Hanfpflanze („Neon Kush“, Photoperiode). Ablauf wie beim echten Anbau, nur schneller:
##   Erde einfüllen → Samen setzen → Keimung → Keimling → Wachstum → Blüte → Ernte.
## Pflege (gewähltes Item + E):
##   - Wasserflasche: Feuchte +60 %. Trocknet die Erde aus (< 12 %), welkt die Pflanze (Gesundheit
##     sinkt); gießt man in nasse Erde (> 85 %), gibt es Staunässe (Gesundheit −15 %).
##   - Dünger: Nährstoffe +50 %. Über 120 % Nährstoffbrand (Gesundheit −20 %), ohne Nährstoffe wächst
##     sie langsamer und blüht schwächer.
##   - Licht: unter einer Growlampe volles Tempo und mehr Ertrag. 18/6 hält sie im Wachstum (sie wird
##     größer), 12/12 löst die Blüte aus. Ohne Lampe halbes Tempo, Blüte von selbst nach dem Wachstum.
## Erntezeitpunkt an den Trichomen: klar (zu früh, wenig Ertrag), milchig (richtig), bernstein
## (spät, ab 130 % Blüte überreif). Ernte gibt frische Blüten (Gramm), Premium ab Qualität 75 %.
## Zeiten (bei vollem Licht): Keimung 30 s, Keimling 90 s, Wachstum 180 s, Blüte 360 s.

enum Stage { EMPTY, SOIL, GERM, SEEDLING, VEG, FLOWER, DEAD }

const GERM_TIME := 30.0
const SEEDLING_TIME := 90.0
const VEG_TIME := 180.0
## So weit wächst sie unter 18/6 höchstens weiter (Vielfaches von VEG_TIME).
const VEG_MAX := 2.33
const FLOWER_TIME := 360.0
const WATER_DRAIN := 1.0 / 150.0
const NUTRIENT_DRAIN := 1.0 / 300.0
const WATER_DOSE := 0.6
const NUTRIENT_DOSE := 0.5
## Ab dieser Blüte (Anteil) darf geerntet werden.
const HARVEST_FROM := 0.6
## Womit gegossen wird: Wasserflasche (verbraucht) oder Gießkanne (Anzahl = Liter, 1 l je Gabe).
const CAN := "watering_can"
const CAN_EMPTY := "watering_can_empty"
const WATER_IDS := ["water_bottle", "watering_can"]
const PREMIUM := 0.75

var stage: Stage = Stage.EMPTY
var water := 0.0
var nutrients := 0.0
var health := 1.0
## Fortschritt im aktuellen Abschnitt (Keimung/Keimling: Sekunden; Wachstum, Blüte: Anteil).
var progress := 0.0
var veg := 0.0
var flower := 0.0

var _grow_time := 0.0
var _health_time := 0.0
var _lit_time := 0.0
var _fed_time := 0.0
var _flower_time := 0.0
var _stress := 0
var _shape_key := ""


func can_dismantle() -> bool:
	return stage == Stage.EMPTY


func is_lit() -> bool:
	return _lamp() != null


## Kennzahlen für Hinweis und Tests.
func size() -> float:
	match stage:
		Stage.GERM:
			return 0.02
		Stage.SEEDLING:
			return 0.05 + 0.1 * progress / SEEDLING_TIME
		Stage.VEG, Stage.FLOWER, Stage.DEAD:
			var s := 0.15 + 0.6 * minf(veg, 1.0) + 0.25 * clampf((veg - 1.0) / (VEG_MAX - 1.0), 0.0, 1.0)
			# Streckung in den ersten Blütenwochen.
			return minf(s * (1.0 + 0.2 * clampf(flower / 0.3, 0.0, 1.0)), 1.2)
	return 0.0


func trichomes() -> String:
	if flower < 0.85:
		return "klar"
	if flower <= 1.15:
		return "milchig"
	return "bernstein"


func _lamp() -> Node:
	for lamp in get_tree().get_nodes_in_group(&"grow_lamp"):
		if lamp.has_method("lights") and lamp.lights(global_position + Vector3.UP * 0.3):
			return lamp
	return null


func _tick(dt: float) -> void:
	if stage <= Stage.SOIL or stage == Stage.DEAD:
		return
	var lamp := _lamp()
	var lit := lamp != null
	var growing := stage >= Stage.VEG
	water = maxf(water - WATER_DRAIN * dt * (1.3 if lit else 1.0) * (1.2 if stage == Stage.FLOWER else 1.0), 0.0)
	if growing:
		nutrients = maxf(nutrients - NUTRIENT_DRAIN * dt, 0.0)
	# Gesundheit: Trockenheit schadet, gute Bedingungen erholen.
	if water < 0.12 and stage >= Stage.SEEDLING:
		health -= dt / 90.0
	elif water >= 0.25 and water <= 0.85 and (not growing or nutrients >= 0.1):
		health += dt / 240.0
	health = clampf(health, 0.0, 1.0)
	if health <= 0.0:
		stage = Stage.DEAD
		_refresh()
		return
	var speed := (1.0 if lit else 0.5) * (0.5 + 0.5 * health)
	if water <= 0.0:
		speed = 0.0
	if growing and nutrients < 0.1:
		speed *= 0.6
	_grow_time += dt
	_health_time += health * dt
	if lit:
		_lit_time += dt
	if growing and nutrients >= 0.1:
		_fed_time += dt
	match stage:
		Stage.GERM:
			progress += dt * speed
			if progress >= GERM_TIME:
				stage = Stage.SEEDLING
				progress = 0.0
		Stage.SEEDLING:
			progress += dt * speed
			if progress >= SEEDLING_TIME:
				stage = Stage.VEG
				progress = 0.0
		Stage.VEG:
			var flower_light: bool = lit and bool(lamp.get("flower_cycle"))
			var cap: float = VEG_MAX if lit and not flower_light else 1.0
			veg = minf(veg + dt * speed / VEG_TIME, cap)
			# Blüte: ohne Lampe nach dem Wachstum von selbst, unter 12/12 ab halber Größe.
			var bloom: bool = (not lit and veg >= 1.0) or (flower_light and veg >= 0.5)
			if bloom:
				stage = Stage.FLOWER
		Stage.FLOWER:
			flower = minf(flower + dt * speed / FLOWER_TIME, 1.6)
			_flower_time += dt
	_update_shape()


func _update_shape() -> void:
	var key := _model_key()
	if key != _shape_key:
		_shape_key = key
		_refresh()


func _model_key() -> String:
	return "%d|%d|%d|%d" % [stage, int(size() * 20.0), int(flower * 20.0), int(health * 10.0)]


func _net_vars() -> Array:
	return ["stage", "water", "nutrients", "health", "progress", "veg", "flower", "_grow_time",
		"_health_time", "_lit_time", "_fed_time", "_flower_time", "_stress"]


func _text(player: Player) -> String:
	var item := _selected(player)
	var id := item.id if item != null else ""
	match stage:
		Stage.EMPTY:
			return "Erde einfüllen" if id == "potting_soil" else "Leerer Topf – Blumenerde wählen"
		Stage.SOIL:
			if id == "cannabis_seed":
				return "Samen einpflanzen"
			if id in WATER_IDS:
				return "Erde anfeuchten (Feuchte %s)" % pct(water)
			return "Topf mit Erde – Hanfsamen wählen"
		Stage.DEAD:
			return "Pflanze ist eingegangen – entsorgen"
	if id in WATER_IDS:
		return "Gießen (Feuchte %s)" % pct(water)
	if id == CAN_EMPTY:
		return "Gießkanne ist leer – am Wasserhahn füllen"
	if id == "fertilizer" and stage >= Stage.SEEDLING:
		return "Düngen (Nährstoffe %s)" % pct(nutrients)
	if stage == Stage.FLOWER and flower >= HARVEST_FROM:
		return "Ernten (Trichome %s, Blüte %s)" % [trichomes(), pct(flower)]
	return _status()


func _status() -> String:
	var phase := ""
	match stage:
		Stage.GERM:
			phase = "Keimung %s" % pct(progress / GERM_TIME)
		Stage.SEEDLING:
			phase = "Keimling %s" % pct(progress / SEEDLING_TIME)
		Stage.VEG:
			phase = "Wachstum %s" % pct(veg)
		Stage.FLOWER:
			phase = "Blüte %s, Trichome %s" % [pct(flower), trichomes()]
	var hints := []
	if water < 0.2:
		hints.append("durstig")
	if stage >= Stage.VEG and nutrients < 0.1:
		hints.append("Nährstoffmangel")
	if not is_lit():
		hints.append("ohne Lampe")
	return "%s · Feuchte %s · Nährstoffe %s · Gesundheit %s%s" % [phase, pct(water), pct(nutrients), pct(health),
		(" · " + ", ".join(hints)) if not hints.is_empty() else ""]


func _act(player: Player) -> void:
	var item := _selected(player)
	var id := item.id if item != null else ""
	match stage:
		Stage.EMPTY:
			if id == "potting_soil" and player.inventory.remove_item(item, 1) == 1:
				stage = Stage.SOIL
				water = 0.2
				_refresh()
				_say(player, "Erde eingefüllt")
			return
		Stage.SOIL:
			if id == "cannabis_seed" and player.inventory.remove_item(item, 1) == 1:
				_plant()
				_say(player, "Samen eingepflanzt – feucht halten")
				return
			if id in WATER_IDS:
				_water(player, item)
			elif id == CAN_EMPTY:
				_say(player, "Gießkanne ist leer – am Wasserhahn füllen", false)
			return
		Stage.DEAD:
			_reset()
			_say(player, "Pflanze entsorgt, Erde verbraucht", false)
			return
	if id in WATER_IDS:
		_water(player, item)
	elif id == CAN_EMPTY:
		_say(player, "Gießkanne ist leer – am Wasserhahn füllen", false)
	elif id == "fertilizer" and stage >= Stage.SEEDLING:
		if player.inventory.remove_item(item, 1) == 1:
			nutrients += NUTRIENT_DOSE
			if nutrients > 1.2:
				health -= 0.2
				_stress += 1
				_say(player, "Nährstoffbrand! Zu viel Dünger", false)
			else:
				_say(player, "Gedüngt (Nährstoffe %s)" % pct(nutrients))
	elif stage == Stage.FLOWER and flower >= HARVEST_FROM:
		_harvest(player)
	else:
		_say(player, _status())


func _plant() -> void:
	stage = Stage.GERM
	progress = 0.0
	veg = 0.0
	flower = 0.0
	health = 1.0
	nutrients = maxf(nutrients, 0.3)
	_grow_time = 0.0
	_health_time = 0.0
	_lit_time = 0.0
	_fed_time = 0.0
	_flower_time = 0.0
	_stress = 0
	_refresh()


func _water(player: Player, item: ItemData) -> void:
	if item.id == CAN:
		# Gießkanne: 1 Liter aus der gewählten Kanne, die letzte Gabe lässt die leere Kanne zurück.
		var slot: int = player.inventory.selected
		if player.inventory.remove_at(slot, 1) != 1:
			return
		if player.inventory.get_item(slot) == null:
			if player.inventory.add_at(slot, load(ITEM % CAN_EMPTY) as ItemData, 1) > 0:
				_give(player, CAN_EMPTY, 1)
	elif player.inventory.remove_item(item, 1) != 1:
		return
	if water > 0.85 and stage >= Stage.SEEDLING:
		health = maxf(health - 0.15, 0.0)
		_stress += 1
		_say(player, "Staunässe! Die Wurzeln brauchen Luft", false)
	else:
		_say(player, "Gegossen")
	water = minf(water + WATER_DOSE, 1.0)


## Ertrag und Qualität nach Pflege, Licht und Erntezeitpunkt.
func harvest_result() -> Dictionary:
	var avg_health := _health_time / maxf(_grow_time, 1.0)
	var lit := _lit_time / maxf(_grow_time, 1.0)
	var fed := _fed_time / maxf(_flower_time, 1.0) if _flower_time > 0.0 else 0.0
	var timing: float
	if flower < 0.85:
		timing = lerpf(0.55, 0.85, clampf((flower - HARVEST_FROM) / (0.85 - HARVEST_FROM), 0.0, 1.0))
	elif flower < 1.0:
		timing = lerpf(0.85, 1.0, (flower - 0.85) / 0.15)
	elif flower <= 1.15:
		timing = 1.0
	elif flower <= 1.3:
		timing = lerpf(1.0, 0.8, (flower - 1.15) / 0.15)
	else:
		timing = 0.7
	var veg_bonus := clampf((veg - 1.0) / (VEG_MAX - 1.0), 0.0, 1.0)
	var grams := int(round((40.0 + 50.0 * veg_bonus) * avg_health * timing * (0.6 + 0.4 * lit) * (0.7 + 0.3 * fed)))
	var quality := 0.45 * avg_health + 0.3 * timing + 0.15 * lit + 0.1 * fed - 0.05 * _stress
	return {"grams": maxi(grams, 1), "quality": clampf(quality, 0.0, 1.0), "premium": quality >= PREMIUM}


func _harvest(player: Player) -> void:
	var result := harvest_result()
	var id := "weed_wet_premium" if result.premium else "weed_wet"
	_give(player, id, result.grams)
	_say(player, "%d g frische Blüten geerntet%s (Qualität %s)" % [result.grams, " – Premium" if result.premium else "",
		pct(result.quality)])
	_reset()


func _reset() -> void:
	stage = Stage.EMPTY
	water = 0.0
	nutrients = 0.0
	health = 1.0
	progress = 0.0
	veg = 0.0
	flower = 0.0
	_refresh()


func _build_model() -> Node3D:
	var model := Models.pot(stage != Stage.EMPTY)
	if stage >= Stage.GERM:
		var plant := Models.plant(size(), flower if stage != Stage.DEAD else 0.0,
			health if stage != Stage.DEAD else 0.0)
		plant.position = Vector3(0, 0.24, 0)
		model.add_child(plant)
	return model
