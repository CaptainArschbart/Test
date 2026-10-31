# Spieler bewegt sich wieder · Claude (für Arschi)

## 2026-10-31 · PickpocketBar per preload

- Fehler nach PR #60: `scenes/player/item_user.gd` nutzte den neuen Klassennamen `PickpocketBar`. Godot trägt neue `class_name`s erst bei einem Editor-Scan in `.godot/global_script_class_cache.cfg` ein. Nach dem Pull fehlte der Eintrag, deshalb kompilierten `item_user.gd` und alle abhängigen Skripte nicht (`player_movement.gd`, `weapon_holder.gd`, `world_sync.gd` …). Der Spieler konnte sich nicht mehr bewegen.
- Fix: `item_user.gd` lädt die Leiste per `const PICKPOCKET_BAR := preload("res://scenes/crime/pickpocket_bar.gd")`, so wie schon `GRENADE_SCRIPT`. Das funktioniert auch ohne Cache-Eintrag.
- Neu: `tools/tests/test_player_move.gd` startet Sektor 7 über das Menü und prüft, dass der Spieler mit W läuft. Ohne den Fix bricht er mit den Compile-Fehlern ab.
- Regel für neue Skripte, die vom Spieler benutzt werden: preload statt `class_name`.
- Getestet mit Godot 4.7.2 headless:

| Test | Checks | Fehler |
|---|---|---|
| `test_player_move` | 2 | 0 |
| `test_npc_robbery` | 39 | 0 |
| `test_gas_stations` | 59 | 0 |
| `test_sector7_city` | 44 | 0 |
