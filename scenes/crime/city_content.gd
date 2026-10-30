class_name CityContent
extends Node3D
## Vier Waffenläden und drei Tankstellen. Wohnungen sitzen im Wohnblock Res2, nicht auf freien Platten.
## Waffenläden 8×7 m, Tankstellen inklusive Vordach etwa 8×9 m.
const PLACES: Array[Dictionary] = [
	{"kind": "guns", "at": Vector3(-110.0, 0.0, 60.0), "yaw": 90.0},
	{"kind": "guns", "at": Vector3(70.0, 0.0, 64.0), "yaw": 0.0},
	{"kind": "guns", "at": Vector3(-70.0, 0.0, -46.0), "yaw": 0.0},
	{"kind": "guns", "at": Vector3(-16.0, 0.0, -42.0), "yaw": 0.0},
	{"kind": "gas", "at": Vector3(-111.0, 0.0, 88.0), "yaw": 90.0},
	{"kind": "gas", "at": Vector3(-48.0, 0.0, -71.0), "yaw": 0.0},
	{"kind": "gas", "at": Vector3(90.0, 0.0, -101.0), "key": "apt_c", "yaw": 0.0},
]


func _ready() -> void:
	for place: Dictionary in PLACES:
		var at: Vector3 = place["at"]
		var yaw := deg_to_rad(float(place["yaw"]))
		var node: Node3D
		if str(place["kind"]) == "apt":
			var home := ApartmentBlock.new()
			home.key_id = str(place["key"])
			home.hidden_key = str(place.get("hide", ""))
			node = home
		else:
			var shop := StreetShop.new()
			shop.kind = StreetShop.Kind.GAS if str(place["kind"]) == "gas" else StreetShop.Kind.GUNS
			shop.shop_key = str(place.get("key", ""))
			node = shop
		node.position = at
		node.rotation.y = yaw
		add_child(node)
