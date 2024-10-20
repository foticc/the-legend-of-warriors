extends Enemy

enum State {
	IDLE,
	WALK,
	RUN,
}
@onready var wall_checker: RayCast2D = $Graphics/WallChecker
@onready var player_checker: RayCast2D = $Graphics/PlayerChecker
@onready var floor_checker: RayCast2D = $Graphics/FloorChecker
@onready var calm_down_timer: Timer = $CalmDownTimer

# 是否能看见player 防止boar 透过墙检测到player进入RUN 状态
func can_see_player() -> bool:
	if not player_checker.is_colliding():
		return false
	return player_checker.get_collider() is Player

func transition_state(from:State,to:State)->void:
	print("[%s]from [%s]--->[%s]"%
		[
			Engine.get_physics_frames(),
			State.keys()[from] if from != -1 else "START",
			State.keys()[to]
		]
	)
	match to:
		State.IDLE:
			animation_player.play("idle")
			if wall_checker.is_colliding():
				direction *=-1
		State.WALK:
			animation_player.play("walk")
			if not floor_checker.is_colliding():
				direction *=-1
				# 因为godot 会缓存raycast 的碰撞结果，要刷新一次
				floor_checker.force_raycast_update()
		State.RUN:
			animation_player.play("run")

func tick_physics(state:State,delta:float)->void:
	match state:
		State.IDLE:
			move(0,delta)
		State.WALK:
			move(max_speed/3,delta)
		State.RUN:
			# 转身
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				direction *=-1
			move(max_speed,delta)
			if can_see_player():
				calm_down_timer.start()

func get_next_state(state:State)->State:
	if can_see_player():
		return State.RUN
	match state:
		State.IDLE:
			# 站的时间够了 进入走状态
			if state_machine.state_time > 2:
				return State.WALK
		State.WALK:
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				return State.IDLE
		State.RUN:
			if calm_down_timer.is_stopped():
				return State.WALK
	return state


func _on_hurt_box_hurt(hitbox: HitBox) -> void:
	print("卧槽，你小子大胆！") #  # Replace with function body.
