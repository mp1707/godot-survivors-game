extends Node2D
class_name FloatingDamageNumber

@export var float_speed: float = 40.0
@onready var life_timer: Timer = $LifeTimer
@onready var label: Label = $Label

func _process(delta: float) -> void:
	position.y -= float_speed * delta
	
	var t: float = 1.0 - (life_timer.time_left / life_timer.wait_time) 
	modulate.a = 1.0 - t
	

func setup(amount: int) -> void:
	label.text = str(amount)


func _on_timer_timeout() -> void:
	queue_free()
