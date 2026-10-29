# Läden ausgebaut: neuer Grundriss, 11 neue Items mit Modellen, realistisches Einkaufen und Klauen · Claude (für Arschi)

## 2026-10-29

- **Auftrag:**
  - Die Läden besser gestalten und mehr Regale aufstellen.
  - Mehr Items, und jedes Item braucht ein Modell.
  - Die Ware zum Klauen soll zufällig liegen, und manche Regalplätze sollen leer sein.
  - Laden- und Raubsystem realistischer machen.

### Items
- `scenes/items/item_data.gd`:
  - `model` ist von `ConsumableData` hierher umgezogen. Damit können auch Nicht-Verbrauchsitems (Wertsachen) ein Modell haben. Bestehende `.tres`-Dateien laufen unverändert weiter, weil der Name gleich bleibt.
  - Neu ist `value`, der Grundpreis in ¢.
- `scenes/items/consumable_model.gd`: 11 neue Modelle, jeweils mit Griff, Haltung, Pickup-Größe und Inventar-Icon:
  - `bottle`, `cup`, `bar`, `onigiri`, `pills`, `medkit`.
  - `phone`, `chip`, `watch`, `cigarettes`, `shard`.
  - Die Modelle nutzen dieselben Teilnamen wie die alten (`Tab`, `Mouth`, `Lid`, `Noodles`), damit die vorhandenen Animationen (`drink`, `eat`, `bandage`) funktionieren.
- Neue Items in `scenes/items/data/`:

  | Item | Name | Wirkung | Wert |
  |---|---|---|---|
  | `water_bottle` | Aqua-Pure | Wasser +45 | 2 ¢ |
  | `coffee` | Synth-Kaffee | Wasser +15, Ausdauer +50 | 3 ¢ |
  | `soy_bar` | Soja-Riegel | Essen +22 | 2 ¢ |
  | `onigiri` | Neon-Onigiri | Essen +32 | 4 ¢ |
  | `beer` | Neon-Lager | Wasser +25 | 3 ¢ |
  | `painkillers` | Schmerzmittel | HP +20 | 4 ¢ |
  | `medkit` | Trauma-Medkit | HP +100, 4,5 s | 18 ¢ |

  Dazu die Wertsachen, ohne Wirkung und nur zum Verkaufen: `smartphone` 30 ¢, `neuro_chip` 45 ¢, `gold_watch` 70 ¢, `cigarettes` 8 ¢.
- Bestehende Items haben jetzt einen `value`. Der Data-Shard hat zusätzlich das Modell `shard` (18 ¢).
- Modell-Anzeige verallgemeinert, jetzt für jedes Item mit `model`:
  - Pickup (`pickup.gd`).
  - Inventar-Icon (`inventory_slot.gd`).
  - In der Hand (`item_user.gd`).

### Laden-Gebäude (`scenes/slum/kit/slum_building.gd`, `_shop`)
- **Theke** seitlich am Eingang, damit der Verkäufer Tür und Gänge sieht. Darauf stehen Kasse, Kartenterminal und ein Kaugummi-Aufsteller.
- **Vitrine** hinter dem Verkäufer: Glas, innen beleuchtet, mit Wertsachen bzw. Medizin.
- **Regale:**
  - 2–3 beidseitige **Mittelregale**, 1,5 m hoch. Stehend sieht man über sie hinweg, geduckt ist man dahinter versteckt. Über den Gängen hängen Schilder (SNACKS, INSTANT, PFLEGE, DIVERSES) und Lichtleisten.
  - **Kühlschränke** an der rechten Wand, hohl mit Glastür, Leuchtrückwand und Glasböden. Darüber das Schild „DRINKS“.
  - **Wandregal** hinten.
  - Neue Helfer `_shelf_unit()` (Regal mit Preisleisten und Füllware), `_fridge()` und `_aisle_sign()`.
- **Sicherheit**, je Laden zufällig:
  - Kamera unter der Decke bei 60 % der Läden.
  - Diebstahlsicherung (zwei Säulen am Eingang) bei 40 % der Läden, bei Apotheke und 24/7 bei 80 %.
- `scenes/slum/kit/slum_mats.gd`: neues Material `glass()`.
- Etwa 30–45 Warenplätze pro Laden, insgesamt 1729 in Sektor 7.

### Laden-Logik (`scenes/interact/shop_interior.gd`, neu geschrieben)
- **Ware:**
  - Jeder Platz wird zufällig bestückt (Gewichtung nach Ladenschild und Platzart). Etwa 30 % der Plätze sind leer, in der Vitrine mehr.
  - Je Platz liegen 1–3 Stück als echte Modelle (1,25-fach) mit Preisschild.
  - Nach 180 s wird neu bestückt.
- **Einkaufen:**
  - E an der Ware legt ein Stück ins Inventar, es ist aber noch unbezahlt (Warenkorb).
  - Am Verkäufer: „Bezahlen (N ¢)“. Das Ladenfenster zeigt Warenkorb, Theke (Vitrine) und beim Hehler den Ankauf.
  - Der Verkäufer erinnert einmal: „Vergiss nicht zu bezahlen!“
- **Klauen:** Mit unbezahlter Ware raus, dann gilt in dieser Reihenfolge:
  1. Diebstahlsicherung vorhanden: piept immer, Alarm.
  2. Der Verkäufer sieht dich an der Tür: Alarm. Er sieht mit ±80° bis 14 m, braucht Sichtlinie zu Brust oder Kopf. Regale verdecken, Hocken versteckt den Kopf.
  3. Die Kamera hat dich beim Einstecken gesehen: Alarm 5 s nach dem Rausgehen. Ein Treffer zerstört die Kamera, danach ist das egal.
  4. Sonst: „Geklaut: Ware für N ¢“.
- **Vitrine:** Unter den Augen des Verkäufers daraus zu nehmen gibt sofort Alarm.
- **Kasse aufbrechen:**
  - Dauert 3 s, man muss bis 1,9 m daneben bleiben. Weggehen bricht ab.
  - Ist der Verkäufer ergeben oder tot, dauert es 1 s.
  - Sieht er zu, gibt es Alarm. Nach dem Knacken merkt er es nach 8 s.
- **Überfall:** Mit der Waffe zielen.
  - Unbewaffnete heben die Hände und legen das Kassengeld auf die Theke. Nach 4 s gibt es stillen Alarm.
  - Bewaffnete wehren sich in 50 % der Fälle. Bewaffnet sind bei der Bar 60 %, beim 24/7 45 %, beim Hehler 70 %, sonst 25 %.
- **Bewaffneter Verkäufer im Alarm:** Er dreht sich zum Täter und schießt alle ~1,1 s, trifft mit 45 % und macht 14 Schaden. Hocken und Rennen senken die Trefferquote. Neue Todesursache `shopkeeper`. Unbewaffnete ducken sich.
- **Hehler** (Ladenschild `sign_shop`, „ANKAUF & VERKAUF“): kauft Wertsachen ab 8 ¢ Wert für 50 % an. Essen kauft er nicht.
- **Leistung:** Warenmodelle und Benutzflächen entstehen nur, wenn die eigene Kamera näher als 32 m ist. Ohne Kamera (Map lädt noch) entsteht nichts.
- **Multiplayer:**
  - Der Host entscheidet über Ware, Warenkorb, Rausgehen, Kasse, Verkäufer und Kamera. Clients fragen per RPC an.
  - Der eigene Warenkorb kommt per `_set_unpaid` zum Spieler.
  - Bezahlen und Theke ziehen das Geld beim Spieler ab (Feld `cost` in `_give`).
- `scenes/interact/shop_ui.gd`: neu mit den drei Bereichen KASSE, THEKE und ANKAUF.

### WorldSync
- `autoload/world_sync.gd`: Unveränderte NPC-Zustände gehen nur noch alle 1,5 s raus (`UNCHANGED_RESEND`).
  - **Grund:** Mit 41 Läden wurde jedes Paket so groß, dass der Client im Mehrspieler-Test mehrere Sekunden hinterherhing. `test_mp_world` und `test_mp_sync slum` schlugen auf der Host-Seite fehl, auf main liefen sie.
  - Nach der Änderung sind beide wieder grün.

### Getestet (Godot 4.7.2 headless, Windows)
- `test_shop`: 43/0. Abgedeckt:
  - 12 Items mit Modell, Wert und ≥3 Teilen. Die Gold-Uhr als Pickup zeigt ihr Modell.
  - Eingang ohne Kante (größte Stufe 0,02 m), Tor ≥ 2,5 m hoch.
  - Mindestens 28 Plätze pro Laden, alle 4 Platzarten, 31 % leer, 16 verschiedene Items, jede Ware mit Modell, 41 verschiedene Bestückungen.
  - Einkaufen und Bezahlen. Rausgehen mit bezahlter Ware trotz Diebstahlsicherung gibt keinen Alarm.
  - Klauen in allen Fällen: unbemerkt, Diebstahlsicherung, Verkäufer an der Tür, Kamera mit verzögertem Alarm, Kamera zerschossen und kein Alarm.
  - Vitrine, Kasse (dauert 3,4 s, Weggehen bricht ab), Überfall, bewaffneter Verkäufer (5 Schüsse in 5 s, HP 100 → 44), Hehler (+35 ¢ für die Uhr, Nudeln abgelehnt), Verkäufer erschießen.
- `test_shop_net`: Host 8/0, Client 12/0. Ablauf: nehmen, bezahlen, klauen, Verkäufer erschießen, Kasse knacken.
- `test_mp_world`: Host 12/0, Client 14/0. `test_mp_sync slum`: Host 9/0, Client 10/0.
- `test_consumables` 45/0, `test_money` 25/0, `test_bank` 41/0, `test_sector7_enemies` 15/0, `test_enemy_xp` 29/0, `test_player_melee` 42/0.
- **Leistung**, Sektor 7 headless gemessen:

  | | Laden der Map | Zeit pro Bild |
  |---|---|---|
  | main | 4,2 s | 6,9 ms |
  | dieser Branch | 5,9 s | 8,3 ms |

### Nicht getestet
- Wie Laden, Item-Modelle, Griffe der Hände und Icons auf echter Hardware aussehen. Die Griffe der neuen Modelle sind von Dose bzw. Verband abgeleitet und nicht angesehen.
- Leistung auf echter GPU mit vielen Läden in Sichtweite.

### Offen
- Kein Fahndungs- oder Polizeisystem, Alarm heißt: Gegner in der Nähe werden feindlich.
- Der Hehler fragt nicht, ob die Ware geklaut ist. Gekaufte Ware kann man also zum halben Preis wieder verkaufen.
- Ladenstand und Warenkorb werden nicht gespeichert.
