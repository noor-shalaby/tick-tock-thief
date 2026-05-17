extends Button

# Custom signal to pass the card type back to the GameManager
signal card_played(card_type: String)

var type: String = ""


func _ready():
	# 1. Hide it initially so it doesn't blink at full size
	modulate.a = 0.0 
	
	# 2. HALT EXECUTION: Wait exactly one frame for the GridContainer to finish its math
	await get_tree().process_frame
	
	# 3. Now that the layout is locked, the size is correct! Set the pivot.
	pivot_offset = size / 2.0
	
	# 4. Shrink it down so it has room to pop up
	scale = Vector2.ZERO
	
	# 5. Run the juicy animation
	var pop_tween = create_tween().set_parallel(true)
	pop_tween.tween_property(self, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "modulate:a", 1.0, 0.2)


# We call this right after instantiating the button
func setup(card_type: String):
	type = card_type
	
	# Format the text so "time_thief" becomes "Time Thief"
	text = type.replace("_", " ").capitalize() 
	
	# Optional: Change button colors based on type using modulate
	match type:
		"shield": modulate = Color.AQUA
		"time_thief": modulate = Color.CRIMSON
		"reverse": modulate = Color.GOLD
		"double": modulate = Color.MEDIUM_PURPLE

# Godot's built-in virtual function for when a button is pressed
func _pressed():
	card_played.emit(type)
	
	# Disable button so they can't spam click it during the animation
	disabled = true 
	
	var press_tween = create_tween()
	# Squish the button down
	press_tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# Wait for the squish to finish, THEN tell the GameManager the card was played
	press_tween.tween_callback(func(): card_played.emit(type))
