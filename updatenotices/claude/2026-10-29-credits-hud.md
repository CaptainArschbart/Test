# Credits-Anzeige im HUD überarbeitet · Claude (für Arschi)

## 2026-10-29 · Geldfeld im Stil der Stealth-Box, Credchip-Symbol, Aufleuchten bei Änderungen

- `scenes/survival/survival_hud.gd`, nur das Geldfeld (`_build_money_panel`, `_draw_money_panel`, neu `_draw_credchip`, `_set_money_flash`):
  - Größe 200 × 40 statt 190 × 34. Damit ist es genauso breit wie die Stealth-Box darüber. Die Position bleibt `frame.offset_bottom + 62` (y 266).
  - Gleiche Optik wie die Stealth-Box: Kopfzeile „CREDITS“ mit Magenta-Trennlinie, Magenta-Streifen links, Scanlines wie im Vitals-Rahmen und eine leuchtende Ecke oben rechts. Oben rechts steht klein „NC-ACCT“. Die Beschriftung „CREDS“ und der gelbe Streifen sind entfernt.
  - Links ist ein Credchip gezeichnet: eine goldene Karte mit Kontaktfeld und Leiterbahnen. Der Betrag steht rechtsbündig darunter, golden mit weichem Schein, dahinter „¢“.
  - Bei jeder Änderung leuchten Rand, Hintergrund und Chip 0,7 s lang auf, bei Gutschrift grün, bei Abbuchung rot. Die Einblendung („+15 ¢“ bzw. „−5 ¢“) steigt leicht nach oben und blendet nach 1 s aus.
  - `money_label` und `format_money` bleiben gleich, der Text im Label ist weiterhin nur die Zahl.
- Getestet mit Godot 4.7.2 headless unter Windows: `test_money` 25/0, `test_consumables` 45/0. Kein `SCRIPT ERROR`. Die Optik ist nicht auf echter Hardware angesehen.
