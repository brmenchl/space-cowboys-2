extends Resource
class_name ShipConfig

@export var movement_config: ShipMovementConfig
@export var max_health: int = 100
@export var bullet_config: BulletConfig
@export var visual_scene: PackedScene
@export var collision_polygon: PackedVector2Array
@export var spawn_weight: float = 1.0
