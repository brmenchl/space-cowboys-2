extends Node
class_name PlayerController

signal ship_health_changed(new_health: int)
signal cowboy_health_changed(new_health: int)
signal ejected(cowboy: Cowboy)
signal boarded(ship: Ship)

@export var color: Color = Color.WHITE
@export var input_prefix: String = ""
@export var cowboy_max_health: int = 15

var cowboy_health: int
var current_ship: Ship = null
var current_cowboy: Cowboy = null


func _ready() -> void:
	cowboy_health = cowboy_max_health


func possess_ship(ship: Ship) -> void:
	_release_current_body()
	ship.possess(color, input_prefix)
	current_ship = ship
	ship.cowboy_ejected.connect(_on_cowboy_ejected)
	ship.health_changed.connect(_on_ship_health_changed)
	boarded.emit(ship)
	ship_health_changed.emit(ship.health)


# Both directions of a transfer (ship -> cowboy, cowboy -> ship) start by
# dropping whichever body/connections this controller currently holds, so
# board/eject can share the same cleanup regardless of which way it's going.
func _release_current_body() -> void:
	if current_ship and is_instance_valid(current_ship):
		if current_ship.cowboy_ejected.is_connected(_on_cowboy_ejected):
			current_ship.cowboy_ejected.disconnect(_on_cowboy_ejected)
		if current_ship.health_changed.is_connected(_on_ship_health_changed):
			current_ship.health_changed.disconnect(_on_ship_health_changed)
	current_ship = null

	if current_cowboy and is_instance_valid(current_cowboy):
		if current_cowboy.boarding_requested.is_connected(_on_boarding_requested):
			current_cowboy.boarding_requested.disconnect(_on_boarding_requested)
		if current_cowboy.health_changed.is_connected(_on_cowboy_health_changed):
			current_cowboy.health_changed.disconnect(_on_cowboy_health_changed)
	current_cowboy = null


func _on_cowboy_ejected(cowboy: Cowboy) -> void:
	_release_current_body()
	cowboy.health = cowboy_health
	cowboy.cowboy_max_health = cowboy_max_health
	cowboy.health_changed.connect(_on_cowboy_health_changed)
	cowboy.boarding_requested.connect(_on_boarding_requested)
	current_cowboy = cowboy
	ejected.emit(cowboy)
	cowboy_health_changed.emit(cowboy.health)


func _on_ship_health_changed(new_health: int) -> void:
	ship_health_changed.emit(new_health)


func _on_cowboy_health_changed(new_health: int) -> void:
	cowboy_health = new_health
	cowboy_health_changed.emit(new_health)


# Boarding an occupied ship forces its current cowboy out first; that cowboy's
# own controller reacts independently via its own ship.cowboy_ejected
# connection, so nothing here needs to know who (if anyone) was flying it.
func _on_boarding_requested(ship: Ship) -> void:
	var boarding_cowboy := current_cowboy
	if ship.is_piloted:
		ship._eject()
	possess_ship(ship)
	if boarding_cowboy and is_instance_valid(boarding_cowboy):
		boarding_cowboy.queue_free()
