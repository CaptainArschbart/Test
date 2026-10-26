class_name SlumFlicker
extends Node
## Lässt das Eltern-Licht (und optional ein Material) unregelmäßig flackern, wie eine kaputte Röhre.

## 0 = ruhig, 1 = stark und oft aus.
@export_range(0.0, 1.0) var amount := 0.3
@export var base_energy := 1.0
## Optional: Material, dessen Emission mitflackert.
var material: StandardMaterial3D
var base_emission := 1.0

var _timer := 0.0
var _target := 1.0
var _value := 1.0


func _ready() -> void:
	_timer = randf() * 2.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		if randf() < amount * 0.35:
			_target = randf_range(0.0, 0.3)
			_timer = randf_range(0.03, 0.12)
		else:
			_target = randf_range(1.0 - amount * 0.3, 1.0)
			_timer = randf_range(0.08, 1.6 - amount)
	_value = lerpf(_value, _target, minf(delta * 30.0, 1.0))
	var light := get_parent() as Light3D
	if light != null:
		light.light_energy = base_energy * _value
	if material != null:
		material.emission_energy_multiplier = base_emission * _value
