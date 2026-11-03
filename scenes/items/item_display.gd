class_name ItemDisplay
extends RefCounted
## Das sichtbare 3D-Modell eines Items, ohne Spiellogik: für Pickups und gerenderte Inventar-Icons.
##
## Waffen nehmen ihre view_scene (ohne Mündungsfeuer), Items mit ItemData.model ihr ConsumableModel,
## Klingen und Granaten ohne Modell die Display-Modelle aus ConsumableModel. Sonst kommt null
## zurück, dann bleibt es bei Würfel bzw. Raute.


static func build(item: ItemData) -> Node3D:
	if item is WeaponData:
		var weapon := item as WeaponData
		if weapon.view_scene == null:
			return null
		var model: Node3D = weapon.view_scene.instantiate()
		# Mündungsfeuer gehört nur in die Hand.
		for flash: String in ["Muzzle/Flash", "Muzzle/FlashLight"]:
			var node := model.get_node_or_null(flash)
			if node != null:
				node.get_parent().remove_child(node)
				node.free()
		return model
	if ConsumableModel.has_model(item.model):
		return ConsumableModel.build(item.model, item.color)
	if item is MeleeData:
		return ConsumableModel.build_blade(item.color)
	if item is GrenadeData:
		return ConsumableModel.build_grenade(item.color, (item as GrenadeData).contact_fuse)
	return null
