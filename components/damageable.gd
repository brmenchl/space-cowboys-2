extends CharacterBody2D
class_name Damageable

var health: int


func take_damage(amount: int) -> void:
	health = maxi(health - amount, 0)
	if health == 0:
		_die()


func _die() -> void:
	queue_free()


func is_boardable() -> bool:
	return false
