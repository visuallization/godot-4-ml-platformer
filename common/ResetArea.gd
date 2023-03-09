extends Area3D

signal on_enter()

func _ready():
	self.body_entered.connect(on_body_entered)

func get_size():
	var size: Vector3 = get_node("CollisionShape3D").shape.extents
	return size

func on_body_entered(body: Node):
	emit_signal("on_enter")
