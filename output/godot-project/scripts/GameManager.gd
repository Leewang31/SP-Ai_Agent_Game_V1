extends Node

const BOT_COUNT  : int   = 10
const SPAWN_AREA : float = 20.0
const BOT_SCENE          = preload("res://scenes/Bot.tscn")

func _ready() -> void:
	_spawn_bots()

func _spawn_bots() -> void:
	for i in BOT_COUNT:
		var bot : CharacterBody3D = BOT_SCENE.instantiate()
		bot.position = Vector3(
			randf_range(-SPAWN_AREA, SPAWN_AREA),
			1.0,
			randf_range(-SPAWN_AREA, SPAWN_AREA)
		)
		get_parent().call_deferred("add_child", bot)
