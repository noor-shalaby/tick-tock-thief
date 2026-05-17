extends Node


# Constants
const CARDS: Array[String] = ["shield", "time_thief", "reverse", "double"]
const ANSWERS_NEEDED: int = 3

# Global Game State Variables
var players: Array[Dictionary] = [] 
var current_player_index: int = 0
var play_direction: int = 1 
var is_next_turn_double: bool = false


# Track player answers and award an item card if milestone is hit
func register_correct_answer() -> void:
	var player: Dictionary = players[current_player_index]
	player["correct_answers"] += 1
	
	if player["correct_answers"] >= ANSWERS_NEEDED:
		player["correct_answers"] = 0
		grant_card(player)


# Pick a random ability card and add it to the player's inventory
func grant_card(player: Dictionary) -> void:
	var new_card: String = CARDS.pick_random()
	player["cards"].append(new_card)
	print(player["name"] + " got a card: " + new_card)


# Cycle to the next player based on turn layout and boundary caps
func next_player() -> Dictionary:
	current_player_index += play_direction
	
	# Keep index cleanly wrapped inside player array limits
	if current_player_index >= players.size():
		current_player_index = 0
	elif current_player_index < 0:
		current_player_index = players.size() - 1
		
	return players[current_player_index]
