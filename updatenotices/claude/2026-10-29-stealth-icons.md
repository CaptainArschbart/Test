# Stealth-Anzeige mit Symbolen · Claude (für Arschi)

## 2026-10-29 · Auge und Lautsprecher statt Text, Optik überarbeitet

- `scenes/stealth/stealth_hud.gd`:
  - Vor der Sicht-Leiste steht ein Auge statt „SICHT“. Es öffnet sich mit der Sichtbarkeit und ist fast zu, wenn man verborgen ist.
  - Vor der Lärm-Leiste steht ein Lautsprecher statt „LÄRM“. Bis zu drei Schallbögen leuchten je nach Lärmpegel.
  - Das große Auge rechts neben der Sicht-Leiste ist entfernt. Die Leisten reichen jetzt bis an den rechten Rand.
  - Der Status (VERBORGEN, SICHTBAR, VERDACHT, ENTDECKT) steht als kleines umrandetes Schild oben rechts. Unter „STEALTH“ verläuft eine feine Magenta-Linie.
  - Fix: Die Leisten waren 27 px statt 12 px hoch, weil ProgressBar die Höhe seiner Theme-Schrift erzwingt. Sie saßen dadurch zu tief und ragten über den Rahmen. Jetzt gibt es einen Schriftgrößen-Override, und die Größe wird erst nach `add_child` gesetzt.
- Die Boxgröße (200 × 46) bleibt gleich, das Geldfeld darunter ist unverändert.
- Getestet mit Godot 4.7.2 headless unter Windows: `test_money` 25/0, `test_consumables` 45/0. Zusätzlich ein Wegwerf-Check: Die Testmap lädt, `_draw` läuft ohne Fehler, die Leisten haben die Größe 162 × 12. Die Optik ist nicht auf echter Hardware angesehen.
