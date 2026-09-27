extends AudioStreamPlayer

const RATE := 44100.0
const BPM := 150.0

var _play: AudioStreamGeneratorPlayback
var _pcm := PackedFloat32Array()
var _pos := 0
var _beat := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = int(RATE)
	gen.buffer_length = 0.2
	stream = gen
	volume_db = -10.0
	_beat = 60.0 / BPM
	_compose()
	play()
	_play = get_stream_playback() as AudioStreamGeneratorPlayback


func _compose() -> void:
	var bars := 8
	_pcm.resize(int(_beat * float(bars * 4) * RATE))
	var roots := [65.41, 87.31, 98.0, 65.41, 110.0, 87.31, 98.0, 65.41]
	for bar in bars:
		var root: float = roots[bar]
		var bounce := [root, root * 2.0, root * 1.5, root * 2.0, root, root * 2.0, root * 1.5, root * 2.0]
		for step in bounce.size():
			_tone(float(bar * 4) + float(step) * 0.5, 0.16, bounce[step], 0.28, false)
		_tone(float(bar * 4), 0.12, root * 4.0, 0.07, true)
		_tone(float(bar * 4), 0.12, root * 5.0, 0.05, true)
		_tone(float(bar * 4), 0.12, root * 6.0, 0.04, true)
	for beat in bars * 4:
		_kick(float(beat))
		if beat % 2 == 1:
			_snare(float(beat))
		_hat(float(beat), 0.07)
		_hat(float(beat) + 0.5, 0.035)
	var melody := [
		[0.0, 659.25, 0.18],
		[0.25, 783.99, 0.18],
		[0.5, 880.0, 0.18],
		[0.75, 783.99, 0.18],
		[1.0, 1046.5, 0.28],
		[1.5, 880.0, 0.16],
		[1.75, 783.99, 0.16],
		[2.0, 659.25, 0.28],
		[2.5, 783.99, 0.16],
		[2.75, 659.25, 0.16],
		[3.0, 587.33, 0.22],
		[3.5, 659.25, 0.28],
		[4.0, 523.25, 0.16],
		[4.25, 659.25, 0.16],
		[4.5, 783.99, 0.16],
		[4.75, 880.0, 0.16],
		[5.0, 1046.5, 0.3],
		[5.5, 1174.66, 0.16],
		[5.75, 1046.5, 0.16],
		[6.0, 880.0, 0.22],
		[6.5, 783.99, 0.16],
		[6.75, 659.25, 0.16],
		[7.0, 783.99, 0.4],
		[8.0, 880.0, 0.16],
		[8.25, 1046.5, 0.16],
		[8.5, 1174.66, 0.16],
		[8.75, 1046.5, 0.16],
		[9.0, 880.0, 0.28],
		[9.5, 783.99, 0.16],
		[9.75, 659.25, 0.16],
		[10.0, 783.99, 0.28],
		[10.5, 880.0, 0.16],
		[10.75, 783.99, 0.16],
		[11.0, 659.25, 0.22],
		[11.5, 587.33, 0.28],
		[12.0, 659.25, 0.16],
		[12.25, 783.99, 0.16],
		[12.5, 659.25, 0.16],
		[12.75, 587.33, 0.16],
		[13.0, 523.25, 0.28],
		[13.5, 659.25, 0.16],
		[13.75, 783.99, 0.16],
		[14.0, 880.0, 0.28],
		[14.5, 783.99, 0.16],
		[14.75, 659.25, 0.16],
		[15.0, 523.25, 0.45],
		[16.0, 783.99, 0.16],
		[16.25, 1046.5, 0.16],
		[16.5, 783.99, 0.16],
		[16.75, 659.25, 0.16],
		[17.0, 880.0, 0.28],
		[17.5, 1046.5, 0.16],
		[17.75, 1174.66, 0.16],
		[18.0, 1046.5, 0.28],
		[18.5, 880.0, 0.16],
		[18.75, 783.99, 0.16],
		[19.0, 659.25, 0.22],
		[19.5, 783.99, 0.28],
		[20.0, 880.0, 0.16],
		[20.25, 1046.5, 0.16],
		[20.5, 1174.66, 0.16],
		[20.75, 1318.5, 0.16],
		[21.0, 1174.66, 0.28],
		[21.5, 1046.5, 0.16],
		[21.75, 880.0, 0.16],
		[22.0, 783.99, 0.22],
		[22.5, 659.25, 0.16],
		[22.75, 783.99, 0.16],
		[23.0, 880.0, 0.4],
		[24.0, 659.25, 0.16],
		[24.25, 783.99, 0.16],
		[24.5, 880.0, 0.16],
		[24.75, 1046.5, 0.16],
		[25.0, 880.0, 0.28],
		[25.5, 783.99, 0.16],
		[25.75, 659.25, 0.16],
		[26.0, 587.33, 0.22],
		[26.5, 659.25, 0.16],
		[26.75, 783.99, 0.16],
		[27.0, 659.25, 0.28],
		[27.5, 523.25, 0.16],
		[27.75, 659.25, 0.16],
		[28.0, 783.99, 0.16],
		[28.25, 880.0, 0.16],
		[28.5, 1046.5, 0.16],
		[28.75, 1174.66, 0.16],
		[29.0, 1046.5, 0.28],
		[29.5, 880.0, 0.16],
		[29.75, 783.99, 0.16],
		[30.0, 659.25, 0.22],
		[30.5, 587.33, 0.16],
		[30.75, 659.25, 0.16],
		[31.0, 523.25, 0.7],
	]
	for n in melody:
		_tone(float(n[0]), float(n[2]), float(n[1]), 0.2, true)
	var peak := 0.001
	for sample in _pcm:
		peak = maxf(peak, absf(sample))
	var gain := 0.86 / peak
	for i in _pcm.size():
		_pcm[i] *= gain


func _tone(beat_pos: float, length: float, freq: float, gain: float, bright: bool) -> void:
	var start := int(beat_pos * _beat * RATE)
	var count := int(length * _beat * RATE)
	for n in count:
		var i := start + n
		if i < 0 or i >= _pcm.size():
			continue
		var u := float(n) / float(maxi(count, 1))
		var env := 1.0
		if u < 0.08:
			env = u / 0.08
		elif u > 0.55:
			env = (1.0 - u) / 0.45
		var phase := TAU * freq * float(n) / RATE
		var wave := sin(phase)
		if bright:
			wave += sin(phase * 2.0) * 0.28
		_pcm[i] += wave * env * gain


func _kick(beat_pos: float) -> void:
	var start := int(beat_pos * _beat * RATE)
	var count := int(0.11 * RATE)
	for n in count:
		var i := start + n
		if i < 0 or i >= _pcm.size():
			continue
		var u := float(n) / float(count)
		var freq := 160.0 - u * 100.0
		var env := pow(1.0 - u, 3.0)
		_pcm[i] += sin(TAU * freq * float(n) / RATE) * env * 0.55


func _snare(beat_pos: float) -> void:
	var start := int(beat_pos * _beat * RATE)
	var count := int(0.08 * RATE)
	for n in count:
		var i := start + n
		if i < 0 or i >= _pcm.size():
			continue
		var u := float(n) / float(count)
		var env := pow(1.0 - u, 4.0)
		var noise := _noise(i)
		var body := sin(TAU * 210.0 * float(n) / RATE)
		_pcm[i] += (noise * 0.55 + body * 0.35) * env * 0.34


func _hat(beat_pos: float, gain: float) -> void:
	var start := int(beat_pos * _beat * RATE)
	var count := int(0.03 * RATE)
	for n in count:
		var i := start + n
		if i < 0 or i >= _pcm.size():
			continue
		var u := float(n) / float(count)
		_pcm[i] += _noise(i + 17) * pow(1.0 - u, 6.0) * gain


func _noise(i: int) -> float:
	var x := sin(float(i) * 12.9898) * 43758.5453
	return (x - floor(x)) * 2.0 - 1.0


func _process(_delta: float) -> void:
	if _play == null or _pcm.is_empty():
		return
	var frames := _play.get_frames_available()
	var size := _pcm.size()
	for _i in frames:
		var sample := _pcm[_pos]
		_play.push_frame(Vector2(sample, sample))
		_pos += 1
		if _pos >= size:
			_pos = 0
