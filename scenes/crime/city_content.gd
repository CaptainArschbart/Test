class_name CityContent
extends Node3D
## Wohnungen, vier Waffenläden und drei Tankstellen auf Sektor 7.
## Liegt als Kind der Slum-Map, damit die Kit-Szenen unangetastet bleiben.

## Freie Flecken auf den Bodenplatten, mindestens 1 m von Kit-Gebäuden und nicht auf der Fahrbahn.
## Wohnungen 8×7 m, Waffenläden 8×7 m, Tankstellen inklusive Vordach etwa 8×9 m.
const PLACES: Array[Dictionary] = [
	{"kind": "apt", "at": Vector3(-110.0, 0.0, -82.0), "key": "apt_a", "yaw": 90.0},
	{"kind": "apt", "at": Vector3(-70.0, 0.0, 26.0), "key": "apt_b", "hide": "apt_a", "yaw": 0.0},
	{"kind": "apt", "at": Vector3(84.0, 0.0, 98.0), "key": "apt_c", "hide": "apt_b", "yaw": 180.0},
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
