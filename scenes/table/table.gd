extends Node2D
@export var card_scene : PackedScene 

@onready var pos_jugador = $mano_p1
@onready var pos_rival = $mano_p2
@onready var mazo : Array[int]
var cartas_en_mano_jugador = 0
var cartas_en_mano_rival = 0

func _ready():
	await get_tree().process_frame
	randomize()
	crear_mazo()
	repartir_mano_inicial()
	
func crear_mazo():
	for palo in range(4):
		for valor in range(13):
				var id = palo * 13 + valor
				print(id)
				mazo.append(id)
	mazo.shuffle()

func repartir_mano_inicial():
	cartas_en_mano_jugador = 0
	cartas_en_mano_rival = 0
	for i in range(4):
		crear_carta_normal(pos_jugador, 1, i)
	for i in range(4):
		crear_carta_normal(pos_rival, 2, i)

func crear_carta_normal(marker: Marker2D, es_jugador: int, indice_posicion: int):
	if card_scene == null:
		return

	var nueva_carta = card_scene.instantiate()
	add_child(nueva_carta)
	
	nueva_carta.setup_card(mazo.pop_back(), es_jugador)
	colocar_carta(nueva_carta, marker, indice_posicion)
	if es_jugador: cartas_en_mano_jugador += 1
	else: cartas_en_mano_rival += 1

func robar_carta_cuantica(es_jugador: bool):
	if card_scene == null: return

	var nueva_carta = card_scene.instantiate()
	add_child(nueva_carta)
	
	var efectos_posibles = [1, 2, 3, 4]
	var efecto_elegido = efectos_posibles.pick_random()
	
	nueva_carta.setup_quantum(efecto_elegido, es_jugador)
	
	if es_jugador:
		colocar_carta(nueva_carta, pos_jugador, cartas_en_mano_jugador)
		cartas_en_mano_jugador += 1
	else:
		colocar_carta(nueva_carta, pos_rival, cartas_en_mano_rival)
		cartas_en_mano_rival += 1

func colocar_carta(carta, marker, indice):
	var separacion = Vector2(90 * indice, 0)
	carta.position = marker.position + separacion


func _on_mazo_especial_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		robar_carta_cuantica(true)


func _on_mazo_normal_input_event(viewport, event, shape_idx):
	pass # Replace with function body.
