class_name RoadNetwork
extends RefCounted
## Fahrspuren und Abbiegekurven aus einem einfachen Straßengraphen (Kreuzungen + Straßen).
##
## Rechtsverkehr: jede Straße hat zwei Spuren, je `lane_offset` rechts von der Mitte. Eine Spur
## endet `stop` Meter vor der Kreuzungsmitte (vor dem Zebrastreifen). In jeder Kreuzung verbindet
## eine Kurve (quadratische Bézier) jede ankommende mit jeder abgehenden Spur, außer Wenden.
## Spuren und Kurven sind „Stücke“ (Piece): Polylinien mit Länge, an denen ein Auto per Strecke s
## entlangfährt. Kurven, die sich in derselben Kreuzung schneiden, stehen in `conflicts`.

class Piece:
	var id := 0
	var points := PackedVector3Array()
	## Strecke bis zu jedem Punkt.
	var dist := PackedFloat32Array()
	var length := 0.0
	var is_turn := false
	## Spur: Kreuzung am Ende. Kurve: die Kreuzung, durch die sie führt.
	var junction := -1
	## Spur: Kreuzung am Anfang.
	var from_junction := -1
	## Spur: mögliche Kurven am Ende. Kurve: leer (danach kommt out_lane).
	var turns: Array[int] = []
	## Kurve: Spur davor und danach, Richtung (0 geradeaus, 1 rechts, -1 links).
	var in_lane := -1
	var out_lane := -1
	var turn := 0
	var max_speed := 99.0
	var conflicts: Array[int] = []

	func point_at(s: float) -> Vector3:
		var i := _segment(s)
		var span := dist[i + 1] - dist[i]
		var t := (s - dist[i]) / span if span > 0.0001 else 0.0
		return points[i].lerp(points[i + 1], clampf(t, 0.0, 1.0))

	func dir_at(s: float) -> Vector3:
		var i := _segment(s)
		return (points[i + 1] - points[i]).normalized()

	func _segment(s: float) -> int:
		if s <= 0.0:
			return 0
		var i := dist.bsearch(s) - 1
		return clampi(i, 0, points.size() - 2)

	func _finish() -> void:
		dist.resize(points.size())
		var total := 0.0
		dist[0] = 0.0
		for i: int in range(1, points.size()):
			total += points[i].distance_to(points[i - 1])
			dist[i] = total
		length = total


const TURN_SPEED := {0: 9.0, 1: 4.2, -1: 5.5}

var pieces: Array[Piece] = []
## Nur die Spuren (für Spawn und Zufall).
var lanes: Array[int] = []
var junction_count := 0


func _init(junctions: PackedVector3Array, stops: PackedFloat32Array, roads: PackedInt32Array,
		lane_offset := 2.25) -> void:
	junction_count = junctions.size()
	var into := {}
	var out_of := {}
	for i: int in range(0, roads.size() - 1, 2):
		for pair: Array in [[roads[i], roads[i + 1]], [roads[i + 1], roads[i]]]:
			var a: int = pair[0]
			var b: int = pair[1]
			var dir := (junctions[b] - junctions[a]).normalized()
			var right := dir.cross(Vector3.UP)
			var lane := Piece.new()
			lane.points = PackedVector3Array([junctions[a] + dir * stops[a] + right * lane_offset,
					junctions[b] - dir * stops[b] + right * lane_offset])
			lane.from_junction = a
			lane.junction = b
			_add(lane)
			lanes.append(lane.id)
			into.get_or_add(b, []).append(lane.id)
			out_of.get_or_add(a, []).append(lane.id)
	for j: int in junction_count:
		var turns_here: Array[int] = []
		for lin: int in into.get(j, []):
			var options: Array[int] = []
			for lout: int in out_of.get(j, []):
				if pieces[lout].junction == pieces[lin].from_junction:
					continue  # Wenden
				options.append(_make_turn(j, lin, lout))
			if options.is_empty():
				# Sackgasse: dann doch wenden.
				for lout: int in out_of.get(j, []):
					options.append(_make_turn(j, lin, lout))
			pieces[lin].turns = options
			turns_here.append_array(options)
		for a: int in turns_here:
			for b: int in turns_here:
				if a < b and pieces[a].in_lane != pieces[b].in_lane and _crosses(pieces[a], pieces[b]):
					pieces[a].conflicts.append(b)
					pieces[b].conflicts.append(a)


func _add(p: Piece) -> void:
	p.id = pieces.size()
	p._finish()
	pieces.append(p)


func _make_turn(j: int, lin: int, lout: int) -> int:
	var a := pieces[lin]
	var b := pieces[lout]
	var p0 := a.points[a.points.size() - 1]
	var p2 := b.points[0]
	var d0 := a.dir_at(a.length)
	var d2 := b.dir_at(0.0)
	var cross := d0.x * d2.z - d0.z * d2.x
	var p1 := (p0 + p2) * 0.5
	var kind := 0
	if absf(cross) > 0.3:
		kind = 1 if cross > 0.0 else -1
		# Schnittpunkt der beiden Spurgeraden als Kontrollpunkt.
		var diff := p2 - p0
		var t := (diff.x * d2.z - diff.z * d2.x) / cross
		p1 = p0 + d0 * t
	var turn := Piece.new()
	turn.is_turn = true
	turn.junction = j
	turn.in_lane = lin
	turn.out_lane = lout
	turn.turn = kind
	turn.max_speed = TURN_SPEED[kind]
	var steps := 4 if kind == 0 else 10
	for i: int in steps + 1:
		var t := float(i) / steps
		var u := 1.0 - t
		turn.points.append(p0 * u * u + p1 * 2.0 * u * t + p2 * t * t)
	_add(turn)
	return turn.id


## Kommen sich zwei Kurven näher als eine Autobreite (plus Rand)?
func _crosses(a: Piece, b: Piece) -> bool:
	var s := 0.0
	while s <= a.length:
		var pa := a.point_at(s)
		var u := 0.0
		while u <= b.length:
			var pb := b.point_at(u)
			if Vector2(pa.x - pb.x, pa.z - pb.z).length() < 2.6:
				return true
			u += 0.75
		s += 0.75
	return false
