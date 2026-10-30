# Optionen im Pausemenü und 4K-Bild · Claude (für Arschi)

## 2026-10-30 · Optionen ingame wieder sichtbar, 3D-Skalierung bei 4K korrigiert

- `scenes/pause/pause_menu.tscn`: Die Optionen bekommen eine Mindestgröße von 720 × 520. Im Pausemenü sitzen sie in einem CenterContainer. Seit die Listen scrollen (e4fc130), hatten die ScrollContainer dort keine Mindesthöhe mehr und klappten auf 0 px zusammen. Ingame waren dadurch nur Kopf, Reiter und Knöpfe zu sehen. Im Hauptmenü hat das Feld eine feste Größe, deshalb trat der Fehler dort nicht auf.
- `autoload/settings.gd` (`_apply_3d_scale`):
  - Der Full-HD-Deckel und die Upscaling-Stufe werden nicht mehr multipliziert. Bei 4K ergab „DLSS Qualität“ bisher 0,5 × 0,77 = 0,385, also etwa 1478 × 831. FSR2 zog das auf 4K hoch, das Bild war pixelig und trotzdem langsam. Jetzt gilt der kleinere der beiden Faktoren (bei 4K 0,5, also 1920 × 1080 intern).
  - Der Regler „3D-Auflösung“ wirkt jetzt auch über 1920 px. Bisher war er bei 4K oberhalb von 50 % wirkungslos.
  - Ohne Upscaling-Stufe, aber unter voller Auflösung (z. B. 4K-Deckel), skaliert FSR 1 statt bilinear. Das kostet kaum etwas und macht das Bild schärfer.
- Tests: `test_options_scroll` prüft jetzt auch das Pausemenü (Grafikliste > 200 px hoch, Vollbild-Schalter sichtbar). Ohne den Fix schlägt das fehl. In `test_resolution_window` wird statt „immer bilinear“ jetzt FSR 1 unter 100 % erwartet.
- Getestet mit Godot 4.7.2 unter Windows auf einem 3840 × 2160-Monitor: `test_options_scroll` 27/0, `test_resolution_window` 43/0, `test_content_update` 46/1. Der Fehler „Einbruch +1 Stern“ tritt genauso auf unverändertem main auf.
- Nicht geändert: Vollbild bleibt randlos (`WINDOW_MODE_FULLSCREEN`). Das Spiel ist nicht auf echter Hardware angespielt, die FPS bei 4K sind also nicht gemessen.
