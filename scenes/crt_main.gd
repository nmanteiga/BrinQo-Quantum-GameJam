extends Node2D

@onready var viewport = $SubViewport
@onready var help_button = $SubViewport/UILayer/HelpButton
@onready var help_overlay = $SubViewport/UILayer/HelpOverlay
@onready var close_button = $SubViewport/UILayer/HelpOverlay/MarginContainer/VBoxContainer/CloseButton
@onready var table = $SubViewport/table
@onready var music_player = $SubViewport/MusicPlayer

var currently_hovered = null
var is_paused = false

func _ready():
	help_button.pressed.connect(_on_help_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	# Store initial playback position
	if music_player:
		music_player.set_meta("was_playing", true)

func _input(event):
	# Handle ESC key to close overlay
	if event.is_action_pressed("ui_cancel") and is_paused:
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		viewport.push_input(event)
	
	# Only do hover detection when not paused
	if event is InputEventMouseMotion and not is_paused:
		var mouse_pos = event.position
		var space_state = viewport.world_2d.direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = mouse_pos
		query.collide_with_areas = true
		query.collide_with_bodies = false
		
		var results = space_state.intersect_point(query)
		
		var found_card = null
		for result in results:
			if result.collider.has_method("_on_mouse_entered"):
				found_card = result.collider
				break
		
		# Handle hover changes
		if found_card != currently_hovered:
			if currently_hovered and currently_hovered.has_method("_on_mouse_exited"):
				currently_hovered._on_mouse_exited()
			if found_card:
				found_card._on_mouse_entered()
			currently_hovered = found_card

func _on_help_button_pressed():
	show_help_overlay()

func _on_close_button_pressed():
	hide_help_overlay()

func show_help_overlay():
	help_overlay.visible = true
	is_paused = true
	# Reduce music volume instead of filter (more reliable)
	var music_bus = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music_bus, -15.0)  # Quieter
	# OR enable filter effect on Master bus
	# AudioServer.set_bus_effect_enabled(0, 0, true)

func hide_help_overlay():
	help_overlay.visible = false
	is_paused = false
	# Restore music volume
	var music_bus = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music_bus, 0.0)  # Normal volume
	# OR disable filter effect on Master bus
	# AudioServer.set_bus_effect_enabled(0, 0, false)
