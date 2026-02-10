extends Node2D
@export var card_scene : PackedScene 
var local_player_id = 1

var is_server: bool = false
var opponent_id: int = 0
var is_single_player: bool = true  # Default to single-player AI mode

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
var ya_jugue_esta_ronda: bool = false
var solicitud_finalizar: bool = false  # Flag to end game after current turn


# -----------------
# --- FUNCIONES ---
func _ready():
	await get_tree().process_frame
	
	print("=== TABLE _ready START ===")
	print("local_player_id received: ", local_player_id)  # Verificar valor
	
	if local_player_id != 1 and local_player_id != 2:
		push_error("local_player not initialized correctly")
		local_player_id = 1 #fallback
	print("Table ready, local player id =", local_player_id)
	
	# Detect if we're in multiplayer mode or single-player AI mode
	# Check if it's OfflineMultiplayerPeer (default) means single-player
	var peer = multiplayer.multiplayer_peer
	var is_offline_peer = peer is OfflineMultiplayerPeer
	
	is_single_player = is_offline_peer
	
	if not is_single_player:
		is_server = multiplayer.is_server()
		opponent_id = 2 if local_player_id == 1 else 1
		print("Multiplayer: is_server=", is_server, " opponent_id=", opponent_id)
	else:
		# Single-player mode against AI
		is_server = false
		local_player_id = 1
		opponent_id = 2
	print("=========================")
	
	# Disable collision on Descartes1 - only Descartes2 should be a valid drop zone
	# Both players drop in Descartes2 (first zone), but see opponent's cards visually in Descartes1
	var descartes1_area = $Descartes1/Area2D
	if descartes1_area:
		descartes1_area.collision_mask = 0
		descartes1_area.collision_layer = 0
		print("Descartes1 collision disabled (only Descartes2 is drop zone)")
	
	randomize()
	screen_size = get_viewport_rect().size
	if panel_game_over: panel_game_over.visible = false
	
	if boton_plantarse:
		boton_plantarse.pressed.connect(solicitar_finalizar_partida)
	
	if has_node("mazoNormal/Sprite2D"):
		$mazoNormal/Sprite2D.scale = Vector2(3, 3)
		
	crear_mazo()
	
	# Only deal cards if single-player OR if we're the server in multiplayer
	# Clients will receive cards via RPC from server
	if is_single_player or is_server:
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
	
	# Only send RPC in multiplayer mode when server
	if not is_single_player and is_server and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		rpc_sync_deck.rpc(mazo)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_deck(deck_order: Array):
	mazo = deck_order

func repartir_mano_inicial():
	print("=== repartir_mano_inicial called ===")
	print("  Before clear: slots_jugador=", slots_jugador.keys(), " slots_rival=", slots_rival.keys())
	slots_jugador.clear()
	slots_rival.clear()
	cartas_vistas_ronda = 0
	mirando_carta = false
	ronda_actual = 1 # resetea la ronda al iniciar
	
	if is_single_player:
		# Single-player mode: directly create cards locally without RPC
		for i in range(4):
			var card_id_p1 = mazo.pop_back()
			var card_id_p2 = mazo.pop_back()
			_spawn_card(card_id_p1, 1, i)
			_spawn_card(card_id_p2, 2, i)
	else:
		# Multiplayer mode
		if is_server and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			# Server deals cards and broadcasts via RPC
			for i in range(4):
				var card_id_p1 = mazo.pop_back()
				var card_id_p2 = mazo.pop_back()
				rpc_receive_card.rpc(card_id_p1, 1, i)
				rpc_receive_card.rpc(card_id_p2, 2, i)
		# else: Client waits for server to deal
	
	fase_actual = Fase.SELECCION
	actualizar_ui_ronda()

# Internal card spawning function (not RPC)
func _spawn_card(card_id: int, owner_player: int, slot_idx: int):
	if card_scene == null:
		return

	var nueva_carta = card_scene.instantiate()
	add_child(nueva_carta)
	
	# Position at deck initially
	if mazo_visual:
		nueva_carta.global_position = mazo_visual.global_position
	else:
		nueva_carta.global_position = Vector2(-100, -100)
	
	# Determine if this card belongs to local player or opponent
	var marker = pos_jugador if owner_player == local_player_id else pos_rival
	var slots_dict = slots_jugador if owner_player == local_player_id else slots_rival
	
	var dict_name = "slots_jugador" if owner_player == local_player_id else "slots_rival"
	print("_spawn_card: card_id=", card_id, " owner=", owner_player, " local_player=", local_player_id, " slot=", slot_idx, " -> ", dict_name)
	
	# Setup card - ALL CARDS START FACE DOWN
	nueva_carta.setup_card(card_id, owner_player)
	nueva_carta.face_up = false  # All cards start face down per game rules
	nueva_carta.update_visuals()
	nueva_carta.slot_index = slot_idx
	slots_dict[slot_idx] = nueva_carta
	
	# Animate to hand position
	colocar_carta(nueva_carta, marker, slot_idx)

# RPC wrapper for multiplayer mode
@rpc("any_peer", "call_local", "reliable")
func rpc_receive_card(card_id: int, owner_player: int, slot_idx: int):
	_spawn_card(card_id, owner_player, slot_idx)

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

# Reposition all cards in a hand to eliminate gaps
func reposicionar_mano(slots_dict, marker):
	var sorted_slots = slots_dict.keys()
	sorted_slots.sort()
	var visual_index = 0
	for slot_idx in sorted_slots:
		var carta = slots_dict[slot_idx]
		var separacion = Vector2(150 * visual_index, 0)
		var destino = marker.position + separacion
		
		var tween = create_tween()
		tween.tween_property(carta, "position", destino, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		visual_index += 1

# lógica de juego
func jugar_carta_en_mesa(carta: Carta, zona: Node2D):
	var destino_visual
	
	if carta.controlled_by_player == local_player_id:
		# My card goes to Descartes2 (zona_juego_p2) on my screen
		destino_visual = zona_juego_p2.global_position
		if local_player_id == 1:
			carta_jugada_p1 = carta
		else:
			carta_jugada_p2 = carta
	else:
		# Opponent's card appears in Descartes1 (zona_juego_p1) on my screen
		destino_visual = zona_juego_p1.global_position 
		if opponent_id == 1:
			carta_jugada_p1 = carta
		else:
			carta_jugada_p2 = carta

	var tween = create_tween()
	tween.tween_property(carta, "global_position", destino_visual, 0.2)
	tween.parallel().tween_property(carta, "rotation_degrees", 0, 0.2)
	carta.scale = carta.base_scale
	carta.z_index = 5 
	
	if carta.has_node("CollisionShape2D"):
		carta.get_node("CollisionShape2D").disabled = true 
	
	var slots_actual = slots_jugador if carta.controlled_by_player == local_player_id else slots_rival
	var dict_name = "slots_jugador" if carta.controlled_by_player == local_player_id else "slots_rival"
	print("jugar_carta_en_mesa: Erasing slot ", carta.slot_index, " from ", dict_name, " (before: ", slots_actual.keys(), ")")
	slots_actual.erase(carta.slot_index)
	print("  After erase: ", slots_actual.keys())
	
	# Cards maintain their slot positions - no repositioning needed
	
	if carta.controlled_by_player == local_player_id: 
		fase_actual = Fase.ANIMACION
		ya_jugue_esta_ronda = true
		# In multiplayer, notify other player about the card played
		if not is_single_player:
			rpc_opponent_played_card.rpc(carta.slot_index)
	
	if carta_jugada_p1 != null and carta_jugada_p2 != null:
		resolver_ronda()
	elif carta_jugada_p2 == null and is_single_player:
		# Only use AI in single-player mode
		turno_rival_ia_jugar()

# RPC to synchronize card plays between players
#@rpc("any_peer", "call_remote", "reliable")
#func rpc_play_card(card_id: int, player_id: int, slot_idx: int):
	# Find the card in the appropriate slots
#	var slots_dict = slots_jugador if player_id == local_player_id else slots_rival
#	if slots_dict.has(slot_idx):
#		var carta = slots_dict[slot_idx]
#		var zona = zona_juego_p1 if player_id == 1 else zona_juego_p2
#		jugar_carta_en_mesa(carta, zona)

func turno_rival_ia_jugar():
	await get_tree().create_timer(1.0).timeout 
	if slots_rival.size() > 0:
		var slot_random = slots_rival.keys().pick_random()
		var carta_ia = slots_rival[slot_random]
		jugar_carta_en_mesa(carta_ia, zona_juego_p2)
		
# RPC called when opponent plays a card
@rpc("any_peer", "call_remote", "reliable")
func rpc_opponent_played_card(slot_idx: int):
	print("rpc_opponent_played_card received: slot_idx=", slot_idx, " opponent_id=", opponent_id)
	print("  slots_rival keys: ", slots_rival.keys())
	# Find the card the opponent played in their slots (which are rival slots from our perspective)
	if slots_rival.has(slot_idx):
		var carta = slots_rival[slot_idx]
		print("  Found opponent card, type: ", carta.get_class())
		var zona = zona_juego_p2 if opponent_id == 2 else zona_juego_p1
		jugar_carta_en_mesa(carta, zona)
	else:
		print("  ERROR: slot_idx ", slot_idx, " not found in slots_rival!")

func resolver_ronda():
	#print("--- RESOLVIENDO ---")
	await get_tree().create_timer(1.0).timeout
	
	# Reveal cards - sync for multiplayer
	if not is_single_player:
		rpc_reveal_cards.rpc()
	else:
		reveal_cards_local()
	
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

@rpc("any_peer", "call_local", "reliable")
func rpc_reveal_cards():
	reveal_cards_local()

func reveal_cards_local():
	if carta_jugada_p1: 
		carta_jugada_p1.face_up = true
		carta_jugada_p1.update_visuals()
	if carta_jugada_p2: 
		carta_jugada_p2.face_up = true
		carta_jugada_p2.update_visuals()

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
	if ronda_actual >= MAX_RONDAS or solicitud_finalizar:
		finalizar_partida()
		return

	ronda_actual += 1
	actualizar_ui_ronda()
	
	#print("--- RELLENANDO PARA RONDA " + str(ronda_actual) + " ---")
	
	if is_single_player:
		# Single-player mode: create cards locally
		for i in range(4):
			if not slots_jugador.has(i):
				crear_carta_normal(pos_jugador, 1)
				await get_tree().create_timer(0.2).timeout
		for i in range(4):
			if not slots_rival.has(i):
				crear_carta_normal(pos_rival, 2)
				await get_tree().create_timer(0.2).timeout
		
		# Cards are positioned at their slot index - no repositioning needed
	else:
		# Multiplayer mode: server deals cards to all players
		if is_server and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			for i in range(4):
				if not slots_jugador.has(i):
					var card_id_p1 = mazo.pop_back()
					rpc_receive_card.rpc(card_id_p1, 1, i)
					await get_tree().create_timer(0.2).timeout
				if not slots_rival.has(i):
					var card_id_p2 = mazo.pop_back()
					rpc_receive_card.rpc(card_id_p2, 2, i)
					await get_tree().create_timer(0.2).timeout
		
		# Cards are positioned at their slot index - no repositioning needed
	cartas_vistas_ronda = 0
	ya_jugue_esta_ronda = false
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

# Request to end the game (syncs with opponent)
func solicitar_finalizar_partida():
	solicitud_finalizar = true
	if not is_single_player:
		rpc_solicitar_finalizar.rpc()

@rpc("any_peer", "call_remote", "reliable")
func rpc_solicitar_finalizar():
	solicitud_finalizar = true

func calcular_puntos_mano(slots_dict):
	var total = 0
	for carta in slots_dict.values():
		total += obtener_poder_carta(carta.value)
	return total


# input y visualización
func _input(event):
	if fase_actual != Fase.SELECCION or ya_jugue_esta_ronda or mirando_carta: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			var carta = check_carta()
			
			if carta and carta is Carta and carta.controlled_by_player == local_player_id:
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
	
	# Only show AI animation in single-player mode
	if is_single_player:
		animacion_ia_mirando()
	else:
		# Tell opponent you peeked at this card
		rpc_opponent_peeked_card.rpc(carta.slot_index)
		mirando_carta = false  # In multiplayer, don't wait for opponent's peek

func animacion_ia_mirando():
	await get_tree().create_timer(0.5).timeout
	
	if slots_rival.size() > 0:
		var slot_random = slots_rival.keys().pick_random()
		var carta_ia = slots_rival[slot_random]
		
		# Store original position before animating
		var original_position = carta_ia.position
		
		var tween = create_tween()
		tween.tween_property(carta_ia, "position", original_position + Vector2(0, 30), 0.3).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(carta_ia, "scale", carta_ia.base_scale * 1.1, 0.3)
		
		await get_tree().create_timer(1.5).timeout 
		
		tween = create_tween()
		tween.tween_property(carta_ia, "position", original_position, 0.3)
		tween.parallel().tween_property(carta_ia, "scale", carta_ia.base_scale, 0.3)
		
		await get_tree().create_timer(0.3).timeout
	
	mirando_carta = false 
	
# RPC to tell opponent which card you looked at
@rpc("any_peer", "call_remote", "reliable")
func rpc_opponent_peeked_card(slot_idx: int):
	# Highlight the opponent's card they looked at
	if slots_rival.has(slot_idx):
		var carta = slots_rival[slot_idx]
		mostrar_carta_vista_rival(carta)
		
func mostrar_carta_vista_rival(carta: Carta):
	# Animate the opponent's card like AI does - shows which one they peeked
	var original_pos = carta.position
	var tween = create_tween()
	tween.tween_property(carta, "position", original_pos + Vector2(0, 30), 0.3).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(carta, "scale", carta.base_scale * 1.1, 0.3)
	
	await get_tree().create_timer(1.5).timeout 
	
	tween = create_tween()
	tween.tween_property(carta, "position", original_pos, 0.3)
	tween.parallel().tween_property(carta, "scale", carta.base_scale, 0.3)

func start_drag(carta):
	carta_en_movimiento = carta
	carta.scale = carta.base_scale * 1.2
	carta.z_index = 20

func finish_drag():
	if carta_en_movimiento:
		var zona_detectada = check_slot_carta()
		print("finish_drag: zona_detectada=", zona_detectada, " fase=", fase_actual)
		
		# Solo permitir jugar si suelta en una zona válida Y está en fase de selección
		if zona_detectada and fase_actual == Fase.SELECCION:
			print("Playing card - using local player's zone")
			# Siempre pasar zona_juego_p1, la lógica interna decide donde va visualmente
			jugar_carta_en_mesa(carta_en_movimiento, zona_juego_p1)
		else:
			print("Returning card to hand - no valid zone or wrong phase")
			devolver_carta_a_mano(carta_en_movimiento)
			
		carta_en_movimiento = null

func devolver_carta_a_mano(carta):
	var marker_destino = pos_jugador if carta.controlled_by_player == local_player_id else pos_rival
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
	
	print("check_slot_carta: detected ", result.size(), " areas")
	
	# Debug: mostrar todas las áreas detectadas
	for dict in result:
		var area = dict.collider
		print("  - Area: ", area, " parent: ", area.get_parent().name if area.get_parent() else "NO PARENT")
	
	# Solo aceptar la zona Descartes2/Area2D (primera zona)
	for dict in result:
		var area = dict.collider
		if area.get_parent() and area.get_parent().name == "Descartes2":
			print("  -> Accepted zone!")
			return area
	
	print("  -> No valid zone found")
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
	
