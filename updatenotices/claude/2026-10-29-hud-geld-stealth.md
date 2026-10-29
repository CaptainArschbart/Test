# HUD: Geldfeld und Stealth-Anzeige überlappen nicht mehr · Claude (für Arschi)

## 2026-10-29 · Geldfeld verschoben, Stealth-Anzeige verkleinert

- Problem: Das Geldfeld „CREDS“ (`survival_hud.gd`) und die Stealth-Box (`stealth_hud.gd`) standen beide bei y = 212 direkt unter dem Vitals-Rahmen und lagen übereinander.
- Stealth-Anzeige: kompakt 200 × 46 px statt 300 × 66 px, an derselben Stelle (16, 212). Kleinere Schrift, dünnere Leisten (SICHT, LÄRM), Status und Auge bleiben. Der Zusatz „// SIGNATUR“ ist entfallen.
- Geldfeld: steht jetzt darunter bei `frame.offset_bottom + 62` (= y 266).
- Wer die Stealth-Box höher macht, muss den Abstand in `_build_money_panel` mit anpassen.
- Geänderte Dateien: `scenes/stealth/stealth_hud.gd`, `scenes/survival/survival_hud.gd`
- Getestet mit Godot 4.7.2 headless unter Windows: `test_money` 25/0, `test_consumables` 45/0. Die Optik ist nicht auf echter Hardware angesehen.
