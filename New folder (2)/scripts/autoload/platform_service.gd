extends Node
## The ONLY place that talks to platform specifics (Android / iOS / desktop):
## input map setup, haptics, safe-area insets. Everything else in the game
## calls these functions, so a new platform only needs changes here.


func _ready() -> void:
	_setup_input_map()
	Engine.max_fps = 60  # saves battery on 90/120 Hz displays


func is_mobile() -> bool:
	return OS.has_feature("mobile")


func platform_name() -> String:
	return OS.get_name()  # "Android", "iOS", "Windows", "Linux", "macOS", "Web"


func vibrate(ms: int) -> void:
	if is_mobile() and bool(GameState.settings.get("haptics", true)):
		Input.vibrate_handheld(ms)


## Safe-area insets (display cutouts, rounded corners, gesture bars) converted
## to viewport units. Returns zeros on desktop or when unsupported.
func get_safe_insets() -> Dictionary:
	var out := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if not is_mobile():
		return out
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return out
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return out
	var vp := get_tree().root.get_visible_rect().size
	var sx := vp.x / win.x
	var sy := vp.y / win.y
	out["left"] = maxf(safe.position.x, 0.0) * sx
	out["top"] = maxf(safe.position.y, 0.0) * sy
	out["right"] = maxf(win.x - safe.end.x, 0.0) * sx
	out["bottom"] = maxf(win.y - safe.end.y, 0.0) * sy
	return out


func _setup_input_map() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action("interact", [KEY_E, KEY_ENTER])
	_add_action("pause", [KEY_ESCAPE, KEY_P])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
