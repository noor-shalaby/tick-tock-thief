extends Control


# Constants
const CardButtonScene: PackedScene = preload("uid://cjb37l4qn5mxf")
const MainMenuScenePath: String = "uid://rudhctu0u6x5"
const QuestionsFilepath: String = "res://questions.json"

# Game Variables
var master_questions: Array = []
var active_questions: Array = []
var turn_start_time: int = 0
var shake_strength: float = 0.0
var pulse_tween: Tween

# Node References
@onready var scene_tree: SceneTree = get_tree()
@onready var question_label: Label = %QuestionLabel
@onready var player_label: Label = %PlayerNameLabel
@onready var bomb_timer: Timer = $BombTimer
@onready var tick_audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var card_container: GridContainer = %CardContainer
@onready var pass_bomb_button: Button = %PassBombButton
@onready var game_over_overlay: MarginContainer = $GameOverOverlay
@onready var loser_label: Label = %LoserLabel
@onready var leaderboard_label: Label = %LeaderBoardLabel


# ==============================================================================
# Built-In Engine Lifecycle Functions
# ==============================================================================

func _ready() -> void:
	load_questions()
	start_new_round()
	start_pulse_animation()


func _process(delta: float) -> void:
	# Speed up ticking audio and button heartbeat as timer runs down
	if not bomb_timer.is_stopped():
		var time_left_ratio: float = bomb_timer.time_left / bomb_timer.wait_time
		var current_pitch: float = lerp(2.0, 1.0, time_left_ratio)
		tick_audio.pitch_scale = current_pitch
		if pulse_tween and pulse_tween.is_valid():
			pulse_tween.set_speed_scale(current_pitch)
			
	# Generate screen shake vector on Game Over
	if shake_strength > 0.1:
		var random_offset: Vector2 = Vector2(
			randf_range(-shake_strength, shake_strength), 
			randf_range(-shake_strength, shake_strength)
		)
		position = random_offset
		shake_strength = lerp(shake_strength, 0.0, 10.0 * delta)
	else:
		position = Vector2.ZERO
		shake_strength = 0.0


# ==============================================================================
# Core Game Mode Logic
# ==============================================================================

func load_questions() -> void:
	if not FileAccess.file_exists(QuestionsFilepath):
		push_error("Questions file not found!")
		return
		
	var file: FileAccess = FileAccess.open(QuestionsFilepath, FileAccess.READ)
	var content: String = file.get_as_text()
	var parsed_data: Variant = JSON.parse_string(content)
	
	if parsed_data is Array:
		master_questions = parsed_data
		active_questions = master_questions.duplicate() 
	else:
		push_error("Error parsing JSON: Ensure it's a valid array.")


func start_new_round() -> void:
	var bomb_time: int = randi_range(20, 45)
	bomb_timer.start(bomb_time)
	tick_audio.play()
	tick_audio.pitch_scale = 1.0 
	start_turn()


func start_turn() -> void:
	var current_player: Dictionary = GameState.players[GameState.current_player_index]
	player_label.text = current_player["name"] + "'s Turn!"
	
	# Refresh question deck if empty
	if active_questions.is_empty():
		active_questions = master_questions.duplicate()
		
	var q: String = active_questions.pick_random()
	active_questions.erase(q)
	
	# Process Double Ability Card rule
	if GameState.is_next_turn_double:
		var regex: RegEx = RegEx.new()
		regex.compile("\\d+")
		var reg_match: RegExMatch = regex.search(q)
		if reg_match:
			var original_num_str: String = reg_match.get_string()
			var doubled_num: int = original_num_str.to_int() * 2
			q = q.replace(original_num_str, str(doubled_num))
		q += "\n(DOUBLE CHALLENGE!)"
		GameState.is_next_turn_double = false
		
	question_label.text = q
	turn_start_time = Time.get_ticks_msec()
	update_card_ui()
	
	# Reset animations for turn change text pop
	player_label.pivot_offset_ratio = Vector2.ONE / 2.0
	player_label.scale = Vector2.ONE / 2.0
	player_label.modulate.a = 0.0
	question_label.modulate.a = 1.0 
	question_label.visible_ratio = 0.0 
	
	var turn_tween: Tween = create_tween().set_parallel(true) 
	turn_tween.tween_property(player_label, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	turn_tween.tween_property(player_label, "modulate:a", 1.0, 0.2)
	turn_tween.tween_property(question_label, "visible_ratio", 1.0, 0.6)\
		.set_trans(Tween.TRANS_LINEAR)


func pass_turn() -> void:
	GameState.register_correct_answer()
	GameState.next_player()
	start_turn()


func play_card(card_type: String) -> void:
	var current_player: Dictionary = GameState.players[GameState.current_player_index]
	if not card_type in current_player["cards"]:
		return 
		
	current_player["cards"].erase(card_type)
	
	match card_type:
		"shield":
			GameState.next_player()
			start_turn()
		"time_thief":
			bomb_timer.start(max(1.0, bomb_timer.time_left - 5.0))
			GameState.next_player()
			start_turn()
		"reverse":
			GameState.play_direction *= -1
			GameState.next_player()
			start_turn()
		"double":
			GameState.is_next_turn_double = true
			GameState.next_player()
			start_turn()


func explode_bomb() -> void:
	var loser: Dictionary = GameState.players[GameState.current_player_index]
	shake_strength = 1000.0
	
	player_label.hide()
	question_label.hide()
	card_container.hide()
	pass_bomb_button.hide()
	
	loser_label.text = loser["name"] + " BLEW UP!"
	loser.score = 0
	
	# Generate and sort current lobby rankings
	var scores_text: String = ""
	var sorted_players: Array = GameState.players.duplicate()
	sorted_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: 
		return a["score"] > b["score"]
	)
	
	for player: Dictionary in sorted_players:
		scores_text += player["name"] + ": " + str(int(player["score"])) + " pts\n"
	leaderboard_label.text = scores_text
	
	# Fade overlay screen in
	game_over_overlay.modulate.a = 0.0
	game_over_overlay.show()
	var game_over_tween: Tween = create_tween()
	game_over_tween.tween_property(game_over_overlay, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ==============================================================================
# UI Animation & Cosmetic Generation
# ==============================================================================

func start_pulse_animation() -> void:
	if pulse_tween:
		pulse_tween.kill()
		
	pass_bomb_button.scale = Vector2.ONE
	pass_bomb_button.pivot_offset_ratio = Vector2.ONE / 2.0
	
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(pass_bomb_button, "scale", Vector2(1.05, 1.05), 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(pass_bomb_button, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func update_card_ui() -> void:
	for child: Node in card_container.get_children():
		child.queue_free()
		
	var current_player: Dictionary = GameState.players[GameState.current_player_index]
	for card: String in current_player["cards"]:
		var btn: Button = CardButtonScene.instantiate()
		card_container.add_child(btn) 
		btn.setup(card)
		btn.card_played.connect(_on_card_played)


func spawn_score_popup(points: int) -> void:
	var popup: Label = Label.new()
	popup.text = "+" + str(points) + " pts!"
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.modulate = Color(0.2, 1.0, 0.4, 1.0) 
	add_child(popup)
	
	await scene_tree.process_frame
	popup.pivot_offset = popup.size / 2.0
	
	var spawn_pos: Vector2 = pass_bomb_button.global_position
	spawn_pos.x += (pass_bomb_button.size.x / 2.0) - (popup.size.x / 2.0)
	spawn_pos.y -= 20
	popup.global_position = spawn_pos
	
	# Score burst and float up animation
	var score_tween: Tween = create_tween().set_parallel(true)
	score_tween.tween_property(popup, "global_position:y", popup.global_position.y - 120, 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	score_tween.tween_property(popup, "scale", Vector2(1.3, 1.3), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	var fade_tween: Tween = create_tween()
	fade_tween.tween_interval(0.3)
	fade_tween.tween_property(popup, "modulate:a", 0.0, 0.3)
	
	score_tween.chain().tween_callback(popup.queue_free)


# ==============================================================================
# Signal Callback Handlers
# ==============================================================================

func _on_pass_bomb_button_pressed() -> void:
	var current_player: Dictionary = GameState.players[GameState.current_player_index]
	var time_taken_seconds: float = (Time.get_ticks_msec() - turn_start_time) / 1000.0
	var points_earned: int = max(10, 50 - floor(time_taken_seconds) * 5)
	
	current_player["score"] += points_earned
	spawn_score_popup(points_earned)
	
	print(current_player["name"] + " took " + str(time_taken_seconds) + "s and earned " + str(points_earned) + " pts!")
	pass_turn()


func _on_bomb_timer_timeout() -> void:
	tick_audio.stop()
	explode_bomb()


func _on_play_again_button_pressed() -> void:
	for player: Dictionary in GameState.players:
		player["cards"].clear()
		player["score"] = 0
		player["correct_answers"] = 0
		
	active_questions = master_questions.duplicate()
	GameState.play_direction = 1 
	GameState.is_next_turn_double = false 
	GameState.players.shuffle()
	GameState.current_player_index = 0
	
	game_over_overlay.hide()
	player_label.show()
	question_label.show()
	card_container.show()
	pass_bomb_button.show()
	
	start_new_round()


func _on_main_menu_button_pressed() -> void:
	GameState.players.clear()
	SceneTransition.change_scene(MainMenuScenePath)


func _on_card_played(card_type: String) -> void:
	play_card(card_type)
	update_card_ui()
