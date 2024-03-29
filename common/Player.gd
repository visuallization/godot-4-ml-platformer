extends RigidBody3D

@export var slope_limit := 45.0
@export var move_speed := 10.0
@export var turn_speed := 8.0
@export var jump_speed := 8.0
@export var jump_drag := 2.0

var is_grounded := false : get = get_is_grounded
var forward_input := 0.0 : get = get_forward_input, set = set_forward_input
var turn_input := 0.0 : get = get_turn_input, set = set_turn_input
var jump_input := false : get = get_jump_input, set = set_jump_input

var resetted_transform = null

@onready var capsule_collider: CollisionShape3D = $CapsuleCollider

func _physics_process(delta) -> void:
	check_grounded()

func _integrate_forces(state) -> void:
	if resetted_transform:
		state.linear_velocity = Vector3.ZERO
		state.transform = resetted_transform
		
		resetted_transform = null
		
	process_actions(state)

func reset(position: Transform3D) -> void:
	resetted_transform = position
	
func check_grounded() -> void:
	is_grounded = false
	var capsule_height: float = max(capsule_collider.shape.radius * 2.0, capsule_collider.shape.height)
	var capsule_bottom: Vector3 = global_position + (capsule_collider.position - Vector3.UP * (capsule_height / 2.0))
	var radius: float = (scale * Vector3(capsule_collider.shape.radius, 0.0, 0.0)).length()
	var space_state := get_world_3d().direct_space_state
	var from: Vector3 = capsule_bottom + global_transform.basis.y * 0.1
	var to: Vector3 = capsule_bottom - global_transform.basis.y * 2
	var hit := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit:
		var normal_angle: float = hit.normal.angle_to(global_transform.basis.y)
		if normal_angle < slope_limit:
			var max_distance = radius / cos(deg_to_rad(normal_angle)) - radius + 0.2
			var hit_distance = from.distance_to(hit.position)
			if hit_distance < max_distance:
				is_grounded = true
	
func process_actions(state: PhysicsDirectBodyState3D) -> void:
	# Rotation
	if turn_input != 0.0:
		var angle: float = clamp(turn_input, -1.0, 1.0) * turn_speed
		state.transform.basis = state.transform.basis.rotated(Vector3.UP, get_physics_process_delta_time() * angle)

	# Movement & Jumping
	if is_grounded:
		state.linear_velocity = Vector3.ZERO

		if jump_input:
			state.linear_velocity += Vector3.UP * jump_speed
		
		state.linear_velocity += -global_transform.basis.z * clamp(forward_input, -1.0, 1.0) * move_speed
	else:
		# Check if player tries to move while jumping/falling
		if not is_zero_approx(forward_input):
			# make it possible to move the player at half speed when jumping/falling
			var vertical_velocity: Vector3 = state.linear_velocity.project(Vector3.UP)
			state.linear_velocity = vertical_velocity + (-global_transform.basis.z) * clamp(forward_input, -1.0, 1.0) * (move_speed / jump_drag)

# Setter & Getter
func get_is_grounded() -> bool:
	return is_grounded

func set_forward_input(input: float) -> void:
	forward_input = input

func get_forward_input() -> float:
	return forward_input

func set_turn_input(input: float) -> void:
	turn_input = input

func get_turn_input() -> float:
	return turn_input

func set_jump_input(input: bool) -> void:
	jump_input = input

func get_jump_input() -> bool:
	return jump_input
