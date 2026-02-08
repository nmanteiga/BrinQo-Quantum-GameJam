extends Node2D
@export var card_scene : PackedScene 

@onready var pos_jugador = $mano_p1
@onready var pos_rival = $mano_p2
@onready var mazo : Array[int]
var cartas_en_mano_jugador = 0
var cartas_en_mano_rival = 0
var slots_jugador = {} # Dictionary to track which slots have cards
var slots_rival = {} # Dictionary to track which slots have cards
var carta_en_movimiento
var carta_hovered #variable para evitar que se resalten otras cartas mientras pasamos una agarrada por encima
var screen_size
var cartas_en_descartes1 = []
var cartas_en_descartes2 = []

func _ready():
	await get_tree().process_frame
	randomize() #crea la seed
	screen_size = get_viewport_rect().size
	crear_mazo()
	repartir_mano_inicial()
	
func _process(delta: float) -> void:
	if carta_en_movimiento:
		var mouse_pos = get_global_mouse_position()
		carta_en_movimiento.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x),clamp(mouse_pos.y, 0, screen_size.y))	
	
func crear_mazo():
	#52 cartas
	for palo in range(4):
		for valor in range(13):
				var id = palo * 13 + valor
				print(id)
				mazo.append(id)
	mazo.shuffle() #se randomiza el orden

func repartir_mano_inicial():
	cartas_en_mano_jugador = 0
	cartas_en_mano_rival = 0
	slots_jugador.clear()
	slots_rival.clear()
	for i in range(4):
		crear_carta_normal(pos_jugador, 1)
	for i in range(4):
		crear_carta_normal(pos_rival, 2)

func crear_carta_normal(marker: Marker2D, es_jugador: int):
	if card_scene == null:
		return

	var nueva_carta = card_scene.instantiate()
	add_child(nueva_carta)
	
	# Find first free slot
	var slots_dict = slots_jugador if es_jugador == 1 else slots_rival
	var indice_posicion = 0
	while slots_dict.has(indice_posicion):
		indice_posicion += 1
	
	nueva_carta.setup_card(mazo.pop_back(), es_jugador)
	nueva_carta.slot_index = indice_posicion
	slots_dict[indice_posicion] = nueva_carta
	colocar_carta(nueva_carta, marker, indice_posicion)
	if es_jugador == 1: cartas_en_mano_jugador += 1
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
	var separacion = Vector2(150 * indice, 0)
	carta.position = marker.position + separacion
	
func check_carta():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = 1
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		var collider = result[0].collider
		#Para poder arrastrar cartas comprobamos si el collider en el que clicamos lo es para evitar errores
		if collider is Carta:
			return collider
	return null
	
func check_slot_carta():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = 2
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		var collider = result[0].collider
		return collider
	return null

func connect_card_signals(carta):
	#recibe las señales de las cartas al detectar ser hovereadas
	carta.connect("hovered", on_hovered_over_card)
	carta.connect("hovered_off", on_hovered_off_card)
	
func on_hovered_over_card(carta):
	if !carta_hovered:
		carta_hovered = true
		highlight_card(carta, true)
	
func on_hovered_off_card(carta):
	if !carta_en_movimiento:
		highlight_card(carta, false)
		var nuevo_hover = check_carta()
		if nuevo_hover:
			highlight_card(nuevo_hover, true)
		else:
			carta_hovered = false
	
func highlight_card(carta, hovered):
	if hovered:
		carta.scale = carta.base_scale * 1.2
		carta.z_index = 2
	else:
		#al deshoverear deshacemos el aumento de tamaño
		carta.scale = carta.base_scale
		carta.z_index = 1

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			var carta = check_carta()
			if carta and carta.controlled_by_player == 1:
				start_drag(carta)
		else:
			finish_drag()
				 
func start_drag(carta):
	carta_en_movimiento = carta
	carta.scale = carta.base_scale * 1.2
	
func finish_drag():
	if carta_en_movimiento:
		carta_en_movimiento.scale = carta_en_movimiento.base_scale
		var zona_descartes = check_slot_carta()
		if zona_descartes:
			#Por ahora solo creé una zona de descartes
			#Posteriormente habría que manejar la lógica de detectar en que pila se está dejando la carta
			cartas_en_descartes1.append(carta_en_movimiento)
			if cartas_en_descartes1.size() >2:
				var carta_vieja = cartas_en_descartes1.pop_front()
				carta_vieja.queue_free()
			carta_en_movimiento.global_position = zona_descartes.global_position
			carta_en_movimiento.get_node("CollisionShape2D").disabled = true
			#Se determina en funcion del propietario de la carta que hueco de la mano queda libre
			var slots_actual = slots_jugador if carta_en_movimiento.controlled_by_player == 1 else slots_rival
			slots_actual.erase(carta_en_movimiento.slot_index)
			if carta_en_movimiento.controlled_by_player == 1:
				cartas_en_mano_jugador -= 1
			else:
				cartas_en_mano_rival -= 1
		carta_en_movimiento = null

func _on_mazo_especial_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		robar_carta_cuantica(true)


func _on_mazo_normal_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		crear_carta_normal(pos_jugador, 1)
