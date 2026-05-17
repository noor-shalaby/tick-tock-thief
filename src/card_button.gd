extends Button


signal card_played(card_type: String)

var type: String = ""

@onready var _scene_tree: SceneTree = get_tree()


func _ready() -> void:
	modulate.a = 0.0 
	
	# Wait 1 frame for parent GridContainer to finish layout math
	await _scene_tree.process_frame
	
	pivot_offset_ratio = Vector2.ONE / 2.0
	scale = Vector2.ZERO
	
	# Pop-in animation
	var pop_tween: Tween = create_tween().set_parallel(true)
	pop_tween.tween_property(self, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "modulate:a", 1.0, 0.2)


func setup(card_type: String) -> void:
	type = card_type
	text = type.replace("_", " ").capitalize() 
	
	# Color code the cards
	match type:
		"shield": modulate = Color.AQUA
		"time_thief": modulate = Color.CRIMSON
		"reverse": modulate = Color.GOLD
		"double": modulate = Color.MEDIUM_PURPLE


func _pressed() -> void:
	disabled = true # Prevent double clicks
	
	# Squish animation on click
	var press_tween: Tween = create_tween()
	press_tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# Emit signal after the squish finishes
	press_tween.tween_callback(func() -> void: card_played.emit(type))
