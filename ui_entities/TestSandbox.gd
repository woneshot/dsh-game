class_name TestSandbox
extends Control
## Test sandbox: instantiates one EnemyView and four CardViews, feeds them the
## real GameData catalog and drives the animations for a headless smoke test.

@onready var _enemy_view: EnemyView = $EnemyView
@onready var _card_1: CardView = $Card1
@onready var _card_2: CardView = $Card2
@onready var _card_3: CardView = $Card3
@onready var _card_4: CardView = $Card4


func _ready() -> void:
	_setup_enemy()
	_setup_cards()
	_schedule_animations()
	_simulate_card_interaction(_card_1)
	print("TestSandbox ready: enemy + 4 cards configured.")


## Deterministic smoke check for the CardView interaction path: hover tween
## and click signal, without needing a real mouse in headless runs.
func _simulate_card_interaction(card: CardView) -> void:
	card.mouse_entered.emit()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	card._gui_input(event)


func _setup_enemy() -> void:
	if GameData.BOSS_SEQUENCE.is_empty():
		return
	var boss_id: String = GameData.BOSS_SEQUENCE[0]
	var boss: Dictionary = GameData.BOSSES.get(boss_id, {})
	var max_hp: int = int(boss.get("max_hp", 80))
	_enemy_view.setup(boss_id, max_hp)
	_enemy_view.update_state(int(max_hp * 0.6), 12, "Attack %d" % int(boss.get("attack", 8)))


func _setup_cards() -> void:
	var skill_ids: Array[String] = []
	for key: Variant in GameData.SKILLS:
		skill_ids.append(str(key))
	var cards: Array[CardView] = [_card_1, _card_2, _card_3, _card_4]
	for i in mini(cards.size(), skill_ids.size()):
		_build_card(cards[i], skill_ids[i])


func _build_card(card: CardView, skill_id: String) -> void:
	var data: Dictionary = GameData.SKILLS[skill_id]
	var cost: int = int(data.get("cost", 1))
	card.setup(skill_id, str(data.get("title", skill_id)), cost, str(data.get("description", "")), null)
	card.set_usable(cost <= 2)
	card.card_clicked.connect(_on_card_clicked)


func _schedule_animations() -> void:
	_enemy_view.play_attack_anim()
	get_tree().create_timer(0.5).timeout.connect(_on_hit_timer.bind(12))
	get_tree().create_timer(1.1).timeout.connect(_on_hit_timer.bind(7))


func _on_hit_timer(damage: int) -> void:
	_enemy_view.play_hit_anim(damage)
	print("Hit animation for %d damage triggered." % damage)


func _on_card_clicked(skill_id: String) -> void:
	print("Card clicked: %s" % skill_id)
