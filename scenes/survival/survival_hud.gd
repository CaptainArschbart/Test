extends CanvasLayer
## Vier Leisten oben links. Liegt auf Layer 2, das Pausemenü auf Layer 10 darüber.
## Die NOCLIP-Zeile bleibt darüber frei (sie steht bei y = 20).
## Feste Größe in der 1280×720-Basis. Der Projekt-Stretch skaliert sie mit.

## Unter 20 % wird die Leiste entsättigt und durchsichtiger. Größe und Position bleiben.
const FADE_RATIO := 0.2
const FADE_ALPHA := 0.42

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
	_fade(hp_bar, stats.hp, stats.max_hp)
	_fade(stamina_bar, stats.stamina, stats.max_stamina)
	_fade(hunger_bar, stats.hunger, stats.max_hunger)
	_fade(durst_bar, stats.thirst, stats.max_thirst)


func _fade(bar: ProgressBar, value: float, maximum: float) -> void:
	var cap := maximum if maximum > 0.0 else 1.0
	bar.modulate = fade_color(value / cap)


## 1 = volle Neonfarbe. Darunter Grau, nahe 0 ein gedämpftes Rot und weniger Alpha.
## Alpha bleibt über 0, die Leiste verschwindet nicht und rückt nicht.
static func fade_color(ratio: float) -> Color:
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped >= FADE_RATIO:
		return Color(1.0, 1.0, 1.0, 1.0)
	var amount := 1.0 - (clamped / FADE_RATIO)
	var gray := lerpf(1.0, 0.55, amount)
	var alpha := lerpf(FADE_ALPHA, 1.0, 1.0 - amount)
	var color := Color(gray, gray, gray, alpha)
	if amount > 0.65:
		var warn := (amount - 0.65) / 0.35
		color = color.lerp(Color(0.72, 0.34, 0.34, alpha), warn)
	if clamped <= 0.02:
		var pulse := 0.82 + 0.18 * absf(sin(float(Time.get_ticks_msec()) * 0.004))
		color.a *= pulse
	return color


func _apply(bar: ProgressBar, current: float, maximum: float) -> void:
	var cap := maximum if maximum > 0.0 else 1.0
	bar.max_value = cap
	bar.value = clampf(current, 0.0, cap)
