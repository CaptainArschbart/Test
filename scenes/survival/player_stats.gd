class_name PlayerStats
extends Node
## HP, Ausdauer, Hunger und Durst eines Spielers.
##
## Hängt am Player (kein Autoload): im Hauptmenü gibt es den Knoten nicht,
## bei Pause läuft er nicht mit, weil der Baum angehalten ist.
## Hunger und Durst sinken von selbst. Bei 0 gibt es keinen Ausdauer-Nachschub
## und HP fallen. Sprinten verbraucht Ausdauer und startet erst wieder ab
## `sprint_restart`, damit die Leiste an der Null nicht flackert.

signal stat_changed(stat_name: String, current: float, maximum: float)
signal died

const STAT_HP := "hp"
const STAT_STAMINA := "stamina"
const STAT_HUNGER := "hunger"
const STAT_THIRST := "thirst"

@export var max_hp: float = 100.0
@export var max_stamina: float = 100.0
@export var max_hunger: float = 100.0
@export var max_thirst: float = 100.0

## Verlust pro Sekunde, solange der Spieler lebt.
@export var hunger_per_second: float = 0.35
@export var thirst_per_second: float = 0.55
## Sprint-Verbrauch und Erholung pro Sekunde.
@export var stamina_drain_per_second: float = 20.0
@export var stamina_regen_per_second: float = 15.0
## HP-Verlust pro Sekunde, wenn der jeweilige Wert auf 0 steht. Beide addieren sich.
@export var starve_hp_per_second: float = 4.0
@export var dehydrate_hp_per_second: float = 6.0
## Unter diesem Wert erholt sich Ausdauer nur noch halb, solange der Wert über 0 liegt.
@export var low_need: float = 25.0
## Ausdauer, die da sein muss, um Sprint neu zu starten.
@export var sprint_restart: float = 15.0
## Sekunden ohne Sprint, bevor Ausdauer wieder steigt.
@export var regen_delay_seconds: float = 0.75

var hp: float = 100.0
var stamina: float = 100.0
var hunger: float = 100.0
var thirst: float = 100.0

var _sprinting := false
var _regen_delay := 0.0
var _dead := false


func _ready() -> void:
	hp = max_hp
	stamina = max_stamina
	hunger = max_hunger
	thirst = max_thirst


func _process(delta: float) -> void:
	advance(delta)


## Eine Zeitscheibe. Tests rufen das direkt auf.
func advance(delta: float) -> void:
	if _dead or delta <= 0.0:
		return
	_add(STAT_HUNGER, -hunger_per_second * delta)
	_add(STAT_THIRST, -thirst_per_second * delta)
	if _sprinting:
		_add(STAT_STAMINA, -stamina_drain_per_second * delta)
		if stamina <= 0.0:
			_sprinting = false
	elif _regen_delay > 0.0:
		_regen_delay = maxf(_regen_delay - delta, 0.0)
	elif hunger > 0.0 and thirst > 0.0:
		var rate := stamina_regen_per_second
		if hunger < low_need or thirst < low_need:
			rate *= 0.5
		_add(STAT_STAMINA, rate * delta)
	if hunger <= 0.0:
		_add(STAT_HP, -starve_hp_per_second * delta)
	if thirst <= 0.0:
		_add(STAT_HP, -dehydrate_hp_per_second * delta)


func set_sprinting(wants: bool) -> void:
	var continuing := _sprinting and stamina > 0.0
	var starting := not _sprinting and stamina >= sprint_restart
	_sprinting = wants and not _dead and (continuing or starting)
	if _sprinting:
		_regen_delay = regen_delay_seconds


func is_sprinting() -> bool:
	return _sprinting


func is_alive() -> bool:
	return not _dead


func damage(amount: float) -> void:
	_add(STAT_HP, -absf(amount))


func heal(amount: float) -> void:
	if _dead:
		return
	_add(STAT_HP, absf(amount))


func eat(amount: float) -> void:
	_add(STAT_HUNGER, absf(amount))


func drink(amount: float) -> void:
	_add(STAT_THIRST, absf(amount))


func restore_all() -> void:
	_dead = false
	_sprinting = false
	_regen_delay = 0.0
	hp = max_hp
	stamina = max_stamina
	hunger = max_hunger
	thirst = max_thirst
	stat_changed.emit(STAT_HP, hp, max_hp)
	stat_changed.emit(STAT_STAMINA, stamina, max_stamina)
	stat_changed.emit(STAT_HUNGER, hunger, max_hunger)
	stat_changed.emit(STAT_THIRST, thirst, max_thirst)


func _add(stat_name: String, amount: float) -> void:
	var current := _value(stat_name)
	var maximum := _maximum(stat_name)
	var next := clampf(current + amount, 0.0, maximum)
	if is_equal_approx(next, current):
		return
	_set_value(stat_name, next)
	stat_changed.emit(stat_name, next, maximum)
	if stat_name == STAT_HP and next <= 0.0 and not _dead:
		_dead = true
		_sprinting = false
		died.emit()


func _value(stat_name: String) -> float:
	match stat_name:
		STAT_HP:
			return hp
		STAT_STAMINA:
			return stamina
		STAT_HUNGER:
			return hunger
		STAT_THIRST:
			return thirst
		_:
			return 0.0


func _maximum(stat_name: String) -> float:
	match stat_name:
		STAT_HP:
			return max_hp
		STAT_STAMINA:
			return max_stamina
		STAT_HUNGER:
			return max_hunger
		STAT_THIRST:
			return max_thirst
		_:
			return 1.0


func _set_value(stat_name: String, value: float) -> void:
	match stat_name:
		STAT_HP:
			hp = value
		STAT_STAMINA:
			stamina = value
		STAT_HUNGER:
			hunger = value
		STAT_THIRST:
			thirst = value
