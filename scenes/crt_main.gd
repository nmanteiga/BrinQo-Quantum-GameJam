extends Node2D

@onready var viewport = $SubViewport
@onready var help_button = $UILayer/HelpButton
@onready var help_overlay = $UILayer/HelpOverlay
@onready var close_button = $UILayer/HelpOverlay/MarginContainer/VBoxContainer/CloseButton

var currently_hovered = null
var is_paused = false

func _ready():
	help_button.pressed.connect(_on_help_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)

func _input(event):
	# Handle ESC key to close overlay
	if event.is_action_pressed("ui_cancel") and is_paused:
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		viewport.push_input(event)
	
	# Manually trigger hover detection
	if event is InputEventMouseMotion:
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
	get_tree().paused = true

func hide_help_overlay():
	help_overlay.visible = false
	is_paused = false
	get_tree().paused = false
