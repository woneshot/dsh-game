extends Control
## Authoritative battle state for the co-op fight, synchronized over RPC.
## EnemyView/CardView are the partner's scenes; they are driven through their
## documented method/signal contract via call()/connect() so this file does not
## statically depend on those scripts.


const EnemyViewScene: String = "res://ui_entities/EnemyView.tscn"
const CardViewScene: String = "res://ui_entities/CardView.tscn"

enum Phase { PLAYER, ENEMY, VICTORY, DEFEAT }

const MAX_ENERGY: int = 3
const PLAYER_MAX_HP: int = 100

var player_hp: int = PLAYER_MAX_HP
var phase: int = Phase.PLAYER
var boss_index: int = 0
var boss_hp: int = 0
var boss_max_hp: int = 0

var _energy_by_peer: Dictionary = {}
var _shield_by_peer: Dictionary = {}
var _buff_by_peer: Dictionary = {}
var _end_turn_peers: Dictionary = {}

var _enemy_view: Node = null
var _card_entries: Array[Dictionary] = []

@onready var hp_label: Label = %HPLabel
@onready var energy_label: Label = %EnergyLabel
@onready var phase_label: Label = %PhaseLabel
@onready var boss_label: Label = %BossLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var enemy_container: Node = %EnemyContainer
@onready var hand_container: Node = %HandContainer


func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	_reset_turn_state()
	_spawn_boss()
	_spawn_cards()
	_refresh_ui()


func _all_peer_ids() -> Array[int]:
	var ids: Array[int] = [multiplayer.get_unique_id()]
	for peer in multiplayer.get_peers():
		ids.append(int(peer))
	return ids


func _reset_turn_state() -> void:
	for id in _all_peer_ids():
		_energy_by_peer[id] = MAX_ENERGY
		_shield_by_peer[id] = 0


func _spawn_boss() -> void:
	var boss_id: String = str(GameData.BOSS_SEQUENCE[boss_index])
	var boss: Dictionary = GameData.BOSSES.get(boss_id, {})
	boss_max_hp = int(boss.get("max_hp", 80))
	boss_hp = boss_max_hp
	for child in enemy_container.get_children():
		child.queue_free()
	_enemy_view = null
	if ResourceLoader.exists(EnemyViewScene):
		var scene: PackedScene = load(EnemyViewScene) as PackedScene
		_enemy_view = scene.instantiate()
		enemy_container.add_child(_enemy_view)
		_enemy_view.call("setup", boss_id, boss_max_hp)
		_enemy_view.call("update_state", boss_hp, 0, _intent_text())
	else:
		var label := Label.new()
		label.text = "Enemy placeholder: %s" % boss.get("name", boss_id)
		enemy_container.add_child(label)


func _spawn_cards() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	_card_entries.clear()
	for skill_id_raw in GameData.SKILLS:
		var skill_id: String = str(skill_id_raw)
		var skill: Dictionary = GameData.SKILLS[skill_id]
		var cost: int = int(skill.get("cost", 0))
		var entry: Dictionary = {"skill_id": skill_id, "cost": cost}
		if ResourceLoader.exists(CardViewScene):
			var scene: PackedScene = load(CardViewScene) as PackedScene
			var view: Node = scene.instantiate()
			hand_container.add_child(view)
			view.connect("card_clicked", _on_card_clicked)
			view.call("setup", skill_id, skill.get("title", skill_id), cost, skill.get("description", ""), null)
			entry["view"] = view
		else:
			var btn := Button.new()
			btn.text = "%s (%d)" % [skill.get("title", skill_id), cost]
			btn.pressed.connect(_on_card_clicked.bind(skill_id))
			hand_container.add_child(btn)
			entry["button"] = btn
		_card_entries.append(entry)


func _intent_text() -> String:
	if phase == Phase.VICTORY or phase == Phase.DEFEAT:
		return "-"
	var boss: Dictionary = GameData.BOSSES.get(str(GameData.BOSS_SEQUENCE[boss_index]), {})
	return "Attack %d" % int(boss.get("attack", 8))


func _on_card_clicked(skill_id: String) -> void:
	if phase != Phase.PLAYER:
		return
	_play_skill.rpc(skill_id)


func _on_end_turn_pressed() -> void:
	if phase != Phase.PLAYER:
		return
	_end_turn.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _play_skill(skill_id: String) -> void:
	if not multiplayer.is_server():
		return
	if phase != Phase.PLAYER:
		return
	var who: int = multiplayer.get_remote_sender_id()
	if who == 0:
		who = multiplayer.get_unique_id()
	var skill: Dictionary = GameData.SKILLS.get(skill_id, {})
	if skill.is_empty():
		return
	var cost: int = int(skill.get("cost", 0))
	var current_energy: int = int(_energy_by_peer.get(who, 0))
	if current_energy < cost:
		return
	_energy_by_peer[who] = current_energy - cost
	var shield: int = int(skill.get("shield", 0))
	var buff: int = int(skill.get("buff", 0))
	var heal: int = int(skill.get("heal", 0))
	var damage: int = int(skill.get("damage", 0))
	if shield > 0:
		_shield_by_peer[who] = int(_shield_by_peer.get(who, 0)) + shield
	if buff > 0:
		_buff_by_peer[who] = int(_buff_by_peer.get(who, 0)) + buff
	if heal > 0:
		player_hp = mini(player_hp + heal, PLAYER_MAX_HP)
	if damage > 0:
		var bonus: int = int(_buff_by_peer.get(who, 0))
		_buff_by_peer[who] = 0
		var total: int = damage + bonus
		boss_hp = maxi(boss_hp - total, 0)
		_enemy_took_damage.rpc(total)
		if boss_hp <= 0:
			_advance_boss()
			return
	_broadcast_state()


@rpc("any_peer", "call_local", "reliable")
func _end_turn() -> void:
	if not multiplayer.is_server():
		return
	if phase != Phase.PLAYER:
		return
	var who: int = multiplayer.get_remote_sender_id()
	if who == 0:
		who = multiplayer.get_unique_id()
	_end_turn_peers[who] = true
	var required: int = multiplayer.get_peers().size() + 1
	if _end_turn_peers.size() >= required:
		_end_turn_peers.clear()
		_enemy_phase()


func _enemy_phase() -> void:
	phase = Phase.ENEMY
	_broadcast_state()
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(_resolve_enemy_attack)


func _resolve_enemy_attack() -> void:
	if not multiplayer.is_server():
		return
	if phase != Phase.ENEMY:
		return
	if _enemy_view != null:
		_enemy_attacked.rpc()
	var boss: Dictionary = GameData.BOSSES.get(str(GameData.BOSS_SEQUENCE[boss_index]), {})
	var attack: int = int(boss.get("attack", 8))
	var target: int = _pick_target()
	var shield: int = int(_shield_by_peer.get(target, 0))
	var absorbed: int = mini(shield, attack)
	_shield_by_peer[target] = shield - absorbed
	player_hp = maxi(player_hp - (attack - absorbed), 0)
	_reset_turn_state()
	phase = Phase.PLAYER
	_broadcast_state()
	if player_hp <= 0:
		_defeat()


func _pick_target() -> int:
	var ids: Array[int] = _all_peer_ids()
	return ids[randi() % ids.size()]


func _advance_boss() -> void:
	boss_index += 1
	if boss_index >= GameData.BOSS_SEQUENCE.size():
		phase = Phase.VICTORY
		_end_turn_peers.clear()
		_broadcast_state()
		return
	_spawn_boss()
	_broadcast_state()


func _defeat() -> void:
	phase = Phase.DEFEAT
	_end_turn_peers.clear()
	_broadcast_state()


@rpc("any_peer", "call_local", "reliable")
func _enemy_took_damage(damage: int) -> void:
	if _enemy_view != null:
		_enemy_view.call("play_hit_anim", damage)


@rpc("any_peer", "call_local", "reliable")
func _enemy_attacked() -> void:
	if _enemy_view != null:
		_enemy_view.call("play_attack_anim")


func _broadcast_state() -> void:
	_sync_state.rpc(player_hp, boss_hp, boss_index, phase, _energy_by_peer, _shield_by_peer, _buff_by_peer)


@rpc("any_peer", "call_local", "reliable")
func _sync_state(php: int, bhp: int, bidx: int, ph: int, energy: Dictionary, shields: Dictionary, buffs: Dictionary) -> void:
	player_hp = php
	phase = ph
	if bidx != boss_index:
		boss_index = bidx
		if bidx < GameData.BOSS_SEQUENCE.size():
			_spawn_boss()
	boss_hp = bhp
	_energy_by_peer = energy
	_shield_by_peer = shields
	_buff_by_peer = buffs
	_refresh_ui()


func _refresh_ui() -> void:
	hp_label.text = "HP: %d/%d" % [player_hp, PLAYER_MAX_HP]
	var local_id: int = multiplayer.get_unique_id()
	energy_label.text = "Energy: %d/%d" % [int(_energy_by_peer.get(local_id, 0)), MAX_ENERGY]
	phase_label.text = _phase_text()
	boss_label.text = _boss_text()
	end_turn_button.disabled = phase != Phase.PLAYER
	if _enemy_view != null:
		_enemy_view.call("update_state", boss_hp, 0, _intent_text())
	_refresh_cards()


func _refresh_cards() -> void:
	var local_id: int = multiplayer.get_unique_id()
	var local_energy: int = int(_energy_by_peer.get(local_id, 0))
	for entry in _card_entries:
		var e: Dictionary = entry
		var usable: bool = phase == Phase.PLAYER and local_energy >= int(e.get("cost", 0))
		if e.has("view"):
			var view: Node = e["view"]
			view.call("set_usable", usable)
		elif e.has("button"):
			var button: Button = e["button"]
			button.disabled = not usable


func _phase_text() -> String:
	match phase:
		Phase.PLAYER:
			return "Player phase"
		Phase.ENEMY:
			return "Enemy phase"
		Phase.VICTORY:
			return "Victory!"
		Phase.DEFEAT:
			return "Defeat"
	return ""


func _boss_text() -> String:
	if boss_index >= GameData.BOSS_SEQUENCE.size():
		return "Boss %d/%d" % [GameData.BOSS_SEQUENCE.size(), GameData.BOSS_SEQUENCE.size()]
	var boss: Dictionary = GameData.BOSSES.get(str(GameData.BOSS_SEQUENCE[boss_index]), {})
	return "Boss %d/%d: %s" % [boss_index + 1, GameData.BOSS_SEQUENCE.size(), boss.get("name", "?")]
