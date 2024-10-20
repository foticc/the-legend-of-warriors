class_name Player
extends CharacterBody2D

enum State{
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
	ATTACK_1,
	ATTACK_2,
	ATTACK_3
}

var default_gravity := ProjectSettings.get_setting("physics/2d/default_gravity") as float

# 处在地板上的情况
const GROUND_STATES:=[
	State.IDLE,State.RUNNING,State.LANDING,
	State.ATTACK_1,State.ATTACK_2,State.ATTACK_3
]

const SPEED = 300.0
const JUMP_VELOCITY = -300.0
const WALL_JUMP_VELOCITY = Vector2(500,-300)
const AIR_A = SPEED/0.1
const FLOOR_A = SPEED/0.2

var is_first_frame := false

@export var can_combo := false

var is_combo_request := false

@onready var graphics: Node2D = $Graphics
@onready var hand_check: RayCast2D = $Graphics/HandCheck
@onready var foot_check: RayCast2D = $Graphics/FootCheck

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var timer: Timer = $CoyoteTimer
# 在快要接触地面时也可以起跳
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var state_machine: StateMachine = $StateMachine


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		jump_request_timer.start()
	# 松开跳跃  松开跳跃键后
	#if not is_zero_approx(velocity.y):
		#print(velocity)
	# 如果松开跳跃键时 y方向的速度  y向上的分量为负数 
	# 如果松开跳跃键时,人物已经比JUMP_VELOCITY/2 还要小(往上为负数，也就是在JUMP_VELOCITY/2上方)
	# 将velocity.y = JUMP_VELOCITY/2 加速人物下落
	if event.is_action_released("ui_accept"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY/2:
			velocity.y = JUMP_VELOCITY/2
	if event.is_action_pressed("attack"):
		is_combo_request = true

#func _physics_process(delta: float) -> void:
	## Add the gravity.
	#if not is_on_floor():
		#velocity += get_gravity() * delta
	#
	## 人物处于地板上，或者计时器剩余时间大于0 ，可以起跳
	#var can_jump = is_on_floor() or timer.time_left > 0
	#var should_jump = can_jump and jump_request_timer.time_left > 0
	## Handle jump.
	#if should_jump:
		#velocity.y = JUMP_VELOCITY
		## 起跳之后 停止计时器，避免反复起跳
		#timer.stop()
		#jump_request_timer.stop()
#
	## Get the input direction and handle the movement/deceleration.
	## As good practice, you should replace UI actions with custom gameplay actions.
	#var direction := Input.get_axis("ui_left", "ui_right")
	#var a:= FLOOR_A if is_on_floor() else AIR_A
	#if direction:
		#velocity.x = move_toward(velocity.x,direction * SPEED,a*delta) 
	#else:
		#velocity.x = move_toward(velocity.x, 0, SPEED)
	#
	## 在地板上
	#if is_on_floor():
		## 速度值几乎为0代表不运动
		#if is_zero_approx(direction) and is_zero_approx(velocity.x):
			#animation_player.play("idle")
		#else:
			#animation_player.play("running")
	#elif velocity.y < 0:
		#animation_player.play("jumping")
	#else:
		#animation_player.play("fall")
	#
	#if not is_zero_approx(direction):
		#sprite_2d.flip_h = direction<0
	#
	##记录是否在地板上
	#var is_onfloor := is_on_floor()
	#
	#move_and_slide()
	#
	## 是否在地板上  状态和之前不同
	#if is_on_floor()!=is_onfloor:
		## 并且之前的状态是在地板上，现在不在了，现在处于腾空状态 并且判断不是因为主动起跳离开的地板
		#if is_onfloor and not should_jump:
			#timer.start()
		#else:
			#timer.stop()


func get_next_state(state:State)->State:
	# 人物处于地板上，或者计时器剩余时间大于0 ，可以起跳
	var can_jump := is_on_floor() or timer.time_left > 0
	var should_jump := can_jump and jump_request_timer.time_left > 0
	# Handle jump.
	if should_jump:
		return State.JUMP
	
	# 如果状态为在地板上的状态，但实际不在，进入下落状态
	if state in GROUND_STATES and not is_on_floor():
		return State.FALL

		
	var direction := Input.get_axis("ui_left", "ui_right")
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	match state:
		State.IDLE:
			if Input.is_action_pressed("attack"):
				return State.ATTACK_1
			if not is_still:
				return State.RUNNING
		State.RUNNING:
			if Input.is_action_pressed("attack"):
				return State.ATTACK_1
			if is_still:
				return State.IDLE
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
			if can_wall_slide():
				return State.WALL_SLIDING
		State.LANDING:
			if not is_still:
				return State.RUNNING
			if not animation_player.is_playing():
				return State.IDLE
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
		State.WALL_JUMP:
			if can_wall_slide() and not is_first_frame:
				return State.WALL_SLIDING
			if velocity.y >=0:
				return State.FALL
		State.ATTACK_1:
			if not animation_player.is_playing():
				return State.ATTACK_2 if is_combo_request else State.IDLE
		State.ATTACK_2:
			if not animation_player.is_playing():
				return State.ATTACK_3 if is_combo_request else State.IDLE
		State.ATTACK_3:
			if not animation_player.is_playing():
				return State.IDLE
	return state

func transition_state(from:State,to:State):
	#print("[%s]from [%s]--->[%s]"%
		#[
			#Engine.get_physics_frames(),
			#State.keys()[from] if from != -1 else "START",
			#State.keys()[to]
		#]
	#)
	if from not in GROUND_STATES and to in GROUND_STATES:
		timer.stop()
	match to:
		State.RUNNING:
			animation_player.play("running")
		State.IDLE:
			animation_player.play("idle")
		State.JUMP:
			animation_player.play("jumping")
			velocity.y = JUMP_VELOCITY
			# 起跳之后 停止计时器，避免反复起跳
			timer.stop()
			jump_request_timer.stop()
		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATES:
				timer.start()
		State.LANDING:
			animation_player.play("landing")
		State.WALL_SLIDING:
			animation_player.play("wall_sliding")
		State.WALL_JUMP:
			animation_player.play("jumping")
			velocity = WALL_JUMP_VELOCITY
			velocity.x *= get_wall_normal().x 
			jump_request_timer.stop()
		State.ATTACK_1:
			animation_player.play("attack_1")
			is_combo_request = false
		State.ATTACK_3:
			animation_player.play("attack_2")
			is_combo_request = false
		State.ATTACK_3:
			animation_player.play("attack_3")
			is_combo_request = false
	#if to==State.WALL_JUMP:
		#Engine.time_scale = 0.3
	#if from == State.WALL_JUMP:
		#Engine.time_scale = 1
	is_first_frame = true

func tick_physics(state:State,delta: float):
	match state:
		State.RUNNING:
			move(default_gravity,delta)
		State.IDLE:
			move(default_gravity,delta)
		State.JUMP:
			move(0.0 if is_first_frame else default_gravity,delta)
		State.FALL:
			move(default_gravity,delta)
		State.LANDING:
			stand(default_gravity,delta)
		State.WALL_SLIDING:
			move(default_gravity/3,delta)
			# 墙面法线，翻转人物
			graphics.scale.x = get_wall_normal().x
		State.WALL_JUMP:
			if state_machine.state_time > 0.1:
				stand(0.0 if is_first_frame else default_gravity,delta)
				graphics.scale.x = get_wall_normal().x
			else:
				move(default_gravity,delta)
		State.ATTACK_1,State.ATTACK_2,State.ATTACK_3:
			stand(default_gravity,delta)
	is_first_frame = false

func move(gravity:float,delta:float):
	var direction := Input.get_axis("ui_left", "ui_right")
	var a:= FLOOR_A if is_on_floor() else AIR_A
	if direction:
		velocity.x = move_toward(velocity.x,direction * SPEED,a*delta) 
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	if not is_on_floor():
		velocity.y += gravity * delta
	if not is_zero_approx(direction):
		graphics.scale.x = -1 if direction<0 else 1
	move_and_slide()

func stand(gravity:float,delta:float)->void:
	var a:= FLOOR_A if is_on_floor() else AIR_A
	velocity.x = move_toward(velocity.x, 0, a*delta)
	velocity.y += gravity * delta
	move_and_slide()


func can_wall_slide()->bool:
	return is_on_wall() and hand_check.is_colliding() and foot_check.is_colliding()
