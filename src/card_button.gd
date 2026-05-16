extends Button

# Custom signal to pass the card type back to the GameManager
signal card_played(card_type: String)

var type: String = ""

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
