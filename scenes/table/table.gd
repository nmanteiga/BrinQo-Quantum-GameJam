extends Node2D
@export var card_scene : PackedScene 

# --- MUNDO ---
@onready var pos_jugador = $mano_p1
@onready var pos_rival = $mano_p2
@onready var zona_juego_p1 = $zonaJuego_p1 
@onready var zona_juego_p2 = $zonaJuego_p2
@onready var mazo_visual = $mazoNormal 

# --- REFERENCIAS UI ---
@onready var label_ronda = $CanvasLayer/LabelRonda
@onready var boton_plantarse = $CanvasLayer/BotonPlantarse
@onready var panel_game_over = $CanvasLayer/PanelGameOver
@onready var label_resultado = $CanvasLayer/PanelGameOver/LabelResultado


# -----------------
# --- VARIABLES ---
# lógica de juego
var mazo : Array[int] = []
var slots_jugador = {} 
var slots_rival = {} 
var descartes_p1 : Array[Carta] = []
var descartes_p2 : Array[Carta] = []
var carta_jugada_p1 : Carta = null
var carta_jugada_p2 : Carta = null

# control de juego
var ronda_actual : int = 1
const MAX_RONDAS : int = 10
var cartas_vistas_ronda : int = 0
var mirando_carta : bool = false 
var carta_en_movimiento = null
var carta_hovered = null 
var screen_size

# fases del juego
enum Fase { SELECCION, ANIMACION, GAME_OVER }
var fase_actual : int = Fase.SELECCION


# -----------------
# --- FUNCIONES ---
func _ready():
	await get_tree().process_frame
	randomize()
	screen_size = get_viewport_rect().size
	if panel_game_over: panel_game_over.visible = false
	
	if boton_plantarse:
		boton_plantarse.pressed.connect(finalizar_partida)
	
	if has_node("mazoNormal/Sprite2D"):
		$mazoNormal/Sprite2D.scale = Vector2(3, 3)
		
	crear_mazo()
	repartir_mano_inicial()
	actualizar_ui_ronda()

func _process(delta: float) -> void:
	if carta_en_movimiento:
		var mouse_pos = get_global_mouse_position()
		carta_en_movimiento.global_position = mouse_pos

# gestión del mazo y mano
func crear_mazo():
	mazo.clear()
	for palo in range(4):
		for valor in range(13):
			var id = palo * 13 + valor
			mazo.append(id)
	mazo.shuffle()

func repartir_mano_inicial():
	slots_jugador.clear()
	slots_rival.clear()
	cartas_vistas_ronda = 0
	mirando_carta = false
	ronda_actual = 1 # resetea la ronda al iniciar
	
	for i in range(4):
		crear_carta_normal(pos_jugador, 1)
		crear_carta_normal(pos_rival, 2)
	
	fase_actual = Fase.SELECCION
	actualizar_ui_ronda()

func crear_carta_normal(marker: Marker2D, es_jugador: int):
	if card_scene == null or mazo.is_empty(): return

	var nueva_carta = card_scene.instantiate()
	add_child(nueva_carta)
	
	if mazo_visual:
		nueva_carta.global_position = mazo_visual.global_position
	else:
		nueva_carta.global_position = Vector2(-100, -100)

	var slots_dict = slots_jugador if es_jugador == 1 else slots_rival
	var indice_posicion = 0
	while slots_dict.has(indice_posicion):
		indice_posicion += 1
	
	if indice_posicion >= 4:
		nueva_carta.queue_free()
		return

	nueva_carta.setup_card(mazo.pop_back(), es_jugador)
	nueva_carta.face_up = false 
	nueva_carta.update_visuals()
	nueva_carta.slot_index = indice_posicion
	slots_dict[indice_posicion] = nueva_carta

	colocar_carta(nueva_carta, marker, indice_posicion)

func colocar_carta(carta, marker, indice):
	var separacion = Vector2(150 * indice, 0)
	var destino = marker.position + separacion
	
	carta.rotation_degrees = 0
	carta.z_index = 10 
	
	var tween = create_tween()
	tween.tween_property(carta, "position", destino, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_callback(func(): carta.z_index = 1).set_delay(0.5)


# lógica de juego
func jugar_carta_en_mesa(carta: Carta, zona: Node2D):
	var destino_visual
	
	if carta.controlled_by_player == 1:
		destino_visual = zona_juego_p1.global_position
		carta_jugada_p1 = carta
	else:
		destino_visual = zona_juego_p2.global_position 
		carta_jugada_p2 = carta

	var tween = create_tween()
	tween.tween_property(carta, "global_position", destino_visual, 0.2)
	tween.parallel().tween_property(carta, "rotation_degrees", 0, 0.2)
	carta.scale = carta.base_scale
	carta.z_index = 5 
	
	if carta.has_node("CollisionShape2D"):
		carta.get_node("CollisionShape2D").disabled = true 
	
	var slots_actual = slots_jugador if carta.controlled_by_player == 1 else slots_rival
	slots_actual.erase(carta.slot_index)
	
	if carta.controlled_by_player == 1: 
		fase_actual = Fase.ANIMACION
	
	if carta_jugada_p1 != null and carta_jugada_p2 != null:
		resolver_ronda()
	elif carta_jugada_p2 == null:
		turno_rival_ia_jugar()

func turno_rival_ia_jugar():
	await get_tree().create_timer(1.0).timeout 
	if slots_rival.size() > 0:
		var slot_random = slots_rival.keys().pick_random()
		var carta_ia = slots_rival[slot_random]
		jugar_carta_en_mesa(carta_ia, zona_juego_p2)

func resolver_ronda():
	#print("--- RESOLVIENDO ---")
	await get_tree().create_timer(1.0).timeout
	
	if carta_jugada_p1: 
		carta_jugada_p1.face_up = true
		carta_jugada_p1.update_visuals()
	if carta_jugada_p2: 
		carta_jugada_p2.face_up = true
		carta_jugada_p2.update_visuals()
	
	await get_tree().create_timer(2.0).timeout 
	var val1 = obtener_poder_carta(carta_jugada_p1.value)
	var val2 = obtener_poder_carta(carta_jugada_p2.value)
	#print("P1 (Valor " + str(val1) + ") vs IA (Valor " + str(val2) + ")")
	
	#if val1 > val2:
	#	print("GANADOR: JUGADOR")
	#elif val2 > val1:
	#	print("GANADOR: RIVAL")
	#else:
	#	print("EMPATE")
		
	gestionar_descarte(carta_jugada_p1, 1)
	gestionar_descarte(carta_jugada_p2, 2)
	carta_jugada_p1 = null
	carta_jugada_p2 = null
	
	rellenar_manos_y_seguir()

func gestionar_descarte(carta: Carta, id_jugador: int):
	var lista_descarte = descartes_p1 if id_jugador == 1 else descartes_p2
	lista_descarte.append(carta)
	
	if lista_descarte.size() > 2:
		var carta_vieja = lista_descarte.pop_front()
		if is_instance_valid(carta_vieja):
			carta_vieja.queue_free()

	var rotacion_random = randf_range(-10, 10)
	var tween = create_tween()
	tween.tween_property(carta, "rotation_degrees", rotacion_random, 0.3).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(carta, "modulate", Color(0.7, 0.7, 0.7), 0.3)
	
	for i in range(lista_descarte.size()):
		lista_descarte[i].z_index = i

func rellenar_manos_y_seguir():
	if ronda_actual >= MAX_RONDAS:
		finalizar_partida()
		return

	ronda_actual += 1
	actualizar_ui_ronda()
	
	#print("--- RELLENANDO PARA RONDA " + str(ronda_actual) + " ---")
	for i in range(4):
		if not slots_jugador.has(i):
			crear_carta_normal(pos_jugador, 1)
			await get_tree().create_timer(0.2).timeout
	for i in range(4):
		if not slots_rival.has(i):
			crear_carta_normal(pos_rival, 2)
			await get_tree().create_timer(0.2).timeout
			
	cartas_vistas_ronda = 0
	fase_actual = Fase.SELECCION


# sistema de puntuación y GAME OVER
func actualizar_ui_ronda():
	if label_ronda:
		label_ronda.text = "Ronda: " + str(ronda_actual) + " / " + str(MAX_RONDAS)

func finalizar_partida():
	#print("--- FIN DE PARTIDA ---")
	fase_actual = Fase.GAME_OVER # bloquea cualquier interacción
	
	# girar todas las cartas para ver qué tenían
	for carta in slots_jugador.values():
		carta.face_up = true
		carta.update_visuals()
		
	for carta in slots_rival.values():
		carta.face_up = true
		carta.update_visuals()
	
	# calcular puntos
	var puntos_p1 = calcular_puntos_mano(slots_jugador)
	var puntos_p2 = calcular_puntos_mano(slots_rival)
	
	#print("Puntos Jugador: ", puntos_p1)
	#print("Puntos Rival: ", puntos_p2)
	
	# muestra el rto
	var mensaje = ""
	if puntos_p1 > puntos_p2:
		mensaje = "¡HAS GANADO!\n"
	elif puntos_p2 > puntos_p1:
		mensaje = "¡HAS PERDIDO!\n"
	else:
		mensaje = "¡EMPATE!\n"
		
	mensaje += "Tus puntos: " + str(puntos_p1) + "\n"
	mensaje += "Rival: " + str(puntos_p2)
	
	if label_resultado: label_resultado.text = mensaje
	if panel_game_over: panel_game_over.visible = true
	if boton_plantarse: boton_plantarse.visible = false

func calcular_puntos_mano(slots_dict):
	var total = 0
	for carta in slots_dict.values():
		total += obtener_poder_carta(carta.value)
	return total


# input y visualización
func _input(event):
	# bloquea las acciones si es game over
	if fase_actual != Fase.SELECCION or carta_jugada_p1 != null or mirando_carta: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			var carta = check_carta()
			
			if carta and carta is Carta and carta.controlled_by_player == 1:
				if not carta.face_up and cartas_vistas_ronda == 0:
					activar_vista_temporal(carta)
					return 
				else:
					start_drag(carta)
		else:
			finish_drag()

func activar_vista_temporal(carta: Carta):
	mirando_carta = true 
	cartas_vistas_ronda += 1
	carta.face_up = true
	carta.update_visuals()

	var tween = create_tween()
	tween.tween_property(carta, "scale", carta.base_scale * 1.2, 0.2)
	
	await get_tree().create_timer(2.0).timeout
	
	carta.face_up = false
	carta.update_visuals()
	tween = create_tween()
	tween.tween_property(carta, "scale", carta.base_scale, 0.2)
	
	animacion_ia_mirando()

func animacion_ia_mirando():
	await get_tree().create_timer(0.5).timeout
	
	if slots_rival.size() > 0:
		var slot_random = slots_rival.keys().pick_random()
		var carta_ia = slots_rival[slot_random]
		
		var tween = create_tween()
		tween.tween_property(carta_ia, "position", carta_ia.position + Vector2(0, 30), 0.3).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(carta_ia, "scale", carta_ia.base_scale * 1.1, 0.3)
		
		await get_tree().create_timer(1.5).timeout 
		
		tween = create_tween()
		tween.tween_property(carta_ia, "position", carta_ia.position - Vector2(0, 30), 0.3)
		tween.parallel().tween_property(carta_ia, "scale", carta_ia.base_scale, 0.3)
		
		await get_tree().create_timer(0.3).timeout
	
	mirando_carta = false 

func start_drag(carta):
	carta_en_movimiento = carta
	carta.scale = carta.base_scale * 1.2
	carta.z_index = 20

func finish_drag():
	if carta_en_movimiento:
		var zona_destino = check_slot_carta() 
		
		if zona_destino and fase_actual == Fase.SELECCION:
			jugar_carta_en_mesa(carta_en_movimiento, zona_destino)
		else:
			devolver_carta_a_mano(carta_en_movimiento)
			
		carta_en_movimiento = null

func devolver_carta_a_mano(carta):
	var marker_destino = pos_jugador if carta.controlled_by_player == 1 else pos_rival
	var offset = Vector2(150 * carta.slot_index, 0)
	var destino = marker_destino.position + offset
	
	var tween = create_tween()
	tween.tween_property(carta, "position", destino, 0.3).set_trans(Tween.TRANS_CUBIC)
	
	carta.rotation_degrees = 0
	carta.scale = carta.base_scale
	carta.z_index = 1
	if carta.has_node("CollisionShape2D"):
		carta.get_node("CollisionShape2D").disabled = false


# sistema de señales
func connect_card_signals(carta):
	if !carta.is_connected("hovered", on_hovered_over_card):
		carta.connect("hovered", on_hovered_over_card)
	if !carta.is_connected("hovered_off", on_hovered_off_card):
		carta.connect("hovered_off", on_hovered_off_card)

func on_hovered_over_card(carta):
	if fase_actual != Fase.SELECCION or mirando_carta: return
	if !carta_hovered:
		carta_hovered = true
		highlight_card(carta, true)

func on_hovered_off_card(carta):
	if !carta_en_movimiento:
		highlight_card(carta, false)
		var nuevo_hover = check_carta()
		if nuevo_hover and nuevo_hover is Carta:
			highlight_card(nuevo_hover, true)
		else:
			carta_hovered = false

func highlight_card(carta, hovered):
	if not is_instance_valid(carta) or not carta is Carta: return
	if hovered:
		carta.scale = carta.base_scale * 1.2
		carta.z_index = 10
	else:
		carta.scale = carta.base_scale
		carta.z_index = 1

func check_carta():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = 1 
	var result = space_state.intersect_point(parameters)
	
	for dict in result:
		if dict.collider is Carta:
			return dict.collider
	return null
	
func check_slot_carta():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = 2 
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider
	return null

# función auxiliar para que el as sea la carta más alta
func obtener_poder_carta(valor_visual: int) -> int:
	if valor_visual == 0: 
		return 14 
	else:
		return valor_visual + 1


# función cartas especiales (a implementar)
func robar_carta_cuantica(es_jugador: bool):
	pass
	
