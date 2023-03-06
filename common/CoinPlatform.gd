extends Node3D

signal coin_collected()

func _ready():
	var collectible = get_node("Collectible")
	collectible.collected.connect(on_coin_collected)

func on_coin_collected():
	emit_signal("coin_collected")

