extends Control


# Constants
const PlayerListEntryScene: PackedScene = preload("uid://dk5q8jhc82bdm")
const GameScenePath: String = "uid://b3j0l1wrankxw"

# Node References
@onready var name_input: LineEdit = %NameInput
@onready var player_list: VBoxContainer = %PlayerList
@onready var start_button: Button = %StartGameButton


# ==============================================================================
# Built-In Engine Lifecycle Functions
# ==============================================================================

func _ready() -> void:
	start_button.disabled = true
	GameState.players.clear()


# ==============================================================================
# UI List Operations
# ==============================================================================

# Instantiates a new name entry and types it out letter-by-letter
func update_player_list_ui(player_name: String) -> void:
	var label: Label = PlayerListEntryScene.instantiate() as Label
	label.text = "- " + player_name
	label.visible_ratio = 0.0
	player_list.add_child(label)
	
	# Scale typewriter speed based on how long the player name is
	var duration: float = max(0.15, player_name.length() * 0.04)
	
	var type_tween: Tween = create_tween()
	type_tween.tween_property(label, "visible_ratio", 1.0, duration)\
		.set_trans(Tween.TRANS_LINEAR)


# ==============================================================================
# Signal Callback Handlers
# ==============================================================================

# Validates input, builds the player data dictionary, and checks team limit thresholds
func _on_add_player_button_pressed() -> void:
	name_input.placeholder_text = "Enter Player Name"
	var player_name: String = name_input.text.strip_edges()
	
	# Block empty submissions
	if player_name.is_empty():
		return
		
	# Block identical name copies
	for player: Dictionary in GameState.players:
		if player["name"].to_lower() == player_name.to_lower():
			name_input.text = ""
			name_input.placeholder_text = "Name already taken!"
			return
			
	# Construct core structural dataset for the new participant
	var new_player: Dictionary = {
		"name": player_name,
		"cards": [],
		"score": 0,
		"correct_answers": 0
	}
	GameState.players.append(new_player)
	update_player_list_ui(player_name)
	name_input.text = ""
	
	# Unlock start button with a swell punch animation if group threshold met
	if GameState.players.size() >= 2 and start_button.disabled:
		start_button.disabled = false
		start_button.pivot_offset_ratio = Vector2.ONE / 2.0
		
		var btn_tween: Tween = create_tween()
		btn_tween.tween_property(start_button, "scale", Vector2(1.2, 1.2), 0.15)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		btn_tween.tween_property(start_button, "scale", Vector2.ONE, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Shuffles seating alignment and transfers context over to the action arena map
func _on_start_game_button_pressed() -> void:
	GameState.players.shuffle()
	GameState.current_player_index = 0 
	SceneTransition.change_scene(GameScenePath)
