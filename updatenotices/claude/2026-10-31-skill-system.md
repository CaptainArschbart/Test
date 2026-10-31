# Skill-System · Claude (für Arschi)

## 2026-10-31 · Drei Skill-Bäume, Reiter „Skills“ im Inventar

- **Reiter im Inventar:** Das Inventar-Fenster (Tab) hat oben jetzt zwei Reiter, INVENTAR und SKILLS. Der Skills-Reiter zeigt die drei Bäume nebeneinander, je drei Stufen. Linien verbinden jeden Skill mit seinen Voraussetzungen. Ein Klick auf einen freischaltbaren Skill lernt ihn. Fährt man mit der Maus über einen Skill, zeigt die Infozeile Wirkung und Voraussetzungen.
  - Zustände: gelernt (gefüllt, leuchtend), freischaltbar (Cyan-Rand pulsiert, „+ LERNEN“), ohne Punkt („KEIN PUNKT“) und gesperrt (grau).
  - Unten steht ein Magenta-Abzeichen „FREIE PUNKTE“. Sind Punkte frei, steht ihre Zahl auch auf dem Reiter („SKILLS [2]“).
  - Die Farben kommen aus `xp_hud.gd`: Kampf in Magenta, Gauner in Cyan, Tech in Grün, dazu dunkelviolette Flächen.
- **Punkte:** Jeder Stufenaufstieg gibt einen Punkt, frei sind also Stufe − 1 − gelernte Skills. Beim Aufstieg zeigt die XP-Leiste jetzt „STUFE 3 // +1 SKILLPUNKT (Tab)“. Alle 15 Skills hat man mit Stufe 16.
- **Bäume und Wirkung** (alle an den bestehenden Stellschrauben):

| Baum | Stufe | Skill | Wirkung | Wo |
|---|---|---|---|---|
| Kampf | 1 | Ruhige Hand | Streuung −30 % | `weapon_holder.gd` `get_spread_degrees` |
| Kampf | 1 | Schwere Fäuste | Nahkampf +25 % (Fäuste, Power-Schlag, Klingen) | `player_melee.gd` `_apply_hit`, `item_user.gd` `_strike` |
| Kampf | 2 | Schnellladen (← Ruhige Hand) | Nachladen 35 % kürzer | `weapon_holder.gd` `start_reload` |
| Kampf | 2 | Sprengmeister (← Schwere Fäuste) | Granaten +30 % Schaden, +25 % Wurfweite | `grenade.gd` `damage_at`, `item_user.gd` `_release` |
| Kampf | 3 | Panzerhaut (← beide) | 20 % weniger Schaden durch Gegner, Spieler und Granaten (kein Fall-, Hunger- oder Durstschaden) | `player.gd` `_receive_damage` |
| Gauner | 1 | Leise Sohlen | Schritte, Rutschen und Landungen 40 % leiser | `player_stealth.gd` `make_noise` |
| Gauner | 1 | Flinke Finger | Taschendiebstahl 35 % schneller, Verdacht 25 % langsamer | `civilian_crime.gd` `_pick_tick` |
| Gauner | 2 | Schatten (← Leise Sohlen) | Sichtbarkeit −25 % | `player_stealth.gd` `_compute_visibility` |
| Gauner | 2 | Dietrich (← Flinke Finger) | Verschlossene Türen ohne Schlüssel leise knacken (E, „Schloss knacken“) | `locked_door.gd` |
| Gauner | 3 | Großer Fang (← beide) | 50 % mehr Bargeld aus Taschen, Raub (Person und Ladenkasse) 40 % schneller | `civilian_crime.gd`, `shop_interior.gd` |
| Tech | 1 | Zäh | +25 max HP | `PlayerStats.max_hp` |
| Tech | 1 | Ausdauernd | +30 % max Ausdauer, 25 % schneller nachgeladen | `PlayerStats.max_stamina`, `stamina_regen_per_second` |
| Tech | 2 | Sanitäter (← Zäh) | Heilung durch Items +50 % | `item_user.gd` `apply_consumable` |
| Tech | 2 | Feilscher (← Ausdauernd) | Läden 15 % billiger, der Hehler zahlt 20 % mehr | `shop_interior.gd` `price_of`, `fence_price`, `shop_ui.gd` |
| Tech | 3 | Kamera-Hack (← beide) | Ladenkameras zeichnen dich nicht auf | `shop_interior.gd` `camera_sees` |

- **Code:** Neu sind `scenes/player/player_skills.gd` (Daten, Punkte, Wirkung, Speichern, Netz) und `scenes/inventory/skill_tree_view.gd` (Zeichnung und Klicks). Beide werden per `preload` geladen, ohne neuen `class_name`. Der Player legt den Knoten `PlayerSkills` bei jeder Figur an. Andere Systeme fragen `player.skill_mult(&"…")` bzw. `player.has_skill_flag(&"…")`. Neue Skills trägt man in `PlayerSkills.SKILLS` ein.
- **Speichern:** Für Spielerdaten gab es bisher keinen Spielstand, auch die XP gingen beim Beenden verloren. Neu ist `user://player_profile.cfg` mit Stufe, XP und Skills. Das Profil wird beim Start geladen und bei jedem Skill und XP-Gewinn gespeichert. Ein kaputtes oder geschummeltes Profil wird bereinigt: Skills ohne Voraussetzung und mehr Skills als Punkte fallen weg. In headless-Läufen (Prüfskripte) wird nichts geladen oder gespeichert, damit die Tests nicht vom Spielstand auf dem Rechner abhängen.
- **Multiplayer:** Jeder Spieler hat sein eigenes Profil. Der Besitzer schickt seine Skills und Stufe an alle, wenn er lernt oder aufsteigt. Fremde Figuren fragen beim Spawn selbst nach, das deckt auch späteren Beitritt ab. Damit rechnet der Host Taschendiebstahl, Raub, Ladenpreise und Kamera mit den Skills des jeweiligen Spielers. Empfangene Listen prüft er ebenfalls auf Voraussetzungen und Punkte.
- **Nicht verändert:** Bestehende Lücken bleiben, wie sie sind. Clients können weiterhin keinen Taschendiebstahl starten, weil `civilian_crime.interact` beim Client abbricht. Die Sichtbarkeit fremder Figuren wird beim Host nicht berechnet. Die Preisschilder im Regal zeigen den Grundpreis, Warenkorb und Theke den Preis mit Feilscher.
- Getestet mit Godot 4.7.2 headless:

| Test | Checks | Fehler |
|---|---|---|
| `test_skills` (neu) | 71 | 0 |
| `test_mp_sync -- host/client testmap` (+ Skills pro Spieler) | 17 / 19 | 0 |
| `test_player_move` | 3 | 0 |
| `test_npc_robbery` | 39 | 0 |
| `test_shop` | 43 | 0 |
| `test_options_scroll` | 27 | 0 |
| `test_player_melee` | 42 | 0 |
| `test_consumables` | 45 | 0 |
| `test_weapons_smg_grenade` | 47 | 0 |
| `test_apartments` | 55 | 0 |

