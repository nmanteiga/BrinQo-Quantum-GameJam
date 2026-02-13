extends Node
## Global autoload singleton for shared game state and utilities

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var music_player: AudioStreamPlayer = $MusicPlayer

func _ready() -> void:
	rng.randomize()
	
	# Add music player
	var player = AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	var stream = load("res://assets/sounds/music/QUARDS.mp3") as AudioStream
	stream.loop = true
	player.stream = stream
	player.volume_db = -2
	player.bus = "Music"
	player.autoplay = true
	add_child(player)
	music_player = player
