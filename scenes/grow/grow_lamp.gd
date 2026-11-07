extends "res://scenes/grow/grow_station.gd"
## LED-Growlampe. Töpfe bis RADIUS (waagerecht) unter dem Panel wachsen mit vollem Licht.
## Lichtzyklus wie bei echten Photoperiode-Sorten: 18/6 hält die Pflanze im Wachstum (sie wird größer,
## mehr Ertrag), 12/12 löst die Blüte aus. E schaltet um. Violettes bzw. warmes Licht zeigt den Modus.

const LAMP_GROUP := &"grow_lamp"
## Reichweite des Lichtkegels (m, waagerecht vom Panel).
const RADIUS := 0.85
## Lage der Panel-Mitte im Raum der Lampe.
const PANEL := Vector3(0.12, 1.6, 0.0)

## true = 12/12 (Blüte), false = 18/6 (Wachstum).
var flower_cycle := false

var _light: OmniLight3D


func _ready() -> void:
	add_to_group(LAMP_GROUP)
	super._ready()


## Bekommt ein Topf an `point` (Welt) Licht von dieser Lampe?
func lights(point: Vector3) -> bool:
	var panel := global_transform * PANEL
	return Vector2(point.x - panel.x, point.z - panel.z).length() <= RADIUS and point.y < panel.y


func _text(_player: Player) -> String:
	return "Lichtzyklus %s – auf %s umstellen" % ["12/12 (Blüte)" if flower_cycle else "18/6 (Wachstum)",
		"18/6" if flower_cycle else "12/12"]


func _act(player: Player) -> void:
	flower_cycle = not flower_cycle
	_refresh()
	_say(player, "Lichtzyklus %s" % ("12/12: Blüte" if flower_cycle else "18/6: Wachstum"))


func _build_model() -> Node3D:
	var model := Models.lamp(true, flower_cycle)
	_light = OmniLight3D.new()
	_light.position = PANEL + Vector3.DOWN * 0.1
	_light.light_color = Color(1.0, 0.65, 0.45) if flower_cycle else Color(0.8, 0.45, 1.0)
	_light.light_energy = 1.6
	_light.omni_range = 2.2
	model.add_child(_light)
	return model
