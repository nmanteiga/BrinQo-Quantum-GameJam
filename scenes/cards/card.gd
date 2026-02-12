extends Area2D
class_name Carta

enum Tipo { NORMAL, QUANTUM }
enum Efecto { NINGUNO, ENTRELAZADO, SUPERPOSICION, AROUND_WORLD, COUNTER, REVELATION }

@export var textura_especial : Texture2D
@onready var shadow: TextureRect = $Shadow

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
@export var tilt_strength : float = 15.0  # Maximum rotation angle in degrees
@export var max_offset_shadow: float = 150.0
var base_scale : Vector2
var is_mouse_hovering : bool = false

func _ready():
	base_scale = Vector2(card_scale, card_scale)
	scale = base_scale
	face_up = false 
	
	if sprite and sprite.material:
		sprite.material = sprite.material.duplicate()
	
	if get_parent().has_method("connect_card_signals"):
		get_parent().connect_card_signals(self)
	
	if shadow:
		shadow.visible = false
	
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
		return "res://assets/cards/back/back_v01.png"
	
	var suit_name = get_suit_name(suit)
	var card_number = value + 1 
	return "res://assets/cards/%s/%s_%02d_v01.png" % [suit_name, suit_name, card_number]

func update_visuals():
	if not sprite: return
	
	if tipo_carta == Tipo.NORMAL:
		var texture_path = get_card_texture_path()
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
		else:
			print("Failed to load texture: ", texture_path)
	
	else:
		if textura_especial:
			sprite.texture = textura_especial

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
		if sprite:
			sprite.queue_redraw()
	)
	
	tween.tween_interval(0.01)
	tween.tween_method(
		func(angle): sprite.material.set_shader_parameter("y_rot", angle),
		-90.0,
		0.0,
		0.15
	)
func aplicar_efecto_visual_cuantico(color: Color):
	if sprite: sprite.modulate = color

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
	if not shadow or not shadow.visible:
		return
		
	var viewport = get_viewport()
	if not viewport:
		return
		
	var viewport_size = viewport.get_visible_rect().size
	var center_x = viewport_size.x / 2.0
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
