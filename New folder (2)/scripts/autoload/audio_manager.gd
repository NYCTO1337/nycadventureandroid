extends Node
## All audio. Every sound is synthesized in code at startup, so the project
## ships without audio files (no licensing questions, tiny APK). Players are
## created once and reused: no allocations during gameplay.

const SFX_RATE := 22050
const MUSIC_RATE := 16000

var _music: AudioStreamPlayer
var _sfx: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.stream = _make_music()
	add_child(_music)

	_sfx["jump"] = _make_player(_wav(_tone(380.0, 720.0, 0.16, 0.35), SFX_RATE))
	_sfx["coin"] = _make_player(_wav(_arp([880.0, 1320.0], 0.09, 0.3), SFX_RATE))
	_sfx["hurt"] = _make_player(_wav(_tone(300.0, 80.0, 0.35, 0.5), SFX_RATE))
	_sfx["stomp"] = _make_player(_wav(_tone(220.0, 460.0, 0.12, 0.45), SFX_RATE))
	_sfx["win"] = _make_player(_wav(_arp([523.0, 659.0, 784.0, 1047.0], 0.16, 0.35), SFX_RATE))

	GameState.paused_changed.connect(_on_paused)
	GameState.settings_changed.connect(apply_volumes)
	apply_volumes()
	_music.play()


func play(sfx_name: String) -> void:
	var p: AudioStreamPlayer = _sfx.get(sfx_name)
	if p != null:
		p.play()


func apply_volumes() -> void:
	_music.volume_db = linear_to_db(maxf(float(GameState.settings["music_volume"]) * 0.5, 0.0001))
	var sv := linear_to_db(maxf(float(GameState.settings["sfx_volume"]), 0.0001))
	for p in _sfx.values():
		p.volume_db = sv


func _on_paused(is_paused: bool) -> void:
	_music.stream_paused = is_paused
	for p in _sfx.values():
		p.stream_paused = is_paused


func _make_player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p


func _wav(samples: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


func _tone(f0: float, f1: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(f0, f1, t)
		phase += TAU * f / SFX_RATE
		var env := minf(t / 0.05, 1.0) * pow(1.0 - t, 1.5)
		out[i] = sin(phase) * env * vol
	return out


func _arp(freqs: Array, note_len: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		out.append_array(_tone(f, f, note_len, vol))
	return out


func _make_music() -> AudioStreamWAV:
	# Calm 4-chord arpeggio loop (Am - F - C - G), 4 seconds.
	var chords := [
		[220.0, 261.63, 329.63],
		[174.61, 220.0, 261.63],
		[261.63, 329.63, 392.0],
		[196.0, 246.94, 293.66],
	]
	var pattern := [0, 1, 2, 1]
	var note_len := 0.25
	var per_note := int(note_len * MUSIC_RATE)
	var out := PackedFloat32Array()
	out.resize(per_note * 16)
	var idx := 0
	for c in chords:
		for step in pattern:
			var f: float = c[step]
			for i in per_note:
				var t := float(i) / MUSIC_RATE
				var env := minf(t / 0.01, 1.0) * exp(-t * 6.0)
				var s := sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)
				out[idx * per_note + i] = s * env * 0.2
			idx += 1
	return _wav(out, MUSIC_RATE, true)
