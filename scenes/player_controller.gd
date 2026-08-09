extends Node
class_name PlayerController

signal ship_health_changed(new_health: int)
signal pilot_health_changed(new_health: int)
signal ejected(pilot: Pilot)
signal boarded(ship: Ship)

@export var color: Color = Color.WHITE
@export var input_prefix: String = ""
@export var pilot_max_health: int = 15

var pilot_health: int
var current_ship: Ship = null
var current_pilot: Pilot = null


func _ready() -> void:
	pilot_health = pilot_max_health


func possess_ship(ship: Ship) -> void:
	_release_current_body()
	ship.possess(color, input_prefix)
	current_ship = ship
	ship.pilot_ejected.connect(_on_pilot_ejected)
	ship.health_changed.connect(_on_ship_health_changed)
	boarded.emit(ship)
	ship_health_changed.emit(ship.health)


# Both directions of a transfer (ship -> pilot, pilot -> ship) start by
# dropping whichever body/connections this controller currently holds, so
# board/eject can share the same cleanup regardless of which way it's going.
func _release_current_body() -> void:
	if current_ship and is_instance_valid(current_ship):
		if current_ship.pilot_ejected.is_connected(_on_pilot_ejected):
			current_ship.pilot_ejected.disconnect(_on_pilot_ejected)
		if current_ship.health_changed.is_connected(_on_ship_health_changed):
			current_ship.health_changed.disconnect(_on_ship_health_changed)
	current_ship = null

	if current_pilot and is_instance_valid(current_pilot):
		if current_pilot.boarding_requested.is_connected(_on_boarding_requested):
			current_pilot.boarding_requested.disconnect(_on_boarding_requested)
		if current_pilot.health_changed.is_connected(_on_pilot_health_changed):
			current_pilot.health_changed.disconnect(_on_pilot_health_changed)
	current_pilot = null


func _on_pilot_ejected(pilot: Pilot) -> void:
	_release_current_body()
	pilot.health = pilot_health
	pilot.pilot_max_health = pilot_max_health
	pilot.health_changed.connect(_on_pilot_health_changed)
	pilot.boarding_requested.connect(_on_boarding_requested)
	current_pilot = pilot
	ejected.emit(pilot)
	pilot_health_changed.emit(pilot.health)


func _on_ship_health_changed(new_health: int) -> void:
	ship_health_changed.emit(new_health)


func _on_pilot_health_changed(new_health: int) -> void:
	pilot_health = new_health
	pilot_health_changed.emit(new_health)


# Boarding an occupied ship forces its current pilot out first; that pilot's
# own controller reacts independently via its own ship.pilot_ejected
# connection, so nothing here needs to know who (if anyone) was flying it.
func _on_boarding_requested(ship: Ship) -> void:
	var boarding_pilot := current_pilot
	if ship.is_piloted:
		ship._eject()
	possess_ship(ship)
	if boarding_pilot and is_instance_valid(boarding_pilot):
		boarding_pilot.queue_free()
