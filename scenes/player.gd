extends Node2D
class_name Player

@export var color: Color = Color.WHITE

@onready var polygon: Polygon2D = $Polygon2D


func _ready() -> void:
	polygon.color = color
