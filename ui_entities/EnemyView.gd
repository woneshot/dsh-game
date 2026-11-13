class_name EnemyView
extends Control
## Enemy battle view: enemy sprite, HP bar, shield icon and intent label.
## Contract for the co-op battler UI (used by the partner's battle scene).

const PLACEHOLDER_SIZE: int = 128

@onready var _sprite: TextureRect = $VBox/EnemySprite
@onready var _health_bar: ProgressBar = $VBox/HealthBar
@onready var _shield_row: HBoxContainer = $VBox/ShieldRow
@onready var _shield_icon: TextureRect = $VBox/ShieldRow/ShieldIcon
@onready var _shield_label: Label = $VBox/ShieldRow/ShieldLabel
@onready var _intent_label: Label = $VBox/IntentLabel

var _enemy_id: String = ""


func _ready() -> void:
	_shield_icon.texture = _make_shield_icon()
	_shield_row.visible = false


## Load the enemy texture from res://assets/enemies/{enemy_id}.png, or fall
## back to a colored placeholder when the file is missing.
func setup(enemy_id: String, max_hp: int) -> void:
	_enemy_id = enemy_id
	_health_bar.max_value = float(maxi(max_hp, 1))
	_health_bar.value = _health_bar.max_value
	_shield_row.visible = false
	_shield_label.text = "0"
	_intent_label.text = ""
	_load_enemy_texture(enemy_id)


## Reflect the current combat state on the view.
func update_state(hp: int, shield: int, intent_text: String) -> void:
	_health_bar.value = clampf(float(hp), 0.0, _health_bar.max_value)
	_shield_label.text = str(shield)
	_shield_row.visible = shield > 0
	_intent_label.text = intent_text


## Shake + red flash + floating damage number.
func play_hit_anim(damage: int) -> void:
	_shake()
	_flash_red()
	_spawn_damage_number(damage)


## Lunge down and back up.
func play_attack_anim() -> void:
	var origin := position
	var tween := create_tween()
	tween.tween_property(self, "position", origin + Vector2(0.0, 28.0), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", origin, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _load_enemy_texture(enemy_id: String) -> void:
	var path := "res://assets/enemies/%s.png" % enemy_id
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			texture = res
	_sprite.texture = texture if texture != null else _make_placeholder_texture(enemy_id)


func _make_placeholder_texture(enemy_id: String) -> ImageTexture:
	var image := Image.create(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(_color_from_id(enemy_id))
	return ImageTexture.create_from_image(image)


func _make_shield_icon() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.4, 0.8, 1.0, 0.95))
	image.fill_rect(Rect2i(6, 6, 20, 20), Color(0.1, 0.35, 0.6, 1.0))
	return ImageTexture.create_from_image(image)


func _color_from_id(id: String) -> Color:
	var hue := absi(hash(id)) % 360
	return Color.from_hsv(float(hue) / 360.0, 0.65, 0.9)


func _shake() -> void:
	var origin := position
	var tween := create_tween()
	var amp := 8.0
	tween.tween_property(self, "position:x", origin.x - amp, 0.04)
	tween.tween_property(self, "position:x", origin.x + amp, 0.04)
	tween.tween_property(self, "position:x", origin.x - amp, 0.04)
	tween.tween_property(self, "position:x", origin.x, 0.04)


func _flash_red() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.6, 0.35, 0.35), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)


func _spawn_damage_number(damage: int) -> void:
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	label.z_index = 10
	add_child(label)
	label.position = Vector2(size.x * 0.5 - 12.0, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -70.0), 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)
