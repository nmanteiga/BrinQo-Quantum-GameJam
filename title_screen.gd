extends Control

@export_group("Referencias")
@export var start_button: Button
@export var start_panel: Control 
@export var exit_button: Button
@export var exit_panel: Control 
@export var tutorial_button: Button
@export var tutorial_panel: Control

@onready var viewport = $ColorRect2/ViewportContainer/SubViewport

var currently_hovered = null

func _ready():
	if start_button and start_panel:
		setup_quantum_button(start_button, start_panel)
	
	if exit_button and exit_panel:
		setup_quantum_button(exit_button, exit_panel)

	if tutorial_button and tutorial_panel:
		setup_quantum_button(tutorial_button, tutorial_panel)
	else:
		#print("OJO: Faltan asignar los nodos de Tutorial en el Inspector")
		pass

func setup_quantum_button(btn: Button, pnl: Control):
	if not btn.mouse_entered.is_connected(_on_hover.bind(pnl, true)):
		btn.mouse_entered.connect(_on_hover.bind(pnl, true))
	if not btn.mouse_exited.is_connected(_on_hover.bind(pnl, false)):
		btn.mouse_exited.connect(_on_hover.bind(pnl, false))
	
	pnl.pivot_offset = pnl.size / 2
	
	var mat = pnl.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("chaos", 0.0)
		mat.set_shader_parameter("border_thickness", 2.0)

func _on_hover(pnl: Control, hovered: bool):
	var mat = pnl.material as ShaderMaterial
	if not mat: return
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if hovered:
		tween.tween_property(mat, "shader_parameter/chaos", 20.0, 0.2)
		tween.tween_property(mat, "shader_parameter/border_thickness", 5.0, 0.2)
		tween.tween_property(pnl, "scale", Vector2(1.1, 1.1), 0.15)
		
	else:
		tween.tween_property(mat, "shader_parameter/chaos", 0.0, 0.3)
		tween.tween_property(mat, "shader_parameter/border_thickness", 2.0, 0.2)
		tween.tween_property(pnl, "scale", Vector2(1.0, 1.0), 0.15)

func _on_start_button_pressed():
	print("[title_screen] Start button pressed")
	get_tree().change_scene_to_file("res://scenes/crt_main.tscn")

func _on_exit_button_pressed():
	print("[title_screen] Exit button pressed")
	get_tree().quit()

func _on_tutorial_button_pressed():
	print("Tutorial clicado (Aún sin función)")

func _input(event):
	# Let the SubViewport and its Controls handle input locally
	pass
