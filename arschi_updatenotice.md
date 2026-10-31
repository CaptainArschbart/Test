# Arschi Update-Notice

Arbeitslog von Arschis Seite (Claude für Arschi). Neuer Eintrag ganz unten. `enscapez_updatenotice.md` nur lesen.

### 2026-10-31 · NPCs berauben: Taschendiebstahl und bewaffneter Raub · Claude (für Arschi) · Branch `claude/npc-raub`
- Auftrag: Eine Mechanik, um Passanten zu berauben, leise per Taschendiebstahl oder bewaffnet.
- Vorher: `CivilianCrime` hatte schon einen Sofort-Taschendiebstahl (nur Bargeld, gab auch unbemerkt einen Stern), Hände hoch beim Zielen und Ausrauben erst nach dem Fesseln. Ohne Kabelbinder oder Handschellen ließ sich eine bedrohte Person nicht ausrauben.
- `scenes/crime/civilian_crime.gd`:
  - Taschendiebstahl: Prompt „Taschendiebstahl“ hockend, leise, langsam und hinter der Person (1,8 m). E startet einen Griff von 1,4 s (`PICK_TIME`). Prompt zeigt „Klauen … x %   Verdacht y %“. Der Verdacht steigt pro Sekunde um `(0,15 + Sichtbarkeit × 0,75 + Lärm × 1,2) × Wachsamkeit`, ×1,3 wenn die Person steht. Wachsamkeit wird pro Versuch zufällig 0,7–1,3 gewürfelt. Ab 100 %: „Erwischt!“, die Person ruft „Dieb!“, flieht, eine Fahndungsstufe (`pickpocket`). Hocke verlassen, zu schnell, nicht mehr dahinter (bis 2,2 m beim Folgen) oder Panik: abgebrochen, ohne Beute, ohne Fahndung. Unbemerkt gibt es jetzt keinen Stern mehr.
  - Bewaffneter Raub: Waffe auf eine isolierte Person zielen (wie bisher Hände hoch und eine Stufe `threat`). Neuer Prompt „Ausrauben (bedroht)“. E: „Okay, okay …“, Übergabe 1,6 s (`ROB_TIME`), Prompt „Tasche her! … x %“. Waffe runter oder Leute in der Nähe vorher: abgebrochen, die Person rennt weg. Nach der Übergabe „Nimm's, nimm's!“. Lässt man sie danach laufen: „Polizei!“, eine weitere Stufe (`robbery`). Wird sie vorher gefesselt (Prompt „Fesseln“ nach dem Raub), meldet sie nichts mehr.
  - Tasche: Bargeld 2–18 ¢ und Schmuck (jeder dritte Seed) wie bisher, neu Smartphone (30 %) und Gold-Uhr (10 %), gewürfelt aus `net_seed`. Alle drei Wege (Taschendiebstahl, bewaffnet, gefesselt durchsuchen) leeren dieselbe Tasche. Was nicht ins Inventar passt, bleibt drin.
- `autoload/wanted_manager.gd`: neue Tat `robbery` mit Gewicht 1.
- Neu: `tools/tests/test_npc_robbery.gd`, kleine Arena mit `player.tscn` und vier Passanten.
- Keine neue Input-Aktion (alles über `interact`). Keine Szene geändert.
- Getestet (Godot 4.7.2 stable, headless, in einem eigenen Worktree): `test_npc_robbery.gd` CHECKS 30 FAILS 0. Unbemerkt im Dunkeln: 2 ¢ und Schmuck, Verdacht 0,45, 0 Sterne. Erwischt (Wachsamkeit erzwungen 12): kein Geld, Flucht, 1 Stern. Vor die Person gegangen: abgebrochen. Bewaffnet: Hände hoch, 1 Stern, 5 ¢, nach dem Loslassen 2 Sterne und Flucht. Raub, dann gefesselt: Sterne bleiben bei 1. `test_apartments.gd` CHECKS 44 FAILS 0. Kein `SCRIPT ERROR`.
- Nicht getestet: im Fenster mit Maus, wie gut man einer gehenden Person hockend folgen kann, Werte bei echten Lichtern in Sektor 7. Multiplayer: wie bisher rechnet nur der Host, ein Client kann Passanten nicht berauben.
- Offen: Nahkampfwaffe als Drohung, Animation der Übergabe, Sync für Clients.
- Git: Branch `claude/npc-raub` aus `origin/main` (e22f2f6), Draft-PR mit Basis `main`.
