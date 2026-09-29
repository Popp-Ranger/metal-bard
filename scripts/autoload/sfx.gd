extends Node
## Sons du jeu, synthétisés au démarrage (aucun fichier audio requis).
## Chaque son est généré échantillon par échantillon puis converti en AudioStreamWAV.
## Pour utiliser de vrais fichiers plus tard : remplacer l'entrée dans `_streams`
## par `load("res://audio/xxx.ogg")` — l'API `Sfx.play("id")` ne change pas.

const RATE := 22050
const NOTE_FREQS := [329.63, 392.0, 440.0, 493.88] # Mi, Sol, La, Si — gamme pentatonique de Mi

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _ambience: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_ambience = AudioStreamPlayer.new()
	add_child(_ambience)
	_build_all()


func play(id: String, volume_db: float = 0.0, pitch_jitter: float = 0.05) -> void:
	var stream: AudioStreamWAV = _streams.get(id)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_ambience(id: String, volume_db: float = -12.0) -> void:
	var stream: AudioStreamWAV = _streams.get(id)
	if stream == null:
		return
	_ambience.stream = stream
	_ambience.volume_db = volume_db
	_ambience.play()


## Musique de fond lue depuis un fichier (MP3 / OGG), jouée en boucle
## sur la même piste que les ambiances : elle s'arrête aux changements de scène.
func play_music(path: String, volume_db: float = -8.0) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Musique introuvable : %s" % path)
		return
	var mp3 := stream as AudioStreamMP3
	if mp3 != null:
		mp3.loop = true
	var ogg := stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
	_ambience.stream = stream
	_ambience.volume_db = volume_db
	_ambience.play()


func stop_ambience() -> void:
	_ambience.stop()


# --- Construction -----------------------------------------------------------

func _build_all() -> void:
	_streams["zap"] = _to_wav(_zap())
	_streams["boom"] = _to_wav(_boom())
	_streams["thud"] = _to_wav(_thud())
	_streams["swoosh"] = _to_wav(_swoosh())
	_streams["clack"] = _to_wav(_clack())
	_streams["bones"] = _to_wav(_bones())
	_streams["thunder"] = _to_wav(_thunder())
	_streams["croak"] = _to_wav(_croak())
	_streams["splash"] = _to_wav(_splash())
	_streams["hurt"] = _to_wav(_hurt())
	_streams["coin"] = _to_wav(_coin())
	_streams["potion"] = _to_wav(_potion())
	_streams["portal"] = _to_wav(_portal())
	_streams["dud"] = _to_wav(_dud())
	_streams["levelup"] = _to_wav(_arpeggio([329.63, 415.3, 493.88, 659.25], 0.11))
	_streams["solo_start"] = _to_wav(_arpeggio([164.81, 246.94, 329.63], 0.08))
	for i in NOTE_FREQS.size():
		var f: float = NOTE_FREQS[i]
		_streams["note_%d" % i] = _to_wav(_power_chord(f, 0.5))
	_streams["amb_dungeon"] = _to_wav(_amb_dungeon(), true)


func _to_wav(buf: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	return wav


func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(RATE * seconds))
	return b


static func _saw(phase: float) -> float:
	return 2.0 * fposmod(phase, 1.0) - 1.0


## Décharge électrique : bruit haute fréquence haché + bourdonnement 110 Hz.
func _zap() -> PackedFloat32Array:
	var b := _buffer(0.45)
	var lp := 0.0
	var gate := 1.0
	for i in b.size():
		var t := float(i) / RATE
		if i % 55 == 0:
			gate = 1.0 if randf() < 0.55 else 0.12
		var noise := randf_range(-1.0, 1.0)
		lp += 0.4 * (noise - lp)
		var crackle := (noise - lp) * gate
		var hum := signf(sin(TAU * 110.0 * t)) * 0.18 + sin(TAU * 1760.0 * t + sin(TAU * 37.0 * t) * 5.0) * 0.12
		var env := exp(-t * 6.5) * minf(1.0, t * 500.0)
		b[i] = (crackle * 0.95 + hum) * env
	return b


## Onde de choc : balayage grave 130 → 35 Hz + souffle.
func _boom() -> PackedFloat32Array:
	var b := _buffer(0.8)
	var phase := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := lerpf(130.0, 35.0, minf(1.0, t / 0.6))
		phase += f / RATE
		lp += 0.05 * (randf_range(-1.0, 1.0) - lp)
		var env := exp(-t * 4.5) * minf(1.0, t * 300.0)
		b[i] = tanh((sin(TAU * phase) * 1.6 + lp * 2.5) * env * 1.5) * 0.9
	return b


## Coup de luth : choc sourd + corde qui vibre.
func _thud() -> PackedFloat32Array:
	var b := _buffer(0.35)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += 0.15 * (randf_range(-1.0, 1.0) - lp)
		var knock := (sin(TAU * 85.0 * t) + lp * 1.5) * exp(-t * 30.0)
		var twang := tanh(_saw(110.0 * t) * 3.0) * 0.35 * exp(-t * 9.0)
		b[i] = (knock + twang) * 0.9
	return b


func _swoosh() -> PackedFloat32Array:
	var b := _buffer(0.22)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += lerpf(0.02, 0.3, t / 0.22) * (randf_range(-1.0, 1.0) - lp)
		b[i] = lp * sin(PI * t / 0.22) * 1.2
	return b


## Os qui s'entrechoquent.
func _clack() -> PackedFloat32Array:
	var b := _buffer(0.18)
	for i in b.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		var tone := sin(TAU * 1250.0 * t) * 0.5 + sin(TAU * 2430.0 * t) * 0.3
		b[i] = (n * 0.5 + tone) * exp(-t * 45.0)
	return b


## Squelette qui s'effondre : cascade de claquements.
func _bones() -> PackedFloat32Array:
	var b := _buffer(0.9)
	var clicks := []
	for k in 14:
		clicks.append(randf_range(0.0, 0.75))
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for c: float in clicks:
			var dt := t - c
			if dt >= 0.0 and dt < 0.06:
				s += sin(TAU * (900.0 + c * 900.0) * dt) * exp(-dt * 90.0)
		b[i] = s * 0.5
	return b


## Tonnerre : craquement sec puis grondement filtré.
func _thunder() -> PackedFloat32Array:
	var b := _buffer(1.6)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		lp += 0.08 * (n - lp)
		lp2 += 0.02 * (lp - lp2)
		var crack := n * exp(-t * 25.0)
		var rumble := lp2 * 6.0 * exp(-t * 1.8) * (0.7 + 0.3 * sin(TAU * 3.0 * t))
		b[i] = tanh(crack * 0.8 + rumble)
	return b


## Coassement de Gloubah : impulsions à 28 Hz modulant un son grave.
func _croak() -> PackedFloat32Array:
	var b := _buffer(0.7)
	for i in b.size():
		var t := float(i) / RATE
		var pulse := maxf(0.0, sin(TAU * 28.0 * t)) ** 3.0
		var body := _saw(95.0 * t) * 0.6 + sin(TAU * 190.0 * t) * 0.4
		var env := sin(PI * minf(1.0, t / 0.7))
		b[i] = tanh(body * pulse * 2.0) * env * 0.9
	return b


## Vague déferlante.
func _splash() -> PackedFloat32Array:
	var b := _buffer(1.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += 0.12 * (randf_range(-1.0, 1.0) - lp)
		var env := minf(1.0, t * 6.0) * exp(-t * 2.5)
		b[i] = lp * 2.2 * env
	return b


func _hurt() -> PackedFloat32Array:
	var b := _buffer(0.25)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += 0.2 * (randf_range(-1.0, 1.0) - lp)
		b[i] = (lp + sin(TAU * lerpf(220.0, 110.0, t / 0.25) * t) * 0.6) * exp(-t * 12.0)
	return b


func _coin() -> PackedFloat32Array:
	var b := _buffer(0.3)
	for i in b.size():
		var t := float(i) / RATE
		var f := 1318.5 if t < 0.07 else 1760.0
		b[i] = sin(TAU * f * t) * 0.45 * exp(-maxf(0.0, t - 0.07) * 14.0)
	return b


func _potion() -> PackedFloat32Array:
	var b := _buffer(0.5)
	for i in b.size():
		var t := float(i) / RATE
		var glug := sin(TAU * (300.0 + 200.0 * fposmod(t * 7.0, 1.0)) * t)
		b[i] = glug * 0.4 * (1.0 - t / 0.5)
	return b


func _portal() -> PackedFloat32Array:
	var b := _buffer(1.4)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		phase += lerpf(80.0, 520.0, t / 1.4) / RATE
		var shimmer := sin(TAU * phase) * 0.4 + sin(TAU * phase * 1.5 + sin(t * 30.0)) * 0.25
		b[i] = shimmer * sin(PI * t / 1.4)
	return b


## Fausse note : triton désaccordé (le « diabolus in musica »).
func _dud() -> PackedFloat32Array:
	var b := _buffer(0.4)
	for i in b.size():
		var t := float(i) / RATE
		var x := _saw(146.8 * t) + _saw(207.6 * t) * 0.8
		b[i] = tanh(x * 3.0) * 0.4 * exp(-t * 7.0)
	return b


## Power chord distordu (fondamentale + quinte + octave).
func _power_chord(freq: float, seconds: float) -> PackedFloat32Array:
	var b := _buffer(seconds)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var x := _saw(freq * t) + _saw(freq * 1.498 * t) * 0.8 + _saw(freq * 2.003 * t) * 0.5
		var y := tanh(x * 5.0)
		lp += 0.35 * (y - lp)
		var env := minf(1.0, t * 200.0) * exp(-t * 2.2)
		b[i] = lp * env * 0.55
	return b


func _arpeggio(freqs: Array, step: float) -> PackedFloat32Array:
	var b := _buffer(step * freqs.size() + 0.5)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for k in freqs.size():
			var start := k * step
			if t >= start:
				var dt := t - start
				var f: float = freqs[k]
				s += tanh((_saw(f * dt) + _saw(f * 1.5 * dt) * 0.7) * 4.0) * exp(-dt * 3.0)
		b[i] = s * 0.3
	return b


## Ambiance du donjon : bourdon grave + souffle + gouttes d'eau (boucle de 6 s).
func _amb_dungeon() -> PackedFloat32Array:
	var b := _buffer(6.0)
	var lp := 0.0
	var drips := []
	for k in 7:
		drips.append(randf_range(0.2, 5.6))
	for i in b.size():
		var t := float(i) / RATE
		lp += 0.004 * (randf_range(-1.0, 1.0) - lp)
		var drone := sin(TAU * 55.0 * t) * 0.25 + sin(TAU * 82.5 * t) * 0.12 * (0.5 + 0.5 * sin(TAU * t / 6.0))
		var drip := 0.0
		for d: float in drips:
			var dt := t - d
			if dt >= 0.0 and dt < 0.15:
				drip += sin(TAU * lerpf(1800.0, 900.0, dt / 0.15) * dt) * exp(-dt * 40.0) * 0.35
		b[i] = drone + lp * 6.0 + drip
	return b
