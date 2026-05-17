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

var pulse_tween: Tween
var shake_strength: float = 0.0


func _ready():
	load_questions()
	start_new_round()
	start_pulse_animation()


func start_pulse_animation():
	if pulse_tween:
		pulse_tween.kill() # Stop any existing pulse
	pass_bomb_button.scale = Vector2.ONE
	
	pass_bomb_button.pivot_offset_ratio = Vector2.ONE / 2.0
	pulse_tween = create_tween().set_loops() # Loop infinitely
	
	# Swell up slightly over 0.4 seconds
	pulse_tween.tween_property(pass_bomb_button, "scale", Vector2(1.05, 1.05), 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	# Shrink back down
	pulse_tween.tween_property(pass_bomb_button, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
	
	# Setup Player Label (Start tiny and transparent)
	player_label.pivot_offset = player_label.size / 2.0
	player_label.scale = Vector2(0.5, 0.5)
	player_label.modulate.a = 0.0
	
	# Setup Question Label for Typewriter (Fully visible opacity, but 0 letters showing)
	question_label.modulate.a = 1.0 
	question_label.visible_ratio = 0.0 
	
	var turn_tween = create_tween().set_parallel(true) 
	
	# Bounce the player name
	turn_tween.tween_property(player_label, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	turn_tween.tween_property(player_label, "modulate:a", 1.0, 0.2)
	
	# Type out the question over 0.6 seconds!
	# (We use TRANS_LINEAR so it types at a constant, robotic speed)
	turn_tween.tween_property(question_label, "visible_ratio", 1.0, 0.6)\
		.set_trans(Tween.TRANS_LINEAR)

func _process(delta):
	if not bomb_timer.is_stopped():
		# Increase the pitch/speed of the ticking as time runs out to build tension
		var time_left_ratio = bomb_timer.time_left / bomb_timer.wait_time
		var current_pitch = lerp(2.0, 1.0, time_left_ratio)
		tick_audio.pitch_scale = current_pitch
		
		# FIX B: Sync the heartbeat speed to the audio pitch!
		if pulse_tween and pulse_tween.is_valid():
			pulse_tween.set_speed_scale(current_pitch)
		
		
	if shake_strength > 0.1:
		# 1. Generate a random X and Y offset based on the current strength
		var random_offset = Vector2(
			randf_range(-shake_strength, shake_strength), 
			randf_range(-shake_strength, shake_strength)
		)
	
		# 2. Apply it to the UI container
		position = random_offset
		
		# 3. Decay the strength rapidly over time using lerp
		shake_strength = lerp(shake_strength, 0.0, 10.0 * delta)
	else:
		# Ensure it snaps perfectly back to (0,0) when the shake finishes
		position = Vector2.ZERO
		shake_strength = 0.0

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
	spawn_score_popup(points_earned)
	# Print to console to verify the math while testing
	print(current_player["name"] + " took " + str(time_taken_seconds) + "s and earned " + str(points_earned) + " pts!")
	GameState.register_correct_answer()
	
	# 3. Move to the next player
	GameState.next_player()
	
	# 4. Start the next turn
	start_turn()


func spawn_score_popup(points: int):
	# 1. Create a brand new Label node out of thin air
	var popup = Label.new()
	popup.text = "+" + str(points) + " pts!"
	
	# 2. Basic styling (Make it pop out visually)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Give it a nice bright green/gold color (RGBA)
	popup.modulate = Color(0.2, 1.0, 0.4, 1.0) 
	
	# 3. Add it to your UI layer so it renders on screen
	add_child(popup)
	
	# 4. Position it directly over the center of the Pass Bomb button
	# Wait 1 frame so Godot can calculate the popup text size for the pivot
	await get_tree().process_frame
	popup.pivot_offset = popup.size / 2.0
	
	# Target center: Top-middle of the button
	var spawn_pos = pass_bomb_button.global_position
	spawn_pos.x += (pass_bomb_button.size.x / 2.0) - (popup.size.x / 2.0)
	spawn_pos.y -= 20 # Start slightly above the button
	popup.global_position = spawn_pos
	
	# 5. Create the Burst and Fade Animation
	var score_tween = create_tween().set_parallel(true)
	
	# Float upward by 120 pixels over 0.6 seconds
	score_tween.tween_property(popup, "global_position:y", popup.global_position.y - 120, 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	# Scale up slightly to "burst", then shrink down
	score_tween.tween_property(popup, "scale", Vector2(1.3, 1.3), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Fade out completely over the second half of the life cycle
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.3) # Wait 0.3 seconds before starting fade
	fade_tween.tween_property(popup, "modulate:a", 0.0, 0.3)
	
	# 6. CRITICAL MEMORY STEP: Delete the label when the animations finish
	score_tween.chain().tween_callback(popup.queue_free)


func _on_bomb_timer_timeout():
	tick_audio.stop()
	explode_bomb()

func explode_bomb():
	var loser = GameState.players[GameState.current_player_index]
	
	# --- TRIGGER THE SHAKE ---
	shake_strength = 1000.0
	
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
	
	game_over_overlay.modulate.a = 0.0 # Start fully transparent
	game_over_overlay.show()
	
	var game_over_tween = create_tween()
	game_over_tween.tween_property(game_over_overlay, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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
	player_label.show()
	question_label.show()
	card_container.show()
	pass_bomb_button.show()
	
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
