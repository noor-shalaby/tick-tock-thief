extends CanvasLayer

@onready var color_rect = $ColorRect

func _ready():
	# Make sure it starts completely invisible
	color_rect.modulate.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(target_scene_path: String):
	# 1. Block all user touch inputs so they can't spam buttons during the fade
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 2. Fade to solid black
	var fade_tween = create_tween()
	fade_tween.tween_property(color_rect, "modulate:a", 1.0, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# 3. Wait for the fade to finish, THEN swap the scene behind the curtain
	fade_tween.chain().tween_callback(func(): 
		get_tree().change_scene_to_file(target_scene_path)
	)
	
	# 4. Fade back out to expose the new scene
	fade_tween.chain().tween_property(color_rect, "modulate:a", 0.0, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
	# 5. Unblock user inputs once the screen is clear
	fade_tween.chain().tween_callback(func(): 
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)
