extends Area3D

@export var rotation_speed := 1

signal collected()

func _ready():
	self.body_entered.connect(_on_body_entered)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	rotate(Vector3(0, 1, 0), rotation_speed * delta)

func _on_body_entered(body:Node):
	emit_signal("collected")
	queue_free()
