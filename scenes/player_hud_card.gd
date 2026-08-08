extends PanelContainer
class_name PlayerHudCard

@onready var _title_label: Label = $Margin/VBox/TitleLabel
@onready var _portrait_container: Control = $Margin/VBox/Portrait
@onready var _health_bar: ProgressBar = $Margin/VBox/HealthBar

var _player: Player
var _portrait_visual: Node2D


func _ready() -> void:
	_portrait_container.resized.connect(_center_portrait)


func setup(player: Player, title: String) -> void:
	_player = player
	_title_label.text = title
	_health_bar.max_value = Player.MAX_HEALTH
	_health_bar.value = player.health
	player.health_changed.connect(_on_health_changed)
	player.visual_changed.connect(_on_visual_changed)
	_on_visual_changed(player.active_visual_scene)


func _process(_delta: float) -> void:
	if is_instance_valid(_player) and is_instance_valid(_portrait_visual):
		_portrait_visual.rotation = _player.rotation


func _on_visual_changed(visual_scene: PackedScene) -> void:
	if _portrait_visual:
		_portrait_visual.queue_free()
	_portrait_visual = visual_scene.instantiate()
	_portrait_visual.modulate = _player.color
	_portrait_container.add_child(_portrait_visual)
	_center_portrait()


func _center_portrait() -> void:
	if _portrait_visual:
		_portrait_visual.position = _portrait_container.size / 2


func _on_health_changed(new_health: int) -> void:
	_health_bar.value = new_health
