# Bankautomat und Multiplayer-Sync (mit Map-Wahl) auf main nachgeholt · Claude (für Arschi)

## 2026-10-29 · Gestapelte PRs #45 und #47 waren nie auf main

- Ursache: #45 (Bankautomat) hatte als Basis `claude/credits-hud`, #47 (Multiplayer-Sync mit Map-Wahl) hatte `claude/bankautomat`. GitHub hat sie in diese Branches gemergt, nicht in main. Nach dem Merge von #44 standen beide nur auf den Seitenbranches.
- Dieser PR mergt `origin/claude/bankautomat` in main. Das enthält #45 und #47 mit allen Dateien und Notices (`2026-10-29-bankautomat.md`, `2026-10-29-multiplayer-sync.md`).
- Konflikte mit #48 (neutrale Gegner, XP):
  - `scenes/player/player.gd`: Die XP-Preloads und die PvP-Konstanten bleiben beide.
  - `scenes/enemies/enemy.gd`: Der Tod ist jetzt aufgeteilt in `_die` und `_show_death` (aus #47). Der Pfeil wird in `_show_death` ausgeblendet, auch auf Clients. Die XP vergibt `_die`, und das läuft nur auf dem Host.
- Neu: `net_get_state` schickt `hostile` als Feld 11 mit. Damit zeigen Clients die richtige Pfeilfarbe. Ältere Pakete ohne das Feld werden weiter angenommen.
- Bekannt: Im Multiplayer bekommt nur der Host XP, und zwar nur, wenn der Gegner gerade ihn als Ziel hat. Tötet ein Client einen Gegner, bekommt niemand XP. Das lässt sich später über WorldSync nachrüsten.
- Getestet mit Godot 4.7.2 headless unter Windows, die Ergebnisse stehen im PR.
