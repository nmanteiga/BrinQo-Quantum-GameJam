extends Area2D

enum Tipo { NORMAL, QUANTUM }
enum Efecto { NINGUNO, ENTRELAZADO, SUPERPOSICION, AROUND_WORLD, COUNTER }

@export var textura_poker : Texture2D
@export var textura_especial : Texture2D

var tipo_carta : int = Tipo.NORMAL
var efecto_especial : int = Efecto.NINGUNO

@export var suit : int = 0
@export var value : int = 0
@export var face_up : bool = false
var controlled_by_player : bool = true 

@onready var sprite = $Sprite2D

func _ready():
	update_visuals()

func setup_card(p_suit: int, p_value: int, p_is_player: bool):
	tipo_carta = Tipo.NORMAL
	suit = p_suit
	value = p_value
	controlled_by_player = p_is_player
	face_up = p_is_player 
	update_visuals()

func setup_quantum(p_efecto: int, p_is_player: bool):
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
		if not controlled_by_player: return
		flip_card()

func flip_card():
	face_up = !face_up
	update_visuals()
