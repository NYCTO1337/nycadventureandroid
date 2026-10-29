extends Control
class_name TouchControls
## Self-contained on-screen controls. It only talks to the game through
## Godot input actions (move_left / move_right / jump / interact), so the game
## code never knows whether input comes from touch, keyboard or a gamepad.
## Porting to another platform = changing this file only.
##
## - Left side: floating horizontal stick (appears where the thumb lands).
## - Right side: big JUMP button and a smaller INTERACT button.
## - Every finger is tracked by its touch index -> true multi-touch + hold.
## - Size, opacity, sensitivity and left/right swap come from GameState.settings.

const BASE_STICK_RADIUS := 90.0
const BASE_BUTTON_RADIUS := 62.0
const DEADZONE := 0.18
const BUTTONS := ["jump", "interact"]

var _touches: Dictionary = {}      # touch index -> "stick" | "jump" | "interact"
var _centers: Dictionary = {}      # button name -> Vector2
var _pressed: Dictionary = {"jump": false, "interact": false}
var _radius_btn := BASE_BUTTON_RADIUS
var _radius_stick := BASE_STICK_RADIUS
var _home_stick := Vector2.ZERO
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _stick_active := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.settings_changed.connect(_relayout)
	GameState.paused_changed.connect(_on_paused_changed)
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _on_paused_changed(is_paused: bool) -> void:
	if is_paused:
		release_all()


func release_all() -> void:
	_touches.clear()
	_stick_active = false
	_set_axis(0.0)
	for b in BUTTONS:
		_set_button(b, false)
	_stick_origin = _home_stick
	_stick_pos = _home_stick
	queue_redraw()


func _relayout() -> void:
	var vp := get_viewport_rect().size
	var ins := PlatformService.get_safe_insets()
	var s: float = GameState.settings["control_scale"]
	var swap: bool = GameState.settings["swap_sides"]
	_radius_btn = BASE_BUTTON_RADIUS * s
	_radius_stick = BASE_STICK_RADIUS * s
	var margin := 36.0
	var bottom_y := vp.y - ins["bottom"] - margin

	var stick_x: float
	var jump_x: float
	var dir: float
	if not swap:
		stick_x = ins["left"] + margin + _radius_stick + 16.0
		jump_x = vp.x - ins["right"] - margin - _radius_btn
		dir = -1.0
	else:
		stick_x = vp.x - ins["right"] - margin - _radius_stick - 16.0
		jump_x = ins["left"] + margin + _radius_btn
		dir = 1.0
	_home_stick = Vector2(stick_x, bottom_y - _radius_stick)
	_centers["jump"] = Vector2(jump_x, bottom_y - _radius_btn)
	_centers["interact"] = _centers["jump"] + Vector2(dir * _radius_btn * 2.2, -_radius_btn * 0.8)
	if not _stick_active:
		_stick_origin = _home_stick
		_stick_pos = _home_stick
	queue_redraw()


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_down(event.index, event.position)
		else:
			_on_up(event.index)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position)


func _on_down(index: int, pos: Vector2) -> void:
	for b in BUTTONS:
		# Hit area is a little bigger than the drawn circle: easier to hit.
		if pos.distance_to(_centers[b]) <= _radius_btn * 1.25:
			_touches[index] = b
			_set_button(b, true)
			return
	var vp := get_viewport_rect().size
	var swap: bool = GameState.settings["swap_sides"]
	var in_stick_zone := (pos.x < vp.x * 0.5) != swap
	# Top 25% is reserved for HUD (pause button).
	if in_stick_zone and not _stick_active and pos.y > vp.y * 0.25:
		_stick_active = true
		_touches[index] = "stick"
		_stick_origin = pos
		_stick_pos = pos
		_apply_stick()
		queue_redraw()


func _on_drag(index: int, pos: Vector2) -> void:
	if _touches.get(index, "") != "stick":
		return
	var dx := pos.x - _stick_origin.x
	if absf(dx) > _radius_stick:
		# Origin follows the thumb: reversing direction is instant.
		_stick_origin.x = pos.x - signf(dx) * _radius_stick
	_stick_pos = pos
	_apply_stick()
	queue_redraw()


func _on_up(index: int) -> void:
	var role: String = _touches.get(index, "")
	_touches.erase(index)
	if role == "stick":
		_stick_active = false
		_set_axis(0.0)
		_stick_origin = _home_stick
		_stick_pos = _home_stick
		queue_redraw()
	elif role != "":
		_set_button(role, false)


func _apply_stick() -> void:
	var sens: float = GameState.settings["stick_sensitivity"]
	var v := clampf((_stick_pos.x - _stick_origin.x) / _radius_stick * sens, -1.0, 1.0)
	if absf(v) < DEADZONE:
		v = 0.0
	else:
		v = signf(v) * (absf(v) - DEADZONE) / (1.0 - DEADZONE)
	_set_axis(v)


func _set_axis(v: float) -> void:
	if v > 0.0:
		Input.action_press("move_right", v)
		Input.action_release("move_left")
	elif v < 0.0:
		Input.action_press("move_left", -v)
		Input.action_release("move_right")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")


func _set_button(b: String, down: bool) -> void:
	if _pressed[b] == down:
		return
	_pressed[b] = down
	if down:
		Input.action_press(b)
		if b == "jump":
			PlatformService.vibrate(10)
	else:
		Input.action_release(b)
	queue_redraw()


func _draw() -> void:
	var a: float = GameState.settings["control_opacity"]
	var rim := Color(0.8, 0.9, 1.0, a * 0.8)

	# Stick
	draw_circle(_stick_origin, _radius_stick, Color(0.7, 0.8, 1.0, a * (0.28 if _stick_active else 0.14)))
	draw_arc(_stick_origin, _radius_stick, 0.0, TAU, 48, rim, 3.0, true)
	var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(_radius_stick)
	draw_circle(knob, _radius_stick * 0.42, Color(0.8, 0.92, 1.0, a * (0.9 if _stick_active else 0.55)))

	# Jump
	var jc: Vector2 = _centers["jump"]
	draw_circle(jc, _radius_btn, Color(0.7, 0.85, 1.0, a * (0.55 if _pressed["jump"] else 0.22)))
	draw_arc(jc, _radius_btn, 0.0, TAU, 48, rim, 3.0, true)
	var r := _radius_btn * 0.35
	draw_polyline(PackedVector2Array([jc + Vector2(-r, r * 0.4), jc + Vector2(0, -r * 0.6), jc + Vector2(r, r * 0.4)]), rim, 6.0, true)

	# Interact
	var ic: Vector2 = _centers["interact"]
	var ir := _radius_btn * 0.72
	draw_circle(ic, ir, Color(1.0, 0.85, 0.5, a * (0.55 if _pressed["interact"] else 0.22)))
	draw_arc(ic, ir, 0.0, TAU, 40, Color(1.0, 0.9, 0.6, a * 0.8), 3.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, ic + Vector2(-ir, ir * 0.3), "E", HORIZONTAL_ALIGNMENT_CENTER, ir * 2.0, int(ir * 0.9), Color(1, 0.95, 0.8, a * 1.1))
