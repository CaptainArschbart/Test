class_name GameSettings
extends RefCounted
## Gemeinsame Einstellungen in user://settings.cfg.
##
## [video] fullscreen, vsync
## [audio] master_volume
##
## set_fullscreen schreibt nur das Vollbild-Flag und lässt die übrigen Schlüssel stehen.


const PATH := "user://settings.cfg"


static func get_fullscreen(default: bool) -> bool:
	return bool(_load().get_value("video", "fullscreen", default))


static func get_vsync(default: bool = true) -> bool:
	return bool(_load().get_value("video", "vsync", default))


static func get_master_volume(default: float = 80.0) -> float:
	return float(_load().get_value("audio", "master_volume", default))


static func set_fullscreen(enabled: bool) -> void:
	var config := _load()
	config.set_value("video", "fullscreen", enabled)
	config.save(PATH)


static func save_preferences(fullscreen: bool, vsync: bool, master_volume: float) -> void:
	var config := _load()
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("audio", "master_volume", master_volume)
	config.save(PATH)


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(PATH)
	return config
