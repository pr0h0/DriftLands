extends Node
## Sound effects (2D + positional pools), the wind loop, and a generative music sequencer
## that plays transposed instrument samples over slow chord progressions.

const SEMI := 1.0594630943592953

## mood -> root (semitones from C), scale, chord roots (scale degrees), bell chance, pluck chance, drone
const MOODS := {
	"menu": {"root": 2, "scale": [0, 2, 4, 7, 9], "chords": [0, 3, 4, 2], "bell": 0.25, "pluck": 0.0, "drone": false, "bar": 8.0},
	"dawn": {"root": 2, "scale": [0, 2, 4, 6, 7, 9, 11], "chords": [0, 4, 5, 3], "bell": 0.3, "pluck": 0.1, "drone": false, "bar": 8.0},
	"bright": {"root": 7, "scale": [0, 2, 4, 7, 9], "chords": [0, 3, 1, 4], "bell": 0.2, "pluck": 0.35, "drone": false, "bar": 6.0},
	"night": {"root": 9, "scale": [0, 2, 3, 5, 7, 9, 10], "chords": [0, 5, 3, 4], "bell": 0.18, "pluck": 0.05, "drone": false, "bar": 9.0},
	"storm": {"root": 4, "scale": [0, 2, 3, 5, 7, 8, 10], "chords": [0, 5, 6, 4], "bell": 0.08, "pluck": 0.0, "drone": true, "bar": 8.0},
	"frost": {"root": 4, "scale": [0, 2, 4, 6, 7, 9, 11], "chords": [0, 3, 5, 4], "bell": 0.32, "pluck": 0.0, "drone": false, "bar": 10.0},
	"desert": {"root": 2, "scale": [0, 1, 4, 5, 7, 8, 10], "chords": [0, 3, 5, 0], "bell": 0.12, "pluck": 0.4, "drone": true, "bar": 7.0},
	"glass": {"root": 6, "scale": [0, 2, 4, 6, 8, 10], "chords": [0, 2, 4, 1], "bell": 0.4, "pluck": 0.15, "drone": false, "bar": 9.0},
	"triumph": {"root": 2, "scale": [0, 2, 4, 7, 9], "chords": [0, 4, 3, 4], "bell": 0.5, "pluck": 0.3, "drone": false, "bar": 5.0},
}

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _music: Array[AudioStreamPlayer] = []
var _wind: AudioStreamPlayer
var _pi := 0
var _p3i := 0
var _mi := 0

var _mood := {}
var _mood_name := ""
var _bar_t := 0.0
var _beat_t := 0.0
var _chord_i := 0
var _chord_notes: Array = []
var _music_gain := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in 12:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 8.0
		p.max_distance = 90.0
		add_child(p)
		_pool3d.append(p)
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_music.append(p)
	_wind = AudioStreamPlayer.new()
	_wind.bus = "SFX"
	_wind.stream = _looped("wind_loop")
	_wind.volume_db = -40.0
	add_child(_wind)


func stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		_streams[sound] = load("res://assets/audio/%s.wav" % sound)
	return _streams[sound]


func looped(sound: String) -> AudioStream:
	return _looped(sound)


func _looped(sound: String) -> AudioStream:
	var s := (stream(sound) as AudioStreamWAV).duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	return s


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p := _pool[_pi]
	_pi = (_pi + 1) % _pool.size()
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var p := _pool3d[_p3i]
	_p3i = (_p3i + 1) % _pool3d.size()
	p.stream = stream(sound)
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_step(stone: bool) -> void:
	play("%s_%d" % ["step_stone" if stone else "step_grass", randi() % 3], -6.0, randf_range(0.9, 1.1))


## 0..1 intensity from player speed/height. 0 silences it.
func set_wind(amount: float) -> void:
	if amount <= 0.001:
		if _wind.playing:
			_wind.volume_db = move_toward(_wind.volume_db, -50.0, 2.0)
			if _wind.volume_db <= -49.0:
				_wind.stop()
		return
	if not _wind.playing:
		_wind.play()
	_wind.volume_db = lerp(_wind.volume_db, linear_to_db(clamp(amount, 0.02, 1.0)) - 4.0, 0.1)
	_wind.pitch_scale = lerp(_wind.pitch_scale, 0.8 + amount * 0.5, 0.1)


# ------------------------------------------------------------ music

func music(mood: String) -> void:
	if mood == _mood_name:
		return
	_mood_name = mood
	_mood = MOODS.get(mood, {})
	_bar_t = 0.0
	_chord_i = 0


func stop_music() -> void:
	_mood_name = ""
	_mood = {}
	for p in _music:
		create_tween().tween_property(p, "volume_db", -60.0, 2.0)


## Quieter, sparser music (night time).
func set_music_gain(g: float) -> void:
	_music_gain = g


func _note(sample: String, semis: int, vol: float, root_octave_shift := 0) -> void:
	var p := _music[_mi]
	_mi = (_mi + 1) % _music.size()
	p.stream = stream(sample)
	p.pitch_scale = pow(SEMI, semis + root_octave_shift * 12)
	p.volume_db = linear_to_db(max(vol * _music_gain, 0.0001))
	p.play()


func _process(dt: float) -> void:
	if _mood.is_empty():
		return
	_bar_t -= dt
	_beat_t -= dt
	var scale: Array = _mood["scale"]
	var root: int = _mood["root"]
	if _bar_t <= 0.0:
		_bar_t = _mood["bar"]
		var chords: Array = _mood["chords"]
		var degree: int = chords[_chord_i % chords.size()]
		_chord_i += 1
		_chord_notes = []
		for k in [0, 2, 4]:
			var idx: int = degree + k
			_chord_notes.append(root + int(scale[idx % scale.size()]) + 12 * (idx / scale.size()))
		for n in _chord_notes:
			_note("mus_pad_c3", n - (12 if n > 9 else 0), 0.32)
		if _mood["drone"]:
			_note("mus_drone_c2", root, 0.5)
	if _beat_t <= 0.0:
		_beat_t = _mood["bar"] / 8.0
		if randf() < _mood["bell"]:
			var s: int = scale[randi() % scale.size()]
			_note("mus_bell_c5", root + s - (12 if root + s > 7 else 0), 0.22)
		if randf() < _mood["pluck"] and not _chord_notes.is_empty():
			_note("mus_pluck_c4", int(_chord_notes[randi() % _chord_notes.size()]), 0.25)
