class_name TestSandbox
extends Control
## Test sandbox: instantiates one EnemyView and four CardViews, wires their
## contract methods and drives the animations for a headless smoke test.

@onready var _enemy_view: EnemyView = $EnemyView
@onready var _card_1: CardView = $Card1
@onready var _card_2: CardView = $Card2
@onready var _card_3: CardView = $Card3
@onready var _card_4: CardView = $Card4


func _ready() -> void:
	_setup_enemy()
	_setup_cards()
	_schedule_animations()
	print("TestSandbox ready: enemy + 4 cards configured.")


func _setup_enemy() -> void:
	_enemy_view.setup("goblin_chief", 80)
	_enemy_view.update_state(54, 12, "Heavy Blow")


func _setup_cards() -> void:
	_build_card(_card_1, "slash", "Slash", 1, "Deal 6 damage.")
	_build_card(_card_2, "heavy_blow", "Heavy Blow", 2, "Deal 12 damage.")
	_build_card(_card_3, "block", "Block", 1, "Gain 5 shield.")
	_build_card(_card_4, "heal", "Heal", 2, "Restore 8 HP.")


func _build_card(card: CardView, skill_id: String, title: String, cost: int, desc: String) -> void:
	card.setup(skill_id, title, cost, desc, null)
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
