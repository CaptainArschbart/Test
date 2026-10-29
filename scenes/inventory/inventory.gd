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
## Bankkonto hat sich geändert (Bankautomat: einzahlen, abheben, Überweisung).
signal bank_changed(balance: int, delta: int)
## Eine Überweisung ist eingegangen (nur beim Empfänger).
signal transfer_received(amount: int, from_name: String)

const HOTBAR_SIZE := 9
## Obergrenze für das Geld.
const MAX_MONEY := 999999

## Slots im Rucksack (Raster mit HOTBAR_SIZE Spalten).
@export var backpack_size := 27
## Startausrüstung, kommt beim Spielstart in die Hotbar.
@export var starting_items: Array[ItemData] = []
## Geld beim Spielstart.
@export var starting_money := 0
## Guthaben auf dem Bankkonto beim Spielstart.
@export var starting_bank := 0

var selected := 0
## Kontostand in Credchips. Währungs-Items (ItemData.is_currency) landen hier statt in einem Slot.
var money := 0
## Guthaben auf dem Bankkonto (Bankautomat). Bleibt beim Tod erhalten, nur das Bargeld `money` fällt.
var bank := 0

var _items: Array[ItemData] = []
var _counts := PackedInt32Array()


func _ready() -> void:
	_items.resize(HOTBAR_SIZE + backpack_size)
	_counts.resize(HOTBAR_SIZE + backpack_size)
	for item in starting_items:
		add_item(item, 1, false)
	add_money(starting_money)
	add_bank(starting_bank)


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


## Bucht `amount` aufs Bankkonto (bis MAX_MONEY). Gibt zurück, wie viel dazukam.
func add_bank(amount: int) -> int:
	var added := clampi(amount, 0, MAX_MONEY - bank)
	if added > 0:
		bank += added
		bank_changed.emit(bank, added)
	return added


## Zieht `amount` vom Bankkonto ab. false = zu wenig Guthaben, nichts abgezogen.
func spend_bank(amount: int) -> bool:
	if amount < 0 or bank < amount:
		return false
	if amount > 0:
		bank -= amount
		bank_changed.emit(bank, -amount)
	return true


## Bargeld aufs Konto: so viel, wie da ist und aufs Konto passt. Gibt den Betrag zurück.
func deposit(amount: int) -> int:
	var moved := mini(clampi(amount, 0, money), MAX_MONEY - bank)
	if moved <= 0:
		return 0
	spend_money(moved)
	add_bank(moved)
	return moved


## Vom Konto abheben: so viel, wie da ist und ins Bargeld passt. Gibt den Betrag zurück.
func withdraw(amount: int) -> int:
	var moved := mini(clampi(amount, 0, bank), MAX_MONEY - money)
	if moved <= 0:
		return 0
	spend_bank(moved)
	add_money(moved)
	return moved


## Überweist `amount` vom eigenen Konto auf das Konto von `target` (z. B. eines anderen Spielers).
## Online bucht der Besitzer von `target` die Gutschrift per RPC, offline geschieht sie direkt.
## false = ungültiger Betrag, zu wenig Guthaben oder kein Empfänger.
func send_transfer(target: Inventory, amount: int, from_name := "") -> bool:
	if target == null or target == self or amount <= 0 or bank < amount:
		return false
	var peer := multiplayer.multiplayer_peer
	var online := peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	var owner_id := target.get_multiplayer_authority()
	spend_bank(amount)
	if online and owner_id != multiplayer.get_unique_id():
		target.receive_transfer.rpc_id(owner_id, amount)
	else:
		target.credit_transfer(amount, from_name)
	return true


## Gutschrift einer Überweisung über das Netz. Der Absendername kommt aus der Peer-ID.
@rpc("any_peer", "reliable", "call_remote")
func receive_transfer(amount: int) -> void:
	if amount <= 0 or amount > MAX_MONEY:
		return
	credit_transfer(amount, peer_display_name(multiplayer.get_remote_sender_id()))


## Bucht eine eingegangene Überweisung. Bei vollem Konto (MAX_MONEY) verfällt der Rest.
func credit_transfer(amount: int, from_name: String) -> void:
	var added := add_bank(amount)
	if added > 0:
		transfer_received.emit(added, from_name)


## Anzeigename eines Spielers aus seiner Peer-ID (1 = Host).
static func peer_display_name(peer_id: int) -> String:
	if peer_id == 1:
		return "Runner-1 (Host)"
	return "Runner-%d" % (peer_id % 10000)


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


## Wie viele Stück von `item` noch ins Inventar passen (bei Währung: bis MAX_MONEY).
func space_for(item: ItemData) -> int:
	if item == null:
		return 0
	if item.is_currency:
		return MAX_MONEY - money
	var space := 0
	for i: int in _items.size():
		if _items[i] == null:
			space += item.max_stack
		elif item.is_same(_items[i]):
			space += maxi(item.max_stack - _counts[i], 0)
	return space


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
