extends Control
## Main menu: host or join a co-op game, then move to the battle scene.


const BATTLE_SCENE: String = "res://core/BattleScene.tscn"

@onready var ip_input: LineEdit = %IPInput
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_host_pressed() -> void:
	NetworkManager.host_game()
	status_label.text = "Hosting on port 7777. Waiting for a partner..."


func _on_join_pressed() -> void:
	var ip: String = ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Enter the host IP first."
		return
	NetworkManager.join_game(ip)
	status_label.text = "Joining %s..." % ip


func _on_peer_connected(_id: int) -> void:
	# A second player has arrived (host side): start the battle on every peer.
	status_label.text = "Partner connected. Starting battle..."
	_start_battle.rpc()


func _on_connected_to_server() -> void:
	status_label.text = "Connected to host. Waiting for it to start..."


func _on_connection_failed() -> void:
	status_label.text = "Connection failed. Check the IP."


func _on_server_disconnected() -> void:
	status_label.text = "Disconnected from host."


@rpc("any_peer", "call_local", "reliable")
func _start_battle() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE)
