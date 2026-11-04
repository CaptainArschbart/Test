class_name InteriorPlanner
extends RefCounted
## Grundriss-Prüfung für Innenräume (Schedule 1, Phase 0, P0-2), wie der Neon-City-Generator für
## die Stadt: Jedes Möbelstück meldet seine Grundfläche an, freizuhaltende Wege und Türbereiche
## ebenso. Gemeldet werden (in `errors`):
##   R2  feste Dinge überschneiden sich oder stehen in einem freizuhaltenden Bereich oder außerhalb
##   R1  etwas über dem Boden liegt auf keiner tragenden Fläche (Tisch, Theke, Regal)
##   R5  ein Ziel (Theke, Tür, Kiste, Automat) ist vom Eingang aus nicht zu Fuß erreichbar
## Koordinaten: lokal im Raum, x und z am Boden (Vector2(x, z)), Rechtecke als Rect2.

## Rasterweite für die Erreichbarkeit und halbe Breite einer Figur.
const CELL := 0.1
const CLEAR := 0.3
## Toleranz an Kanten (aneinanderstoßen ist erlaubt).
const EPS := 0.02

var room: Rect2
var errors := PackedStringArray()
## [Rect2, Art, Name, Oberkante]; Art: solid, keep, support.
var _items: Array = []


func _init(room_rect: Rect2) -> void:
	room = room_rect


## Wand oder anderes Festes. Wände dürfen sich gegenseitig berühren und kreuzen.
func wall(rect: Rect2, what: String) -> void:
	_items.append([rect.abs(), "wall", what, INF])


## Festes Möbelstück mit Kollision; `height` = Oberkante (für Dinge, die darauf liegen).
func solid(rect: Rect2, what: String, height := 0.0) -> bool:
	rect = rect.abs()
	var ok := true
	if not _inside(rect):
		errors.append("R2 %s ragt aus dem Raum %s" % [what, _fmt(rect)])
		ok = false
	for it: Array in _items:
		var other: Rect2 = it[0]
		if it[1] != "support" and _overlap(rect, other):
			errors.append("R2 %s %s überschneidet %s %s" % [what, _fmt(rect), it[2], _fmt(other)])
			ok = false
	_items.append([rect, "solid", what, height])
	return ok


## Ding ohne Kollision, auf dem etwas anderes liegen darf (Karton auf Karton). Blockiert keinen Weg.
func support(rect: Rect2, height: float, what: String) -> void:
	_items.append([rect.abs(), "support", what, height])


## Bereich, der frei bleiben muss (Laufweg, Platz vor einer Tür oder Theke).
func keep(rect: Rect2, what: String) -> void:
	rect = rect.abs()
	for it: Array in _items:
		if it[1] in ["wall", "solid"] and _overlap(rect, it[0]):
			errors.append("R5 %s ist zugestellt von %s" % [what, it[2]])
	_items.append([rect, "keep", what, 0.0])


## Ding ohne eigene Grundfläche, das auf etwas liegt (Monitor auf dem Schreibtisch): Seine Mitte
## muss über einer tragenden Fläche liegen, deren Oberkante auf 3 cm zur Unterkante passt.
func on_top(at: Vector2, bottom: float, what: String) -> void:
	if bottom < 0.15:
		return  # steht auf dem Boden
	for it: Array in _items:
		if it[1] in ["solid", "support"] and (it[0] as Rect2).grow(EPS).has_point(at) and absf(float(it[3]) - bottom) < 0.03:
			return
	errors.append("R1 %s schwebt bei %s (Unterkante %.2f m, keine Fläche darunter)" % [what, at, bottom])


## Zu Fuß erreichbar vom Eingang aus (Raster, Figur mit 0,3 m halber Breite)?
func check_reachable(entrance: Vector2, targets: Dictionary) -> void:
	var w := int(ceil(room.size.x / CELL))
	var h := int(ceil(room.size.y / CELL))
	var free := PackedByteArray()
	free.resize(w * h)
	for j in h:
		for i in w:
			var p := room.position + Vector2(i + 0.5, j + 0.5) * CELL
			var ok := true
			for it: Array in _items:
				if it[1] in ["wall", "solid"] and (it[0] as Rect2).grow(CLEAR).has_point(p):
					ok = false
					break
			free[j * w + i] = 1 if ok else 0
	var start := _cell(entrance, w, h)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var queue: Array[int] = []
	if start >= 0 and free[start] == 1:
		queue.append(start)
		seen[start] = 1
	while not queue.is_empty():
		var c: int = queue.pop_back()
		var ci := c % w
		var cj := c / w
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni := ci + d.x
			var nj := cj + d.y
			if ni < 0 or nj < 0 or ni >= w or nj >= h:
				continue
			var n := nj * w + ni
			if free[n] == 1 and seen[n] == 0:
				seen[n] = 1
				queue.append(n)
	for what: String in targets:
		var c := _cell(targets[what], w, h)
		if c < 0 or seen[c] == 0:
			errors.append("R5 %s ist vom Eingang aus nicht erreichbar (%s)" % [what, targets[what]])


func _cell(p: Vector2, w: int, h: int) -> int:
	var i := int((p.x - room.position.x) / CELL)
	var j := int((p.y - room.position.y) / CELL)
	return j * w + i if i >= 0 and j >= 0 and i < w and j < h else -1


func _inside(r: Rect2) -> bool:
	return room.grow(EPS).encloses(r)


static func _overlap(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x - EPS and a.end.x > b.position.x + EPS \
			and a.position.y < b.end.y - EPS and a.end.y > b.position.y + EPS


static func _fmt(r: Rect2) -> String:
	return "(%.2f..%.2f, %.2f..%.2f)" % [r.position.x, r.end.x, r.position.y, r.end.y]


## Achsparallele Grundfläche einer Box der Größe size (x, z) um center, gedreht um yaw.
static func footprint(center: Vector2, size: Vector2, yaw_deg := 0.0) -> Rect2:
	var c := absf(cos(deg_to_rad(yaw_deg)))
	var s := absf(sin(deg_to_rad(yaw_deg)))
	var ext := Vector2(size.x * c + size.y * s, size.x * s + size.y * c)
	return Rect2(center - ext * 0.5, ext)
