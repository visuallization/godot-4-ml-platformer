extends Node

@export var platform_scene: PackedScene
@export var coin_platform_scene: PackedScene
@export var platform_spawn_distance: float = 20.0

@onready var player = $"../Player"
@onready var start_platform = $"../Platform"
@onready var raycast_sensor = $"../Player/RayCastSensor3D"
@onready var reset_area = $"../ResetArea"

var coin_platforms := []

var boundaries: Vector3
var boundary_offset := 10

var player_start_transform: Transform3D
var platform_start_position: Vector3

var rng: RandomNumberGenerator

const MAX_STEPS = 20000

var n_steps := 0
var _heuristic := "player"
var done := false
var needs_reset := false
var reward = 0.0

var move_action: int
var turn_action: int
var jump_action: bool

var best_goal_distance := platform_spawn_distance

func _ready():
	rng = RandomNumberGenerator.new()
	#rng.seed = 42
	rng.randomize()

	boundaries = reset_area.get_size()
	boundaries.x -= boundary_offset
	boundaries.z -= boundary_offset

	player_start_transform = player.global_transform
	raycast_sensor.activate()

	platform_start_position = start_platform.position
	
	spawn_platform(null, true)

func _physics_process(delta):
	#print(raycast_sensor.get_observation())

	n_steps += 1
	if n_steps >= MAX_STEPS:
		done = true
		needs_reset = true

	if needs_reset:
		reset()
		return

	var move = get_move_action()
	var turn = get_turn_action()
	var jump = get_jump_action()

	player.set_forward_input(move)
	player.set_turn_input(turn)
	player.set_jump_input(jump)
	
	update_reward_step()
	
func on_pickup_coin():
	if is_instance_valid(start_platform):
		start_platform.queue_free()

	update_reward(100.0)
	spawn_platform()

func on_game_over():
	done = true
	reset()

func spawn_platform(spawn_origin = null, defer = false):
	var coin_platform
	if coin_platforms.size() > 1:
		coin_platform = coin_platforms.pop_front()
		coin_platform.queue_free()

	coin_platform = coin_platform_scene.instantiate()
	var origin = spawn_origin if spawn_origin != null else Vector3(player.position.x, platform_start_position.y, player.position.z)
	var rotation = Quaternion().from_euler(Vector3.UP * deg_to_rad(rng.randi_range(0, 360)))
	var spawn_position: Vector3 = origin + rotation * Vector3.FORWARD * platform_spawn_distance

	# if the platform would be spawned outside of the envrionment boundaries
	# calculate a new position
	while abs(spawn_position.x) > boundaries.x or abs(spawn_position.z) > boundaries.z:
		rotation = Quaternion().from_euler(Vector3.UP * deg_to_rad(rng.randi_range(0, 360)))
		spawn_position = origin + rotation * Vector3.FORWARD * platform_spawn_distance
	
	coin_platform.position = spawn_position
	coin_platform.coin_collected.connect(on_pickup_coin)

	# add this deferred call, as this is needed in the _ready function
	# because the parent node is still busy setting up children
	# see here for more information: https://godotengine.org/qa/146487/packedscene-instance-not-working-in-_ready-function
	if defer:
		get_parent().call_deferred("add_child", coin_platform)
	else:
		get_parent().add_child(coin_platform)

	coin_platforms.append(coin_platform)
	reset_best_goal_distance()

func reset():
	needs_reset = false
	n_steps = 0

	if is_instance_valid(start_platform):
		start_platform.queue_free()

	for platform in coin_platforms:
		platform.queue_free()

	coin_platforms.clear()

	start_platform = platform_scene.instantiate()
	start_platform.position = platform_start_position
	get_parent().add_child(start_platform)

	player.reset(player_start_transform)

	spawn_platform(Vector3(0, platform_start_position.y, 0))
	reset_best_goal_distance()

func set_heuristic(heuristic):
	# sets the heuristic from "human" or "model"
	self._heuristic = heuristic

func set_action(action):
	# convert actions from Discrete (0, 1, 2) to expected input values (-1, 0, +1)
	# of the character controller
#	move_action = action["move"] if action["move"] <= 1 else -1
#	turn_action = action["turn"] if action["turn"] <= 1 else -1
#	jump_action = action["jump"] == 1
	
	move_action = action["move"][0]
	turn_action = action["turn"][0]
	jump_action = action["jump"] == 1

func get_action_space():
#	return {
#		"move": {
#			"size": 3, # 0, 1, 2
#			"action_type": "discrete"
#		},
#		"turn": {
#			"size": 3, # 0, 1, 2
#			"action_type": "discrete"
#		},
#		"jump": {
#			"size": 2, # 0, 1
#			"action_type": "discrete"
#		}
#	}

	return {
		"move": {
			"size": 1,
			"action_type": "continuous"
		},
		"turn": {
			"size": 1,
			"action_type": "continuous"
		},
		"jump": {
			"size": 2,
			"action_type": "discrete"
		}
	}

func get_move_action() -> int:
	if done:
		move_action = 0
		return move_action

	if _heuristic == "model":
		return move_action

	return int(Input.get_axis("up", "down"))
	
func get_turn_action() -> int:
	if done:
		turn_action = 0
		return turn_action

	if _heuristic == "model":
		return turn_action
	
	return int(Input.get_axis("right", "left"))

func get_jump_action() -> bool:
	if done:
		jump_action = false
		return jump_action
	
	if _heuristic == "model":
		return jump_action

	return Input.is_action_pressed("jump")

func get_obs():
	# The observation of the agent, think of what is the key information that is needed to perform the task, try to have things in coordinates that a relative to the play
	# return a dictionary with the "obs" as a key, you can have several keys

	var goal_distance = 0.0
	var goal_vector = Vector3.ZERO
	
	goal_distance = player.position.distance_to(coin_platforms[-1].position)
	goal_distance = clamp(goal_distance, 0.0, platform_spawn_distance) / platform_spawn_distance
	goal_vector = (coin_platforms[-1].position - player.position).normalized()
	
	var obs = []
	obs.append_array([
		goal_distance,
		goal_vector.x, 
		goal_vector.y, 
		goal_vector.z
	])
	obs.append(player.get_is_grounded())
	obs.append_array(raycast_sensor.get_observation())

	return {
		"obs": obs
	}

func get_obs_space():
	# typs of observation spaces: box, discrete, repeated (for variable length observations)
	return {
		"obs": {
			"size": [len(get_obs()["obs"])],
			"space": "box"
		}
	}

func get_obs_size():
	return len(get_obs())

func get_done():
	return done

func set_done_false():
	done = false

func update_reward(value: float):
	reward += value

#func get_reward():
#	return reward
	# var current_reward = reward
	# reward = 0 # reset the reward to zero on every decision step
	# return current_reward

func reset_best_goal_distance():
	best_goal_distance = platform_spawn_distance
		
func zero_reward():
	reward = 0

func update_reward_step():
	reward -= 0.01 # step penalty
	reward += shaping_reward()
	
func get_reward():
	var current_reward = reward
	reward = 0 # reset the reward to zero checked every decision step
	return current_reward
	
func shaping_reward():
	var s_reward = 0.0
	var goal_distance = 0
	goal_distance = player.position.distance_to(coin_platforms[-1].position)
	
	if goal_distance < best_goal_distance:
		s_reward += best_goal_distance - goal_distance
		best_goal_distance = goal_distance
		
	s_reward /= 1.0
	return s_reward 
