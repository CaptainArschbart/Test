# Test

Grundgerüst für ein **3D-Spiel in Godot 4** (GDScript). Kein fertiges Spiel, sondern eine saubere Basis zum Weiterbauen.

## Starten

1. [Godot 4.4 oder neuer](https://godotengine.org/download) (Standard-Version, nicht .NET) installieren.
2. In Godot **Importieren** wählen und die `project.godot` in diesem Ordner öffnen.
3. **F5** startet das Spiel. Zuerst kommt das Hauptmenü (`scenes/menu/main_menu.tscn`), **Start** lädt die Testmap (`scenes/testmap/testmap.tscn`). Die alte, einfache Welt `scenes/main/main.tscn` gibt es weiter (direkt mit F6 starten).

## Steuerung

| Taste | Aktion |
|---|---|
| W / A / S / D | Laufen |
| Shift | Sprinten |
| Leertaste | Springen |
| V | Noclip an/aus (fliegen durch Wände; Leertaste hoch, Strg runter, Shift schneller) |
| Maus | Umschauen |
| Esc | Maus freigeben (Klick fängt sie wieder ein) |
| F11 | Vollbild an/aus |

Die Tasten lassen sich im Spiel unter *Optionen → Steuerung* ändern. Die Standardbelegung steht unter *Projekt → Projekteinstellungen → Eingabezuordnung* (`move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `sprint`, `noclip`, `noclip_down`).

## Ordnerstruktur

```
project.godot          Projekteinstellungen, Eingabezuordnung, Physik-Layer, Autoloads
autoload/
  settings.gd          Autoload "Settings": Optionen laden, speichern, anwenden
scenes/
  menu/                Hauptmenü (Cyberpunk-Stil) mit Hintergrund- und CRT-Shader
  main/                Alte einfache Testwelt: Himmel, Licht, Boden, ein paar Kisten
  testmap/             Testmap "Neon District" (Cyberpunk-Straße mit Testzonen), Fassaden-Shader
  player/              Spielfigur (CharacterBody3D) + Skript
assets/
  models/ textures/ materials/ audio/
```

Szenen liegen zusammen mit ihrem Skript in einem eigenen Ordner. Neue Dinge (Gegner, Items, UI, …) bekommen jeweils einen eigenen Ordner unter `scenes/`.

## Was drin ist

- **Hauptmenü** (`scenes/menu/main_menu.tscn`, Startszene): Neon-Skyline mit bewegtem Gitter, Scanlines, Farbverschiebung und zufällige Glitch-Effekte. Knöpfe *Start*, *Optionen* und *Beenden*. Bedienbar mit Maus, Tastatur und Controller. Titeltext und Farben lassen sich direkt in der Szene bzw. in den Shader-Parametern ändern.
- **Optionen** (zwei Reiter): *Anzeige & Audio* (Vollbild, VSync, Lautstärke) und *Steuerung* (Mausempfindlichkeit, Maus-Y invertieren, Tastenbelegung für alle Bewegungsaktionen). Änderungen gelten erst nach **Übernehmen**; *Standard* setzt alles zurück, *Zurück* mit offenen Änderungen fragt einmal nach.
- **Settings** (`autoload/settings.gd`, Autoload): hält alle Einstellungen, lädt/speichert `user://settings.cfg` und wendet sie beim Spielstart an (auch wenn man direkt `main.tscn` startet). Der Player liest Mausempfindlichkeit und Y-Invertierung von hier.
- **Main** (`scenes/main/main.tscn`): WorldEnvironment mit prozeduralem Himmel, Sonne mit Schatten, Boden und ein paar Kisten und eine Rampe zum Testen (CSG-Formen mit Kollision, später durch echte Modelle ersetzen).
- **Testmap** (`scenes/testmap/testmap.tscn`, wird von *Start* geladen): Nacht-Cyberpunk-Straße passend zum Menü, mit Leuchtreklamen und Fassaden-Shader (Fenster leuchten zufällig). Testzonen mit Schildern: Treppen mit Stufen 0,15/0,25/0,35/0,50 m, Rampen 15°/30°/40°/50°, Tunnel mit Deckenhöhe 2,6/1,95/1,7 m, Messwand bis 6 m, Sprunghöhe 0,5–1,5 m, Weitsprung-Lücken 2–6 m, Parkour-Turm bis auf ein Dach (7,2 m) und ein großer offener Platz mit Deckung und Brücke. Plätze für Items sind `Marker3D` in der Gruppe `item_spawn` unter `Pickups/SpawnPoints`.
- **Player** (`scenes/player/player.tscn`): First-Person-Steuerung mit Beschleunigung, Luftsteuerung, Sprint, Sprung und Respawn beim Herunterfallen. Werte wie Geschwindigkeit, Sprunghöhe und Maus-Empfindlichkeit sind im Inspector unter *Bewegung*, *Kamera*, *Respawn* und *Noclip* einstellbar.
- **Physik-Layer**: 1 = `world`, 2 = `player`.

## Zusammenarbeit

Mehrere Leute arbeiten hier mit KI. Vor dem Arbeiten immer den neuesten Stand holen (`git pull`) und auf einem eigenen Branch arbeiten. Nach jedem Arbeitsgang einen Eintrag ans Ende von `AI_HANDOVER.md` (Abschnitt *Arbeitslog*) anhängen, damit die anderen nachvollziehen können, was passiert ist. Die `.godot/`-Cache-Ordner sind per `.gitignore` ausgeschlossen; `.uid`- und `.import`-Dateien gehören ins Repo.
