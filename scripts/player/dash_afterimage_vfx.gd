extends Node
class_name DashAfterimageVfx

@export var afterimage_z_index: int = 100

func spawn_from(source_sprite: AnimatedSprite2D, tint: Color, alpha: float, lifetime: float) -> void:
	if source_sprite == null:
		return
	if lifetime <= 0.0:
		return

	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var frame_texture: Texture2D = _get_current_frame_texture(source_sprite)
	if frame_texture == null:
		return

	var afterimage: Sprite2D = Sprite2D.new()
	afterimage.texture = frame_texture
	afterimage.centered = true
	afterimage.global_position = source_sprite.global_position
	afterimage.global_rotation = source_sprite.global_rotation
	afterimage.flip_h = source_sprite.flip_h
	afterimage.scale = source_sprite.global_scale
	afterimage.z_as_relative = false
	afterimage.z_index = afterimage_z_index
	afterimage.modulate = Color(tint.r, tint.g, tint.b, clampf(alpha, 0.0, 1.0))
	tree.current_scene.add_child(afterimage)

	var fade_tween: Tween = afterimage.create_tween()
	fade_tween.tween_property(afterimage, "modulate:a", 0.0, lifetime)
	fade_tween.finished.connect(afterimage.queue_free)

func _get_current_frame_texture(source_sprite: AnimatedSprite2D) -> Texture2D:
	if source_sprite.sprite_frames == null:
		return null

	var frames: SpriteFrames = source_sprite.sprite_frames
	var animation_name: StringName = source_sprite.animation
	var frame_count: int = frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return null

	var frame_index: int = clampi(source_sprite.frame, 0, frame_count - 1)
	return frames.get_frame_texture(animation_name, frame_index)
