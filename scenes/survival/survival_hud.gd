extends CanvasLayer
## Vier Leisten oben links. Liegt auf Layer 2, das Pausemenü auf Layer 10 darüber.
## Die NOCLIP-Zeile bleibt darüber frei (sie steht bei y = 20).
## Feste Größe in der 1280×720-Basis. Der Projekt-Stretch skaliert sie mit.

const WARN_HP := 30.0

@onready var hp_bar: ProgressBar = %HPBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var durst_bar: ProgressBar = %DurstBar

var stats: PlayerStats


func _ready() -> void:
	var player := get_parent() as Player
	if player == null:
		push_error("SurvivalHud braucht den Player als Parent.")
		return
	stats = player.get_node_or_null(^"PlayerStats") as PlayerStats
	if stats == null:
		push_error("SurvivalHud: Knoten PlayerStats fehlt.")
		return
	if not stats.is_node_ready():
		await stats.ready
	_apply(hp_bar, stats.hp, stats.max_hp)
	_apply(stamina_bar, stats.stamina, stats.max_stamina)
	_apply(hunger_bar, stats.hunger, stats.max_hunger)
	_apply(durst_bar, stats.thirst, stats.max_thirst)
	stats.stat_changed.connect(_on_stat_changed)


func _on_stat_changed(stat_name: String, current: float, maximum: float) -> void:
	var bar := _bar_for(stat_name)
	if bar == null:
		return
	_apply(bar, current, maximum)


func _bar_for(stat_name: String) -> ProgressBar:
	match stat_name:
		PlayerStats.STAT_HP:
			return hp_bar
		PlayerStats.STAT_STAMINA:
			return stamina_bar
		PlayerStats.STAT_HUNGER:
			return hunger_bar
		PlayerStats.STAT_THIRST:
			return durst_bar
		_:
			return null


func _process(_delta: float) -> void:
	if stats == null:
		return
	_warn(hp_bar, stats.hp, WARN_HP)
	_warn(stamina_bar, stats.stamina, stats.sprint_restart)
	_warn(hunger_bar, stats.hunger, stats.low_need)
	_warn(durst_bar, stats.thirst, stats.low_need)


func _warn(bar: ProgressBar, value: float, threshold: float) -> void:
	if value <= 0.0:
		var blink := 0.35 + 0.65 * absf(sin(float(Time.get_ticks_msec()) * 0.01))
		bar.modulate = Color(1.0, blink, blink, 1.0)
		return
	if value < threshold:
		bar.modulate = Color(1.0, 0.78, 0.4, 1.0)
		return
	bar.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _apply(bar: ProgressBar, current: float, maximum: float) -> void:
	var cap := maximum if maximum > 0.0 else 1.0
	bar.max_value = cap
	bar.value = clampf(current, 0.0, cap)
