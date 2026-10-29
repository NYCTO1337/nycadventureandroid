extends Node2D
class_name Level
## Builds the whole level from the data tables below (tile units, 48 px/tile).
## Static art is drawn once into a cached canvas item; only coins, flag and
## hints are redrawn each frame. Collision uses a few merged shapes, not one
## per tile.

signal coin_collected(count: int, total: int)
signal sign_requested(text: String)
signal completed

const TILE := 48
const COLS := 72
const ROWS := 14

# [col_from, col_to_exclusive, top_row]  (ground fills down to the bottom)
const GROUND: Array = [[0, 14, 11], [17, 28, 11], [31, 40, 10], [43, 52, 11], [55, 72, 10]]
# One-way platforms: [col_from, col_to_exclusive, top_row]
const PLATFORMS: Array = [[21, 24, 10], [33, 35, 9], [36, 38, 8]]
# Spikes: [col, row]
const SPIKES: Array = [[26, 10], [46, 10], [47, 10]]
# Enemies: [start_col, ground_top_row, patrol_left_col, patrol_right_col]
const ENEMIES: Array = [[35, 10, 32, 39], [49, 11, 48, 51], [62, 10, 57, 70]]
# Coins: [col, row]
const COINS: Array = [
	[5, 10], [6, 10], [7, 10], [15, 9], [16, 9],
	[21, 9], [22, 9], [23, 9], [26, 9], [29, 9],
	[34, 8], [37, 7], [45, 9], [46, 9], [47, 9],
	[58, 9], [59, 9], [60, 9], [65, 9], [66, 9],
]
# Signs: [col, ground_top_row, text]
const SIGNS: Array = [
	[3, 11, "მოძრაობა — მარცხენა მხარე. ხტომა — მარჯვენა დიდი ღილაკი. დააგროვე მონეტები!"],
	[32, 10, "ფრთხილად! წვეტიანები საშიშია, მტრებს კი თავზე ახტი."],
	[56, 10, "დროშა ახლოსაა — დაასრულე თავგადასავალი!"],
]
const GOAL := [68, 10]
const START_COL := 2

var player: Player
var total_coins := 0

var _coin_pos: Array[Vector2] = []
var _coin_taken: Array[bool] = []
var _sign_pos: Array[Vector2] = []
var _checkpoint := Vector2.ZERO
var _world: Node2D
var _dynamic: Node2D
var _modulate: CanvasModulate
var _burst: CPUParticles2D
var _dust: CPUParticles2D
var _t := 0.0
var _near_sign := -1
var _finished := false
var _quality := 0


func _ready() -> void:
	_build_background()
	_world = Node2D.new()
	_world.draw.connect(_draw_world)
	add_child(_world)
	_build_collision()
	_build_hazards()
	_build_goal()
	_build_enemies()

	for c in COINS:
		_coin_pos.append(Vector2((c[0] + 0.5) * TILE, (c[1] + 0.5) * TILE))
		_coin_taken.append(false)
	total_coins = _coin_pos.size()
	GameState.level_coins_total = total_coins
	for s in SIGNS:
		_sign_pos.append(Vector2((s[0] + 0.5) * TILE, s[1] * TILE))

	_dynamic = Node2D.new()
	_dynamic.z_index = 5
	_dynamic.draw.connect(_draw_dynamic)
	add_child(_dynamic)

	_modulate = CanvasModulate.new()
	_modulate.color = Color(0.6, 0.64, 0.85)
	add_child(_modulate)

	_burst = _make_particles(Color(1.0, 0.85, 0.3), 14, 0.5, 90.0, 170.0)
	_dust = _make_particles(Color(0.8, 0.8, 0.9, 0.8), 6, 0.35, 30.0, 70.0)

	_spawn_player()
	PerfGovernor.quality_changed.connect(_apply_quality)
	_apply_quality(PerfGovernor.quality)


func _spawn_player() -> void:
	_checkpoint = Vector2((START_COL + 0.5) * TILE, 11 * TILE - 21)
	player = Player.new()
	player.position = _checkpoint
	add_child(player)
	player.died.connect(_on_player_died)
	player.jumped.connect(_on_jumped)
	player.landed.connect(_on_landed)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 9.0
	cam.limit_left = 0
	cam.limit_right = COLS * TILE
	cam.limit_top = 0
	cam.limit_bottom = ROWS * TILE + TILE
	player.add_child(cam)


# ----------------------------------------------------------------- building

func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(func() -> void: _draw_background(bg))
	layer.add_child(bg)
	get_viewport().size_changed.connect(bg.queue_redraw)


func _draw_background(bg: Control) -> void:
	var vp := get_viewport_rect().size
	var top := Color(0.05, 0.07, 0.18)
	var bottom := Color(0.24, 0.18, 0.43)
	bg.draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(vp.x, 0), Vector2(vp.x, vp.y), Vector2(0, vp.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 70:
		var p := Vector2(rng.randf() * vp.x, rng.randf() * vp.y * 0.7)
		bg.draw_circle(p, rng.randf_range(0.8, 1.8), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
	bg.draw_circle(Vector2(vp.x * 0.82, vp.y * 0.2), 46.0, Color(0.96, 0.94, 0.8))
	bg.draw_circle(Vector2(vp.x * 0.82 + 18.0, vp.y * 0.2 - 8.0), 42.0, Color(0.12, 0.11, 0.27))


func _static_body(rect: Rect2, one_way := false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	shape.shape = r
	shape.position = rect.position + rect.size * 0.5
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)


func _build_collision() -> void:
	for g in GROUND:
		var x0: float = g[0] * TILE
		var x1: float = g[1] * TILE
		var top: float = g[2] * TILE
		_static_body(Rect2(x0, top, x1 - x0, ROWS * TILE + TILE - top))
	for p in PLATFORMS:
		var x0: float = p[0] * TILE
		var x1: float = p[1] * TILE
		_static_body(Rect2(x0, p[2] * TILE, x1 - x0, 12.0), true)
	# Invisible side walls keep the player inside the level.
	_static_body(Rect2(-40, -400, 40, ROWS * TILE + 1200))
	_static_body(Rect2(COLS * TILE, -400, 40, ROWS * TILE + 1200))


func _hazard_area(rect: Rect2, on_enter: Callable) -> void:
	var a := Area2D.new()
	a.collision_layer = 4
	a.collision_mask = 2
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	shape.shape = r
	shape.position = rect.position + rect.size * 0.5
	a.add_child(shape)
	add_child(a)
	a.body_entered.connect(on_enter)


func _build_hazards() -> void:
	for s in SPIKES:
		var bottom: float = (s[1] + 1) * TILE
		_hazard_area(Rect2(s[0] * TILE + 6.0, bottom - 22.0, TILE - 12.0, 22.0), _on_hazard_entered)


func _build_goal() -> void:
	var x: float = GOAL[0] * TILE
	var bottom: float = (GOAL[1]) * TILE
	_hazard_area(Rect2(x, bottom - 120.0, TILE, 120.0), _on_goal_entered)
	var lamp := PointLight2D.new()
	lamp.texture = _make_light_texture()
	lamp.texture_scale = 3.0
	lamp.color = Color(1.0, 0.8, 0.4)
	lamp.energy = 1.1
	lamp.position = Vector2(x + 24.0, bottom - 90.0)
	lamp.name = "GoalLight"
	add_child(lamp)


func _build_enemies() -> void:
	for e in ENEMIES:
		var en := Enemy.new()
		en.position = Vector2((e[0] + 0.5) * TILE, e[1] * TILE)
		en.setup((e[2] + 0.5) * TILE, (e[3] + 0.5) * TILE)
		en.stomped.connect(_on_enemy_stomped)
		add_child(en)


func _make_light_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color.BLACK])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


func _make_particles(col: Color, amount: int, life: float, v_min: float, v_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = Vector2(0, 420)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = col
	p.z_index = 6
	add_child(p)
	return p


func _emit(p: CPUParticles2D, at: Vector2) -> void:
	if _quality >= 2:
		return
	p.global_position = at
	p.restart()
	p.emitting = true


# ------------------------------------------------------------------- drawing

func _draw_world() -> void:
	var dirt := Color(0.2, 0.17, 0.3)
	var dirt_line := Color(0.15, 0.13, 0.24)
	var grass := Color(0.35, 0.62, 0.55)
	for g in GROUND:
		var x0: float = g[0] * TILE
		var x1: float = g[1] * TILE
		var top: float = g[2] * TILE
		var bottom := float(ROWS * TILE)
		_world.draw_rect(Rect2(x0, top, x1 - x0, bottom - top), dirt)
		var y := top + TILE
		while y < bottom:
			_world.draw_line(Vector2(x0, y), Vector2(x1, y), dirt_line, 2.0)
			y += TILE
		var x := x0 + TILE
		while x < x1:
			_world.draw_line(Vector2(x, top), Vector2(x, bottom), dirt_line, 2.0)
			x += TILE
		_world.draw_rect(Rect2(x0, top, x1 - x0, 10.0), grass)
	for p in PLATFORMS:
		var x0: float = p[0] * TILE
		var x1: float = p[1] * TILE
		var y: float = p[2] * TILE
		_world.draw_rect(Rect2(x0, y, x1 - x0, 18.0), Color(0.3, 0.26, 0.45))
		_world.draw_rect(Rect2(x0, y, x1 - x0, 6.0), Color(0.5, 0.78, 0.7))
	for s in SPIKES:
		var base: float = (s[1] + 1) * TILE
		for k in 3:
			var x0: float = s[0] * TILE + k * 16.0
			_world.draw_colored_polygon(
				PackedVector2Array([Vector2(x0, base), Vector2(x0 + 8.0, base - 28.0), Vector2(x0 + 16.0, base)]),
				Color(0.8, 0.82, 0.9))


func _draw_dynamic() -> void:
	# Coins
	for i in _coin_pos.size():
		if _coin_taken[i]:
			continue
		var p := _coin_pos[i] + Vector2(0, sin(_t * 3.0 + float(i)) * 4.0)
		var squeeze := absf(cos(_t * 2.5 + float(i) * 0.5))
		_dynamic.draw_set_transform(p, 0.0, Vector2(maxf(squeeze, 0.25), 1.0))
		_dynamic.draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.8, 0.2))
		_dynamic.draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.92, 0.5))
	_dynamic.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Signs
	for i in _sign_pos.size():
		var sp := _sign_pos[i]
		_dynamic.draw_rect(Rect2(sp.x - 3.0, sp.y - 30.0, 6.0, 30.0), Color(0.45, 0.3, 0.2))
		_dynamic.draw_rect(Rect2(sp.x - 20.0, sp.y - 52.0, 40.0, 26.0), Color(0.7, 0.52, 0.32))
		_dynamic.draw_rect(Rect2(sp.x - 20.0, sp.y - 52.0, 40.0, 26.0), Color(0.35, 0.22, 0.12), false, 2.0)
		if i == _near_sign:
			_dynamic.draw_string(ThemeDB.fallback_font, sp + Vector2(-20.0, -62.0), "E", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 22, Color(1, 0.9, 0.5))

	# Goal flag
	var gx: float = GOAL[0] * TILE + 22.0
	var gy: float = GOAL[1] * TILE
	_dynamic.draw_rect(Rect2(gx, gy - 110.0, 5.0, 110.0), Color(0.85, 0.85, 0.9))
	var wave := sin(_t * 4.0) * 6.0
	_dynamic.draw_colored_polygon(
		PackedVector2Array([
			Vector2(gx + 5.0, gy - 108.0),
			Vector2(gx + 50.0, gy - 94.0 + wave),
			Vector2(gx + 5.0, gy - 76.0)]),
		Color(0.95, 0.45, 0.4))


# ------------------------------------------------------------------- runtime

func _physics_process(delta: float) -> void:
	_t += delta
	if _finished:
		return
	GameState.run_time += delta

	var pp := player.position
	# Coins
	for i in _coin_pos.size():
		if not _coin_taken[i] and pp.distance_squared_to(_coin_pos[i]) < 900.0:
			_coin_taken[i] = true
			GameState.add_coin()
			AudioManager.play("coin")
			_emit(_burst, _coin_pos[i])
			coin_collected.emit(GameState.coins, total_coins)

	# Signs: hint, checkpoints, interaction
	_near_sign = -1
	for i in _sign_pos.size():
		var dx := absf(pp.x - _sign_pos[i].x)
		if dx < 70.0 and absf(pp.y - _sign_pos[i].y) < 90.0:
			_near_sign = i
		if dx < 40.0 and i > 0 and absf(pp.y - _sign_pos[i].y) < 60.0:
			_checkpoint = Vector2(_sign_pos[i].x, _sign_pos[i].y - 21.0)
	if _near_sign >= 0 and Input.is_action_just_pressed("interact"):
		sign_requested.emit(SIGNS[_near_sign][2])

	# Fell into a pit
	if not player.frozen and pp.y > ROWS * TILE + 150.0:
		player.hurt()

	_dynamic.queue_redraw()


func _apply_quality(q: int) -> void:
	_quality = q
	player.light.enabled = q < 2
	var lamp := get_node_or_null("GoalLight") as PointLight2D
	if lamp:
		lamp.enabled = q < 2
	_modulate.color = Color(0.6, 0.64, 0.85) if q < 2 else Color(0.85, 0.88, 1.0)


func _on_hazard_entered(body: Node2D) -> void:
	if body is Player:
		body.hurt()


func _on_goal_entered(body: Node2D) -> void:
	if body is Player and not _finished:
		_finished = true
		player.frozen = true
		player.velocity = Vector2.ZERO
		completed.emit()


func _on_player_died() -> void:
	GameState.deaths += 1
	AudioManager.play("hurt")
	PlatformService.vibrate(60)
	await get_tree().create_timer(0.7, false).timeout
	if not _finished:
		player.respawn(_checkpoint)


func _on_enemy_stomped(at: Vector2) -> void:
	AudioManager.play("stomp")
	_emit(_dust, at + Vector2(0, -10))
	PlatformService.vibrate(25)


func _on_jumped() -> void:
	AudioManager.play("jump")
	_emit(_dust, player.position + Vector2(0, 20))


func _on_landed() -> void:
	_emit(_dust, player.position + Vector2(0, 20))
