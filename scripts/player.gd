extends CharacterBody2D

@export var speed: float = 150.0

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1

	velocity = input_vector.normalized() * speed

	if input_vector != Vector2.ZERO:
		if abs(input_vector.x) > abs(input_vector.y):
			$AnimatedSprite2D.animation = "walk_side"
			$AnimatedSprite2D.flip_h = input_vector.x > 0
		else:
			if input_vector.y > 0:
				$AnimatedSprite2D.animation = "walk_down"
			else:
				$AnimatedSprite2D.animation = "walk_up"
		$AnimatedSprite2D.play()
	else:
		if $AnimatedSprite2D.animation == "walk_side":
			$AnimatedSprite2D.animation = "idle_side"
		elif $AnimatedSprite2D.animation == "walk_up":
			$AnimatedSprite2D.animation = "idle_up"
		elif $AnimatedSprite2D.animation == "walk_down":
			$AnimatedSprite2D.animation = "idle_down"
		$AnimatedSprite2D.play()

	move_and_slide()
