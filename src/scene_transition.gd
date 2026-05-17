extends CanvasLayer


# Node References
@onready var color_rect: ColorRect = $ColorRect


# ==============================================================================
# Built-In Engine Lifecycle Functions
# ==============================================================================

func _ready() -> void:
	# Start completely transparent and allow touches to click through it
	color_rect.modulate.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ==============================================================================
# Core Scene Transition Operations
# ==============================================================================

# Fades the screen to black, swaps the map under the hood, and fades back out
func change_scene(target_scene_path: String) -> void:
	# Block all user input touches during the transition fade
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var fade_tween: Tween = create_tween()
	
	# Fade screen into solid black
	fade_tween.tween_property(color_rect, "modulate:a", 1.0, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# Safely switch scenes behind the black screen curtain
	fade_tween.chain().tween_callback(func() -> void: 
		get_tree().change_scene_to_file(target_scene_path)
	)
	
	# Fade back out to expose the new layout scene
	fade_tween.chain().tween_property(color_rect, "modulate:a", 0.0, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
	# Unblock player interaction once the screen is fully clear
	fade_tween.chain().tween_callback(func() -> void: 
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)
