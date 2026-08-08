extends PanelContainer
class_name PlayerHudCard

@onready var _title_label: Label = $Margin/VBox/TitleLabel
@onready var _portrait_container: Control = $Margin/VBox/Portrait
@onready var _portrait: Polygon2D = $Margin/VBox/Portrait/Triangle
@onready var _health_bar: ProgressBar = $Margin/VBox/HealthBar

var _player: Player


func _ready() -> void:
	_portrait_container.resized.connect(_center_portrait)
	_center_portrait()


func setup(player: Player, title: String) -> void:
	_player = player
	_title_label.text = title
	_portrait.color = player.color
	_health_bar.max_value = Player.MAX_HEALTH
	_health_bar.value = player.health
	player.health_changed.connect(_on_health_changed)


func _process(_delta: float) -> void:
	if is_instance_valid(_player):
		_portrait.polygon = _player.polygon.polygon
		_portrait.rotation = _player.rotation


func _center_portrait() -> void:
	_portrait.position = _portrait_container.size / 2


func _on_health_changed(new_health: int) -> void:
	_health_bar.value = new_health
