# Performance · Claude (für Arschi)

## 2026-10-31 · CPU-Last gesenkt, zwei Leistungsoptionen

Ausgangslage auf Arschis Ryzen 7 1700 mit 4K, Schatten Ultra, SSAO und Nebel: 10–15 FPS. Die GPU braucht nur ~6 ms pro Frame, gebremst hat die CPU. Laut Messung über die Merges kam der große Einbruch mit PR #62 (Wohnungen in acht Häusern, 20 → 11 FPS), ein kleinerer mit #53 (25 → 20 FPS).

- **Bewohner-LOD** (`civilian.gd`): Personen ohne CrowdDirector (Bewohner der Wohnungen) stufen sich selbst ein, alle 0,5 s nach dem Abstand zur Kamera und zum nächsten Spieler. Unter 18 m voll, bis 35 m gedrosselt, dahinter schlafen sie. Vorher liefen alle 18 Bewohner immer mit voller Rechenlast (Kollision, zwei Strahltests und Animation pro Physik-Tick).
- **Wohnhäuser** (`apartment_house.gd`): Treppenhaus, Wohnungen und Lichter werden ab 45 m Kameraabstand nicht gezeichnet (`INTERIOR_FAR`).
- **Läden** (`shop_interior.gd`): Der Innenraum wird ab 60 m nicht gezeichnet. Ein ruhiger Verkäufer wird ab 42 m nicht mehr animiert (gleiche Grenze wie die Waren).
- **Sonnenschatten Ultra** (`world_atmosphere.gd`): Reichweite 100 statt 160 m. Jede Kaskade zeichnet die Stadt noch einmal.
- **Lampenschatten** (`slum_piece.gd`, `slum_prop.gd`): `distance_fade_shadow = 22 m` (`SlumPiece.SHADOW_FADE`). Die Schattenkarten der Laternen werden nur noch in der Nähe gezeichnet.
- **Neue Optionen unter Grafik**, beide standardmäßig aus:
  - „Physik 30 Hz (schont die CPU)“: `Settings.physics_rate` 60/30. Bei 30 Hz ist die Physik-Interpolation an. Die Kamera ist dabei nicht interpoliert, damit der Mausblick sofort reagiert, folgt aber jedes Bild der interpolierten Körperposition (`PlayerMovement.refresh_camera`). Beim Respawn und bei verlegten oder synchronisierten Passanten wird die Interpolation zurückgesetzt.
  - „Render-Thread (experimentell, nach Neustart)“: `Settings.render_thread` schreibt `rendering/driver/threads/thread_model=2` in `override.cfg`. Im Editor liegt die Datei im Projektordner, exportiert neben der exe. Godot liest sie beim Start, deshalb wirkt die Option erst nach einem Neustart. `override.cfg` steht in `.gitignore`.
- `tools/tests/test_player_move.gd`: prüft zusätzlich Laufen bei 30 Hz, Kamera am Kopf und das Zurückschalten auf 60 Hz.
- Bewohner-LOD nur für ortsfeste Personen (`stay_put`). Eine Test-Person ohne CrowdDirector, die laufen soll, bleibt wie bisher voll aktiv.
- Gemessen in Sektor 7 mit Arschis Einstellungen (4K, Ultra-Schatten, SSAO, Nebel, Ryzen 7 1700 + RTX 5060), FPS-Begrenzung aus:

| Stand | FPS |
|---|---|
| main vorher | 10–15 |
| dieser PR, Physik 60 Hz | 24,5 |
| dieser PR, Physik 30 Hz | 28,9 |
| dieser PR, Physik 60 Hz + Render-Thread | 62,0 |
| dieser PR, Physik 30 Hz + Render-Thread | 66,3 |

  Mit Render-Thread meldet Godot beim Start einmal „Condition p_image.is_null()“. Abgestürzt ist es in den Messläufen nicht.
- Getestet mit Godot 4.7.2 headless, alle Tests ohne Fehler:

| Test | Checks |
|---|---|
| `test_player_move` | 7 |
| `test_apartments` | 55 |
| `test_apartments_walk` | 96 |
| `test_npc_robbery` | 39 |
| `test_shop` | 43 |
| `test_gun_shops` | 29 |
| `test_options_scroll` | 27 |
| `test_sector7_city` | 44 |
| `test_gas_stations` | 59 |
| `test_content_update` | 47 |
