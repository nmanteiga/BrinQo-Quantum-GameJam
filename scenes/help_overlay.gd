extends Control

# --- CONFIGURACIÓN ---
@export var portada_texture : Texture2D
@export var paginas_textures : Array[Texture2D]

# --- REFERENCIAS ---
@onready var book_container = $BookContainer
@onready var cover_image = $BookContainer/CoverImage
@onready var pages_container = $BookContainer/PagesContainer

# REFERENCIAS A LAS DOS PÁGINAS
@onready var pag_izq = $BookContainer/PagesContainer/HBoxContainer/PaginaIzq
@onready var pag_der = $BookContainer/PagesContainer/HBoxContainer/PaginaDer

@onready var next_button = $BookContainer/PagesContainer/NextButton
@onready var close_button = $BookContainer/PagesContainer/CloseButton

# Si quieres botón "Anterior", crea un botón llamado PrevButton y descomenta esto:
# @onready var prev_button = $BookContainer/PagesContainer/PrevButton

@onready var timer_portada = $TimerPortada
@onready var anim_player = $AnimationPlayer

var indice_doble_pagina = 0 # 0 = pgs 1-2, 1 = pgs 3-4...
var manual_abierto = false

signal on_close 

func _ready():
	visible = false
	pages_container.visible = false
	
	if timer_portada:
		if not timer_portada.timeout.is_connected(_abrir_libro):
			timer_portada.timeout.connect(_abrir_libro)
	
	next_button.pressed.connect(_siguiente_pagina)
	close_button.pressed.connect(_cerrar_manual)
	
	# Conexión botón anterior (opcional)
	# if has_node("BookContainer/PagesContainer/PrevButton"):
	# 	$BookContainer/PagesContainer/PrevButton.pressed.connect(_pagina_anterior)
	
	if portada_texture and cover_image:
		cover_image.texture = portada_texture

func iniciar_manual():
	visible = true
	manual_abierto = true
	indice_doble_pagina = 0
	
	# Reset visual
	if book_container: book_container.scale = Vector2(1, 1)
	if cover_image: cover_image.visible = true
	pages_container.visible = false
	
	# Animación entrada
	if anim_player.has_animation("entrada_desde_abajo"):
		anim_player.play("entrada_desde_abajo")
		await anim_player.animation_finished
		if timer_portada: timer_portada.start(3.0)
	else:
		if timer_portada: timer_portada.start(1.0)

func _abrir_libro():
	# Animación abrir
	if anim_player.has_animation("abrir_libro_zoom"):
		anim_player.play("abrir_libro_zoom")
	else:
		cover_image.visible = false 
	
	pages_container.visible = true
	_actualizar_paginas()

func _actualizar_paginas():
	# Calculamos qué índices tocan
	var idx_izq = indice_doble_pagina * 2
	var idx_der = idx_izq + 1
	
	# Poner página izquierda
	if idx_izq < paginas_textures.size():
		pag_izq.texture = paginas_textures[idx_izq]
		pag_izq.visible = true
	else:
		pag_izq.visible = false # No hay página
		
	# Poner página derecha
	if idx_der < paginas_textures.size():
		pag_der.texture = paginas_textures[idx_der]
		pag_der.visible = true
	else:
		pag_der.visible = false # Es la última impar
	
	_actualizar_botones()

func _siguiente_pagina():
	# Avanzamos al siguiente par
	indice_doble_pagina += 1
	
	# Comprobamos si nos hemos pasado del total de pares
	var total_pares = ceil(paginas_textures.size() / 2.0)
	
	if indice_doble_pagina < total_pares:
		_actualizar_paginas()
	else:
		_cerrar_manual()

func _pagina_anterior():
	if indice_doble_pagina > 0:
		indice_doble_pagina -= 1
		_actualizar_paginas()

func _actualizar_botones():
	var total_pares = ceil(paginas_textures.size() / 2.0)
	
	if indice_doble_pagina == total_pares - 1:
		next_button.text = "CLOSE"
	else:
		next_button.text = "NEXT >"

func _cerrar_manual():
	if not manual_abierto: return
	manual_abierto = false
	
	if anim_player.has_animation("entrada_desde_abajo"):
		anim_player.play_backwards("entrada_desde_abajo")
		await anim_player.animation_finished
	
	visible = false
	emit_signal("on_close")
