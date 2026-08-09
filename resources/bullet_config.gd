extends Resource
class_name BulletConfig

@export var speed: float = 700.0
@export var time_to_live: float = 1.5
@export var radius: float = 8.0
@export var visual_scene: PackedScene = preload("res://scenes/visuals/bullet_visual_fighter.tscn")

# Distance from the shooter's center to where the bullet spawns.
@export var muzzle_distance: float = 36.0
@export var damage: int = 5
@export var fire_rate: float = 2.0
