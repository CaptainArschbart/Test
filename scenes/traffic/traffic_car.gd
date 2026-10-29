class_name TrafficCar
extends CharacterBody3D
## Ein Auto, das nur von NPCs gefahren wird. Der Spieler kann es nicht betreten.
##
## Fahren: folgt den Stücken des RoadNetwork (Spur → Kurve → Spur …) per Strecke s, Tempo mit
## weichem Beschleunigen/Bremsen. Vor Kurven bremst es auf Kurventempo, an Kreuzungen fragt es den
## TrafficDirector um Einfahrt (keine sich kreuzenden Kurven gleichzeitig, Platz auf der Spur danach).
##
## Hindernisse: Punkte entlang des eigenen Wegs werden gegen alle Personen (Spieler, Fußgänger,
## Gegner) und andere Autos geprüft, das Auto hält davor an. Steht eine Person oder ein Hindernis
## länger im Weg, hupt es und fährt langsam seitlich daran vorbei, wenn die Gegenspur frei ist.
##
## Treffer: Wer trotzdem vor ein fahrendes Auto springt, wird weggestoßen. Der Spieler bekommt
## moderaten Schaden (Ursache „car“), Fußgänger fallen um, Gegner bekommen Schaden.
## Physik: Kollision auf Layer world (der Spieler läuft nicht hindurch), bewegt wird per Transform.

const Sounds := preload("res://scenes/traffic/vehicle_sounds.gd")

const ACCEL := 2.8
const COMFORT_DECEL := 3.5
const BRAKE_DECEL := 7.0
const SAMPLE_STEP := 1.5
## Seitlich ausweichen: links in die Gegenspur, rechts bis an den Bordstein.
const OFFSETS := [-2.9, 1.2]

var director: TrafficDirector
var model: VehicleModel
var piece_id := -1
var s := 0.0
var speed := 0.0
var cruise := 10.0
var next_turn := -1
var granted := false
var offset := 0.0
var offset_target := 0.0
var lod_far := false

var _rng := RandomNumberGenerator.new()
var _blocked_time := 0.0
var _offset_time := 0.0
var _horn_cd := 0.0
var _hit_cd := 0.0
var _braking := false
var _accum := 0.0
var _waiting_since := -1.0
var _engine: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _blocker_kind := -1
## Multiplayer: Beim Client fährt das Auto nicht selbst, sondern folgt dem Host (net_apply).
var net_puppet := false
var kind_id := 0
var seed_id := 0
var _net_s := 0.0


func setup(new_director: TrafficDirector, lane: int, start_s: float, kind: VehicleModel.Kind, seed_value: int) -> void:
	director = new_director
	piece_id = lane
	s = start_s
	kind_id = kind
	seed_id = seed_value
	_rng.seed = seed_value
	cruise = _rng.randf_range(director.speed_min, director.speed_max)
	collision_layer = 1
	collision_mask = 0
	add_to_group(TrafficDirector.CAR_GROUP)
	model = VehicleModel.new()
	model.name = "Model"
	add_child(model)
	model.build(kind, _rng)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(model.half_width * 2.0, model.height - 0.25, model.half_length * 2.0)
	shape.shape = box
	shape.position.y = 0.25 + (model.height - 0.25) * 0.5
	add_child(shape)
	_engine = _audio(-8.0, 45.0)
	_engine.stream = Sounds.engine_loop()
	_horn = _audio(2.0, 70.0)
	_horn.stream = Sounds.horn()
	director.lane_enter(piece_id, self)
	_place()


func _audio(db: float, reach: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.volume_db = db
	p.max_distance = reach
	p.unit_size = 6.0
	p.position.y = 0.8
	add_child(p)
	return p


func piece() -> RoadNetwork.Piece:
	return director.network.pieces[piece_id]


func is_braking() -> bool:
	return _braking


## Punkte, mit denen andere Autos dieses Auto erkennen (vorn, Mitte, hinten).
func body_points() -> Array[Vector3]:
	var fwd := -global_basis.z
	var reach := model.half_length - 0.9
	return [global_position + fwd * reach, global_position, global_position - fwd * reach]


## Vom Director: Kamera nah oder weit (weit = seltener rechnen, kein Licht, kein Ton).
func set_near(lights: bool, sound: bool, far: bool) -> void:
	lod_far = far
	if model.headlight.visible != lights:
		model.headlight.visible = lights
	if sound and not _engine.playing:
		_engine.play(_rng.randf() * 0.9)
	elif not sound and _engine.playing:
		_engine.stop()


func _physics_process(delta: float) -> void:
	if director == null or director.network == null:
		return
	if net_puppet:
		_puppet_drive(delta)
		return
	if lod_far:
		_accum += delta
		if _accum < 0.1:
			return
		delta = minf(_accum, 0.25)
		_accum = 0.0
	drive(delta)


func drive(delta: float) -> void:
	_horn_cd = maxf(_horn_cd - delta, 0.0)
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	var p := piece()
	if not p.is_turn and next_turn < 0:
		next_turn = _choose_turn(p)
	var target := cruise if not p.is_turn else p.max_speed
	var to_end := p.length - s
	if not p.is_turn:
		# Vor der Kurve auf Kurventempo
		var turn_speed := director.network.pieces[next_turn].max_speed
		target = minf(target, sqrt(turn_speed * turn_speed + 2.0 * COMFORT_DECEL * maxf(to_end - 2.0, 0.0)))
		if not granted:
			if to_end < 16.0 and absf(offset) < 0.3:
				if _waiting_since < 0.0:
					_waiting_since = Time.get_ticks_msec() / 1000.0
				granted = director.try_enter(self, next_turn, _waiting_since)
			if not granted:
				target = minf(target, _stop_speed(to_end - 0.4))
	# Hindernisse auf dem Weg
	var hit := _scan(offset, _look_distance())
	_blocker_kind = -1
	if not hit.is_empty():
		var gap: float = 2.6 if hit[1] == TrafficDirector.Kind.CAR else 2.2
		target = minf(target, _stop_speed(hit[0] - gap))
		_blocker_kind = hit[1]
	if absf(offset) > 0.3 or absf(offset_target) > 0.3:
		target = minf(target, 4.5)
	_braking = target < speed - 0.3
	var rate := ACCEL if target > speed else (BRAKE_DECEL if target < speed - 2.0 or target < 0.5 else COMFORT_DECEL)
	speed = move_toward(speed, maxf(target, 0.0), rate * delta)
	_update_blocked(delta, hit, p)
	offset = move_toward(offset, offset_target, 1.5 * delta)
	_advance(speed * delta)
	_place()
	model.update(speed, delta, _braking or speed < 0.2)
	if _engine.playing:
		_engine.pitch_scale = 0.55 + speed / 14.0
		_engine.volume_db = -14.0 + minf(speed, 10.0) * 0.6
	_check_hits()


func _look_distance() -> float:
	return clampf(model.half_length + 4.0 + speed * speed / (2.0 * BRAKE_DECEL) + speed * 0.6, 8.0, 34.0)


func _stop_speed(distance: float) -> float:
	return sqrt(2.0 * BRAKE_DECEL * maxf(distance, 0.0))


func _choose_turn(p: RoadNetwork.Piece) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for t: int in p.turns:
		var kind := director.network.pieces[t].turn
		var w := 0.5 if kind == 0 else (0.3 if kind == 1 else 0.2)
		weights.append(w)
		total += w
	var roll := _rng.randf() * total
	for i: int in p.turns.size():
		roll -= weights[i]
		if roll <= 0.0:
			return p.turns[i]
	return p.turns[0]


## Weg voraus abtasten. Gibt [Abstand ab Stoßstange, Art, Knoten] des ersten Hindernisses zurück.
func _scan(lateral: float, distance: float) -> Array:
	var net := director.network
	var pid := piece_id
	var ps := s + model.half_length * 0.5
	var travelled := -model.half_length * 0.5
	var side_ok := true
	var nearby := director.obstacles_near(global_position, distance + 4.0)
	if nearby.is_empty():
		return []
	while travelled < distance:
		var p := net.pieces[pid]
		while ps > p.length:
			ps -= p.length
			var next := -1
			if p.is_turn:
				next = p.out_lane
			elif pid == piece_id and next_turn >= 0:
				next = next_turn
			elif not p.turns.is_empty():
				next = p.turns[0]
			if next < 0:
				return []
			pid = next
			p = net.pieces[pid]
			side_ok = false
		var point := p.point_at(ps)
		if side_ok and absf(lateral) > 0.01:
			point += p.dir_at(ps).cross(Vector3.UP) * lateral
		for o: Array in nearby:
			if o[2] == self:
				continue
			var pos: Vector3 = o[0]
			var r: float = o[1] + model.half_width
			if absf(pos.y - point.y) < 2.5 and Vector2(pos.x - point.x, pos.z - point.z).length_squared() < r * r:
				return [maxf(travelled - model.half_length * 0.5, 0.0), o[3], o[2]]
		ps += SAMPLE_STEP
		travelled += SAMPLE_STEP
	return []


## Steht etwas im Weg, das nicht wegfährt: hupen, dann vorsichtig seitlich vorbei.
func _update_blocked(delta: float, hit: Array, p: RoadNetwork.Piece) -> void:
	var person_block: bool = not hit.is_empty() and hit[1] != TrafficDirector.Kind.CAR and speed < 0.6
	if person_block:
		_blocked_time += delta
	else:
		_blocked_time = maxf(_blocked_time - delta * 2.0, 0.0)
	if person_block and _horn_cd <= 0.0 and _blocked_time > (1.0 if hit[1] == TrafficDirector.Kind.PLAYER else 2.2):
		_horn_cd = _rng.randf_range(3.5, 6.0)
		_horn.pitch_scale = _rng.randf_range(0.92, 1.08)
		_horn.play()
	if offset_target == 0.0 and _blocked_time > 2.8 and not p.is_turn and p.length - s > 14.0:
		for o: float in OFFSETS:
			if _scan(o, 24.0 if o < 0.0 else 14.0).is_empty():
				offset_target = o
				_offset_time = 0.0
				break
	if offset_target != 0.0:
		_offset_time += delta
		var near_end := not p.is_turn and p.length - s < 14.0
		if (_offset_time > 2.5 and _scan(0.0, 9.0).is_empty()) or near_end or p.is_turn:
			offset_target = 0.0
		elif not _scan(offset_target, 10.0).is_empty() and _offset_time > 0.5:
			# Auf der Ausweichspur kommt etwas: zurück, falls frei, sonst warten.
			if _scan(0.0, 9.0).is_empty():
				offset_target = 0.0


func _advance(step: float) -> void:
	s += step
	var p := piece()
	while s > p.length:
		if not p.is_turn and not granted:
			s = p.length
			speed = 0.0
			return
		s -= p.length
		director.lane_leave(piece_id, self)
		if p.is_turn:
			director.leave_junction(self)
			piece_id = p.out_lane
			granted = false
			_waiting_since = -1.0
		else:
			piece_id = next_turn
			next_turn = -1
		director.lane_enter(piece_id, self)
		p = piece()


func _place() -> void:
	var p := piece()
	var pos := p.point_at(s)
	var dir := p.dir_at(s)
	if absf(offset) > 0.001:
		pos += dir.cross(Vector3.UP) * offset
	# Beim Ausweichen leicht schräg stellen.
	var yaw := atan2(-dir.x, -dir.z) - clampf((offset_target - offset) * 0.25, -0.25, 0.25) * signf(speed)
	global_transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * (sin(Time.get_ticks_msec() * 0.011 + _rng.seed % 7) * 0.006))


## Wer im Umriss des fahrenden Autos steht, wird weggestoßen.
func _check_hits() -> void:
	if speed < 1.4 or _hit_cd > 0.0:
		return
	var inv := global_transform.affine_inverse()
	var fwd := -global_basis.z
	for o: Array in director.obstacles_near(global_position, model.half_length + 1.5):
		var kind: int = o[3]
		if kind == TrafficDirector.Kind.CAR:
			continue
		var node: Node3D = o[2]
		if not is_instance_valid(node):
			continue
		var local := inv * node.global_position
		if absf(local.x) > model.half_width + 0.35 or absf(local.z) > model.half_length + 0.35:
			continue
		if local.y > model.height - 0.2 or local.y < -0.8:
			continue  # steht auf dem Dach oder ist weit drunter
		_hit_cd = 0.8
		var side := signf(local.x) if absf(local.x) > 0.05 else 1.0
		var push := fwd * (speed + 2.5) + global_basis.x * side * 2.5 + Vector3.UP * 3.5
		var hit_speed := speed
		speed *= 0.4
		director.play_hit(global_position)
		if kind == TrafficDirector.Kind.PLAYER:
			_hit_player(node, push, hit_speed)
		elif node.has_method("hit_by_car"):
			node.hit_by_car(push, hit_speed)
		elif node.has_method("take_hit"):
			node.take_hit(hit_speed * 4.0, node.global_position + Vector3.UP, -fwd)
		return


func _hit_player(node: Node3D, push: Vector3, hit_speed: float) -> void:
	var player := node as CharacterBody3D
	if player == null:
		return
	var amount := clampf((hit_speed - 1.4) * 3.0, 3.0, 30.0)
	# Multiplayer: Autos fährt der Host, Schaden und Stoß gehen an den Rechner, der die Figur steuert.
	if player.has_method("apply_damage"):
		if player.call("controls_local_body"):
			player.velocity = Vector3.ZERO
		player.call("apply_damage", amount, &"car", push)
		return
	player.velocity = push
	var stats: Variant = player.get("stats")
	if stats != null and stats.has_method("damage"):
		stats.damage(amount, &"car")


# --- Multiplayer --------------------------------------------------------------------------

## Host → Clients (über TrafficDirector.net_get_state): Spur, Strecke, Versatz, Tempo, Bremslicht.
func net_floats() -> PackedFloat32Array:
	return PackedFloat32Array([piece_id, s, offset, speed, 1.0 if _braking else 0.0])


## Client: Stand vom Host. Auf derselben Spur wird weich nachgezogen, sonst springt das Auto.
func net_apply(lane: int, new_s: float, new_offset: float, new_speed: float, braking: bool) -> void:
	if lane != piece_id:
		director.lane_leave(piece_id, self)
		piece_id = lane
		director.lane_enter(piece_id, self)
		s = new_s
	elif absf(new_s - s) > 4.0:
		s = new_s
	_net_s = new_s
	offset = new_offset
	speed = new_speed
	_braking = braking


## Client: zwischen den Paketen mit dem letzten Tempo weiterfahren, Abweichung langsam abbauen.
func _puppet_drive(delta: float) -> void:
	_net_s += speed * delta
	s += speed * delta
	s = lerpf(s, _net_s, minf(delta * 4.0, 1.0))
	s = minf(s, piece().length)
	_place()
	model.update(speed, delta, _braking or speed < 0.2)
	if _engine.playing:
		_engine.pitch_scale = 0.55 + speed / 14.0
		_engine.volume_db = -14.0 + minf(speed, 10.0) * 0.6
