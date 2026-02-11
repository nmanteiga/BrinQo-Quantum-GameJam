extends Node
## Global autoload singleton for shared game state and utilities

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
