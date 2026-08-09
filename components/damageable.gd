extends CharacterBody2D
class_name Damageable

signal health_changed(new_health: int)

var health: int


func take_damage(amount: int) -> void:
	health = maxi(health - amount, 0)
	health_changed.emit(health)
	if health == 0:
		_die()


func _die() -> void:
	queue_free()


func is_boardable() -> bool:
	return false
