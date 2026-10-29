class_name CityContent
extends Node3D
## Wohnungen, zwei Waffenläden und drei Tankstellen auf Sektor 7.
## Liegt als Kind der Slum-Map, damit die Kit-Szenen unangetastet bleiben.

const PLACES: Array[Dictionary] = [
	{"kind": "apt", "at": Vector3(96.0, 0.0, 88.0), "key": "apt_a", "yaw": 0.0},
	{"kind": "apt", "at": Vector3(-92.0, 0.0, 84.0), "key": "apt_b", "hide": "apt_a", "yaw": 180.0},
	{"kind": "apt", "at": Vector3(-88.0, 0.0, -96.0), "key": "apt_c", "hide": "apt_b", "yaw": 90.0},
	{"kind": "guns", "at": Vector3(112.0, 0.0, -36.0), "yaw": 0.0},
	{"kind": "guns", "at": Vector3(-36.0, 0.0, 112.0), "yaw": 180.0},
	{"kind": "gas", "at": Vector3(108.0, 0.0, 24.0), "key": "apt_c", "yaw": 0.0},
	{"kind": "gas", "at": Vector3(-112.0, 0.0, -16.0), "yaw": 90.0},
	{"kind": "gas", "at": Vector3(16.0, 0.0, -112.0), "yaw": 0.0},
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
