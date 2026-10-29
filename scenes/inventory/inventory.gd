class_name Inventory
extends Node
## Inventar des Spielers: Hotbar (Slots 0–8) plus Rucksack (ab Slot 9).
##
## Reine Daten und Logik, keine Anzeige. Die UI (inventory_ui.gd) hört auf
## `changed` und `selected_changed` und ruft move() / quick_move() auf.

## Nach jeder Änderung an Slots.
signal changed
## Neuer gewählter Hotbar-Slot (0–8).
signal selected_changed(index: int)
## Etwas wurde aufgenommen (für die Einblendung "+3 Credchip").
signal item_added(item: ItemData, amount: int)
## Kontostand hat sich geändert (`delta` > 0 = bekommen, < 0 = ausgegeben).
signal money_changed(money: int, delta: int)

const HOTBAR_SIZE := 9
## Obergrenze für das Geld.
const MAX_MONEY := 999999

## Slots im Rucksack (Raster mit HOTBAR_SIZE Spalten).
@export var backpack_size := 27
## Startausrüstung, kommt beim Spielstart in die Hotbar.
@export var starting_items: Array[ItemData] = []
## Geld beim Spielstart.
@export var starting_money := 0

var selected := 0
## Kontostand in Credchips. Währungs-Items (ItemData.is_currency) landen hier statt in einem Slot.
var money := 0

var _items: Array[ItemData] = []
var _counts := PackedInt32Array()


func _ready() -> void:
	_items.resize(HOTBAR_SIZE + backpack_size)
	_counts.resize(HOTBAR_SIZE + backpack_size)
	for item in starting_items:
		add_item(item, 1, false)
	add_money(starting_money)


func get_size() -> int:
	return _items.size()


func has_index(index: int) -> bool:
	return index >= 0 and index < _items.size()


func get_item(index: int) -> ItemData:
	if not has_index(index):
		return null
	return _items[index]


func get_count(index: int) -> int:
	if not has_index(index):
		return 0
	return _counts[index]


func get_selected_item() -> ItemData:
	return get_item(selected)


func is_hotbar(index: int) -> bool:
	return index < HOTBAR_SIZE


## Legt Items ab: erst auf passende Stapel, dann in freie Slots (Hotbar zuerst).
## Gibt zurück, wie viele nicht mehr gepasst haben.
func add_item(item: ItemData, amount := 1, notify := true) -> int:
	if item != null and item.is_currency:
		var added := add_money(amount)
		if added > 0 and notify:
			item_added.emit(item, added)
		return amount - added
	var all := range(get_size())
	var left := _merge_into(item, amount, all)
	left = _fill_empty(item, left, all)
	if left != amount:
		changed.emit()
		if notify:
			item_added.emit(item, amount - left)
	return left


## Bucht Geld gut (bis MAX_MONEY). Gibt zurück, wie viel tatsächlich dazukam.
func add_money(amount: int) -> int:
	var added := clampi(amount, 0, MAX_MONEY - money)
	if added > 0:
		money += added
		money_changed.emit(money, added)
	return added


func has_money(amount: int) -> bool:
	return money >= amount


## Zieht `amount` ab, wenn genug da ist. false = zu wenig Geld, nichts abgezogen.
func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	if amount > 0:
		money -= amount
		money_changed.emit(money, -amount)
	return true


## Nimmt das ganze Geld heraus (z. B. beim Tod). Gibt die Summe zurück.
func take_all_money() -> int:
	var amount := money
	if amount > 0:
		money = 0
		money_changed.emit(0, -amount)
	return amount


## Nimmt bis zu `amount` aus einem Slot. Gibt die tatsächlich entnommene Menge zurück.
func remove_at(index: int, amount := 1) -> int:
	if not has_index(index) or _items[index] == null:
		return 0
	var removed := mini(amount, _counts[index])
	_counts[index] -= removed
	if _counts[index] <= 0:
		_clear(index)
	changed.emit()
	return removed


## Drag & Drop: gleiche stapelbare Items werden zusammengelegt, sonst getauscht.
func move(from: int, to: int) -> void:
	if not has_index(from) or not has_index(to):
		return
	var item := _items[from]
	if from == to or item == null:
		return
	if item.is_same(_items[to]) and item.max_stack > 1:
		var moved := mini(item.max_stack - _counts[to], _counts[from])
		if moved <= 0:
			return
		_counts[to] += moved
		_counts[from] -= moved
		if _counts[from] <= 0:
			_clear(from)
	else:
		var other_item := _items[to]
		var other_count := _counts[to]
		_items[to] = item
		_counts[to] = _counts[from]
		_items[from] = other_item
		_counts[from] = other_count
	changed.emit()


## Rechtsklick: Hotbar → Rucksack bzw. Rucksack → Hotbar, so viel wie passt.
func quick_move(index: int) -> void:
	if not has_index(index):
		return
	var item := _items[index]
	if item == null:
		return
	var target := range(HOTBAR_SIZE, get_size()) if is_hotbar(index) else range(HOTBAR_SIZE)
	var left := _merge_into(item, _counts[index], target)
	left = _fill_empty(item, left, target)
	if left == _counts[index]:
		return
	_counts[index] = left
	if left == 0:
		_clear(index)
	changed.emit()


func select(index: int) -> void:
	index = posmod(index, HOTBAR_SIZE)
	if index == selected:
		return
	selected = index
	selected_changed.emit(selected)


## Mausrad: +1 = nächster Slot, -1 = vorheriger (läuft im Kreis).
func select_next(direction: int) -> void:
	select(selected + direction)


func _merge_into(item: ItemData, amount: int, indices: Array) -> int:
	for i: int in indices:
		if amount <= 0:
			break
		if item.is_same(_items[i]) and _counts[i] < item.max_stack:
			var moved := mini(item.max_stack - _counts[i], amount)
			_counts[i] += moved
			amount -= moved
	return amount


func _fill_empty(item: ItemData, amount: int, indices: Array) -> int:
	for i: int in indices:
		if amount <= 0:
			break
		if _items[i] == null:
			_items[i] = item
			_counts[i] = mini(item.max_stack, amount)
			amount -= _counts[i]
	return amount


func _clear(index: int) -> void:
	_items[index] = null
	_counts[index] = 0
