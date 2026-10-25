extends CanvasLayer
## Vier Leisten oben links. Liegt auf Layer 2, das Pausemenü auf Layer 10 darüber.
## Die NOCLIP-Zeile bleibt darüber frei (sie steht bei y = 20).

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


func _apply(bar: ProgressBar, current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current
