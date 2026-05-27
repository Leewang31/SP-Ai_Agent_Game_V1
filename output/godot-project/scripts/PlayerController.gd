extends CharacterBody3D

const MOVE_SPEED        : float = 5.0
const SPRINT_MULTIPLIER : float = 1.8
const JUMP_VELOCITY     : float = 4.5
const GRAVITY           : float = 9.8
const ATTACK_RANGE      : float = 2.0
const CAM_DISTANCE      : float = 6.0
const MOUSE_SENSITIVITY : float = 0.003
const CAM_PITCH_MIN     : float = -1.22
const CAM_PITCH_MAX     : float =  0.35

@onready var spring_arm : SpringArm3D = $SpringArm3D
@onready var mesh       : MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	spring_arm.spring_length = CAM_DISTANCE
	spring_arm.rotation.x = deg_to_rad(-25.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		spring_arm.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, CAM_PITCH_MIN, CAM_PITCH_MAX)
	elif event.is_action_pressed("ui_cancel") and not event.is_echo():
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("attack") and not event.is_echo():
		_do_attack()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := _get_input_direction()
	var forward   := -transform.basis.z
	var right     := transform.basis.x
	var move_dir  := forward * input_dir.y + right * input_dir.x

	var speed := MOVE_SPEED * (SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1.0)

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	move_and_slide()

func _get_input_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_backward", "move_forward").normalized()

func _do_attack() -> void:
	_play_attack_motion()
	var bots := get_tree().get_nodes_in_group("bots")
	for bot in bots:
		if global_position.distance_to(bot.global_position) <= ATTACK_RANGE:
			bot.take_hit()
			break

func _play_attack_motion() -> void:
	var forward := -transform.basis.z * 0.35
	var tween := create_tween()
	tween.tween_property(mesh, "position", forward, 0.08)
	tween.tween_property(mesh, "position", Vector3.ZERO, 0.10)
