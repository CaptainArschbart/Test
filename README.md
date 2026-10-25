# Test

Grundgerüst für ein **3D-Spiel in Godot 4** (GDScript). Kein fertiges Spiel, sondern eine saubere Basis zum Weiterbauen.

## Starten

1. [Godot 4.4 oder neuer](https://godotengine.org/download) (Standard-Version, nicht .NET) installieren.
2. In Godot **Importieren** wählen und die `project.godot` in diesem Ordner öffnen.
3. **F5** startet das Spiel (Hauptszene `scenes/main/main.tscn`).

## Steuerung

| Taste | Aktion |
|---|---|
| W / A / S / D | Laufen |
| Shift | Sprinten |
| Leertaste | Springen |
| Maus | Umschauen |
| Esc | Maus freigeben (Klick fängt sie wieder ein) |
| F11 | Vollbild an/aus |

Die Tastenbelegung steht unter *Projekt → Projekteinstellungen → Eingabezuordnung* (`move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `sprint`).

## Ordnerstruktur

```
project.godot          Projekteinstellungen, Eingabezuordnung, Physik-Layer
scenes/
  main/                Hauptszene: Himmel, Licht, Boden, Test-Level
  player/              Spielfigur (CharacterBody3D) + Skript
assets/
  models/ textures/ materials/ audio/
```

Szenen liegen zusammen mit ihrem Skript in einem eigenen Ordner. Neue Dinge (Gegner, Items, UI, …) bekommen jeweils einen eigenen Ordner unter `scenes/`.

## Was drin ist

- **Main** (`scenes/main/main.tscn`): WorldEnvironment mit prozeduralem Himmel, Sonne mit Schatten, Boden und ein paar Kisten und eine Rampe zum Testen (CSG-Formen mit Kollision, später durch echte Modelle ersetzen).
- **Player** (`scenes/player/player.tscn`): First-Person-Steuerung mit Beschleunigung, Luftsteuerung, Sprint, Sprung und Respawn beim Herunterfallen. Werte wie Geschwindigkeit, Sprunghöhe und Maus-Empfindlichkeit sind im Inspector unter *Bewegung*, *Kamera* und *Respawn* einstellbar.
- **Physik-Layer**: 1 = `world`, 2 = `player`.

## Zusammenarbeit

Mehrere Leute arbeiten hier mit KI. Vor dem Arbeiten immer den neuesten Stand holen (`git pull`) und auf einem eigenen Branch arbeiten. Die `.godot/`-Cache-Ordner sind per `.gitignore` ausgeschlossen; `.uid`- und `.import`-Dateien gehören ins Repo.
