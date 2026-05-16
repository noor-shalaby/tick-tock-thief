extends Control

@onready var question_label = $UI/QuestionLabel
@onready var player_label = $UI/PlayerNameLabel
@onready var bomb_timer = $BombTimer
@onready var tick_audio = $AudioStreamPlayer
@onready var card_container = $UI/CardContainer
@onready var game_over_overlay = $GameOverOverlay
@onready var loser_label = $GameOverOverlay/CenterContainer/VBoxContainer/LoserLabel
@onready var pass_bomb_button = $UI/PassBombButton

# Preload your new custom scene
const CardButtonScene = preload("res://src/card_button.tscn")

# Mock Database
var questions = []

func _ready():
	load_questions()
	start_new_round()

func load_questions():
	if not FileAccess.file_exists("res://questions.json"):
		push_error("Questions file not found!")
		return
		
	var file = FileAccess.open("res://questions.json", FileAccess.READ)
	var content = file.get_as_text()
	var parsed_data = JSON.parse_string(content)
	
	if parsed_data is Array:
		questions = parsed_data
	else:
		push_error("Error parsing JSON: Ensure it's a valid array.")


func start_new_round():
	# Randomize the hidden timer between 20 and 45 seconds
	var bomb_time = randf_range(20.0, 45.0)
	bomb_timer.start(bomb_time)
	
	tick_audio.play()
	tick_audio.pitch_scale = 1.0 # Reset pitch
	
	start_turn()

func start_turn():
	var current_player = GameState.players[GameState.current_player_index]
	player_label.text = current_player["name"] + "'s Turn!"
	
	var q = questions.pick_random()
	question_label.text = q
	
	# Update the UI every time a turn starts
	update_card_ui()

func _process(delta):
	if not bomb_timer.is_stopped():
		# Increase the pitch/speed of the ticking as time runs out to build tension
		var time_left_ratio = bomb_timer.time_left / bomb_timer.wait_time
		tick_audio.pitch_scale = lerp(2.0, 1.0, time_left_ratio)

# Connected to the PassBombButton
func _on_pass_bomb_button_pressed():
	# 1. Give them credit for answering
	GameState.register_correct_answer()
	
	# 2. Move to the next player
	GameState.next_player()
	
	# 3. Start the next turn
	start_turn()

func _on_bomb_timer_timeout():
	tick_audio.stop()
	explode_bomb()

func explode_bomb():
	var loser = GameState.players[GameState.current_player_index]
	
	# Hide the gameplay UI elements so they can't be clicked
	pass_bomb_button.hide()
	card_container.hide()
	question_label.hide()
	
	# Update and show the Game Over overlay
	loser_label.text = loser["name"] + " BLEW UP!"
	game_over_overlay.show()

# Connected to the PlayAgainButton
func _on_play_again_button_pressed():
	# Hide the overlay and restore the gameplay UI
	game_over_overlay.hide()
	pass_bomb_button.show()
	card_container.show()
	question_label.show()
	
	# Optional: You could shuffle the players array here again if you want!
	
	# Kick off a fresh round
	start_new_round()

# Connected to the MainMenuButton
func _on_main_menu_button_pressed():
	# Reset the player state so the main menu is clean
	GameState.players.clear()
	get_tree().change_scene_to_file("res://src/main_menu.tscn")


# Call this when the player successfully answers and passes the bomb
func pass_turn():
	GameState.register_correct_answer()
	GameState.next_player()
	start_turn()

func update_card_ui():
	# 1. Clear out the old buttons from the previous turn
	for child in card_container.get_children():
		child.queue_free()
		
	var current_player = GameState.players[GameState.current_player_index]
	
	# 2. Instantiate a new button for every card in the player's inventory
	for card in current_player["cards"]:
		var btn = CardButtonScene.instantiate()
		
		# Add it to the tree BEFORE calling setup, just in case setup relies on the tree
		card_container.add_child(btn) 
		
		# Pass the data to the button
		btn.setup(card)
		
		# Connect the custom signal to our GameManager function
		btn.card_played.connect(_on_card_played)

# Signal receiver
func _on_card_played(card_type: String):
	play_card(card_type)
	
	# Refresh the UI immediately so the used card disappears
	update_card_ui()

# Connected to your dynamically generated Card Buttons
func play_card(card_type: String):
	var current_player = GameState.players[GameState.current_player_index]
	
	# Validation check
	if not card_type in current_player["cards"]:
		return 
		
	# Consume the card
	current_player["cards"].erase(card_type)
	
	# Execute clean card logic
	match card_type:
		"shield":
			# Pass the bomb without answering
			GameState.next_player()
			start_turn()
		"time_thief":
			# Shave 5 seconds off the timer, but don't let it go below 1 second
			bomb_timer.start(max(1.0, bomb_timer.time_left - 5.0))
		"reverse":
			# Flip direction and immediately pass to the previous person
			GameState.play_direction *= -1
			GameState.next_player()
			start_turn()
		"double":
			# Quick MVP string manipulation
			question_label.text = question_label.text.replace("3", "6")
			question_label.text += "\n(DOUBLE CHALLENGE!)"

	# You'll want to call a function here to refresh your Card UI 
	# update_card_ui()
