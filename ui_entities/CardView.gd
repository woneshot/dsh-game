class_name CardView
extends PanelContainer
## Skill card: icon, energy cost, title and description. Scales up on hover
## and emits card_clicked when pressed.

signal card_clicked(skill_id: String)

## Maps a skill id to the partner's icon file in res://assets/icons/.
const SKILL_ICON_FILES: Dictionary = {
	"cleave": "strike",
	"guard": "shield",
	"war_cry": "blood_pact",
	"mend": "heal",
}

@onready var _icon: TextureRect = $Margin/VBox/Icon
@onready var _cost_label: Label = $Margin/VBox/CostLabel
@onready var _title_label: Label = $Margin/VBox/TitleLabel
@onready var _desc_label: Label = $Margin/VBox/DescLabel

var _skill_id: String = ""
var _usable: bool = true


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_pivot()
	resized.connect(_update_pivot)


## Configure the card from a skill entry. A null icon loads the real
## partner icon for the skill (or a generated placeholder as last resort).
func setup(skill_id: String, title: String, cost: int, desc: String, icon: Texture2D) -> void:
	_skill_id = skill_id
	_title_label.text = title
	_cost_label.text = "Cost: %d" % cost
	_desc_label.text = desc
	_icon.texture = icon if icon != null else _load_icon(skill_id)


## Toggle the interaction state (greyed out when not usable).
func set_usable(can_use: bool) -> void:
	_usable = can_use
	mouse_filter = Control.MOUSE_FILTER_STOP if can_use else Control.MOUSE_FILTER_IGNORE
	modulate = Color.WHITE if can_use else Color(0.55, 0.55, 0.55, 0.6)


func _gui_input(event: InputEvent) -> void:
	if not _usable:
		return
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		card_clicked.emit(_skill_id)


func _on_mouse_entered() -> void:
	_animate_scale(Vector2(1.08, 1.08))


func _on_mouse_exited() -> void:
	_animate_scale(Vector2.ONE)


func _animate_scale(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _load_icon(skill_id: String) -> Texture2D:
	var icon_name: String = str(SKILL_ICON_FILES.get(skill_id, skill_id))
	var texture := _load_texture("res://assets/icons/%s.png" % icon_name)
	return texture if texture != null else _make_placeholder_icon(skill_id)


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	return null


func _make_placeholder_icon(skill_id: String) -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var hue := absi(hash(skill_id)) % 360
	image.fill(Color.from_hsv(float(hue) / 360.0, 0.5, 0.85))
	return ImageTexture.create_from_image(image)
