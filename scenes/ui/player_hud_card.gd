extends PanelContainer
class_name PlayerHudCard

@onready var _title_label: Label = $Margin/VBox/TitleLabel
@onready var _portrait_container: Control = $Margin/VBox/Portrait
@onready var _ship_health_bar: ProgressBar = $Margin/VBox/ShipHealthBar
@onready var _cowboy_health_bar: ProgressBar = $Margin/VBox/CowboyHealthBar

var _controller: PlayerController
var _portrait_visual: Node2D


func _ready() -> void:
	_portrait_container.resized.connect(_center_portrait)


func setup(controller: PlayerController, title: String) -> void:
	_controller = controller
	_title_label.text = title

	_ship_health_bar.max_value = controller.current_ship.ship_config.max_health
	_ship_health_bar.value = controller.current_ship.health
	_cowboy_health_bar.max_value = controller.cowboy_max_health
	_cowboy_health_bar.value = controller.cowboy_health

	controller.ship_health_changed.connect(_on_ship_health_changed)
	controller.cowboy_health_changed.connect(_on_cowboy_health_changed)
	controller.ejected.connect(_on_ejected)
	controller.boarded.connect(_on_boarded)
	_on_boarded(controller.current_ship)


func _set_visual(visual_scene: PackedScene) -> void:
	if _portrait_visual:
		_portrait_visual.queue_free()
	_portrait_visual = visual_scene.instantiate()
	_portrait_visual.modulate = _controller.color
	_portrait_visual.rotation = 0.0
	_portrait_container.add_child(_portrait_visual)
	_center_portrait()


func _center_portrait() -> void:
	if _portrait_visual:
		_portrait_visual.position = _portrait_container.size / 2


func _on_ship_health_changed(new_health: int) -> void:
	_ship_health_bar.value = new_health


func _on_cowboy_health_changed(new_health: int) -> void:
	_cowboy_health_bar.value = new_health


func _on_ejected(cowboy: Cowboy) -> void:
	_ship_health_bar.visible = false
	_set_visual(cowboy.visual_scene)


func _on_boarded(ship: Ship) -> void:
	_ship_health_bar.max_value = ship.ship_config.max_health
	_ship_health_bar.visible = true
	_set_visual(ship.ship_config.visual_scene)
