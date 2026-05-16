extends Node

var players: Array = [] 
var current_player_index: int = 0
var play_direction: int = 1 

const CARDS = ["shield", "time_thief", "reverse", "double"]
const ANSWERS_NEEDED = 3

func next_player():
	current_player_index += play_direction
	
	# Wrap around logic
	if current_player_index >= players.size():
		current_player_index = 0
	elif current_player_index < 0:
		current_player_index = players.size() - 1
		
	return players[current_player_index]

# Call this when the player answers correctly
func register_correct_answer():
	var player = players[current_player_index]
	player["correct_answers"] += 1
	
	if player["correct_answers"] >= ANSWERS_NEEDED:
		player["correct_answers"] = 0 # Reset counter
		grant_card(player)

func grant_card(player: Dictionary):
	var new_card = CARDS.pick_random()
	player["cards"].append(new_card)
	print(player["name"] + " got a card: " + new_card)
