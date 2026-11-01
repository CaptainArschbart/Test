extends Node
## Skill-Bäume des Spielers (Kampf, Bewegung, Stealth). Der Player legt den Knoten im Code an
## (Player.skills), bei jeder Figur, auch bei fremden. Ohne class_name, der Player lädt das Skript per
## preload.
##
## Punkte: einer pro Stufenaufstieg (PlayerXp), frei = Stufe − 1 − gelernte. Die Zahl hängt also nur
## an der Stufe und lässt sich nicht verlieren.
## Wirkung: Die Systeme fragen Player.skill_mult(key) und Player.has_skill_flag(key). Die Werte
## stehen in SKILLS unter "effects" (Faktoren *_mult werden multipliziert, alles andere addiert).
## Speichern: Stufe, XP und Skills des lokalen Spielers stehen in PROFILE_PATH (save_profile).
## Headless (Prüfskripte) wird nichts automatisch geladen oder gespeichert, sonst hingen die Tests am
## Spielstand auf diesem Rechner.
## Multiplayer: Der Besitzer schickt seine Liste an alle (_net_learned). Fremde Figuren fragen beim
## Spawn nach (_net_request). So kennt der Host die Skills jedes Spielers, etwa beim Taschendiebstahl.
## Der Reiter im Inventar ist SkillTreeView (scenes/inventory/skill_tree_view.gd).

signal changed

const PROFILE_PATH := "user://player_profile.cfg"
const TREES := [&"combat", &"movement", &"stealth"]
const TREE_NAMES := {&"combat": "KAMPF", &"movement": "BEWEGUNG", &"stealth": "STEALTH"}

## tier 0–2 (oben nach unten), column 0 = links, 1 = rechts, 0.5 = mittig.
const SKILLS := {
	# --- Kampf ---------------------------------------------------------------------------------
	&"steady_hand": {
		"tree": &"combat", "tier": 0, "column": 0.0, "requires": [],
		"name": "Ruhige Hand", "description": "Schusswaffen streuen 30 % weniger.",
		"effects": {&"spread_mult": 0.7},
	},
	&"heavy_fists": {
		"tree": &"combat", "tier": 0, "column": 1.0, "requires": [],
		"name": "Schwere Fäuste", "description": "Nahkampf (Fäuste und Klingen) macht 25 % mehr Schaden.",
		"effects": {&"melee_mult": 1.25},
	},
	&"fast_reload": {
		"tree": &"combat", "tier": 1, "column": 0.0, "requires": [&"steady_hand"],
		"name": "Schnellladen", "description": "Nachladen dauert 35 % kürzer.",
		"effects": {&"reload_mult": 0.65},
	},
	&"demolition": {
		"tree": &"combat", "tier": 1, "column": 1.0, "requires": [&"heavy_fists"],
		"name": "Sprengmeister", "description": "Granaten: 30 % mehr Schaden, 25 % weiter geworfen.",
		"effects": {&"grenade_mult": 1.3, &"throw_mult": 1.25},
	},
	&"armored_skin": {
		"tree": &"combat", "tier": 2, "column": 0.5, "requires": [&"fast_reload", &"demolition"],
		"name": "Panzerhaut", "description": "20 % weniger Schaden durch Gegner, Spieler und Granaten.",
		"effects": {&"damage_taken_mult": 0.8},
	},
	# --- Bewegung ------------------------------------------------------------------------------
	&"sprinter": {
		"tree": &"movement", "tier": 0, "column": 0.0, "requires": [],
		"name": "Sprinter", "description": "Sprinten ist 12 % schneller.",
		"effects": {&"sprint_mult": 1.12},
	},
	&"endurance": {
		"tree": &"movement", "tier": 0, "column": 1.0, "requires": [],
		"name": "Ausdauernd", "description": "30 % mehr Ausdauer, sie lädt 25 % schneller nach.",
		"effects": {&"stamina_mult": 1.3, &"stamina_regen_mult": 1.25},
	},
	&"slider": {
		"tree": &"movement", "tier": 1, "column": 0.0, "requires": [&"sprinter"],
		"name": "Rutschpartie", "description": "Rutschen startet 20 % schneller und bremst 25 % weniger.",
		"effects": {&"slide_mult": 1.2, &"slide_friction_mult": 0.75},
	},
	&"climber": {
		"tree": &"movement", "tier": 1, "column": 1.0, "requires": [&"endurance"],
		"name": "Kletterer", "description": "Klettern an Kanten geht 35 % schneller.",
		"effects": {&"climb_time_mult": 0.65},
	},
	&"free_runner": {
		"tree": &"movement", "tier": 2, "column": 0.5, "requires": [&"slider", &"climber"],
		"name": "Freiläufer", "description": "Sprünge 15 % höher, Fallschaden halbiert.",
		"effects": {&"jump_mult": 1.15, &"fall_damage_mult": 0.5},
	},
	# --- Stealth -------------------------------------------------------------------------------
	&"soft_soles": {
		"tree": &"stealth", "tier": 0, "column": 0.0, "requires": [],
		"name": "Leise Sohlen", "description": "Schritte, Rutschen und Landungen sind 40 % leiser.",
		"effects": {&"step_noise_mult": 0.6},
	},
	&"quick_fingers": {
		"tree": &"stealth", "tier": 0, "column": 1.0, "requires": [],
		"name": "Flinke Finger", "description": "Taschendiebstahl 35 % schneller, Verdacht steigt 25 % langsamer.",
		"effects": {&"pick_time_mult": 0.65, &"suspicion_mult": 0.75},
	},
	&"shadow": {
		"tree": &"stealth", "tier": 1, "column": 0.0, "requires": [&"soft_soles"],
		"name": "Schatten", "description": "Du bist 25 % schwerer zu sehen.",
		"effects": {&"visibility_mult": 0.75},
	},
	&"lockpick": {
		"tree": &"stealth", "tier": 1, "column": 1.0, "requires": [&"quick_fingers"],
		"name": "Dietrich", "description": "Verschlossene Türen ohne Schlüssel leise knacken (E).",
		"effects": {&"lockpick": 1.0},
	},
	&"camera_hack": {
		"tree": &"stealth", "tier": 2, "column": 0.5, "requires": [&"shadow", &"lockpick"],
		"name": "Kamera-Hack", "description": "Überwachungskameras in Läden zeichnen dich nicht auf.",
		"effects": {&"camera_ghost": 1.0},
	},
}

## Gelernte Skills (Id → true).
var learned := {}
## Stufe des Besitzers. Beim lokalen Spieler aus PlayerXp, bei fremden Figuren übers Netz.
var level := 1
## Lokaler Spieler: Stand wird in PROFILE_PATH gespeichert (außer headless).
var autosave := false

var _player: Node
var _base_max_stamina := -1.0
var _base_stamina_regen := -1.0
var _effects := {}


func _ready() -> void:
	_player = get_parent()
	# Kinder, die nach dem Spawn entstehen, erben die Autorität nicht von selbst.
	if _player != null:
		set_multiplayer_authority(_player.get_multiplayer_authority(), false)
	_rebuild_effects()
	# Kurz warten: Die in der Map platzierte Figur entfernt NetworkManager erst beim Map-Start, sie
	# soll nicht beim Host nach einem Knoten fragen, den es dort nicht gibt.
	if _is_puppet():
		get_tree().create_timer(0.5).timeout.connect(_net_request)


func _is_puppet() -> bool:
	return _player != null and _player.has_method("controls_local_body") \
		and not _player.call("controls_local_body")


# --- Punkte und Lernen ---------------------------------------------------------------------

func points_total() -> int:
	return maxi(level - 1, 0)


func points_spent() -> int:
	return learned.size()


func points_free() -> int:
	return maxi(points_total() - points_spent(), 0)


func has(id: StringName) -> bool:
	return learned.has(id)


## Alle Voraussetzungen gelernt (der Skill selbst kann schon gelernt sein).
func requirements_met(id: StringName) -> bool:
	if not SKILLS.has(id):
		return false
	for req: StringName in SKILLS[id]["requires"]:
		if not learned.has(req):
			return false
	return true


func can_learn(id: StringName) -> bool:
	return SKILLS.has(id) and not learned.has(id) and requirements_met(id) and points_free() > 0


## "learned", "available" (Punkt und Voraussetzungen da), "unlocked" (Voraussetzungen da, kein Punkt)
## oder "locked".
func state_of(id: StringName) -> String:
	if learned.has(id):
		return "learned"
	if not requirements_met(id):
		return "locked"
	return "available" if points_free() > 0 else "unlocked"


func learn(id: StringName) -> bool:
	if not can_learn(id):
		return false
	learned[id] = true
	_after_change()
	return true


## Alle Punkte zurück (Prüfskripte, Neustart des Profils).
func reset() -> void:
	learned.clear()
	_after_change()


func set_level(value: int) -> void:
	level = maxi(value, 1)
	changed.emit()


func _after_change() -> void:
	_rebuild_effects()
	apply_stats()
	changed.emit()
	broadcast()
	if autosave:
		save_profile()


# --- Wirkung -------------------------------------------------------------------------------

## Faktor für `key` (1 ohne passenden Skill).
func mult(key: StringName) -> float:
	return float(_effects.get(key, 1.0))


## Summe für `key` (0 ohne passenden Skill), z. B. Schalter wie lockpick.
func add(key: StringName) -> float:
	return float(_effects.get(key, 0.0))


func _rebuild_effects() -> void:
	_effects.clear()
	for id: StringName in learned:
		if not SKILLS.has(id):
			continue
		var effects: Dictionary = SKILLS[id]["effects"]
		for key: StringName in effects:
			var value := float(effects[key])
			if String(key).ends_with("_mult"):
				_effects[key] = float(_effects.get(key, 1.0)) * value
			else:
				_effects[key] = float(_effects.get(key, 0.0)) + value


## Ausdauer am PlayerStats nachziehen (Ausdauernd). Die Grundwerte merkt sich der erste Aufruf.
func apply_stats() -> void:
	var stats: Node = _player.get_node_or_null(^"PlayerStats") if _player != null else null
	if stats == null:
		return
	if _base_max_stamina < 0.0:
		_base_max_stamina = stats.max_stamina
		_base_stamina_regen = stats.stamina_regen_per_second
	var old_stamina: float = stats.max_stamina
	stats.max_stamina = _base_max_stamina * mult(&"stamina_mult")
	stats.stamina_regen_per_second = _base_stamina_regen * mult(&"stamina_regen_mult")
	# Mehr Maximum gibt den Zuwachs gleich dazu, weniger schneidet ab.
	if stats.is_alive():
		stats.stamina = PlayerStats.clamp_value(stats.stamina + maxf(stats.max_stamina - old_stamina, 0.0), stats.max_stamina)
	stats.stat_changed.emit("stamina", stats.stamina, stats.max_stamina)


# --- Speichern -----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var ids := PackedStringArray()
	for id: StringName in learned:
		ids.append(String(id))
	ids.sort()
	return {"learned": ids}


func from_dict(data: Dictionary) -> void:
	learned.clear()
	for id in data.get("learned", PackedStringArray()):
		var key := StringName(str(id))
		if SKILLS.has(key):
			learned[key] = true
	_rebuild_effects()
	apply_stats()
	changed.emit()


## Schreibt Stufe, XP und Skills nach `path`.
func save_profile(path := PROFILE_PATH) -> Error:
	var config := ConfigFile.new()
	var xp: Node = _player.get("xp") if _player != null else null
	if xp != null:
		config.set_value("xp", "level", xp.level)
		config.set_value("xp", "xp", xp.xp)
		config.set_value("xp", "total_xp", xp.total_xp)
	config.set_value("skills", "learned", to_dict()["learned"])
	return config.save(path)


## Liest das Profil. Skills ohne genug Punkte (kaputte Datei) werden von hinten verworfen.
func load_profile(path := PROFILE_PATH) -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	var xp: Node = _player.get("xp") if _player != null else null
	if xp != null:
		xp.level = clampi(int(config.get_value("xp", "level", 1)), 1, xp.MAX_LEVEL)
		xp.xp = clampi(int(config.get_value("xp", "xp", 0)), 0, maxi(xp.needed() - 1, 0))
		xp.total_xp = maxi(int(config.get_value("xp", "total_xp", 0)), 0)
		level = xp.level
		xp.xp_changed.emit(xp.level, xp.xp, xp.needed(), 0)
	from_dict({"learned": config.get_value("skills", "learned", PackedStringArray())})
	_drop_invalid()
	broadcast()
	return true


## Ohne Voraussetzung oder über die Punkte hinaus Gelerntes fliegt raus.
func _drop_invalid() -> void:
	var dirty := true
	while dirty:
		dirty = false
		for id: StringName in learned.keys():
			if not requirements_met(id):
				learned.erase(id)
				dirty = true
	var ids: Array = learned.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return SKILLS[a]["tier"] < SKILLS[b]["tier"])
	while learned.size() > points_total() and not ids.is_empty():
		learned.erase(ids.pop_back())
	_rebuild_effects()
	apply_stats()
	changed.emit()


# --- Multiplayer ---------------------------------------------------------------------------

func _online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer) \
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## Besitzer: eigenen Stand an alle schicken.
func broadcast() -> void:
	if not _online() or _is_puppet() or not is_inside_tree():
		return
	_net_learned.rpc(to_dict()["learned"], level)


## Fremde Figur: beim Besitzer nachfragen (späterer Beitritt, Spawn-Reihenfolge).
func _net_request() -> void:
	if not _online() or not is_inside_tree():
		return
	_net_ask.rpc_id(get_multiplayer_authority())


@rpc("any_peer", "reliable", "call_remote")
func _net_ask() -> void:
	if _is_puppet():
		return
	_net_learned.rpc_id(multiplayer.get_remote_sender_id(), to_dict()["learned"], level)


@rpc("any_peer", "reliable", "call_remote")
func _net_learned(ids: PackedStringArray, owner_level: int) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority() or not _is_puppet():
		return
	level = clampi(owner_level, 1, 50)
	from_dict({"learned": ids})
	_drop_invalid()
