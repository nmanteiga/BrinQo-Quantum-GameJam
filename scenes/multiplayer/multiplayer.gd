extends Node2D

const PORT = 42069
const DEFAULT_SERVER_ADDRESS = "localhost"

var peer = ENetMultiplayerPeer.new()
var local_player_id = 1
var players_ready = {}
@export var player_field_scene : PackedScene
@onready var ip_input = $IPInput

func _on_host_pressed() -> void:
	disable_buttons()
	local_player_id = 1
	peer.create_server(PORT)
	
	multiplayer.multiplayer_peer = peer
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	players_ready[1] = true
	print("Host ready, waiting for client...")
	# Don't spawn game yet, wait for client to connect
	
func _on_join_pressed() -> void:
	disable_buttons()
	local_player_id = 2
	
	# Get IP from input field, use default if empty
	var server_address = ip_input.text.strip_edges()
	if server_address.is_empty():
		server_address = DEFAULT_SERVER_ADDRESS
	
	print("Connecting to: ", server_address)
	peer.create_client(server_address, PORT)
	
	multiplayer.multiplayer_peer = peer
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	# Client will spawn game when server tells it to
	
func _on_peer_connected(peer_id):
	print("Player ", peer_id, " joined!")
	players_ready[peer_id] = true
	
	# If both players ready, spawn game on both
	if multiplayer.is_server() and players_ready.size() == 2:
		print("Both players connected, starting game...")
		# Spawn on server
		spawn_player_scene()
		# Tell client to spawn
		rpc_spawn_game.rpc()

@rpc("authority", "call_remote", "reliable")
func rpc_spawn_game():
	spawn_player_scene()

func spawn_player_scene():
	var player_scene = player_field_scene.instantiate()
	player_scene.local_player_id = local_player_id
	print("Spawning table for player", local_player_id)
	add_child(player_scene)
	await player_scene.ready
	print("Tabla scene ready for player",local_player_id)
	
func _on_peer_disconnected(peer_id):
	print("Player ", peer_id, " disconnected")
	players_ready.erase(peer_id)

func _on_connected_to_server():
	print("Successfully connected to server")
	local_player_id = 2
	players_ready[multiplayer.get_unique_id()] = true

func _on_connection_failed():
	print("Connection failed")

func disable_buttons():
	$Host.disabled = true
	$Host.visible = false
	$Join.disabled = true
	$Join.visible = false
	ip_input.visible = false
	ip_input.editable = false
