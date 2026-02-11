extends Area2D
class_name Carta

enum Tipo { NORMAL, QUANTUM }
enum Efecto { NINGUNO, ENTRELAZADO, SUPERPOSICION, AROUND_WORLD, COUNTER }

@export var textura_especial : Texture2D

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
var base_scale : Vector2
var is_mouse_hovering : bool = false

func _ready():
	base_scale = Vector2(card_scale, card_scale)
	scale = base_scale
	face_up = false 
	
	# Duplicate material so each card has its own instance
	if sprite and sprite.material:
		sprite.material = sprite.material.duplicate()
	
	if get_parent().has_method("connect_card_signals"):
		get_parent().connect_card_signals(self)
	
	update_visuals()
	call_deferred("adjust_collision_shape")

func _process(delta):
	if is_mouse_hovering and sprite and sprite.material:
		var mouse_pos = get_local_mouse_position()
		# Normalize mouse position relative to card size
		# Card is 760x1072, centered at origin
		var norm_x = clamp(mouse_pos.x / 380.0, -1.0, 1.0)  # -1 to 1
		var norm_y = clamp(mouse_pos.y / 536.0, -1.0, 1.0)  # -1 to 1
		
		# Apply tilt: x position affects y_rot, y position affects x_rot
		var target_y_rot = norm_x * tilt_strength
		var target_x_rot = -norm_y * tilt_strength  
		
		# Smoothly interpolate to target rotation
		var current_y = sprite.material.get_shader_parameter("y_rot")
		var current_x = sprite.material.get_shader_parameter("x_rot")
		
		sprite.material.set_shader_parameter("y_rot", lerp(current_y, target_y_rot, delta * 10.0))
		sprite.material.set_shader_parameter("x_rot", lerp(current_x, target_x_rot, delta * 10.0))

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
	var card_number = value + 1  # 0-12 becomes 1-13
	return "res://assets/cards/%s/%s_%02d_v01.png" % [suit_name, suit_name, card_number]

func update_visuals():
	if not sprite: return
	
	if tipo_carta == Tipo.NORMAL:
		var texture_path = get_card_texture_path()
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
			print("Loaded texture: ", texture_path, " face_up: ", face_up)
		else:
			print("Failed to load texture: ", texture_path)
	
	else:
		if textura_especial:
			sprite.texture = textura_especial
			# For quantum cards, you might need to adjust this
			# if textura_especial is also a sprite sheet
			if face_up:
				match efecto_especial:
					Efecto.ENTRELAZADO: pass  # Load specific quantum card texture
					Efecto.SUPERPOSICION: pass
					Efecto.AROUND_WORLD: pass
					4: pass  # NOT
					_: pass
			else:
				# Load back of quantum card
				pass

func flip_card():
	if not sprite or not sprite.material:
		return
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Rotate to 90 degrees (edge-on, card is invisible)
	flip1.pitch_scale = randf_range(0.8, 1.2)
	flip1.play()
	tween.tween_method(
		func(angle): sprite.material.set_shader_parameter("y_rot", angle),
		0.0,
		90.0,
		0.15
	)
	
	# At 90 degrees, swap the texture
	tween.tween_callback(func():
		face_up = !face_up
		print("Flipping card, new face_up: ", face_up)
		update_visuals()
		# Force the texture to update
		if sprite:
			sprite.queue_redraw()
	)
	
	# Small pause at 90 degrees to ensure texture loads
	tween.tween_interval(0.01)
	# Rotate from -90 to 0 (coming from the other side)
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
	# Reset rotation smoothly
	if sprite and sprite.material:
		create_tween().tween_method(reset_rotation, 1.0, 0.0, 0.2)
	emit_signal("hovered_off", self)

func reset_rotation(progress: float):
	if sprite and sprite.material:
		var current_y = sprite.material.get_shader_parameter("y_rot")
		var current_x = sprite.material.get_shader_parameter("x_rot")
		sprite.material.set_shader_parameter("y_rot", current_y * progress)
		sprite.material.set_shader_parameter("x_rot", current_x * progress)
