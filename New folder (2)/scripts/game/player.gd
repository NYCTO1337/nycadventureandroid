extends CharacterBody2D
class_name Player

signal died
signal jumped
signal landed

const SPEED := 270.0
const ACCEL := 2200.0
const FRICTION := 2600.0
const JUMP_VELOCITY := -560.0
const GRAVITY := 1700.0
const MAX_FALL := 900.0
const COYOTE_TIME := 0.10
const BUFFER_TIME := 0.12

var frozen := false
var light: PointLight2D

var _coyote := 0.0
var _buffer := 0.0
var _facing := 1.0
var _was_on_floor := false
var _squash := Vector2.ONE


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 40)
	shape.shape = rect
	add_child(shape)
	_make_light()


func _make_light() -> void:
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
	light = PointLight2D.new()
	light.texture = tex
	light.texture_scale = 5.0
	light.energy = 0.9
	light.color = Color(1.0, 0.85, 0.6)
	add_child(light)


func _physics_process(delta: float) -> void:
	if frozen:
		return

	var on_floor := is_on_floor()
	_coyote = COYOTE_TIME if on_floor else maxf(_coyote - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_buffer = BUFFER_TIME
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	if not on_floor:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_squash = Vector2(0.8, 1.25)
		jumped.emit()
	# Variable jump height: releasing early cuts the jump short.
	if Input.is_action_just_released("jump") and velocity.y < -200.0:
		velocity.y *= 0.5

	var axis := Input.get_axis("move_left", "move_right")
	var rate := ACCEL if absf(axis) > 0.01 else FRICTION
	velocity.x = move_toward(velocity.x, axis * SPEED, rate * delta)
	if absf(axis) > 0.05:
		_facing = signf(axis)

	move_and_slide()

	var now_floor := is_on_floor()
	if now_floor and not _was_on_floor:
		_squash = Vector2(1.25, 0.8)
		landed.emit()
	_was_on_floor = now_floor
	_squash = _squash.lerp(Vector2.ONE, minf(delta * 12.0, 1.0))
	queue_redraw()


func hurt() -> void:
	if frozen:
		return
	frozen = true
	velocity = Vector2.ZERO
	modulate.a = 0.35
	died.emit()


func respawn(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	_coyote = 0.0
	_buffer = 0.0
	modulate.a = 1.0
	frozen = false


func bounce() -> void:
	velocity.y = JUMP_VELOCITY * 0.75
	_squash = Vector2(0.85, 1.2)


func _draw() -> void:
	# Placeholder art drawn in code (no image assets): a little night owl.
	draw_set_transform(Vector2(0, 20), 0.0, _squash)
	var body := Color(0.91, 0.64, 0.24)
	draw_rect(Rect2(-14, -40, 28, 40), body)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -40), Vector2(-9, -52), Vector2(-3, -40)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(14, -40), Vector2(9, -52), Vector2(3, -40)]), body)
	draw_rect(Rect2(-8, -16, 16, 14), Color(0.98, 0.84, 0.55))
	for ex in [-6.5, 6.5]:
		draw_circle(Vector2(ex, -28), 6.5, Color.WHITE)
		draw_circle(Vector2(ex + _facing * 2.0, -27), 3.2, Color(0.1, 0.1, 0.17))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -21), Vector2(3, -21), Vector2(0, -16)]), Color(0.48, 0.29, 0.07))
