extends Control

@onready var name_input = $VBoxContainer/HBoxContainer/NameInput
@onready var player_list = $VBoxContainer/PlayerList
@onready var start_button = $VBoxContainer/StartGameButton

func _ready():
	# Ensure the start button is disabled until we have at least 2 players
	start_button.disabled = true
	GameState.players.clear() # Reset state in case we return to the main menu

# Connected to the AddPlayerButton's 'pressed' signal
func _on_add_player_button_pressed():
	var player_name = name_input.text.strip_edges()
	
	if player_name.is_empty():
		return # Don't add blank names
		
	# Build the player dictionary
	var new_player = {
		"name": player_name,
		"cards": [],
		"score": 0,
		"correct_answers": 0
	}
	
	GameState.players.append(new_player)
	update_player_list_ui(player_name)
	
	name_input.text = "" # Clear input for the next name
	
	# Enable start if we have enough players
	if GameState.players.size() >= 2:
		start_button.disabled = false

func update_player_list_ui(player_name: String):
	# Dynamically create a label for the list
	var label = Label.new()
	label.text = "- " + player_name
	# Optional: Align center or adjust font size here
	player_list.add_child(label)

# Connected to the StartGameButton's 'pressed' signal
func _on_start_game_button_pressed():
	# Shuffle the players array so the starting order is random!
	GameState.players.shuffle()
	GameState.current_player_index = 0 
	
	# Transition to the main game scene
	get_tree().change_scene_to_file("res://src/game.tscn")
