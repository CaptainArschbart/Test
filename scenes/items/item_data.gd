class_name ItemData
extends Resource
## Beschreibung eines Item-Typs (eine .tres-Datei pro Item unter scenes/items/data/).
##
## Ohne eigenes Icon zeichnet die UI eine Neon-Raute in `color` mit `glyph`.

## Eindeutiger Schlüssel. Zwei Stapel sind gleich, wenn die id gleich ist.
@export var id := ""
@export var display_name := "Item"
@export_multiline var description := ""
## Optionales Bild für Slots. Leer = Raute mit Kürzel.
@export var icon: Texture2D
## Kurzes Kürzel (1–3 Zeichen) für das Platzhalter-Icon.
@export var glyph := "?"
## Neonfarbe für Icon und Pickup in der Welt.
@export var color := Color(0, 0.95, 1)
## Wie viele davon in einen Slot passen (1 = nicht stapelbar).
@export_range(1, 999) var max_stack := 1
## Währung: landet nicht in einem Slot, sondern als Geld im Inventar (Inventory.money).
@export var is_currency := false


func is_same(other: ItemData) -> bool:
	return other != null and other.id == id
