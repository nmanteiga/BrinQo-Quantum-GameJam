extends Area2D
class_name Carta

enum Tipo { NORMAL, QUANTUM }
enum Efecto { NINGUNO, ENTRELAZADO, SUPERPOSICION, AROUND_WORLD, COUNTER, REVELATION }

@export var textura_especial : Texture2D
@onready var shadow: TextureRect = $Shadow
@onready var animated_quantum: TextureRect = $AnimatedQuantum

var tipo_carta : int = Tipo.NORMAL
var efecto_especial : int = Efecto.NINGUNO

@export var suit : int = 0
@export var value : int = 0
@export var face_up : bool = false 
var controlled_by_player : int = 0 
var slot_index : int = 0

# cuántica
var entrelazada_con : Node2D = null 
var opciones_superposicion : Array = [] 
var es_superposicion : bool = false

@onready var sprite = $TextureRect
signal hovered
signal hovered_off
#Audio
@onready var flip1: AudioStreamPlayer2D = $"AudioStream(Flip1)"
@onready var flip2: AudioStreamPlayer2D = $"AudioStream(Flip2)"

@export var card_scale : float = 0.25
@export var tilt_strength : float = 20.0 
@export var max_offset_shadow: float = 150.0
var base_scale : Vector2
var is_mouse_hovering : bool = false

func _ready():
	base_scale = Vector2(card_scale, card_scale)
	scale = base_scale
	face_up = false 
	
	if sprite and sprite.material:
		sprite.material = sprite.material.duplicate()
	
	if animated_quantum and animated_quantum.material:
		animated_quantum.material = animated_quantum.material.duplicate()
	
	if shadow and shadow.material:
		shadow.material = shadow.material.duplicate()
	
	if get_parent().has_method("connect_card_signals"):
		get_parent().connect_card_signals(self)
	
	if shadow: shadow.visible = false
	if animated_quantum: animated_quantum.visible = false
	
	update_visuals()
	call_deferred("adjust_collision_shape")

func _process(delta):
	if is_mouse_hovering and sprite and sprite.material:
		var mouse_pos = get_local_mouse_position()
		var norm_x = clamp(mouse_pos.x / 380.0, -1.0, 1.0) 
		var norm_y = clamp(mouse_pos.y / 536.0, -1.0, 1.0) 
		var target_y_rot = norm_x * tilt_strength
		var target_x_rot = -norm_y * tilt_strength  
		var current_y = sprite.material.get_shader_parameter("y_rot")
		var current_x = sprite.material.get_shader_parameter("x_rot")
		
		sprite.material.set_shader_parameter("y_rot", lerp(current_y, target_y_rot, delta * 10.0))
		sprite.material.set_shader_parameter("x_rot", lerp(current_x, target_x_rot, delta * 10.0))
	
	handle_shadow(delta)

func adjust_collision_shape():
	var collision = $CollisionShape2D
	var fixed_width = 760.0
	var fixed_height = 1072.0
	
	if collision.shape is RectangleShape2D:
		collision.shape.size = Vector2(fixed_width, fixed_height)
	else:
		var rect = RectangleShape2D.new()
		rect.size = Vector2(fixed_width, fixed_height)
		collision.shape = rect

func setup_card(p_id: int, p_is_player: int):
	tipo_carta = Tipo.NORMAL
	suit = int(p_id / 13)
	value = int(p_id % 13)
	controlled_by_player = p_is_player
	face_up = false
	update_visuals()

func setup_quantum(p_efecto: int, p_is_player: int):
	tipo_carta = Tipo.QUANTUM
	efecto_especial = p_efecto
	controlled_by_player = p_is_player
	face_up = (p_is_player == 1) 
	
	load_quantum_animation()
	update_visuals()

func get_suit_name(suit_id: int) -> String:
	match suit_id:
		0: return "heart"
		1: return "diamond"
		2: return "clover"
		3: return "spades"
		_: return "heart"

func get_card_texture_path() -> String:
	if not face_up:
		return "res://assets/cards/back/back_v10.png"
	
	var suit_name = get_suit_name(suit)
	var card_number = value + 1 
	return "res://assets/cards/%s/%s_%02d_v01.png" % [suit_name, suit_name, card_number]

func get_quantum_base_texture() -> Texture2D:
	var texture_path: String = ""
	
	if not face_up:
		return load("res://assets/cards/back/back_v10.png")
	
	match efecto_especial:
		Efecto.ENTRELAZADO:
			texture_path = "res://assets/cards/entanglement/entanglement01_v03.png"
		Efecto.SUPERPOSICION:
			texture_path = "res://assets/cards/superposition/super01_v02.png"
		Efecto.AROUND_WORLD:
			texture_path = "res://assets/cards/around/around_v02.png"
		Efecto.COUNTER:
			texture_path = "res://assets/cards/not/not01_v02.png"
		Efecto.REVELATION:
			texture_path = "res://assets/cards/revelation/revelation_v04.png"
		_:
			return textura_especial if textura_especial else load("res://assets/cards/mazo_especial.png")
	
	if texture_path != "":
		var texture = load(texture_path)
		if texture: return texture
	
	return textura_especial if textura_especial else null

func update_visuals():
	if not sprite: return
	
	if tipo_carta == Tipo.NORMAL:
		if animated_quantum:
			animated_quantum.visible = false
		
		var texture_path = get_card_texture_path()
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
		else:
			print("Failed to load texture: ", texture_path)
	
	else:
		var quantum_texture = get_quantum_base_texture()
		if quantum_texture:
			sprite.texture = quantum_texture
		
		if animated_quantum:
			animated_quantum.visible = face_up
			animated_quantum.z_index = 1 # Relativo al padre

func load_quantum_animation():
	if not animated_quantum: return
	
	var anim_tex = AnimatedTexture.new()
	# CORRECCIÓN AQUÍ: Es one_shot, no oneshot
	anim_tex.pause = false 
	anim_tex.one_shot = false 
	
	var frames_list = []
	var speed = 4.0
	
	match efecto_especial:
		Efecto.ENTRELAZADO:
			for i in range(7):
				frames_list.append("res://assets/cards/entanglement/entanglement%02d_v03.png" % (i + 1))
		
		Efecto.SUPERPOSICION:
			for i in range(7):
				frames_list.append("res://assets/cards/superposition/super%02d_v02.png" % (i + 1))
		
		Efecto.AROUND_WORLD:
			speed = 1.0
			frames_list.append("res://assets/cards/around/around_v02.png")
		
		Efecto.COUNTER:
			var not_frames = [
				"res://assets/cards/not/not01_v02.png", "res://assets/cards/not/not02_v02.png",
				"res://assets/cards/not/not03_v02.png", "res://assets/cards/not/not04_v02.png",
				"res://assets/cards/not/not05_v02.png"
			]
			frames_list = not_frames
		
		Efecto.REVELATION:
			speed = 3.0
			frames_list = ["res://assets/cards/revelation/revelation_v04.png", "res://assets/cards/revelation/revelation_v05.png"]
		
		_: return

	if frames_list.is_empty(): return

	anim_tex.frames = frames_list.size()
	anim_tex.speed_scale = speed
	
	for i in range(frames_list.size()):
		var tex = load(frames_list[i])
		if tex:
			anim_tex.set_frame_texture(i, tex)
			anim_tex.set_frame_duration(i, 1.0)
	
	animated_quantum.texture = anim_tex

func flip_card():
	if not sprite or not sprite.material:
		return
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	flip1.pitch_scale = randf_range(0.8, 1.2)
	flip1.play()
	
	tween.tween_method(
		func(angle): sprite.material.set_shader_parameter("y_rot", angle),
		0.0,
		90.0,
		0.15
	)
	
	tween.tween_callback(func():
		face_up = !face_up
		update_visuals()
		if sprite: sprite.queue_redraw()
	)
	
	tween.tween_interval(0.01)
	
	tween.tween_method(
		func(angle): sprite.material.set_shader_parameter("y_rot", angle),
		-90.0,
		0.0,
		0.15
	)

func aplicar_efecto_visual_cuantico(color: Color):
	if sprite: 
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", color, 0.3)
	
	if animated_quantum and animated_quantum.visible:
		var tween2 = create_tween()
		tween2.tween_property(animated_quantum, "modulate", color, 0.3)

func show_entanglement_highlight():
	if sprite:
		var tween = create_tween()
		tween.set_parallel(false)
		tween.tween_property(sprite, "self_modulate", Color(2, 2, 2, 1), 0.2)
		tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.2)
		tween.tween_property(sprite, "self_modulate", Color.CYAN, 0.2)
		tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.2)

# eventos de ratón
func _on_input_event(viewport, event, shape_idx): pass 

func _on_mouse_entered() -> void:
	is_mouse_hovering = true
	emit_signal("hovered", self)

func _on_mouse_exited() -> void:
	is_mouse_hovering = false
	if sprite and sprite.material:
		create_tween().tween_method(reset_rotation, 1.0, 0.0, 0.2)
	emit_signal("hovered_off", self)

func reset_rotation(progress: float):
	if sprite and sprite.material:
		var current_y = sprite.material.get_shader_parameter("y_rot")
		var current_x = sprite.material.get_shader_parameter("x_rot")
		sprite.material.set_shader_parameter("y_rot", current_y * progress)
		sprite.material.set_shader_parameter("x_rot", current_x * progress)
		
func handle_shadow(delta: float) -> void:
	if not shadow or not shadow.visible: return
		
	var viewport = get_viewport()
	if not viewport: return
		
	var viewport_size = viewport.get_visible_rect().size
	var center_x = viewport_size.x / 1.6
	var distance: float = global_position.x - center_x
	var weight = clamp(abs(distance / center_x), 0.0, 1.0)
	var target_offset = -sign(distance) * max_offset_shadow * weight
	var base_left = -381.0
	var base_right = 379.0
	var current_offset = (shadow.offset_left - base_left)
	var new_offset = lerp(current_offset, target_offset, delta * 10.0)
	
	shadow.offset_left = base_left + new_offset
	shadow.offset_right = base_right + new_offset

func show_shadow():
	if shadow: shadow.visible = true

func hide_shadow():
	if shadow: shadow.visible = false
