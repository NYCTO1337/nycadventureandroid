extends CanvasLayer
class_name PauseMenu
## Pause menu (with control / audio settings) and the level-complete panel.
## Runs while the tree is paused, so it uses PROCESS_MODE_ALWAYS.

signal restart_requested

var _pause_panel: PanelContainer
var _win_panel: PanelContainer
var _win_label: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_pause_panel = _make_panel(center)
	var vb := _panel_box(_pause_panel)
	vb.add_child(_title("პაუზა"))
	_add_slider(vb, "ღილაკების გამჭვირვალობა", "control_opacity", 0.1, 0.9, 0.05)
	_add_slider(vb, "ღილაკების ზომა", "control_scale", 0.6, 1.6, 0.05)
	_add_slider(vb, "მართვის მგრძნობელობა", "stick_sensitivity", 0.5, 2.0, 0.05)
	_add_check(vb, "მართვის მხარეების შებრუნება", "swap_sides")
	_add_check(vb, "ვიბრაცია", "haptics")
	_add_slider(vb, "მუსიკა", "music_volume", 0.0, 1.0, 0.05)
	_add_slider(vb, "ხმოვანი ეფექტები", "sfx_volume", 0.0, 1.0, 0.05)
	var resume := _button("გაგრძელება")
	resume.pressed.connect(func() -> void: GameState.set_paused(false))
	vb.add_child(resume)
	var restart := _button("თავიდან დაწყება")
	restart.pressed.connect(func() -> void: restart_requested.emit())
	vb.add_child(restart)

	_win_panel = _make_panel(center)
	var wb := _panel_box(_win_panel)
	wb.add_child(_title("დონე გავლილია!"))
	_win_label = Label.new()
	_win_label.add_theme_font_size_override("font_size", 26)
	_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wb.add_child(_win_label)
	var again := _button("თავიდან თამაში")
	again.pressed.connect(func() -> void: restart_requested.emit())
	wb.add_child(again)

	GameState.paused_changed.connect(_on_paused_changed)


func _on_paused_changed(is_paused: bool) -> void:
	visible = is_paused
	if is_paused:
		_pause_panel.visible = not GameState.level_finished
		_win_panel.visible = GameState.level_finished
		if GameState.level_finished:
			_update_win_text()
	else:
		GameState.save_all()  # persist changed settings


func _update_win_text() -> void:
	var best := float(GameState.progress["best_time"])
	_win_label.text = "მონეტები: %d / %d\nდრო: %s\nდაღუპვა: %d\nსაუკეთესო დრო: %s" % [
		GameState.coins, GameState.level_coins_total,
		GameState.format_time(GameState.run_time), GameState.deaths,
		GameState.format_time(best) if best >= 0.0 else "—"]


# ------------------------------------------------------------------ builders

func _make_panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.2, 0.96)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(26)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _panel_box(panel: PanelContainer) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(560, 0)
	panel.add_child(vb)
	return vb


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 36)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 24)
	return b


func _add_slider(parent: Control, label_text: String, key: String, lo: float, hi: float, step: float) -> void:
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 20)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(GameState.settings[key])
	s.custom_minimum_size = Vector2(0, 36)
	s.value_changed.connect(func(v: float) -> void:
		GameState.settings[key] = v
		GameState.settings_changed.emit())
	parent.add_child(s)


func _add_check(parent: Control, label_text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = label_text
	c.add_theme_font_size_override("font_size", 22)
	c.button_pressed = bool(GameState.settings[key])
	c.toggled.connect(func(on: bool) -> void:
		GameState.settings[key] = on
		GameState.settings_changed.emit())
	parent.add_child(c)
