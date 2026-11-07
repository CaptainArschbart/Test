class_name PlaceableData
extends ItemData
## Item, das man in der Welt aufstellt (Anbau: Topf, Growlampe, Trockengestell, Fermentierglas,
## Verpackungstisch). Gewählt in der Hotbar zeigt ItemUser eine Vorschau auf dem Boden, Rechtsklick
## stellt es auf (GrowPlacer). Geduckt + E baut eine leere Station wieder ab.

## Welche Station entsteht: pot, lamp, rack, jar, table (GrowStation.SCRIPTS).
@export var station := &"pot"
