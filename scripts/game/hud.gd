extends CanvasLayer
class_name HUD

signal pause_pressed

var _stats: VBoxContainer
var _coins_label: Label
var _time_label: Label
var _toast: Label
var _pause_btn: Button
var _toast_time := 0.0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_stats = VBoxContainer.new()
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stats)
	_coins_label = _make_label(30)
	_time_label = _make_label(24)
	_stats.add_child(_coins_label)
	_stats.add_child(_time_label)

	_toast = _make_label(26)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.custom_minimum_size = Vector2(780, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.12, 0.8)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	_toast.add_theme_stylebox_override("normal", sb)
	_toast.visible = false
	root.add_child(_toast)

	_pause_btn = Button.new()
	_pause_btn.text = "II"
	_pause_btn.custom_minimum_size = Vector2(76, 76)
	_pause_btn.add_theme_font_size_override("font_size", 30)
	_pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	root.add_child(_pause_btn)

	get_viewport().size_changed.connect(_layout)
	_layout()
	set_coins(0, GameState.level_coins_total)


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var ins := PlatformService.get_safe_insets()
	_stats.position = Vector2(ins["left"] + 24.0, ins["top"] + 14.0)
	_pause_btn.position = Vector2(vp.x - ins["right"] - 24.0 - 76.0, ins["top"] + 14.0)
	_toast.position = Vector2((vp.x - 780.0) * 0.5, ins["top"] + 96.0)


func set_coins(count: int, total: int) -> void:
	_coins_label.text = "მონეტები: %d / %d" % [count, total]


func show_toast(text: String, seconds := 4.0) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_time = seconds


func _process(delta: float) -> void:
	_time_label.text = "დრო: " + GameState.format_time(GameState.run_time)
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
		if _toast_time <= 0.0:
			_toast.visible = false
