class_name PlayerStats
extends Node
## HP, Ausdauer, Hunger und Durst eines Spielers.
##
## Hängt am Player (kein Autoload): im Hauptmenü gibt es den Knoten nicht,
## bei Pause läuft er nicht mit, weil der Baum angehalten ist.
## Hunger und Durst sinken von selbst. Unter 15 % gibt es alle 3 Sekunden
## 1–3 Schaden. Sprinten verbraucht Ausdauer und startet erst wieder ab
## `sprint_restart`, damit die Leiste an der Null nicht flackert.

signal stat_changed(stat_name: String, current: float, maximum: float)
signal died

const STAT_HP := "hp"
const STAT_STAMINA := "stamina"
const STAT_HUNGER := "hunger"
const STAT_THIRST := "thirst"

## Todesursachen für den Death-Screen (last_damage_cause). Leer = unbekannt.
const CAUSE_FALL := &"fall"
const CAUSE_GUARD := &"guard"
const CAUSE_HUNGER := &"hunger"
const CAUSE_THIRST := &"thirst"

@export var max_hp: float = 100.0
@export var max_stamina: float = 100.0
@export var max_hunger: float = 100.0
@export var max_thirst: float = 100.0

## Abnahme pro Sekunde, solange der Spieler lebt. Werte bleiben in 0…Maximum.
## Bewusst langsam: volle Leiste hält grob 15–20 Minuten.
@export var hunger_drain_rate: float = 0.08
@export var thirst_drain_rate: float = 0.12
## Sprint-Verbrauch und Erholung pro Sekunde.
@export var stamina_drain_per_second: float = 20.0
@export var stamina_regen_per_second: float = 15.0
## Schaden erst unter diesem Anteil von Hunger oder Durst (0,15 = 15 %).
@export var need_damage_ratio: float = 0.15
## Abstand zwischen zwei Mangel-Treffern.
@export var need_damage_interval: float = 3.0
## Mangel-Schaden pro Treffer: 1, bei beiden Werten 2, bei einem Wert auf 0 zusätzlich bis 3.
@export var need_damage_min: int = 1
@export var need_damage_max: int = 3
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

## Kein HP-Verlust, solange gesetzt (Noclip). Hunger und Durst sinken weiter, töten aber nicht.
var invulnerable := false
## Woher der letzte HP-Verlust kam (CAUSE_*), für den Death-Screen.
var last_damage_cause: StringName = &""

var _sprinting := false
var _regen_delay := 0.0
var _need_damage_wait := 0.0
var _dead := false
var _speed_multiplier := 1.0
var _boost_left := 0.0


func _ready() -> void:
	hp = max_hp
	stamina = max_stamina
	hunger = max_hunger
	thirst = max_thirst


func _process(delta: float) -> void:
	deplete_stats(delta)


## Eine Zeitscheibe. Tests rufen das direkt auf.
func advance(delta: float) -> void:
	deplete_stats(delta)


## Hunger und Durst sinken mit der Zeit. Unter `need_damage_ratio` fällt HP
## in festen Ticks. `delta` kommt aus `_process`, damit es nicht an die Bildrate hängt.
func deplete_stats(delta: float) -> void:
	if _dead or delta <= 0.0:
		return
	if _boost_left > 0.0:
		_boost_left = maxf(_boost_left - delta, 0.0)
		if _boost_left == 0.0:
			_speed_multiplier = 1.0
	var hunger_loss := maxf(hunger_drain_rate, 0.0) * delta
	var thirst_loss := maxf(thirst_drain_rate, 0.0) * delta
	_add(STAT_HUNGER, -hunger_loss)
	_add(STAT_THIRST, -thirst_loss)
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
	_apply_need_damage(delta)


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


## `cause` (CAUSE_*) steht später auf dem Death-Screen.
func damage(amount: float, cause: StringName = &"") -> void:
	if invulnerable or _dead:
		return
	last_damage_cause = cause
	_add(STAT_HP, -absf(amount))


func heal(amount: float) -> void:
	if _dead:
		return
	_add(STAT_HP, absf(amount))


func eat(amount: float) -> void:
	_add(STAT_HUNGER, absf(amount))


func drink(amount: float) -> void:
	_add(STAT_THIRST, absf(amount))


## Ausdauer auffüllen (positiv) oder abziehen (negativ).
func add_stamina(amount: float) -> void:
	if _dead:
		return
	_add(STAT_STAMINA, amount)


## Schneller laufen für `duration` Sekunden. Ein neuer Boost ersetzt den alten.
func boost_speed(multiplier: float, duration: float) -> void:
	if _dead or duration <= 0.0:
		return
	_speed_multiplier = maxf(multiplier, 0.1)
	_boost_left = duration


## Faktor auf die Laufgeschwindigkeit (1 = kein Boost).
func get_speed_multiplier() -> float:
	return _speed_multiplier


## Restzeit des Boosts in Sekunden.
func get_boost_left() -> float:
	return _boost_left


func restore_all() -> void:
	_dead = false
	_sprinting = false
	_regen_delay = 0.0
	_speed_multiplier = 1.0
	_boost_left = 0.0
	_need_damage_wait = 0.0
	last_damage_cause = &""
	hp = max_hp
	stamina = max_stamina
	hunger = max_hunger
	thirst = max_thirst
	stat_changed.emit(STAT_HP, hp, max_hp)
	stat_changed.emit(STAT_STAMINA, stamina, max_stamina)
	stat_changed.emit(STAT_HUNGER, hunger, max_hunger)
	stat_changed.emit(STAT_THIRST, thirst, max_thirst)


func _apply_need_damage(delta: float) -> void:
	var hunger_low := max_hunger > 0.0 and hunger < max_hunger * need_damage_ratio
	var thirst_low := max_thirst > 0.0 and thirst < max_thirst * need_damage_ratio
	if not hunger_low and not thirst_low:
		_need_damage_wait = 0.0
		return
	_need_damage_wait += delta
	var interval := maxf(need_damage_interval, 0.1)
	while _need_damage_wait >= interval:
		_need_damage_wait -= interval
		var amount := need_damage_min
		if hunger_low and thirst_low:
			amount += 1
		if hunger <= 0.0 or thirst <= 0.0:
			amount += 1
		amount = clampi(amount, need_damage_min, need_damage_max)
		if thirst_low and (thirst <= hunger or not hunger_low):
			last_damage_cause = CAUSE_THIRST
		else:
			last_damage_cause = CAUSE_HUNGER
		_add(STAT_HP, -float(amount))
		if _dead:
			return


func _add(stat_name: String, amount: float) -> void:
	if stat_name == STAT_HP and amount < 0.0 and invulnerable:
		return
	var current := _value(stat_name)
	var maximum := _maximum(stat_name)
	var next := clamp_value(current + amount, maximum)
	if is_equal_approx(next, current):
		return
	_set_value(stat_name, next)
	stat_changed.emit(stat_name, next, maximum)
	if stat_name == STAT_HP and next <= 0.0 and not _dead:
		_dead = true
		_sprinting = false
		died.emit()


## Hält einen Wert in 0…Maximum. Maximum 0 ergibt 0, damit nichts überläuft.
static func clamp_value(value: float, maximum: float) -> float:
	var cap := maximum if maximum > 0.0 else 0.0
	return clampf(value, 0.0, cap)


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
