extends Area2D
class_name Carta

enum Tipo { NORMAL, QUANTUM }
enum Efecto { NINGUNO, ENTRELAZADO, SUPERPOSICION, AROUND_WORLD, COUNTER }

@export var textura_poker : Texture2D
@export var textura_especial : Texture2D

var tipo_carta : int = Tipo.NORMAL
var efecto_especial : int = Efecto.NINGUNO

@export var suit : int = 0
@export var value : int = 0
@export var face_up : bool = false
var controlled_by_player : int = 0 #0 no es de ningun jugador, 1 primer jugador, 2 segundo jugador
var slot_index : int = 0 # Position index in hand

@onready var sprite = $Sprite2D

signal hovered
signal hovered_off

@export var card_scale : float = 0.2
var base_scale : Vector2

func _ready():
	base_scale = Vector2(card_scale, card_scale)
	scale = base_scale
	# Adjust collision to match sprite after scaling
	adjust_collision_shape()
	get_parent().connect_card_signals(self)
	update_visuals()

func adjust_collision_shape():
	var collision = $CollisionShape2D
	if collision and collision.shape is RectangleShape2D and sprite.texture:
		var card_width = sprite.texture.get_width() / sprite.hframes
		var card_height = sprite.texture.get_height() / sprite.vframes
		collision.shape.size = Vector2(card_width, card_height)

func setup_card(p_id: int, p_is_player: int):
	tipo_carta = Tipo.NORMAL
	suit = p_id / 13 + 1
	value = p_id % 13
	controlled_by_player = p_is_player
	if p_is_player == 2:
		face_up = 0
	else:
		face_up = 1
	update_visuals()

func setup_quantum(p_efecto: int, p_is_player: int):
	tipo_carta = Tipo.QUANTUM
	efecto_especial = p_efecto
	controlled_by_player = p_is_player
	face_up = p_is_player 
	update_visuals()

func update_visuals():
	if tipo_carta == Tipo.NORMAL:
		sprite.texture = textura_poker
		sprite.hframes = 13
		sprite.vframes = 5
		
		if face_up:
			sprite.frame = suit * 13 + value
		else:
			sprite.frame = 0
	
	else:
		sprite.texture = textura_especial
		sprite.hframes = 5
		sprite.vframes = 1
		
		if face_up:
			match efecto_especial:
				Efecto.ENTRELAZADO:
					sprite.frame = 0 
				Efecto.SUPERPOSICION:
					sprite.frame = 1 
				Efecto.AROUND_WORLD:
					sprite.frame = 2 
				Efecto.COUNTER:
					sprite.frame = 3 
		else:
			sprite.frame = 4 

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if controlled_by_player != 1: return
		#flip_card()


func flip_card():
	face_up = !face_up
	update_visuals()


func _on_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_mouse_exited() -> void:
	emit_signal("hovered_off", self)
