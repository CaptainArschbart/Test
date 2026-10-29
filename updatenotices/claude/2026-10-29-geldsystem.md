# Geldsystem statt Credchip-Items · Claude (für Arschi)

## 2026-10-29 · Credchips sind jetzt ein Kontostand mit HUD-Anzeige

- Credchips belegen keine Inventar-Slots mehr. `ItemData.is_currency` (neu, bei `credchip.tres` an) leitet `Inventory.add_item` auf den Kontostand `Inventory.money` um. Pickups, Gegner-Loot und die Kartenpickups funktionieren dadurch ohne Änderung. Die Einblendung „+15 Credchip“ bleibt.
- Neue Inventory-API: `money`, `money_changed(money, delta)`, `add_money()`, `has_money()`, `spend_money()`, `take_all_money()`, `starting_money` (Export), `MAX_MONEY = 999999`.
- HUD: Unter der Vitals-Box steht ein Feld „CREDS“ mit dem Betrag in Credchip-Gelb, z. B. `1.250 ¢`. Bei Änderungen zählt der Betrag hoch und daneben blinkt kurz `+15` (grün) bzw. `−5` (rot). Das Feld wird in `survival_hud.gd` im Code erzeugt, die `.tscn` ist unverändert.
- Automaten (`vending_machine.gd`) buchen bei Währungs-Items vom Konto ab. Ist das Inventar voll, gibt es das Geld zurück. Das alte Verhalten mit Items als Zahlungsmittel bleibt für Nicht-Währungs-Items erhalten.
- Tod: Das ganze Geld fällt als ein Credchip-Stapel an der Todesstelle (`player.gd`, `_drop_at_death`). Wer ihn aufhebt, bekommt das Geld zurück.
- Pickups mit Währung heißen „40 ¢“ statt „Credchip ×40“.
- Geänderte Dateien:
  - `scenes/items/item_data.gd`
  - `scenes/items/data/credchip.tres`
  - `scenes/inventory/inventory.gd`
  - `scenes/interact/vending_machine.gd`
  - `scenes/player/player.gd`
  - `scenes/items/pickup.gd`
  - `scenes/survival/survival_hud.gd`
  - `tools/tests/test_consumables.gd`: nutzt in Slot 1 jetzt den Data-Shard, weil Credchips keinen Slot mehr belegen
  - neu: `tools/tests/test_money.gd`
- Getestet mit Godot 4.7.2 headless unter Windows:
  - `test_money`: 25/0
  - `test_consumables`: 45/0
  - `test_sector7_enemies`: 15/0
  - `test_weapons_smg_grenade`: 18 Fehler, auf unverändertem main genauso. Ursache: Unter Windows headless lässt sich die Maus nicht einfangen („Maus gefangen“), danach schießt keine Waffe. Das hängt nicht mit diesem PR zusammen.
- Offen / Hinweise:
  - Multiplayer: Das Geld ist lokal pro Spieler und wird nicht synchronisiert, genau wie das Inventar.
  - Es gibt noch keinen Spielstand, der das Geld speichert.
  - Die HUD-Optik ist nicht auf echter Hardware angesehen.
