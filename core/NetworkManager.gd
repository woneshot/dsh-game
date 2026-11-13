extends Node
## Hosts or joins a co-op battle over ENet (UDP) on a fixed port.


const DEFAULT_PORT: int = 7777

var _peer: ENetMultiplayerPeer = null


## Start a server on the default port.
func host_game() -> void:
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_server(DEFAULT_PORT)
	if err != OK:
		push_error("NetworkManager: failed to host on port %d (error %d)." % [DEFAULT_PORT, err])
		return
	multiplayer.multiplayer_peer = _peer
	print("NetworkManager: hosting on port %d." % DEFAULT_PORT)


## Connect to a host at the given IP address.
func join_game(ip: String) -> void:
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_client(ip, DEFAULT_PORT)
	if err != OK:
		push_error("NetworkManager: failed to join %s:%d (error %d)." % [ip, DEFAULT_PORT, err])
		return
	multiplayer.multiplayer_peer = _peer
	print("NetworkManager: joining %s:%d." % [ip, DEFAULT_PORT])


## Number of remote peers currently connected.
func connected_peer_count() -> int:
	return multiplayer.get_peers().size()


## Whether the local player has at least one remote peer.
func has_peer() -> bool:
	return connected_peer_count() > 0
