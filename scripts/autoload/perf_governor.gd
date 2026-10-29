extends Node
## Watches the frame rate and lowers visual quality on weak devices.
## quality 0 = full, 1 = fewer effects, 2 = no dynamic lighting / particles.

signal quality_changed(level: int)

const CHECK_WINDOW := 2.0
const LOW_FPS := 45.0
const MAX_QUALITY := 2

var quality := 0
var _acc := 0.0
var _frames := 0
var _low_windows := 0


func _process(delta: float) -> void:
	# Autoload is pausable, so this does not run while the game is paused.
	_acc += delta
	_frames += 1
	if _acc < CHECK_WINDOW:
		return
	var fps := float(_frames) / _acc
	_acc = 0.0
	_frames = 0
	if fps < LOW_FPS:
		_low_windows += 1
	else:
		_low_windows = 0
	if _low_windows >= 2 and quality < MAX_QUALITY:
		quality += 1
		_low_windows = 0
		quality_changed.emit(quality)
