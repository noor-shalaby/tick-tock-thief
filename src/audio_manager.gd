extends Node


@onready var SFXOneShotScene: PackedScene = preload("uid://neh0al1bepdt")


func play_sfx() -> void:
	var sfx: AudioStreamPlayer = SFXOneShotScene.instantiate()
	add_child(sfx)
	sfx.connect("finished", sfx.queue_free)
