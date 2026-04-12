extends CharacterBody2D


@export var speed = 400
var screen_size

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size

func _process(delta: float) -> void:
	var velocity = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		velocity.x += 1  
	if Input.is_action_pressed("move_left"):
		velocity.x += -1
	if Input.is_action_pressed("move_down"):
		velocity.y += 1
	if Input.is_action_pressed("move_up"):
		velocity.y += -1
	
	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
		
		if velocity.x != 0:
			$AnimatedSprite2D.animation = "walk_side"
			$AnimatedSprite2D.flip_v = false
			$AnimatedSprite2D.flip_h = velocity.x > 0
		elif velocity.y != 0:
			if velocity.y > 0:
				$AnimatedSprite2D.animation = "walk_down"
			else:
				$AnimatedSprite2D.animation = "walk_up"
			$AnimatedSprite2D.flip_v = false
			
		$AnimatedSprite2D.play()
	else:
		if $AnimatedSprite2D.animation.begins_with("walk_"):
			$AnimatedSprite2D.animation = $AnimatedSprite2D.animation.replace("walk_", "idle_")
		elif not $AnimatedSprite2D.animation.begins_with("idle_"):
			$AnimatedSprite2D.animation = "idle_down"
			
		$AnimatedSprite2D.play()
		
	position += velocity * delta
	position = position.clamp(Vector2.ZERO, screen_size)
