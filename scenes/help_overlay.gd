extends Control

# --- CONFIGURACIÓN ---
@export var portada_texture : Texture2D
@export var paginas_textures : Array[Texture2D]

# --- REFERENCIAS INTERNAS ---
@onready var book_container = $BookContainer
@onready var cover_image = $BookContainer/CoverImage
@onready var pages_container = $BookContainer/PagesContainer
@onready var scroll_container = $BookContainer/PagesContainer/ScrollContainer
@onready var page_content = $BookContainer/PagesContainer/ScrollContainer/PageContent
@onready var timer_portada = $TimerPortada
@onready var anim_player = $AnimationPlayer
@onready var next_button = $BookContainer/PagesContainer/NextButton
@onready var close_button = $BookContainer/PagesContainer/CloseButton

# --- VARIABLES ---
var pagina_actual_idx = 0
var manual_abierto = false
signal on_close 

func _ready():
	# Inicialización
	visible = false
	pages_container.visible = false 
	cover_image.visible = true      
	timer_portada.timeout.connect(_abrir_libro)
	next_button.pressed.connect(_siguiente_pagina)
	close_button.pressed.connect(_cerrar_manual)
	
	if portada_texture:
		cover_image.texture = portada_texture

func iniciar_manual():
	visible = true
	manual_abierto = true
	pagina_actual_idx = 0
	book_container.scale = Vector2(1, 1)
	cover_image.visible = true
	cover_image.modulate.a = 1.0
	pages_container.visible = false
	anim_player.play("entrada_desde_abajo")
	
	await anim_player.animation_finished
	timer_portada.start(3.0) 

func _abrir_libro():
	anim_player.play("abrir_libro_zoom")
	
	if paginas_textures.size() > 0:
		page_content.texture = paginas_textures[0]
	
	pages_container.visible = true
	scroll_container.scroll_vertical = 0
	_actualizar_botones()

func _siguiente_pagina():
	pagina_actual_idx += 1
	
	if pagina_actual_idx < paginas_textures.size():
		var tween = create_tween()
		tween.tween_property(page_content, "modulate:a", 0.0, 0.1)
		tween.tween_callback(func(): 
			page_content.texture = paginas_textures[pagina_actual_idx]
			scroll_container.scroll_vertical = 0 # Volver arriba al cambiar página
		)
		tween.tween_property(page_content, "modulate:a", 1.0, 0.1)
		
		_actualizar_botones()
	else:
		_cerrar_manual()

func _actualizar_botones():
	if pagina_actual_idx == paginas_textures.size() - 1:
		next_button.text = "FINISH"
	else:
		next_button.text = "NEXT >"

func _cerrar_manual():
	if not manual_abierto: return
	manual_abierto = false
	
	anim_player.play_backwards("entrada_desde_abajo")
	await anim_player.animation_finished
	
	visible = false
	emit_signal("on_close")
