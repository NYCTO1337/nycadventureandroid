extends Node
## Composition root: builds the level, HUD, touch controls and menus.

var _level: Level
var _hud: HUD
var _menu: PauseMenu


func _ready() -> void:
	GameState.reset_run()

	_level = Level.new()
	add_child(_level)

	_hud = HUD.new()
	add_child(_hud)

	var controls_layer := CanvasLayer.new()
	controls_layer.layer = 20
	controls_layer.add_child(TouchControls.new())
	add_child(controls_layer)

	_menu = PauseMenu.new()
	add_child(_menu)

	_hud.pause_pressed.connect(func() -> void: GameState.set_paused(true))
	_level.coin_collected.connect(_hud.set_coins)
	_level.sign_requested.connect(_hud.show_toast)
	_level.completed.connect(_on_completed)
	_menu.restart_requested.connect(_restart)

	_hud.set_coins(0, _level.total_coins)
	_hud.show_toast("NYCTO'S ADVENTURE", 3.0)


func _on_completed() -> void:
	GameState.finish_level()
	AudioManager.play("win")
	PlatformService.vibrate(120)
	await get_tree().create_timer(1.0, false).timeout
	GameState.set_paused(true)


func _restart() -> void:
	GameState.set_paused(false)
	get_tree().reload_current_scene()
