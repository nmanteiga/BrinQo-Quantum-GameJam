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
var controlled_by_player : int = 0 
var slot_index : int = 0

# cuántica
var entrelazada_con : Node2D = null 
var opciones_superposicion : Array = [] 
var es_superposicion : bool = false

@onready var sprite = $Sprite2D
signal hovered
signal hovered_off

@export var card_scale : float = 0.2
var base_scale : Vector2

func _ready():
	base_scale = Vector2(card_scale, card_scale)
	scale = base_scale
	face_up = false 
	
	if get_parent().has_method("connect_card_signals"):
		get_parent().connect_card_signals(self)
	
	update_visuals()
	call_deferred("adjust_collision_shape")

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

func update_visuals():
	if not sprite: return
	
	if tipo_carta == Tipo.NORMAL:
		if textura_poker:
			sprite.texture = textura_poker
			sprite.hframes = 13
			sprite.vframes = 5
			
			if face_up:
				var fila_offset = (suit + 1) * 13
				sprite.frame = fila_offset + value
			else:
				sprite.frame = 0
	
	else:
		if textura_especial:
			sprite.texture = textura_especial
			sprite.hframes = 5
			sprite.vframes = 1
			
			if face_up:
				match efecto_especial:
					Efecto.ENTRELAZADO: sprite.frame = 0 
					Efecto.SUPERPOSICION: sprite.frame = 1 
					Efecto.AROUND_WORLD: sprite.frame = 2 
					4: sprite.frame = 3 # NOT
					_: sprite.frame = 0
			else:
				sprite.frame = 4

func aplicar_efecto_visual_cuantico(color: Color):
	if sprite: sprite.modulate = color

# eventos de ratón
func _on_input_event(viewport, event, shape_idx): pass 
func _on_mouse_entered() -> void: emit_signal("hovered", self)
func _on_mouse_exited() -> void: emit_signal("hovered_off", self)
