extends Node
## Audio du jeu : musiques (fichiers MP3/OGG) + bruitages synthétisés au démarrage.
## Trois canaux (bus) réglables indépendamment dans le menu Options > Audio :
##   « Musique », « Sorts et effets », « Dialogues ».
## Les réglages sont sauvegardés dans user://settings.cfg.

const RATE := 22050
const NOTE_FREQS := [329.63, 392.0, 440.0, 493.88] # Mi, Sol, La, Si — gamme pentatonique de Mi
const SETTINGS_PATH := "user://settings.cfg"
## Intensité de référence des bruitages synthétisés (LUFS à 0 dB) : chacun y est ramené à sa
## création, nettement sous les enregistrements fournis (riff -5,5, onde de choc -9, tonnerre -8,4)
## pour que montée de niveau et sorts ne couvrent plus le reste.
const SYNTH_LUFS := -21.0

const BUS_MUSIC := "Musique"
const BUS_SFX := "Effets"
const BUS_DIALOGUE := "Dialogues"
## Canaux affichés dans le menu Options : [nom du bus, libellé].
const CHANNELS := [
	[BUS_MUSIC, "Musique"],
	[BUS_SFX, "Sorts et effets"],
	[BUS_DIALOGUE, "Dialogues"],
]

## Émis à chaque coup de tonnerre de la musique d'orage (menu, intro) : force 0..1.
signal music_strike(force: float)

const THUNDER_FILES := ["res://audio/sfx/short_lightning.mp3", "res://audio/sfx/short_thunder.mp3"]
const RIFF_FILE := "res://audio/sfx/riff_electrique.wav"
const WAVE_FILE := "res://audio/sfx/ondes_de_chocs.wav"
const SOLO_FOUDRE_FILE := "res://audio/sfx/solo_de_la_foudre.mp3"
## Éclairs du Solo de la Foudre : toujours le même tonnerre court.
const SOLO_THUNDER_FILE := "res://audio/sfx/short_thunder.mp3"
const STORM_MUSIC := "res://audio/music/lightning_menu.mp3"
const STORM_DATA := "res://data/storm_strikes.json"

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _ambience: AudioStreamPlayer
var _voice: AudioStreamPlayer
## Musique à 40 % par défaut (50 % de moins que les autres canaux).
var _volumes := {BUS_MUSIC: 0.4, BUS_SFX: 0.8, BUS_DIALOGUE: 0.8} # linéaire 0..1
## Extrait de musique joué par un sort (solo de la Ballade réparatrice).
var _clip: AudioStreamPlayer
var _thunders: Array[int] = []
var _strikes: Array[Vector2] = [] # (instant, force) des coups de tonnerre de la musique d'orage
var _last_music_pos := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_buses()
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = BUS_MUSIC
	add_child(_ambience)
	_voice = AudioStreamPlayer.new()
	_voice.bus = BUS_DIALOGUE
	add_child(_voice)
	_clip = AudioStreamPlayer.new()
	_clip.bus = BUS_SFX
	add_child(_clip)
	_clip.finished.connect(_on_clip_finished)
	_build_all()
	load_settings()


# --- Canaux et réglages ---------------------------------------------------------

func _create_buses() -> void:
	for bus_name: String in [BUS_MUSIC, BUS_SFX, BUS_DIALOGUE]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


## Volume d'un canal, de 0.0 (muet) à 1.0 (maximum).
func get_volume(bus_name: String) -> float:
	var v: float = _volumes.get(bus_name, 1.0)
	return v


func set_volume(bus_name: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_volumes[bus_name] = linear
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) # conserve les autres sections éventuelles
	for bus_name: String in _volumes:
		cfg.set_value("audio", bus_name, _volumes[bus_name])
	cfg.set_value("audio", "music_halved", true)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) # fichier absent au premier lancement : valeurs par défaut
	for bus_name: String in _volumes.keys():
		var v := float(cfg.get_value("audio", bus_name, _volumes[bus_name]))
		set_volume(bus_name, v)
	# Réglages d'une ancienne version : la musique est baissée de 50 % une fois.
	if cfg.has_section_key("audio", BUS_MUSIC) and not cfg.has_section_key("audio", "music_halved"):
		set_volume(BUS_MUSIC, get_volume(BUS_MUSIC) * 0.5)
		save_settings()


# --- Lecture ------------------------------------------------------------------------

func play(id: String, volume_db: float = 0.0, pitch_jitter: float = 0.05) -> void:
	# Tous les éclairs : un des deux enregistrements de tonnerre, tiré au hasard.
	if id == "thunder" and _thunders.size() > 0:
		id = "thunder_%d" % randi_range(0, _thunders.size() - 1)
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## « Voix » des personnages pendant les dialogues (petits babillements façon RPG),
## sur le canal Dialogues. `pitch` donne le timbre propre à chaque personnage.
func play_voice(pitch: float, volume_db: float = -10.0) -> void:
	_voice.stream = _streams.get("voice_%d" % randi_range(0, 3))
	_voice.volume_db = volume_db
	_voice.pitch_scale = pitch * randf_range(0.93, 1.07)
	_voice.play()


func play_ambience(id: String, volume_db: float = -12.0) -> void:
	var stream: AudioStreamWAV = _streams.get(id)
	if stream == null:
		return
	_ambience.stream = stream
	_ambience.volume_db = volume_db
	_ambience.play()


## Musique de fond lue depuis un fichier (MP3 / OGG), jouée en boucle
## sur le canal Musique : elle s'arrête aux changements de scène.
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
	_streams["zap"] = _fx(_zap())
	_streams["boom"] = _fx(_boom())
	_streams["thud"] = _fx(_thud())
	_streams["swoosh"] = _fx(_swoosh())
	_streams["clack"] = _fx(_clack())
	_streams["bones"] = _fx(_bones())
	_streams["thunder"] = _fx(_thunder()) # secours si les fichiers manquent
	for i in THUNDER_FILES.size():
		var t := load(str(THUNDER_FILES[i])) as AudioStream
		if t != null:
			_streams["thunder_%d" % i] = t
			_thunders.append(i)
	var riff := load(RIFF_FILE) as AudioStream
	if riff != null:
		_streams["riff"] = riff
	for pair: Array in [["wave", WAVE_FILE], ["solo_thunder", SOLO_THUNDER_FILE]]:
		var s := load(str(pair[1])) as AudioStream
		if s != null:
			_streams[str(pair[0])] = s
	_streams["croak"] = _fx(_croak())
	_streams["splash"] = _fx(_splash())
	_streams["hurt"] = _fx(_hurt())
	_streams["coin"] = _fx(_coin())
	_streams["potion"] = _fx(_potion())
	_streams["portal"] = _fx(_portal())
	_streams["dud"] = _fx(_dud())
	_streams["levelup"] = _fx(_arpeggio([329.63, 415.3, 493.88, 659.25], 0.11))
	_streams["solo_start"] = _fx(_arpeggio([164.81, 246.94, 329.63], 0.08))
	for i in NOTE_FREQS.size():
		var f: float = NOTE_FREQS[i]
		_streams["note_%d" % i] = _fx(_power_chord(f, 0.5))
	_streams["amb_dungeon"] = _to_wav(_amb_dungeon(), true)
	# Syllabes de « voix » (voyelles a, é, o, i) pour les dialogues.
	var vowels := [[730.0, 1090.0], [530.0, 1840.0], [570.0, 840.0], [300.0, 2200.0]]
	for i in vowels.size():
		var v: Array = vowels[i]
		_streams["voice_%d" % i] = _to_wav(_voice_blip(float(v[0]), float(v[1])))


## Bruitage synthétisé ramené à l'intensité de référence (voir SYNTH_LUFS).
func _fx(buf: PackedFloat32Array) -> AudioStreamWAV:
	var level := loudness(buf, RATE)
	var gain := db_to_linear(SYNTH_LUFS - level)
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	if peak > 0.0:
		gain = minf(gain, 0.98 / peak) # jamais de saturation si un son discret est remonté
	for i in buf.size():
		buf[i] *= gain
	return _to_wav(buf)


## Intensité perçue d'un son (LUFS, maximum « momentané » sur 400 ms) : pondération K de la
## norme ITU-R BS.1770 (plateau +4 dB dans les aigus, coupure des infragraves), la même mesure
## que celle qui harmonise les volumes à la radio et sur les plateformes de streaming.
static func loudness(buf: PackedFloat32Array, rate: int) -> float:
	var k := _biquad(buf, _k_shelf(rate))
	k = _biquad(k, _k_highpass(rate))
	# Son plus court que la fenêtre : moyenne sur toute sa durée.
	var win := mini(k.size(), int(rate * 0.4))
	var acc := 0.0
	var best := 0.0
	for i in k.size():
		acc += k[i] * k[i]
		if i >= win:
			acc -= k[i - win] * k[i - win]
		if i >= win - 1:
			best = maxf(best, acc / win)
	return -0.691 + 10.0 * log(maxf(best, 1e-12)) / log(10.0)


static func _k_shelf(rate: int) -> PackedFloat64Array:
	var k := tan(PI * 1681.974 / rate)
	var vh := pow(10.0, 3.99984 / 20.0)
	var vb := pow(vh, 0.4996668)
	var q := 0.7071752
	var a0 := 1.0 + k / q + k * k
	return PackedFloat64Array([(vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0,
		2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0])


static func _k_highpass(rate: int) -> PackedFloat64Array:
	var k := tan(PI * 38.13547 / rate)
	var q := 0.5003270
	var a0 := 1.0 + k / q + k * k
	return PackedFloat64Array([1.0, -2.0, 1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0])


## Filtre biquad : c = [b0, b1, b2, a1, a2].
static func _biquad(x: PackedFloat32Array, c: PackedFloat64Array) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var xi := x[i]
		var yi := c[0] * xi + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
		x2 = x1
		x1 = xi
		y2 = y1
		y1 = yi
		y[i] = yi
	return y


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


## Syllabe de voix : train d'impulsions (cordes vocales, 140 Hz) filtré par deux formants.
func _voice_blip(f1: float, f2: float) -> PackedFloat32Array:
	var b := _buffer(0.075)
	var y1 := 0.0
	var y1b := 0.0
	var y2 := 0.0
	var y2b := 0.0
	# Résonateurs du 2e ordre (formants).
	var r := 0.97
	var c1 := 2.0 * r * cos(TAU * f1 / RATE)
	var c2 := 2.0 * r * cos(TAU * f2 / RATE)
	for i in b.size():
		var t := float(i) / RATE
		var pulse := 1.0 if fposmod(t * 140.0, 1.0) < 0.08 else 0.0
		var o1 := pulse + c1 * y1 - r * r * y1b
		y1b = y1
		y1 = o1
		var o2 := pulse + c2 * y2 - r * r * y2b
		y2b = y2
		y2 = o2
		var env := sin(PI * t / 0.075)
		b[i] = tanh((o1 * 0.05 + o2 * 0.03) * env)
	return b


# --- Extraits musicaux (mini-jeu de la Ballade) ------------------------------------------

## Joue un passage d'un morceau à partir de `from_seconds` (sur le canal des sorts) et met
## la musique de fond en sourdine pendant ce temps.
func play_clip(path: String, from_seconds: float, volume_db: float = -4.0) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var mp3 := stream as AudioStreamMP3
	if mp3 != null:
		mp3 = mp3.duplicate() as AudioStreamMP3 # ne pas toucher au bouclage de la musique de fond
		mp3.loop = false
		stream = mp3
	_clip.stream = stream
	_clip.volume_db = volume_db
	_clip.play(maxf(0.0, from_seconds))
	_ambience.stream_paused = true


func stop_clip() -> void:
	if _clip.playing:
		var tw := create_tween()
		tw.tween_property(_clip, "volume_db", -40.0, 0.4)
		tw.tween_callback(_clip.stop)
	_ambience.stream_paused = false


func _on_clip_finished() -> void:
	_ambience.stream_paused = false


func clip_playing() -> bool:
	return _clip.playing


# --- Musique d'orage : éclairs calés sur les coups de tonnerre ----------------------------

## Musique d'orage (menu, intro) : ses coups de tonnerre déclenchent `music_strike`.
func play_storm_music(volume_db: float = -6.0) -> void:
	if _strikes.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORM_DATA)) if FileAccess.file_exists(STORM_DATA) else null
		if parsed is Dictionary:
			for s: Dictionary in (parsed as Dictionary).get("strikes", []):
				_strikes.append(Vector2(float(s["t"]), float(s["force"])))
	play_music(STORM_MUSIC, volume_db)
	_last_music_pos = 0.0


func storm_playing() -> bool:
	return _ambience.playing and _ambience.stream != null and _ambience.stream.resource_path == STORM_MUSIC


func _process(_delta: float) -> void:
	if not storm_playing():
		_last_music_pos = -1.0
		return
	var pos := _ambience.get_playback_position()
	if _last_music_pos >= 0.0:
		for s in _strikes:
			# Franchi depuis la dernière image (en tenant compte du retour au début de la boucle).
			var crossed := (s.x > _last_music_pos and s.x <= pos) if pos >= _last_music_pos else (s.x > _last_music_pos or s.x <= pos)
			if crossed:
				music_strike.emit(s.y)
	_last_music_pos = pos
