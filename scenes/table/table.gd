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
@onready var label_resultado = $CanvasLayer/PanelGameOver/ContenedorVertical/LabelResultado
@onready var boton_reinicio = %BotonReinicio
@onready var boton_menu = %BotonMenu
# AUDIO
@onready var audio: AudioStreamPlayer2D = $"AudioStream(Play)"
@onready var hover: AudioStreamPlayer2D = $"AudioStream(Hover)"
@onready var cuantico: AudioStreamPlayer2D = $"AudioStream(Cuantico)"

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
const MIN_RONDAS : int = 3
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
	
	if panel_game_over: 
		panel_game_over.visible = false
		panel_game_over.scale = Vector2(0, 0)
		panel_game_over.pivot_offset = panel_game_over.size / 2
	if boton_plantarse: boton_plantarse.pressed.connect(finalizar_partida)
	if boton_debug: boton_debug.pressed.connect(toggle_debug_vision)
	
	if boton_reinicio: boton_reinicio.pressed.connect(_on_reinicio_pressed)
	if boton_menu: boton_menu.pressed.connect(_on_menu_pressed)
	
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
	audio.play()
	var tween = create_tween()
	tween.tween_property(carta, "position", destino, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_callback(func(): carta.z_index = 1).set_delay(0.5)

# --- JUEGO ---
func jugar_carta_en_mesa(carta: Carta, zona: Node2D):
	var dest = zona_juego_p1.global_position if carta.controlled_by_player == 1 else zona_juego_p2.global_position
	if carta.controlled_by_player == 1: carta_jugada_p1 = carta
	else: carta_jugada_p2 = carta
	
	var lista = descartes_p1 if carta.controlled_by_player == 1 else descartes_p2
	var base_z = 20
	var new_z = base_z + lista.size() 
	carta.z_index = new_z
	
	carta.scale = carta.base_scale
	if carta.has_method("move_to_front"): carta.move_to_front()
	
	audio.play()
	var tween = create_tween()
	tween.tween_property(carta, "global_position", dest, 0.2)
	tween.parallel().tween_property(carta, "rotation_degrees", 0, 0.2)
	if carta.has_node("CollisionShape2D"): carta.get_node("CollisionShape2D").disabled = true 
	
	var slots = slots_jugador if carta.controlled_by_player == 1 else slots_rival
	slots.erase(carta.slot_index)
	
	if carta.controlled_by_player == 1: fase_actual = Fase.ANIMACION
	
	if carta_jugada_p1 and carta_jugada_p2: resolver_ronda()
	elif !carta_jugada_p2: turno_rival_ia_jugar()

func turno_rival_ia_jugar():
	await get_tree().create_timer(1.0).timeout 
	if fase_actual == Fase.GAME_OVER and ronda_actual > MIN_RONDAS: return
	
	if slots_rival.size() > 0:
		var carta_a_jugar = obtener_peor_carta_ia()
		if carta_a_jugar:
			jugar_carta_en_mesa(carta_a_jugar, zona_juego_p2)

func resolver_ronda():
	await get_tree().create_timer(1.0).timeout
	if fase_actual == Fase.GAME_OVER and ronda_actual > MIN_RONDAS: return
	
	if carta_jugada_p1: 
		carta_jugada_p1.face_up = false
		if carta_jugada_p1.es_superposicion: colapsar_superposicion(carta_jugada_p1) 
		resolver_entrelazamiento(carta_jugada_p1) 
		carta_jugada_p1.flip_card()
	if carta_jugada_p2: 
		carta_jugada_p2.face_up = false
		if carta_jugada_p2.es_superposicion: colapsar_superposicion(carta_jugada_p2)
		resolver_entrelazamiento(carta_jugada_p2)
		carta_jugada_p2.flip_card()
	
	await get_tree().create_timer(2.0).timeout 
	if fase_actual == Fase.GAME_OVER and ronda_actual > MIN_RONDAS: return
	
	gestionar_descarte(carta_jugada_p1, 1)
	gestionar_descarte(carta_jugada_p2, 2)
	carta_jugada_p1 = null; carta_jugada_p2 = null
	rellenar_manos_y_seguir()

func gestionar_descarte(carta: Carta, id: int):
	var lista = descartes_p1 if id == 1 else descartes_p2
	var base_z = 20
	var new_z = base_z + lista.size() 
	
	if is_instance_valid(carta):
		carta.z_index = new_z
		if carta.has_method("move_to_front"): carta.move_to_front()
		elif carta.has_method("raise"): carta.call("raise")

	lista.append(carta)
	if lista.size() > 2:
		var vieja = lista.pop_front()
		if is_instance_valid(vieja): vieja.queue_free()

	for i in range(lista.size()): lista[i].z_index = base_z + i
	
	var tween = create_tween()
	tween.tween_property(carta, "rotation_degrees", randf_range(-10, 10), 0.3)
	tween.parallel().tween_property(carta, "modulate", Color(0.7, 0.7, 0.7), 0.3)

func rellenar_manos_y_seguir():
	if fase_actual == Fase.GAME_OVER and ronda_actual > MIN_RONDAS: return
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
	if (fase_actual == Fase.GAME_OVER and ronda_actual > MIN_RONDAS) or fase_actual == Fase.ANIMACION: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		
		if fase_actual == Fase.EVENTO_ESPECIAL and estado_efecto_actual == EfectoCuantico.SELECCIONAR_MONTON_SUPERPOSICION:
			var mouse_pos = get_global_mouse_position()
			var radio_detect = 150.0 
			
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
	if fase_actual == Fase.GAME_OVER and ronda_actual > MIN_RONDAS: return
	var roll = randf()
	var efecto = 4 
	
	# Probabilidades
	if ronda_actual <= 2:
		if roll < 0.05: efecto = 3
		elif roll < 0.50: efecto = 4
		else: efecto = 1 
	else:
		if roll < 0.05: efecto = 3 
		elif roll < 0.35: efecto = 4
		elif roll < 0.55: efecto = 5 
		elif roll < 0.80: efecto = 1 
		else: 
			if descartes_p1.size() + descartes_p2.size() >= 2: efecto = 2
			else: efecto = 4
	
	if card_scene:
		var anim = card_scene.instantiate()
		add_child(anim)
		var origen = mazo_especial_visual.global_position if mazo_especial_visual else mazo_visual.global_position
		anim.global_position = origen
		anim.scale = Vector2(0.5, 0.5); anim.z_index = 100 
		anim.setup_quantum(efecto, 1 if es_jugador else 2)
		anim.face_up = true; anim.update_visuals()
		
		await get_tree().process_frame
		if anim.has_method("show_shadow"): anim.show_shadow()
		
		var centro = get_viewport_rect().size / 2
		var dest = centro + (Vector2(0, 160) if es_jugador else Vector2(0, -180))
		var tween = create_tween()
		tween.tween_property(anim, "global_position", dest, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		var target_scale = Vector2(0.6, 0.6) if es_jugador else Vector2(0.3, 0.3)
		tween.parallel().tween_property(anim, "scale", target_scale, 0.6)
		cuantico.play()
		await tween.finished
		
		if fase_actual == Fase.GAME_OVER and ronda_actual > MIN_RONDAS: return
		await get_tree().create_timer(2.5).timeout
		
		var sprite_node = anim.sprite
		var animated_node = anim.animated_quantum
		var shadow_node = anim.shadow
		var dissolve_ok = false
		
		if sprite_node and sprite_node.material:
			var tween_dissolve = create_tween()
			
			# Disolver el sprite principal
			tween_dissolve.tween_method(
				func(val): sprite_node.material.set_shader_parameter("dissolve_value", val),
				0.0, 1.0, 1.0
			)
			
			# Disolver overlay animado
			if animated_node and animated_node.visible and animated_node.material:
				tween_dissolve.parallel().tween_method(
					func(val): animated_node.material.set_shader_parameter("dissolve_value", val),
					0.0, 1.0, 1.0
				)
			
			# Disolver sombra
			if shadow_node and shadow_node.visible and shadow_node.material:
				tween_dissolve.parallel().tween_method(
					func(val): shadow_node.material.set_shader_parameter("dissolve_value", val),
					0.0, 1.0, 1.0
				)
			
			await tween_dissolve.finished
			dissolve_ok = true
		
		if not dissolve_ok:
			var tween_bye = create_tween()
			tween_bye.tween_property(anim, "scale", Vector2(0,0), 0.3)
			await tween_bye.finished
			
		anim.queue_free()
	
		if es_jugador:
			match efecto:
				1: iniciar_efecto_entrelazado()
				2: iniciar_efecto_superposicion()
				3: efecto_around_the_world(); await get_tree().create_timer(1).timeout; await pasar_a_turno_rival_cuantico()
				4: await efecto_not_cuantico(true); await pasar_a_turno_rival_cuantico()
				5: await iniciar_efecto_revelation(); await pasar_a_turno_rival_cuantico()
		else:
			# Lógica IA
			match efecto:
				1: ia_efecto_entrelazado() # Síncrono
				2: ia_efecto_superposicion() # Síncrono
				3: efecto_around_the_world() # Síncrono
				4: await efecto_not_cuantico(false) # Asíncrono (Animación)
				5: await ia_efecto_revelation() # Asíncrono (Animación)
			
			if efecto != 3 and efecto != 4 and efecto != 5:
				await get_tree().create_timer(1.0).timeout
			
			finalizar_fase_cuantica()
		
func finalizar_fase_cuantica():
	limpiar_preview()
	fase_actual = Fase.SELECCION
	estado_efecto_actual = EfectoCuantico.NINGUNO
	mirando_carta = false 
	
func iniciar_efecto_entrelazado():
	estado_efecto_actual = EfectoCuantico.SELECCIONAR_ENTRELAZADO_PROPIA

func iniciar_efecto_superposicion():
	estado_efecto_actual = EfectoCuantico.SELECCIONAR_SUPERPOSICION


# --- LIMPIEZA DE ESTADOS ---
func limpiar_estado_cuantico(carta: Carta):
	limpiar_preview()
	if carta.entrelazada_con and is_instance_valid(carta.entrelazada_con):
		var ex = carta.entrelazada_con
		ex.entrelazada_con = null
		ex.aplicar_efecto_visual_cuantico(Color.WHITE)
	carta.entrelazada_con = null
	carta.es_superposicion = false
	carta.opciones_superposicion.clear()
	carta.aplicar_efecto_visual_cuantico(Color.WHITE)

func gestionar_input_efectos(carta: Carta):
	match estado_efecto_actual:
		EfectoCuantico.SELECCIONAR_ENTRELAZADO_PROPIA:
			if carta.controlled_by_player == 1:
				limpiar_estado_cuantico(carta)
				carta_seleccionada_efecto = carta
				carta.aplicar_efecto_visual_cuantico(Color.CYAN)
				# Llamar al highlight visual (Corregido)
				if carta.has_method("show_entanglement_highlight"): carta.show_entanglement_highlight()
				estado_efecto_actual = EfectoCuantico.SELECCIONAR_ENTRELAZADO_RIVAL
				
		EfectoCuantico.SELECCIONAR_ENTRELAZADO_RIVAL:
			if carta.controlled_by_player == 2:
				limpiar_estado_cuantico(carta_seleccionada_efecto)
				limpiar_estado_cuantico(carta)
				
				# Enlace
				carta_seleccionada_efecto.entrelazada_con = carta
				carta.entrelazada_con = carta_seleccionada_efecto
				
				# Visuales
				carta.aplicar_efecto_visual_cuantico(Color.CYAN)
				carta_seleccionada_efecto.aplicar_efecto_visual_cuantico(Color.CYAN)
				
				if carta.has_method("show_entanglement_highlight"): carta.show_entanglement_highlight()
				if carta_seleccionada_efecto.has_method("show_entanglement_highlight"): 
					carta_seleccionada_efecto.show_entanglement_highlight()
				
				carta_seleccionada_efecto = null
				estado_efecto_actual = EfectoCuantico.NINGUNO
				await pasar_a_turno_rival_cuantico()
				
		EfectoCuantico.SELECCIONAR_SUPERPOSICION:
			if carta.controlled_by_player == 1:
				limpiar_estado_cuantico(carta)
				carta_seleccionada_efecto = carta
				carta.aplicar_efecto_visual_cuantico(Color.PURPLE)
				estado_efecto_actual = EfectoCuantico.SELECCIONAR_MONTON_SUPERPOSICION

func aplicar_superposicion_monton(lista_descartes: Array):
	limpiar_preview()
	
	if carta_seleccionada_efecto:
		var t = create_tween()
		t.tween_property(carta_seleccionada_efecto, "position:y", pos_jugador.position.y, 0.2)
		
		var posibles_ids = [] 
		
		if lista_descartes.size() >= 2:
			var c1 = lista_descartes[lista_descartes.size()-1]
			var c2 = lista_descartes[lista_descartes.size()-2]
			posibles_ids.append(c1.suit * 13 + c1.value)
			posibles_ids.append(c2.suit * 13 + c2.value)
		elif lista_descartes.size() == 1:
			var c1 = lista_descartes[0]
			posibles_ids.append(c1.suit * 13 + c1.value)
			posibles_ids.append(randi() % 52) 
		else:
			posibles_ids.append(randi() % 52)
			posibles_ids.append(randi() % 52)
			
		carta_seleccionada_efecto.es_superposicion = true
		carta_seleccionada_efecto.opciones_superposicion = posibles_ids
		
		carta_seleccionada_efecto = null
		estado_efecto_actual = EfectoCuantico.NINGUNO
	
	await pasar_a_turno_rival_cuantico()

func pasar_a_turno_rival_cuantico(): 
	await get_tree().create_timer(1.0).timeout
	robar_carta_cuantica(false)

func efecto_not_cuantico(es_jugador: bool):
	var target_slots = slots_jugador if es_jugador else slots_rival
	var candidatos_not : Array = [] # <--- Declaramos la variable correctamente
	
	for c in target_slots.values():
		# FILTRO: Solo cartas que NO tengan efectos ya aplicados
		if not c.es_superposicion and c.entrelazada_con == null:
			candidatos_not.append(c)
	
	if candidatos_not.size() > 0:
		var carta = candidatos_not.pick_random()
		var poder_viejo = obtener_poder_carta(carta.value)
		
		# Efecto visual de aviso (rojo)
		var tween_hl = create_tween()
		tween_hl.tween_property(carta, "modulate", Color(1, 0, 0), 0.3)
		tween_hl.tween_property(carta, "modulate", Color.WHITE, 0.3)
		await get_tree().create_timer(0.6).timeout
		
		# Lógica de inversión del valor
		var nuevo_poder = 14 - (poder_viejo - 1) # Inversión simple 1->14, 14->1
		var nuevo_valor_visual = 0
		if nuevo_poder == 14: nuevo_valor_visual = 0 # As
		else: nuevo_valor_visual = nuevo_poder - 1 
		
		carta.value = nuevo_valor_visual
		
		# Animación de transformación
		var tween = create_tween()
		tween.tween_property(carta, "scale", carta.base_scale * 1.3, 0.2)
		tween.parallel().tween_property(carta, "modulate", Color.YELLOW, 0.2)
		tween.tween_property(carta, "scale", carta.base_scale, 0.2)
		tween.parallel().tween_property(carta, "modulate", Color.WHITE, 0.2)
		
		if carta.face_up: carta.update_visuals()
	else:
		print("NOT: No hay cartas válidas (todas tienen efectos)")
		await get_tree().create_timer(0.5).timeout

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
	var id_elegido = c.opciones_superposicion.pick_random()
	c.suit = int(id_elegido / 13)
	c.value = id_elegido % 13
	c.es_superposicion = false
	c.aplicar_efecto_visual_cuantico(Color.WHITE)
	
	if c.has_method("update_visuals"):
		c.update_visuals()
		
func resolver_entrelazamiento(c):
	if not is_instance_valid(c): return

	if c.entrelazada_con and is_instance_valid(c.entrelazada_con):
		var pareja = c.entrelazada_con
		c.entrelazada_con = null
		if "entrelazada_con" in pareja: pareja.entrelazada_con = null
		
		pareja.value = c.value
		pareja.suit = c.suit 
		
		# Animación al copiarse
		var tween = create_tween()
		tween.tween_property(pareja, "modulate", Color.CYAN, 0.2)
		tween.tween_property(pareja, "modulate", Color.WHITE, 0.2)
		
		if pareja.face_up: pareja.update_visuals()
		c.aplicar_efecto_visual_cuantico(Color.WHITE)
		pareja.aplicar_efecto_visual_cuantico(Color.WHITE)
	else:
		c.entrelazada_con = null
		c.aplicar_efecto_visual_cuantico(Color.WHITE)
		
func ia_efecto_entrelazado():
	if slots_rival.size() > 0 and slots_jugador.size() > 0:
		var c1 = slots_rival.values().pick_random()
		var c2 = slots_jugador.values().pick_random()
		limpiar_estado_cuantico(c1)
		limpiar_estado_cuantico(c2)
		
		c1.entrelazada_con = c2; c2.entrelazada_con = c1
		c1.aplicar_efecto_visual_cuantico(Color.CYAN); c2.aplicar_efecto_visual_cuantico(Color.CYAN)
		
		if c1.has_method("show_entanglement_highlight"): c1.show_entanglement_highlight()
		if c2.has_method("show_entanglement_highlight"): c2.show_entanglement_highlight()
		print("IA Entrelazó cartas.")
	else:
		pass
func ia_efecto_superposicion():
	var candidatos_ia = []
	for c in slots_rival.values():
		if not c.es_superposicion and c.entrelazada_con == null:
			candidatos_ia.append(c)
			
	if candidatos_ia.size() > 0:
		var peor_carta = candidatos_ia[0]
		var menor_poder = 999
		for c in candidatos_ia:
			var poder = obtener_poder_carta(c.value)
			if poder < menor_poder:
				menor_poder = poder
				peor_carta = c
		aplicar_superposicion(peor_carta)

func aplicar_superposicion(carta: Carta):
	var ids = []
	if descartes_p1.size() > 0: 
		var c = descartes_p1.back()
		ids.append(c.suit * 13 + c.value)
	if descartes_p2.size() > 0: 
		var c = descartes_p2.back()
		ids.append(c.suit * 13 + c.value)
	
	while ids.size() < 2: 
		ids.append(randi() % 52)
		
	carta.es_superposicion = true
	carta.opciones_superposicion = ids 
	carta.aplicar_efecto_visual_cuantico(Color.PURPLE)

# --- FUNCIONES NUEVAS REVELATION ---
func aplicar_revelation_temporal(carta: Carta):
	if not is_instance_valid(carta): return
	mirando_carta = true
	if carta.es_superposicion: colapsar_superposicion(carta)
	carta.flip_card()
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(carta) and fase_actual != Fase.GAME_OVER:
		carta.flip_card() 
		await get_tree().create_timer(0.3).timeout
	mirando_carta = false 

func iniciar_efecto_revelation():
	var candidatos : Array[Carta] = []
	for c in slots_jugador.values(): if not c.face_up: candidatos.append(c)
	for c in slots_rival.values(): if not c.face_up: candidatos.append(c)
	if candidatos.size() > 0:
		var elegida = candidatos.pick_random()
		await aplicar_revelation_temporal(elegida)
	else:
		await get_tree().create_timer(1.0).timeout

func ia_efecto_revelation():
	var candidatos : Array[Carta] = []
	for c in slots_jugador.values(): if not c.face_up: candidatos.append(c)
	if candidatos.is_empty():
		for c in slots_rival.values(): if not c.face_up: candidatos.append(c)
	if candidatos.size() > 0:
		var elegida = candidatos.pick_random()
		await aplicar_revelation_temporal(elegida)
	else:
		await get_tree().create_timer(1.0).timeout


# UTILS
func activar_vista_temporal(c):
	mirando_carta = true; cartas_vistas_ronda += 1; c.face_up = false
	resolver_entrelazamiento(c); if c.es_superposicion: colapsar_superposicion(c)
	c.flip_card()
	await get_tree().create_timer(2).timeout
	c.flip_card()
	animacion_ia_mirando()

func animacion_ia_mirando():
	await get_tree().create_timer(0.5).timeout
	if fase_actual == Fase.GAME_OVER and ronda_actual > MIN_RONDAS: return
	if slots_rival.size() > 0:
		var c = slots_rival.values().pick_random()
		var t = create_tween()
		t.tween_property(c, "position", c.position + Vector2(0,30), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(1.5).timeout
		t = create_tween(); t.tween_property(c, "position", c.position - Vector2(0,30), 0.3)
		audio.play()
	mirando_carta = false

func start_drag(c): 
	carta_en_movimiento = c
	c.scale = c.base_scale * 1.2
	c.z_index = 50 
	if c.has_method("show_shadow"): c.show_shadow()

func finish_drag():
	if carta_en_movimiento:
		if carta_en_movimiento.has_method("hide_shadow"): carta_en_movimiento.hide_shadow()
		var dest = check_slot_carta()
		if dest and fase_actual == Fase.SELECCION: jugar_carta_en_mesa(carta_en_movimiento, dest)
		else: devolver_carta_a_mano(carta_en_movimiento)
		carta_en_movimiento = null

func devolver_carta_a_mano(c):
	var dest = (pos_jugador if c.controlled_by_player==1 else pos_rival).position + Vector2(208 * c.slot_index, 0)
	var t = create_tween(); t.tween_property(c, "position", dest, 0.3)
	c.rotation_degrees = 0; c.scale = c.base_scale; c.z_index = 1
	if c.has_method("hide_shadow"): c.hide_shadow()
	if c.has_node("CollisionShape2D"): c.get_node("CollisionShape2D").disabled = false

func connect_card_signals(c):
	if !c.is_connected("hovered", on_hovered_over_card): c.connect("hovered", on_hovered_over_card)
	if !c.is_connected("hovered_off", on_hovered_off_card): c.connect("hovered_off", on_hovered_off_card)

func on_hovered_over_card(c): 
	if fase_actual == Fase.SELECCION and !mirando_carta and !carta_en_movimiento: 
		if carta_hovered != c:
			hover.pitch_scale = randf_range(0.9, 1.2)
			hover.play()
		carta_hovered = c
		highlight_card(c, true, 0)
func on_hovered_off_card(c): 
	if !carta_en_movimiento: 
		highlight_card(c, false, 0); var n = check_carta()
		if n and n is Carta: highlight_card(n, true, 0)
		else: carta_hovered = null

func highlight_card(c, h, i): 
	if is_instance_valid(c) and c is Carta:
		if c.z_index == 100: return
		if c.z_index >= 20 and c.z_index <= 40: return
		c.scale = c.base_scale * (1.2 if h else 1.0)
		c.z_index = 10 if h else 1
		
		# Apply outline shader effect
		if c.entrelazada_con != null :
			if i == 0:
				highlight_card(c.entrelazada_con, h, 1)
			if c.sprite and c.sprite.material and c.sprite.material is ShaderMaterial:
				c.sprite.material.set_shader_parameter("outline_enabled", h)
				c.sprite.material.set_shader_parameter("outline_add_margins", h)

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

func obtener_peor_carta_ia() -> Carta:
	var candidatos = slots_rival.values()
	if candidatos.is_empty(): return null
	var peor_carta = candidatos[0]; var menor_poder = 999
	for c in candidatos:
		var poder = obtener_poder_carta(c.value)
		if poder < menor_poder:
			menor_poder = poder; peor_carta = c
	return peor_carta

func actualizar_ui_ronda(): 
	if label_ronda: label_ronda.text = "Ronda: " + str(ronda_actual) + " / " + str(MAX_RONDAS)
	if boton_plantarse: boton_plantarse.disabled = (ronda_actual < MIN_RONDAS)

func finalizar_partida():
	if ronda_actual < MIN_RONDAS: return 
	fase_actual = Fase.GAME_OVER
	carta_en_movimiento = null; mirando_carta = false; carta_hovered = null
	
	for i in range(4):
		if not slots_jugador.has(i): crear_carta_normal(pos_jugador, 1)
		if not slots_rival.has(i): crear_carta_normal(pos_rival, 2)
	await get_tree().process_frame; await get_tree().process_frame
	for c in slots_jugador.values(): c.face_up = true; c.update_visuals()
	for c in slots_rival.values(): c.face_up = true; c.update_visuals()
	
	#var p1 = calcular_puntos_mano(slots_jugador); var p2 = calcular_puntos_mano(slots_rival)
	#var txt = "¡HAS GANADO!\n" if p1 > p2 else ("¡HAS PERDIDO!\n" if p2 > p1 else "¡EMPATE!\n")
	#txt += "Tus puntos: " + str(p1) + "\nRival: " + str(p2)
	#if label_resultado: label_resultado.text = txt
	#if panel_game_over: panel_game_over.visible = true
	#if boton_plantarse: boton_plantarse.visible = false
	var p1 = calcular_puntos_mano(slots_jugador)
	var p2 = calcular_puntos_mano(slots_rival)
	var txt = "[center]"
	
	if p1 > p2:
		txt += "[color=#2ecc71][wave amp=50 freq=2]OPTIMAL TIMELINE![/wave][/color]\nYou win\n\n"
	elif p2 > p1:
		txt += "[color=#ff3333][shake rate=30 level=15]WAVEFUNCTION COLLAPSED[/shake][/color]\nYou lose\n\n"
	else:
		txt += "[color=#b666ff][wave amp=60 freq=5]SUPERPOSITION![/wave][/color]\nQuantum Draw\n\n"
		
	txt += "Your score: " + str(p1) + "\nRival: " + str(p2) + "[/center]"
	
	if label_resultado: 
		label_resultado.text = txt
		
	if boton_plantarse: boton_plantarse.visible = false
	if panel_game_over:
		panel_game_over.visible = true
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel_game_over, "scale", Vector2(1.0, 1.0), 0.5)
	
func calcular_puntos_mano(slots_dict):
	var total = 0
	for carta in slots_dict.values(): total += obtener_poder_carta(carta.value)
	return total
	

# DEBUG
func toggle_debug_vision():
	debug_abierto = !debug_abierto
	for carta in slots_rival.values(): carta.face_up = debug_abierto; carta.update_visuals()
	for carta in slots_jugador.values(): carta.face_up = true; carta.update_visuals()
	if carta_jugada_p1: carta_jugada_p1.face_up = true; carta_jugada_p1.update_visuals()
	if carta_jugada_p2: carta_jugada_p2.face_up = true; carta_jugada_p2.update_visuals()

# PREVIEW 
func gestionar_preview_montones():
	var mouse_pos = get_global_mouse_position()
	var radio = 150.0 
	var nuevo_monton = 0
	if mouse_pos.distance_to(zona_juego_p1.global_position) < radio: nuevo_monton = 1
	elif mouse_pos.distance_to(zona_juego_p2.global_position) < radio: nuevo_monton = 2
	
	if nuevo_monton != monton_hover_actual:
		limpiar_preview(); monton_hover_actual = nuevo_monton
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
		visual.z_index = 250 
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


func _on_reinicio_pressed():
	get_tree().reload_current_scene()

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/title_screen.tscn")
