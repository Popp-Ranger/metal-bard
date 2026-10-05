class_name LegendCinematic
extends CanvasLayer
## Cinématique de la légende (chapitre 2) : sur fond noir, le visage de Back Jlack en gros plan, en contre-plongée,
## sur fond d'orage (nuages qui roulent, éclairs, tonnerre). L'Inconnue raconte la légende (DialogueDB.LEGEND_LINES)
## en bas de l'écran : clic, Espace ou E pour passer à la suite. Le jeu est en pause pendant la cinématique.
## À la dernière réplique (« ...tu vas la vivre ! ») : coup de tonnerre, éclair blanc, puis `finished`.

signal finished

## Visage du modèle généré (secours, sans le modèle 3D de Back Jlack).
const FACE := Vector3(0.0, 1.62, 0.0)

var lines: Array = DialogueDB.LEGEND_LINES
var speaker := ""
var _index := -1
var _vp: SubViewport
var _cam: Camera3D
## Back Jlack : son modèle 3D (art/pnj, « sage ») ou, à défaut, un modèle généré (HeroModel).
var _model: Node3D
var _skin: CharacterSkin
## Centre de son visage (que la caméra regarde).
var _face := FACE
var _sky: ShaderMaterial
var _storm: DirectionalLight3D
var _bolts: Node3D
var _text: Label
var _flash: ColorRect
var _type_tween: Tween
var _t := 0.0
var _next_bolt := 1.2
var _flash_k := 0.0
var _done := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	speaker = DialogueDB.npc_name("inconnue")
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	# Le visage du sage, rendu dans son propre monde 3D (orage, éclairs).
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_top = 60
	frame.offset_bottom = -170
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	frame.add_child(_vp)
	_build_world()
	# Bandeau de texte.
	var panel := PanelContainer.new()
	panel.theme = UiStyle.theme()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -160
	panel.offset_left = 160
	panel.offset_right = -160
	panel.offset_bottom = -24
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UiStyle.label(speaker, 22, DialogueDB.npc_color("inconnue")))
	_text = UiStyle.label("", 22, UiStyle.BONE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	var hint := UiStyle.label("Clic / Espace : continuer", 13, UiStyle.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	Sfx.play("solo_thunder", -6.0)
	_next_line()


func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.45)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	we.environment = env
	_vp.add_child(we)
	_skin = CharacterSkin.create("sage")
	if _skin != null:
		_model = _skin
		_vp.add_child(_skin)
		_skin.step(0.016, false, 0.0)
		_face = _skin.face_point()
	else:
		var look := RaceDB.DEFAULT_APPEARANCE.duplicate()
		look.merge(Npc.COSTUMES["backjlack"], true)
		look["guitar"] = false
		var generated := HeroModel.new()
		generated.anim_style = "pnj_corps"
		generated.appearance = look
		_model = generated
		_vp.add_child(_model)
	# Contre-plongée : la caméra sous le menton regarde le visage, l'orage derrière.
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_vp.add_child(_cam)
	_cam.position = Vector3(0.12, _face.y - 0.57, 1.3)
	_cam.look_at(_face + Vector3(0, 0.08, 0))
	# Nuages d'orage : grand panneau accroché derrière, face à la caméra.
	var sky := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(46, 28)
	sky.mesh = quad
	sky.position = Vector3(0, 0, -16)
	_sky = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float flash = 0.0;
void fragment() {
	vec2 uv = UV * vec2(1.6, 1.0);
	float n = texture(noise_tex, uv * 0.7 + vec2(TIME * 0.02, TIME * 0.006)).r;
	float m = texture(noise_tex, uv * 1.5 - vec2(TIME * 0.035, 0.0)).r;
	float c = smoothstep(0.25, 0.85, n * 0.65 + m * 0.35);
	vec3 col = mix(vec3(0.01, 0.008, 0.02), vec3(0.11, 0.1, 0.16), c);
	col += flash * vec3(0.3, 0.33, 0.5) * (0.2 + c);
	ALBEDO = col;
}
"""
	_sky.shader = sh
	var tex := NoiseTexture2D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 5
	tex.noise = noise
	tex.seamless = true
	tex.width = 512
	tex.height = 512
	_sky.set_shader_parameter("noise_tex", tex)
	sky.material_override = _sky
	_cam.add_child(sky)
	_bolts = Node3D.new()
	_vp.add_child(_bolts)
	# Lueur rouge par en dessous (comme un brasier) et contre-jour bleuté.
	var under := OmniLight3D.new()
	under.light_color = Color(1.0, 0.5, 0.25)
	under.light_energy = 0.45
	under.omni_range = 3.0
	under.position = Vector3(0.2, 0.9, 0.7)
	_vp.add_child(under)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.5, 0.6, 1.0)
	rim.light_energy = 2.5
	rim.omni_range = 3.0
	rim.position = Vector3(-0.4, 2.1, -0.7)
	_vp.add_child(rim)
	var key := OmniLight3D.new()
	key.light_color = Color(0.85, 0.82, 0.8)
	key.light_energy = 0.9
	key.omni_range = 3.0
	key.position = Vector3(0.5, 2.0, 1.2)
	_vp.add_child(key)
	_storm = DirectionalLight3D.new()
	_storm.light_color = Color(0.75, 0.8, 1.0)
	_storm.light_energy = 0.0
	_storm.rotation_degrees = Vector3(-30, 160, 0)
	_vp.add_child(_storm)


func _process(delta: float) -> void:
	_t += delta
	# Lent travelling avant et léger souffle de la caméra.
	_cam.position = Vector3(0.12 + sin(_t * 0.3) * 0.03, _face.y - 0.57 + sin(_t * 0.5) * 0.01, maxf(0.85, 1.3 - _t * 0.015))
	_cam.look_at(_face + Vector3(0, 0.08, 0))
	if _skin != null:
		_skin.step(delta, false, 0.0) # il respire (clip de repos)
	_next_bolt -= delta
	if _next_bolt <= 0.0 and not _done:
		_next_bolt = randf_range(2.0, 4.5)
		_lightning(false)
	_flash_k = maxf(0.0, _flash_k - delta * 3.0)
	_sky.set_shader_parameter("flash", _flash_k)
	_storm.light_energy = _flash_k * 3.0


## Éclair dans le ciel derrière le sage (et coup de tonnerre).
func _lightning(big: bool) -> void:
	_flash_k = 1.0
	var x := randf_range(-6.0, 6.0)
	var top := _cam.global_transform * Vector3(x, 9.0, -14.0)
	var bottom := _cam.global_transform * Vector3(x + randf_range(-2.0, 2.0), -2.0, -14.0)
	ArcBolt.spawn(_bolts, top, bottom, 0.4 if big else 0.25, 0.35, Color(0.8, 0.85, 1.0))
	Sfx.play("solo_thunder", 0.0 if big else -8.0)


func _input(event: InputEvent) -> void:
	if _done:
		return
	var mb := event as InputEventMouseButton
	var pressed := (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) \
		or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _type_tween != null and _type_tween.is_running():
		_type_tween.kill()
		_text.visible_ratio = 1.0
		return
	_next_line()


func _next_line() -> void:
	_index += 1
	if _index >= lines.size():
		_finish()
		return
	_text.text = str(lines[_index])
	_text.visible_ratio = 0.0
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_ratio", 1.0, maxf(0.6, _text.text.length() * 0.03))
	if _index == lines.size() - 1:
		_lightning(true)


## Fin : grand éclair blanc, puis on passe dans l'autre univers.
func _finish() -> void:
	_done = true
	_lightning(true)
	Events.camera_shake.emit(0.4, 0.6)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 1.0, 0.25)
	tw.tween_interval(0.4)
	await tw.finished
	finished.emit()


## Cinématique de la légende jouée par-dessus le niveau `parent` ; le jeu est mis en pause.
static func play(parent: Node) -> LegendCinematic:
	var c := LegendCinematic.new()
	parent.add_child(c)
	parent.get_tree().paused = true
	return c
