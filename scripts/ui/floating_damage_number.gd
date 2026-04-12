extends Node2D

@export var float_speed: float = 40.0
@onready var life_timer: Timer = $LifeTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.y -= float_speed * delta
	
	var t: float = 1.0 - (life_timer.time_left / life_timer.wait_time) 
	modulate.a = 1.0 - t
	

func setup(amount: int) -> void:
	$Label.text = str(amount)


func _on_timer_timeout() -> void:
	queue_free()
