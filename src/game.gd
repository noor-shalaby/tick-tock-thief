extends Control

@onready var question_label = %QuestionLabel
@onready var player_label = %PlayerNameLabel
@onready var bomb_timer = $BombTimer
@onready var tick_audio = $AudioStreamPlayer
@onready var card_container = %CardContainer
@onready var pass_bomb_button = %PassBombButton
@onready var game_over_overlay = $GameOverOverlay
@onready var loser_label = %LoserLabel
@onready var leaderboard_label = %LeaderBoardLabel

# Preload your new custom scene
const CardButtonScene = preload("res://src/card_button.tscn")

var master_questions: Array = []
var active_questions: Array = []
var turn_start_time: int = 0

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
		master_questions = parsed_data
		# Fill the active pool for the very first time
		active_questions = master_questions.duplicate() 
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
	
	# If the pool is empty, refill it from the master list!
	if active_questions.is_empty():
		active_questions = master_questions.duplicate()
	
	# Pick a random question from the remaining pool
	var q = active_questions.pick_random()
	
	# Immediately erase it from the pool so it doesn't repeat
	active_questions.erase(q)
	
	if GameState.is_next_turn_double:
		# Set up a RegEx pattern to find digits
		var regex = RegEx.new()
		regex.compile("\\d+") # This pattern matches any whole number
		
		# Search the question string for the first match
		var reg_match = regex.search(q)
		
		if reg_match:
			var original_num_str = reg_match.get_string()
			var doubled_num = original_num_str.to_int() * 2
			
			# Replace the old number with the doubled number
			q = q.replace(original_num_str, str(doubled_num))
			
		q += "\n(DOUBLE CHALLENGE!)"
		GameState.is_next_turn_double = false # Reset the trap
	
	question_label.text = q
	turn_start_time = Time.get_ticks_msec()
	
	# Update the UI every time a turn starts
	update_card_ui()

func _process(_delta):
	if not bomb_timer.is_stopped():
		# Increase the pitch/speed of the ticking as time runs out to build tension
		var time_left_ratio = bomb_timer.time_left / bomb_timer.wait_time
		tick_audio.pitch_scale = lerp(2.0, 1.0, time_left_ratio)

# Connected to the PassBombButton
func _on_pass_bomb_button_pressed():
	var current_player = GameState.players[GameState.current_player_index]
	# Give them credit for answering
	# 1. Figure out how many seconds they took
	var time_taken_seconds = (Time.get_ticks_msec() - turn_start_time) / 1000.0
	
	# 2. Calculate points: Base 50 pts, minus 5 pts for every second taken. 
	# Use max() to ensure they never get less than 10 points for a correct answer.
	var points_earned = max(10, 50 - floor(time_taken_seconds) * 5)
	current_player["score"] += points_earned
	# Print to console to verify the math while testing
	print(current_player["name"] + " took " + str(time_taken_seconds) + "s and earned " + str(points_earned) + " pts!")
	GameState.register_correct_answer()
	
	# 3. Move to the next player
	GameState.next_player()
	
	# 4. Start the next turn
	start_turn()

func _on_bomb_timer_timeout():
	tick_audio.stop()
	explode_bomb()

func explode_bomb():
	var loser = GameState.players[GameState.current_player_index]
	
	player_label.hide()
	question_label.hide()
	card_container.hide()
	pass_bomb_button.hide()
	
	loser_label.text = loser["name"] + " BLEW UP!"
	
	# --- NEW LEADERBOARD LOGIC ---
	var scores_text = ""
	
	loser.score = 0
	# Sort players by score (highest to lowest) using a custom lambda function
	var sorted_players = GameState.players.duplicate()
	sorted_players.sort_custom(func(a, b): return a["score"] > b["score"])
	
	for player in sorted_players:
		scores_text += player["name"] + ": " + str(int(player["score"])) + " pts\n"
	
	leaderboard_label.text = scores_text
	# -----------------------------
	
	game_over_overlay.show()

# Connected to the PlayAgainButton
# Connected to the PlayAgainButton
func _on_play_again_button_pressed():
	# --- FULL SYSTEM RESET ---
	
	# 1. Scrub all player data (Wipe cards, scores, and answer streaks)
	for player in GameState.players:
		player["cards"].clear()
		player["score"] = 0
		player["correct_answers"] = 0
		
	# 2. Refill the question pool from the master list
	active_questions = master_questions.duplicate()
	
	# 3. Reset GameState variables just in case a card was active when it exploded
	GameState.play_direction = 1 
	GameState.is_next_turn_double = false 
	
	# 4. Reshuffle the players so whoever blew up doesn't always start first
	GameState.players.shuffle()
	GameState.current_player_index = 0
	
	# -------------------------

	# Hide the overlay and restore the gameplay UI
	game_over_overlay.hide()
	pass_bomb_button.show()
	card_container.show()
	question_label.show()
	
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
			GameState.next_player()
			start_turn()
		"reverse":
			# Flip direction and immediately pass to the previous person
			GameState.play_direction *= -1
			GameState.next_player()
			start_turn()
		"double":
			GameState.is_next_turn_double = true
			GameState.next_player()
			start_turn()
