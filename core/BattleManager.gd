extends Control
## Authoritative battle state for the co-op fight, synchronized over RPC.
## EnemyView/CardView are the partner's scenes; they are driven through their
## documented method/signal contract via call()/connect() so this file does not
## statically depend on those scripts.


const EnemyViewScene: String = "res://ui_entities/EnemyView.tscn"
const CardViewScene: String = "res://ui_entities/CardView.tscn"

enum Phase { PLAYER, ENEMY }

const BOSS_ID: String = "goblin_chief"
const MAX_ENERGY: int = 3
const ENEMY_ATTACK: int = 8

var player_max_hp: int = 100
var player_hp: int = 100
var boss_max_hp: int = 80
var boss_hp: int = 80
var energy: int = MAX_ENERGY
var phase: int = Phase.PLAYER

var _enemy_view: Node = null
var _end_turn_peers: Dictionary = {}

@onready var hp_label: Label = %HPLabel
@onready var energy_label: Label = %EnergyLabel
@onready var phase_label: Label = %PhaseLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var enemy_container: Node = %EnemyContainer
@onready var hand_container: Node = %HandContainer


func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	_spawn_enemy()
	_spawn_cards()
	_refresh_ui()


func _spawn_enemy() -> void:
	var boss: Dictionary = GameData.BOSSES.get(BOSS_ID, {})
	boss_max_hp = int(boss.get("max_hp", boss_max_hp))
	boss_hp = boss_max_hp
	if ResourceLoader.exists(EnemyViewScene):
		var scene: PackedScene = load(EnemyViewScene) as PackedScene
		_enemy_view = scene.instantiate()
		enemy_container.add_child(_enemy_view)
		_enemy_view.call("setup", BOSS_ID, boss_max_hp)
		_enemy_view.call("update_state", boss_hp, 0, _intent_text())
	else:
		var label := Label.new()
		label.text = "Enemy placeholder: %s" % boss.get("name", BOSS_ID)
		enemy_container.add_child(label)


func _spawn_cards() -> void:
	for skill_id: String in GameData.SKILLS:
		var skill: Dictionary = GameData.SKILLS[skill_id]
		if ResourceLoader.exists(CardViewScene):
			var scene: PackedScene = load(CardViewScene) as PackedScene
			var view: Node = scene.instantiate()
			hand_container.add_child(view)
			view.connect("card_clicked", _on_card_clicked)
			view.call("setup", skill_id, skill.get("title", skill_id), int(skill.get("cost", 0)), skill.get("description", ""), null)
		else:
			var btn := Button.new()
			btn.text = "%s (%d)" % [skill.get("title", skill_id), int(skill.get("cost", 0))]
			btn.pressed.connect(_on_card_clicked.bind(skill_id))
			hand_container.add_child(btn)


func _intent_text() -> String:
	if phase == Phase.ENEMY:
		return "Attack %d" % ENEMY_ATTACK
	return "…"


func _on_card_clicked(skill_id: String) -> void:
	if phase != Phase.PLAYER:
		return
	_play_skill.rpc(skill_id)


@rpc("any_peer", "call_local", "reliable")
func _play_skill(skill_id: String) -> void:
	if not multiplayer.is_server():
		return
	var skill: Dictionary = GameData.SKILLS.get(skill_id, {})
	if skill.is_empty():
		return
	var cost: int = int(skill.get("cost", 0))
	if energy < cost:
		return
	energy -= cost
	var damage: int = int(skill.get("damage", 0))
	if damage > 0:
		boss_hp = maxi(boss_hp - damage, 0)
		_enemy_took_damage.rpc(damage)
	_broadcast_state()


func _on_end_turn_pressed() -> void:
	_end_turn.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _end_turn() -> void:
	if not multiplayer.is_server():
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
	player_hp = maxi(player_hp - ENEMY_ATTACK, 0)
	_enemy_attacked.rpc()
	energy = MAX_ENERGY
	phase = Phase.PLAYER
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
	_sync_state.rpc(player_hp, boss_hp, energy, phase)


@rpc("any_peer", "call_local", "reliable")
func _sync_state(php: int, bhp: int, en: int, ph: int) -> void:
	player_hp = php
	boss_hp = bhp
	energy = en
	phase = ph
	_refresh_ui()


func _refresh_ui() -> void:
	hp_label.text = "HP: %d/%d" % [player_hp, player_max_hp]
	energy_label.text = "Energy: %d" % energy
	phase_label.text = "Player phase" if phase == Phase.PLAYER else "Enemy phase"
	if _enemy_view != null:
		_enemy_view.call("update_state", boss_hp, 0, _intent_text())
