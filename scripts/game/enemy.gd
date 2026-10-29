extends Area2D
class_name Enemy
## Simple patrolling slime. Jump on its head to defeat it, touch it from the
## side and you get hurt. Origin of the node = its feet.

signal stomped(at: Vector2)

var left_x := 0.0
var right_x := 0.0
var speed := 55.0

var _dir := 1.0
var _t := 0.0
var _dead := false
var _poly := PackedVector2Array()


func setup(l: float, r: float) -> void:
	left_x = l
	right_x = r


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(34, 26)
	c.shape = s
	c.position = Vector2(0, -13)
	add_child(c)
	body_entered.connect(_on_body_entered)
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		_poly.append(Vector2(cos(a) * 18.0, sin(a) * 26.0))


func _physics_process(delta: float) -> void:
	_t += delta
	position.x += _dir * speed * delta
	if position.x > right_x:
		_dir = -1.0
	elif position.x < left_x:
		_dir = 1.0
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _dead or not body.is_in_group("player"):
		return
	var p := body as Player
	if p.frozen:
		return
	if p.velocity.y > 40.0 and p.global_position.y < global_position.y - 30.0:
		_dead = true
		p.bounce()
		stomped.emit(global_position)
		queue_free()
	else:
		p.hurt()


func _draw() -> void:
	var w := sin(_t * 6.0) * 0.06
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 + w, 1.0 - w))
	draw_colored_polygon(_poly, Color(0.52, 0.36, 0.86))
	for ex in [-6.0, 6.0]:
		draw_circle(Vector2(ex, -14), 4.5, Color.WHITE)
		draw_circle(Vector2(ex + _dir * 1.5, -13), 2.2, Color(0.1, 0.1, 0.17))
