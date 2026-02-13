extends Button

func _ready():
	var callable = Callable(self, "_on_pressed")
	if not pressed.is_connected(callable):
		connect("pressed", callable)

func _on_pressed():
	print("[button_debug] pressed: %s" % get_path())
