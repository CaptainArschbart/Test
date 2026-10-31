# Taschendieb-Leiste im HUD-Stil · Claude (für Arschi)

## 2026-10-31 · Eigenes Design statt Skizze, SafeProp per preload

- `scenes/crime/pickpocket_bar.gd` neu gezeichnet, im Stil der XP-Leiste (`xp_hud.gd`):
  - Dunkelvioletter Rahmen mit abgeschrägten Ecken, Cyan-Kante und feinen Scanlines.
  - Segmentierte, schräge Leiste. Links läuft der Griff von Cyan nach Grün auf die Zielmarke zu, rechts der Verdacht von Magenta nach Rot.
  - Die Zielmarke ist ein Bernstein-Strich mit Dreiecken oben und unten. Sie glimmt stärker, je näher eine Seite ihr kommt. Sie liegt weiterhin bei 60 % (`DEAD_POINT`).
  - Beschriftung „GRIFF 45 %“ links und „30 % VERDACHT“ rechts. Leuchtende Spitzen an beiden Füllständen.
  - Ab 70 % Verdacht (`DANGER`) pulsieren Rand und Schrift rot, je näher an 100 %, desto schneller.
  - Größe 420×48 (`SIZE`), unter der Meldungszeile. Neue Hilfsfunktionen `bar_rect()` und `mark_x()`, die auch `test_npc_robbery` nutzt.
- Die Spiellogik ist unverändert (Werte, Verdacht, Abbruch).
- `scenes/crime/apartment_block.gd`: `SafeProp` wird jetzt per `preload` geladen. Aus PR #62 hatte main denselben Fehler wie bei `PickpocketBar`: Ohne Editor-Scan kompilierten `apartment_block.gd`, `city_content.gd` und `slum.gd` nicht, und Läden, Tankstellen und Wohnungen fehlten. Sonst fehlt keine neue Klasse im Cache.
- `tools/tests/test_player_move.gd` prüft jetzt zusätzlich, dass `CityContent` gebaut ist.
- Vorschau der Leiste in fünf Zuständen: `followups/taschendieb-leiste-vorschau.png` (ungetrackt, nicht im PR).
- Getestet mit Godot 4.7.2 headless:

| Test | Checks | Fehler |
|---|---|---|
| `test_player_move` | 3 | 0 |
| `test_npc_robbery` | 39 | 0 |
| `test_apartments` | 55 | 0 |
| `test_sector7_city` | 44 | 0 |
