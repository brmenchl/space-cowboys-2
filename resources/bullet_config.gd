extends Resource
class_name BulletConfig

@export var speed: float = 700.0
@export var time_to_live: float = 1.5
@export var radius: float = 4.0
@export var color: Color = Color(1.0, 0.9, 0.2)

# Distance from the shooter's center to where the bullet spawns.
@export var muzzle_distance: float = 36.0
@export var damage: int = 5
