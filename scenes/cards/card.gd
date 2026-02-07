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

@onready var sprite = $Sprite2D

signal hovered
signal hovered_off

func _ready():
	get_parent().connect_card_signals(self)
	update_visuals()

func setup_card(p_id: int, p_is_player: int):
	tipo_carta = Tipo.NORMAL
	suit = p_id / 13
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
		sprite.hframes = 14
		sprite.vframes = 4
		
		if face_up:
			sprite.frame = (suit * 14) + value
		else:
			sprite.frame = 27 
	
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
		flip_card()


func flip_card():
	face_up = !face_up
	update_visuals()


func _on_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_mouse_exited() -> void:
	emit_signal("hovered_off", self)
