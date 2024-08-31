extends CharacterBody2D

enum State{
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING
}

var default_gravity := ProjectSettings.get_setting("physics/2d/default_gravity") as float

# 处在地板上的情况
const GROUND_STATES:=[State.IDLE,State.RUNNING,State.LANDING]

const SPEED = 300.0
const JUMP_VELOCITY = -300.0
const AIR_A = SPEED/0.02
const FLOOR_A = SPEED/0.2

var is_first_frame := false

@onready var graphics: Node2D = $Graphics
@onready var hand_check: RayCast2D = $Graphics/HandCheck
@onready var foot_check: RayCast2D = $Graphics/FootCheck

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var timer: Timer = $CoyoteTimer
# 在快要接触地面时也可以起跳
@onready var jump_request_timer: Timer = $JumpRequestTimer


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		jump_request_timer.start()
	# 松开跳跃  松开跳跃键后
	if not is_zero_approx(velocity.y):
		print(velocity)
	# 如果松开跳跃键时 y方向的速度  y向上的分量为负数 
	# 如果松开跳跃键时,人物已经比JUMP_VELOCITY/2 还要小(往上为负数，也就是在JUMP_VELOCITY/2上方)
	# 将velocity.y = JUMP_VELOCITY/2 加速人物下落
	if event.is_action_released("ui_accept"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY/2:
			velocity.y = JUMP_VELOCITY/2

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
	var direction := Input.get_axis("ui_left", "ui_right")
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	match state:
		State.IDLE:
			if not is_still:
				return State.RUNNING
		State.RUNNING:
			if not is_on_floor(): 
				return State.FALL
			if is_still:
				return State.IDLE
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
			if is_on_wall() and hand_check.is_colliding() and foot_check.is_colliding():
				return State.WALL_SLIDING
		State.LANDING:
			if not is_still:
				return State.RUNNING
			if not animation_player.is_playing():
				return State.IDLE
		State.WALL_SLIDING:
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
	return state

func transition_state(from:State,to:State):
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
			stand(delta)
		State.WALL_SLIDING:
			move(default_gravity/3,delta)
			# 墙面法线，翻转人物
			graphics.scale.x = get_wall_normal().x
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

func stand(delta:float)->void:
	var a:= FLOOR_A if is_on_floor() else AIR_A
	velocity.x = move_toward(velocity.x, 0, a*delta)
	velocity.y += default_gravity * delta
	move_and_slide()
