extends Node
## Global game / app state: settings, progress, pause handling and the
## application lifecycle (background / foreground / Android back gesture).

signal paused_changed(is_paused: bool)
signal coins_changed(count: int)
signal settings_changed

const DEFAULT_SETTINGS := {
	"control_opacity": 0.45,
	"control_scale": 1.0,
	"stick_sensitivity": 1.0,
	"swap_sides": false,
	"music_volume": 0.6,
	"sfx_volume": 0.9,
	"haptics": true,
}

var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var progress: Dictionary = {"best_time": -1.0, "total_coins": 0, "completions": 0}

var coins := 0
var deaths := 0
var run_time := 0.0
var level_coins_total := 0
var level_finished := false
var is_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	_load()


func _load() -> void:
	var data := SaveSystem.load_data()
	var s = data.get("settings", {})
	if typeof(s) == TYPE_DICTIONARY:
		for key in DEFAULT_SETTINGS:
			if s.has(key) and typeof(s[key]) == typeof(DEFAULT_SETTINGS[key]):
				settings[key] = s[key]
	settings["control_opacity"] = clampf(settings["control_opacity"], 0.1, 0.9)
	settings["control_scale"] = clampf(settings["control_scale"], 0.6, 1.6)
	settings["stick_sensitivity"] = clampf(settings["stick_sensitivity"], 0.5, 2.0)
	settings["music_volume"] = clampf(settings["music_volume"], 0.0, 1.0)
	settings["sfx_volume"] = clampf(settings["sfx_volume"], 0.0, 1.0)

	var p = data.get("progress", {})
	if typeof(p) == TYPE_DICTIONARY:
		if typeof(p.get("best_time")) in [TYPE_FLOAT, TYPE_INT]:
			progress["best_time"] = float(p["best_time"])
		if typeof(p.get("total_coins")) in [TYPE_FLOAT, TYPE_INT]:
			progress["total_coins"] = maxi(int(p["total_coins"]), 0)
		if typeof(p.get("completions")) in [TYPE_FLOAT, TYPE_INT]:
			progress["completions"] = maxi(int(p["completions"]), 0)


func save_all() -> void:
	SaveSystem.save_data({"settings": settings, "progress": progress})


func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [floori(s / 60.0), s % 60]


func reset_run() -> void:
	coins = 0
	deaths = 0
	run_time = 0.0
	level_coins_total = 0
	level_finished = false


func add_coin() -> void:
	coins += 1
	coins_changed.emit(coins)


func finish_level() -> void:
	level_finished = true
	progress["completions"] = int(progress["completions"]) + 1
	progress["total_coins"] = int(progress["total_coins"]) + coins
	var best := float(progress["best_time"])
	if best < 0.0 or run_time < best:
		progress["best_time"] = run_time
	save_all()


func set_paused(value: bool) -> void:
	if is_paused == value:
		return
	is_paused = value
	get_tree().paused = value
	paused_changed.emit(value)


func toggle_pause() -> void:
	set_paused(not is_paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			# App went to background (or lost focus): stop logic + audio, save.
			if not level_finished:
				set_paused(true)
			save_all()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button / gesture opens the pause menu, never quits.
			if not level_finished:
				toggle_pause()
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_all()
			get_tree().quit()
