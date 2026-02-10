extends Node2D

@onready var viewport = $SubViewport
var currently_hovered = null

func _input(event):
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
