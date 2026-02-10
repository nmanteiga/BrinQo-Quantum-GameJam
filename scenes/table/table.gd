extends Node2D
@export var card_scene : PackedScene 

# --- REFERENCIAS ---
@onready var pos_jugador = $mano_p1
@onready var pos_rival = $mano_p2
@onready var zona_juego_p1 = $zonaJuego_p1 
@onready var zona_juego_p2 = $zonaJuego_p2
@onready var mazo_visual = $mazoNormal 
@onready var mazo_especial_visual = get_node_or_null("mazoEspecial")

# UI
@onready var label_ronda = $CanvasLayer/LabelRonda
@onready var boton_plantarse = $CanvasLayer/BotonPlantarse
@onready var panel_game_over = $CanvasLayer/PanelGameOver
@onready var label_resultado = $CanvasLayer/PanelGameOver/LabelResultado

# DEBUG
@onready var boton_debug = $CanvasLayer/BotonDebug 
var debug_abierto : bool = false

# VARIABLES
var mazo : Array[int] = []
var slots_jugador = {} 
var slots_rival = {} 
var descartes_p1 : Array[Carta] = []
var descartes_p2 : Array[Carta] = []
var carta_jugada_p1 : Carta = null
var carta_jugada_p2 : Carta = null
var ronda_actual : int = 1
const MAX_RONDAS : int = 10
var cartas_vistas_ronda : int = 0
var mirando_carta : bool = false 
var carta_en_movimiento = null
var carta_hovered = null 
var screen_size
var cartas_preview : Array[Carta] = [] 
var monton_hover_actual : int = 0 
enum EfectoCuantico { NINGUNO, SELECCIONAR_ENTRELAZADO_PROPIA, SELECCIONAR_ENTRELAZADO_RIVAL, SELECCIONAR_SUPERPOSICION, SELECCIONAR_MONTON_SUPERPOSICION }
var estado_efecto_actual : int = EfectoCuantico.NINGUNO
var carta_seleccionada_efecto : Carta = null 
enum Fase { SELECCION, ANIMACION, EVENTO_ESPECIAL, GAME_OVER }
var fase_actual : int = Fase.SELECCION

func _ready():
	await get_tree().process_frame
	randomize()
	screen_size = get_viewport_rect().size
	if panel_game_over: panel_game_over.visible = false
	if boton_plantarse: boton_plantarse.pressed.connect(finalizar_partida)
	if boton_debug: boton_debug.pressed.connect(toggle_debug_vision)

	crear_mazo()
	repartir_mano_inicial()
	actualizar_ui_ronda()

func _process(delta: float) -> void:
	if carta_en_movimiento:
		carta_en_movimiento.global_position = get_global_mouse_position()
	if fase_actual == Fase.EVENTO_ESPECIAL and estado_efecto_actual == EfectoCuantico.SELECCIONAR_MONTON_SUPERPOSICION:
		gestionar_preview_montones()
	elif monton_hover_actual != 0:
		limpiar_preview()

# --- GESTIÓN CARTAS ---
func crear_mazo():
	mazo.clear()
	for palo in range(4):
		for valor in range(13):
			mazo.append(palo * 13 + valor)
	mazo.shuffle()

func repartir_mano_inicial():
	slots_jugador.clear(); slots_rival.clear()
	cartas_vistas_ronda = 0; mirando_carta = false
	ronda_actual = 1
	for i in range(4):
		crear_carta_normal(pos_jugador, 1)
		crear_carta_normal(pos_rival, 2)
	fase_actual = Fase.SELECCION
	actualizar_ui_ronda()

func crear_carta_normal(marker: Marker2D, es_jugador: int):
	if !card_scene or mazo.is_empty(): return
	var nueva_carta = card_scene.instantiate()
	add_child(nueva_carta)
	nueva_carta.global_position = mazo_visual.global_position if mazo_visual else Vector2(-100,-100)
	
	var slots_dict = slots_jugador if es_jugador == 1 else slots_rival
	var idx = 0
	while slots_dict.has(idx): idx += 1
	if idx >= 4: nueva_carta.queue_free(); return

	nueva_carta.setup_card(mazo.pop_back(), es_jugador)
	nueva_carta.slot_index = idx
	slots_dict[idx] = nueva_carta
	colocar_carta(nueva_carta, marker, idx)

func colocar_carta(carta, marker, idx):
	var destino = marker.position + Vector2(208 * idx, 0)
	carta.z_index = 10 
	var tween = create_tween()
	tween.tween_property(carta, "position", destino, 0.5).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_callback(func(): carta.z_index = 1).set_delay(0.5)


# --- JUEGO ---
func jugar_carta_en_mesa(carta: Carta, zona: Node2D):
	var dest = zona_juego_p1.global_position if carta.controlled_by_player == 1 else zona_juego_p2.global_position
	if carta.controlled_by_player == 1: carta_jugada_p1 = carta
	else: carta_jugada_p2 = carta

	var tween = create_tween()
	tween.tween_property(carta, "global_position", dest, 0.2)
	tween.parallel().tween_property(carta, "rotation_degrees", 0, 0.2)
	carta.z_index = 5 
	if carta.has_node("CollisionShape2D"): carta.get_node("CollisionShape2D").disabled = true 
	
	var slots = slots_jugador if carta.controlled_by_player == 1 else slots_rival
	slots.erase(carta.slot_index)
	
	if carta.controlled_by_player == 1: fase_actual = Fase.ANIMACION
	
	if carta_jugada_p1 and carta_jugada_p2: resolver_ronda()
	elif !carta_jugada_p2: turno_rival_ia_jugar()

func turno_rival_ia_jugar():
	await get_tree().create_timer(1.0).timeout 
	if fase_actual == Fase.GAME_OVER: return 
	
	if slots_rival.size() > 0:
		jugar_carta_en_mesa(slots_rival.values().pick_random(), zona_juego_p2)

func resolver_ronda():
	await get_tree().create_timer(1.0).timeout
	if fase_actual == Fase.GAME_OVER: return
	
	if carta_jugada_p1: 
		carta_jugada_p1.face_up = false
		if carta_jugada_p1.es_superposicion: colapsar_superposicion(carta_jugada_p1) 
		resolver_entrelazamiento(carta_jugada_p1) 
		#carta_jugada_p1.update_visuals()
		carta_jugada_p1.flip_card()
	if carta_jugada_p2: 
		carta_jugada_p2.face_up = false
		if carta_jugada_p2.es_superposicion: colapsar_superposicion(carta_jugada_p2)
		resolver_entrelazamiento(carta_jugada_p2)
		#carta_jugada_p2.update_visuals()
		carta_jugada_p2.flip_card()
	
	await get_tree().create_timer(2.0).timeout 
	if fase_actual == Fase.GAME_OVER: return
	
	gestionar_descarte(carta_jugada_p1, 1)
	gestionar_descarte(carta_jugada_p2, 2)
	carta_jugada_p1 = null; carta_jugada_p2 = null
	rellenar_manos_y_seguir()

func gestionar_descarte(carta: Carta, id: int):
	var lista = descartes_p1 if id == 1 else descartes_p2
	lista.append(carta)
	if lista.size() > 2:
		var vieja = lista.pop_front()
		if is_instance_valid(vieja): vieja.queue_free()

	var tween = create_tween()
	tween.tween_property(carta, "rotation_degrees", randf_range(-10, 10), 0.3)
	tween.parallel().tween_property(carta, "modulate", Color(0.7, 0.7, 0.7), 0.3)
	for i in range(lista.size()): lista[i].z_index = i

func rellenar_manos_y_seguir():
	if fase_actual == Fase.GAME_OVER: return
	if ronda_actual >= MAX_RONDAS: finalizar_partida(); return
	ronda_actual += 1
	actualizar_ui_ronda()
	
	for i in range(4):
		if !slots_jugador.has(i): crear_carta_normal(pos_jugador, 1); await get_tree().create_timer(0.2).timeout
	for i in range(4):
		if !slots_rival.has(i): crear_carta_normal(pos_rival, 2); await get_tree().create_timer(0.2).timeout
			
	cartas_vistas_ronda = 0
	fase_actual = Fase.EVENTO_ESPECIAL 
	robar_carta_cuantica(true) 


# --- INPUT CRÍTICO ---
func _input(event):
	if fase_actual == Fase.GAME_OVER or fase_actual == Fase.ANIMACION: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if fase_actual == Fase.EVENTO_ESPECIAL and estado_efecto_actual == EfectoCuantico.SELECCIONAR_MONTON_SUPERPOSICION:
			var mouse_pos = get_global_mouse_position()
			var radio_detect = 100.0 
			
			if mouse_pos.distance_to(zona_juego_p1.global_position) < radio_detect:
				aplicar_superposicion_monton(descartes_p1)
				return
			elif mouse_pos.distance_to(zona_juego_p2.global_position) < radio_detect:
				aplicar_superposicion_monton(descartes_p2)
				return
			return 

		var carta = check_carta()
		if !carta or !(carta is Carta): return

		if fase_actual == Fase.EVENTO_ESPECIAL and estado_efecto_actual != EfectoCuantico.NINGUNO:
			gestionar_input_efectos(carta)
			return 

		if fase_actual == Fase.SELECCION and !mirando_carta and carta.controlled_by_player == 1:
			if carta.es_superposicion and !carta.face_up: colapsar_superposicion(carta)
			if !carta.face_up and cartas_vistas_ronda == 0: activar_vista_temporal(carta)
			else: start_drag(carta)
	
	elif event is InputEventMouseButton and !event.is_pressed():
		finish_drag()


# --- CUÁNTICA ---
func robar_carta_cuantica(es_jugador: bool):
	if fase_actual == Fase.GAME_OVER: return
	var roll = randf()
	var efecto = 4 
	
	# probabilidades
	if ronda_actual <= 2:
		if roll < 0.05: efecto = 3
		elif roll < 0.50: efecto = 4
		else: efecto = 1 
	else:
		if roll < 0.05: efecto = 3 
		elif roll < 0.40: efecto = 4 
		elif roll < 0.70: efecto = 1 
		else: 
			if descartes_p1.size() + descartes_p2.size() >= 2: efecto = 2
			else: efecto = 4
	
	# animación
	if card_scene:
		var anim = card_scene.instantiate()
		add_child(anim)
		var origen = mazo_especial_visual.global_position if mazo_especial_visual else mazo_visual.global_position
		anim.global_position = origen
		anim.scale = Vector2(0.5, 0.5); anim.z_index = 100 
		anim.setup_quantum(efecto, 1 if es_jugador else 2)
		anim.face_up = true; anim.update_visuals()
		
		var centro = get_viewport_rect().size / 2
		var dest = centro + (Vector2(0, 50) if es_jugador else Vector2(0, -50))
		var tween = create_tween()
		tween.tween_property(anim, "global_position", dest, 0.6).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(anim, "scale", Vector2(1.5, 1.5), 0.6) 
		await tween.finished
		
		if fase_actual == Fase.GAME_OVER: return
		await get_tree().create_timer(3.0).timeout 
		
		var tween_bye = create_tween()
		tween_bye.tween_property(anim, "scale", Vector2(0,0), 0.3)
		tween_bye.tween_callback(anim.queue_free)
		await tween_bye.finished
	
	aplicar_logica_cuantica(efecto, es_jugador)

func aplicar_logica_cuantica(efecto: int, es_jugador: bool):
	if es_jugador:
		match efecto:
			1: iniciar_efecto_entrelazado()
			2: iniciar_efecto_superposicion()
			3: efecto_around_the_world(); await get_tree().create_timer(1).timeout; pasar_a_turno_rival_cuantico()
			4: efecto_not_cuantico(true); await get_tree().create_timer(1).timeout; pasar_a_turno_rival_cuantico()
	else:
		match efecto:
			1: ia_efecto_entrelazado()
			2: ia_efecto_superposicion()
			3: efecto_around_the_world()
			4: efecto_not_cuantico(false)
		await get_tree().create_timer(1).timeout
		finalizar_fase_cuantica()

func iniciar_efecto_entrelazado():
	estado_efecto_actual = EfectoCuantico.SELECCIONAR_ENTRELAZADO_PROPIA

func iniciar_efecto_superposicion():
	estado_efecto_actual = EfectoCuantico.SELECCIONAR_SUPERPOSICION


# --- LIMPIEZA DE ESTADOS ---
func limpiar_estado_cuantico(carta: Carta):
	limpiar_preview()
	
	# romper vínculo con la pareja anterior si existe
	if carta.entrelazada_con and is_instance_valid(carta.entrelazada_con):
		var ex = carta.entrelazada_con
		ex.entrelazada_con = null
		ex.aplicar_efecto_visual_cuantico(Color.WHITE)
	
	# limpiar la propia carta
	carta.entrelazada_con = null
	carta.es_superposicion = false
	carta.opciones_superposicion.clear()
	carta.aplicar_efecto_visual_cuantico(Color.WHITE)

func gestionar_input_efectos(carta: Carta):
	match estado_efecto_actual:
		EfectoCuantico.SELECCIONAR_ENTRELAZADO_PROPIA:
			if carta.controlled_by_player == 1:
				# limpiamos antes de empezar
				limpiar_estado_cuantico(carta)
				carta_seleccionada_efecto = carta
				carta.aplicar_efecto_visual_cuantico(Color.CYAN)
				estado_efecto_actual = EfectoCuantico.SELECCIONAR_ENTRELAZADO_RIVAL
				
		EfectoCuantico.SELECCIONAR_ENTRELAZADO_RIVAL:
			if carta.controlled_by_player == 2:
				# limpiamos ambas cartas de cualquier efecto previo
				limpiar_estado_cuantico(carta_seleccionada_efecto)
				limpiar_estado_cuantico(carta)
				
				# creamos enlace
				carta_seleccionada_efecto.entrelazada_con = carta
				carta.entrelazada_con = carta_seleccionada_efecto
				
				# visuales
				carta.aplicar_efecto_visual_cuantico(Color.CYAN)
				carta_seleccionada_efecto.aplicar_efecto_visual_cuantico(Color.CYAN)
				carta_seleccionada_efecto = null
				estado_efecto_actual = EfectoCuantico.NINGUNO
				pasar_a_turno_rival_cuantico()
				
		EfectoCuantico.SELECCIONAR_SUPERPOSICION:
			if carta.controlled_by_player == 1:
				# limpiamos antes de aplicar
				limpiar_estado_cuantico(carta)
				
				carta_seleccionada_efecto = carta
				carta.aplicar_efecto_visual_cuantico(Color.PURPLE)
				estado_efecto_actual = EfectoCuantico.SELECCIONAR_MONTON_SUPERPOSICION

func aplicar_superposicion_monton(lista_descartes: Array):
	limpiar_preview()
	
	if carta_seleccionada_efecto:
		var posibles_valores = []
		if lista_descartes.size() >= 2:
			posibles_valores.append(lista_descartes[lista_descartes.size()-1].value)
			posibles_valores.append(lista_descartes[lista_descartes.size()-2].value)
		elif lista_descartes.size() == 1:
			posibles_valores.append(lista_descartes[0].value)
			posibles_valores.append(randi() % 13) 
		else:
			posibles_valores.append(randi() % 13)
			posibles_valores.append(randi() % 13)
			
		carta_seleccionada_efecto.es_superposicion = true
		carta_seleccionada_efecto.opciones_superposicion = posibles_valores
		
		carta_seleccionada_efecto = null
		estado_efecto_actual = EfectoCuantico.NINGUNO
		pasar_a_turno_rival_cuantico()

func pasar_a_turno_rival_cuantico(): robar_carta_cuantica(false)

func finalizar_fase_cuantica():
	limpiar_preview()
	fase_actual = Fase.SELECCION
	estado_efecto_actual = EfectoCuantico.NINGUNO
	mirando_carta = false


# AUXILIARES
func aplicar_superposicion(carta: Carta):
	limpiar_estado_cuantico(carta) 
	var vals = []
	if descartes_p1.size()>0: vals.append(descartes_p1.back().value)
	if descartes_p2.size()>0: vals.append(descartes_p2.back().value)
	while vals.size() < 2: vals.append(randi()%13)
	carta.es_superposicion = true; carta.opciones_superposicion = vals
	carta.aplicar_efecto_visual_cuantico(Color.PURPLE)

func efecto_not_cuantico(es_jugador: bool):
	var target = slots_jugador if es_jugador else slots_rival
	var candidatos = []
	
	for c in target.values():
		if not c.es_superposicion and c.entrelazada_con == null:
			candidatos.append(c)
	
	if candidatos.size() > 0:
		var carta = candidatos.pick_random()
		var poder_actual = obtener_poder_carta(carta.value)
		var nuevo_poder = 16 - poder_actual
		var nuevo_valor_visual = 0
		if nuevo_poder == 14: nuevo_valor_visual = 0 
		else: nuevo_valor_visual = nuevo_poder - 1 
		
		carta.value = nuevo_valor_visual
		var tween = create_tween()
		tween.tween_property(carta, "modulate", Color(1, 0.3, 0.3), 0.2) 
		tween.tween_property(carta, "modulate", Color.WHITE, 0.4)
	else:
		pass

func efecto_around_the_world():
	var temp = slots_jugador.duplicate()
	slots_jugador = slots_rival.duplicate(); slots_rival = temp
	for s in slots_jugador: 
		slots_jugador[s].controlled_by_player = 1
		colocar_carta(slots_jugador[s], pos_jugador, s)
	for s in slots_rival: 
		slots_rival[s].controlled_by_player = 2; slots_rival[s].face_up = false; slots_rival[s].update_visuals()
		colocar_carta(slots_rival[s], pos_rival, s)

func colapsar_superposicion(c):
	c.value = c.opciones_superposicion.pick_random()
	c.es_superposicion = false; c.aplicar_efecto_visual_cuantico(Color.WHITE)

func resolver_entrelazamiento(c):
	if not is_instance_valid(c): return

	if c.entrelazada_con and is_instance_valid(c.entrelazada_con):
		var pareja = c.entrelazada_con
		
		c.entrelazada_con = null
		if "entrelazada_con" in pareja:
			pareja.entrelazada_con = null
		
		pareja.value = c.value
		pareja.suit = c.suit 
		if pareja.face_up: pareja.update_visuals()
		
		c.aplicar_efecto_visual_cuantico(Color.WHITE)
		pareja.aplicar_efecto_visual_cuantico(Color.WHITE)
		
	else:
		c.entrelazada_con = null
		c.aplicar_efecto_visual_cuantico(Color.WHITE)
		
# IA
func ia_efecto_entrelazado():
	if slots_rival.size()>0 and slots_jugador.size()>0:
		var c1 = slots_rival.values().pick_random()
		var c2 = slots_jugador.values().pick_random()
		limpiar_estado_cuantico(c1)
		limpiar_estado_cuantico(c2)
		c1.entrelazada_con = c2; c2.entrelazada_con = c1
		c1.aplicar_efecto_visual_cuantico(Color.CYAN); c2.aplicar_efecto_visual_cuantico(Color.CYAN)

func ia_efecto_superposicion():
	if slots_rival.size()>0: aplicar_superposicion(slots_rival.values().pick_random())


# UTILS
func activar_vista_temporal(c):
	mirando_carta = true; cartas_vistas_ronda += 1; c.face_up = false
	resolver_entrelazamiento(c); if c.es_superposicion: colapsar_superposicion(c)
	c.flip_card()
	#c.update_visuals()
	#var t = create_tween(); t.tween_property(c, "scale", c.base_scale * 1.2, 0.2)
	await get_tree().create_timer(2).timeout
	#c.face_up = false; c.update_visuals()
	#t = create_tween(); t.tween_property(c, "scale", c.base_scale, 0.2)
	c.flip_card()
	animacion_ia_mirando()

func animacion_ia_mirando():
	await get_tree().create_timer(0.5).timeout
	if fase_actual == Fase.GAME_OVER: return
	if slots_rival.size() > 0:
		var c = slots_rival.values().pick_random()
		var t = create_tween()
		t.tween_property(c, "position", c.position + Vector2(0,30), 0.3).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(1.5).timeout
		t = create_tween(); t.tween_property(c, "position", c.position - Vector2(0,30), 0.3)
	mirando_carta = false

func start_drag(c): carta_en_movimiento = c; c.scale = c.base_scale * 1.2; c.z_index = 20
func finish_drag():
	if carta_en_movimiento:
		var dest = check_slot_carta()
		if dest and fase_actual == Fase.SELECCION: jugar_carta_en_mesa(carta_en_movimiento, dest)
		else: devolver_carta_a_mano(carta_en_movimiento)
		carta_en_movimiento = null

func devolver_carta_a_mano(c):
	var dest = (pos_jugador if c.controlled_by_player==1 else pos_rival).position + Vector2(150 * c.slot_index, 0)
	var t = create_tween(); t.tween_property(c, "position", dest, 0.3)
	c.rotation_degrees = 0; c.scale = c.base_scale; c.z_index = 1
	if c.has_node("CollisionShape2D"): c.get_node("CollisionShape2D").disabled = false

func connect_card_signals(c):
	if !c.is_connected("hovered", on_hovered_over_card): c.connect("hovered", on_hovered_over_card)
	if !c.is_connected("hovered_off", on_hovered_off_card): c.connect("hovered_off", on_hovered_off_card)

func on_hovered_over_card(c): if fase_actual == Fase.SELECCION and !mirando_carta and !carta_hovered: carta_hovered = true; highlight_card(c, true)
func on_hovered_off_card(c): 
	if !carta_en_movimiento: 
		highlight_card(c, false); var n = check_carta()
		if n and n is Carta: highlight_card(n, true)
		else: carta_hovered = false

func highlight_card(c, h): 
	if is_instance_valid(c) and c is Carta: 
		c.scale = c.base_scale * (1.2 if h else 1.0); c.z_index = 10 if h else 1

func check_carta():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = 1 
	var result = space_state.intersect_point(parameters)
	for dict in result:
		if dict.collider is Carta: return dict.collider
	return null

func check_slot_carta():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = 2 
	var result = space_state.intersect_point(parameters)
	if result.size() > 0: return result[0].collider
	return null

func obtener_poder_carta(v): return 14 if v == 0 else v + 1
func actualizar_ui_ronda(): if label_ronda: label_ronda.text = "Ronda: " + str(ronda_actual) + " / " + str(MAX_RONDAS)

func finalizar_partida():
	fase_actual = Fase.GAME_OVER
	carta_en_movimiento = null; mirando_carta = false; carta_hovered = null
	
	for i in range(4):
		if not slots_jugador.has(i): crear_carta_normal(pos_jugador, 1)
		if not slots_rival.has(i): crear_carta_normal(pos_rival, 2)
	
	await get_tree().process_frame; await get_tree().process_frame
	
	for c in slots_jugador.values(): c.face_up = true; c.update_visuals()
	for c in slots_rival.values(): c.face_up = true; c.update_visuals()
	
	var p1 = calcular_puntos_mano(slots_jugador)
	var p2 = calcular_puntos_mano(slots_rival)
	
	var txt = "¡HAS GANADO!\n" if p1 > p2 else ("¡HAS PERDIDO!\n" if p2 > p1 else "¡EMPATE!\n")
	txt += "Tus puntos: " + str(p1) + "\nRival: " + str(p2)
	
	if label_resultado: label_resultado.text = txt
	if panel_game_over: panel_game_over.visible = true
	if boton_plantarse: boton_plantarse.visible = false
	
func calcular_puntos_mano(slots_dict):
	var total = 0
	for carta in slots_dict.values(): total += obtener_poder_carta(carta.value)
	return total
	

# DEBUG
func toggle_debug_vision():
	debug_abierto = !debug_abierto
	
	for carta in slots_rival.values():
		carta.face_up = debug_abierto 
		carta.update_visuals()
		
	for carta in slots_jugador.values():
		carta.face_up = true 
		carta.update_visuals()
	
	if carta_jugada_p1: carta_jugada_p1.face_up = true; carta_jugada_p1.update_visuals()
	if carta_jugada_p2: carta_jugada_p2.face_up = true; carta_jugada_p2.update_visuals()

# PREVIEW 
func gestionar_preview_montones():
	var mouse_pos = get_global_mouse_position()
	var radio = 100.0
	var nuevo_monton = 0
	
	if mouse_pos.distance_to(zona_juego_p1.global_position) < radio: nuevo_monton = 1
	elif mouse_pos.distance_to(zona_juego_p2.global_position) < radio: nuevo_monton = 2
	
	if nuevo_monton != monton_hover_actual:
		limpiar_preview()
		monton_hover_actual = nuevo_monton
		if nuevo_monton == 1: mostrar_cartas_preview(descartes_p1, zona_juego_p1.global_position)
		elif nuevo_monton == 2: mostrar_cartas_preview(descartes_p2, zona_juego_p2.global_position)

func mostrar_cartas_preview(lista_origen: Array, posicion_base: Vector2):
	if lista_origen.is_empty(): return
	var cartas_a_mostrar = []
	var cantidad = lista_origen.size()
	if cantidad >= 1: cartas_a_mostrar.append(lista_origen[cantidad - 1])
	if cantidad >= 2: cartas_a_mostrar.append(lista_origen[cantidad - 2])
	
	for i in range(cartas_a_mostrar.size()):
		var data = cartas_a_mostrar[i]
		var visual = card_scene.instantiate()
		add_child(visual)
		var offset_y = -120 - (i * 160)
		visual.global_position = posicion_base + Vector2(0, offset_y)
		visual.scale = Vector2(0.3, 0.3)
		visual.z_index = 200 
		visual.setup_card(data.suit * 13 + data.value, 0)
		visual.face_up = true; visual.update_visuals()
		if visual.has_node("CollisionShape2D"): visual.get_node("CollisionShape2D").disabled = true
		visual.modulate.a = 0
		var t = create_tween(); t.tween_property(visual, "modulate:a", 1.0, 0.2)
		cartas_preview.append(visual)

func limpiar_preview():
	for c in cartas_preview: if is_instance_valid(c): c.queue_free()
	cartas_preview.clear()
	monton_hover_actual = 0
