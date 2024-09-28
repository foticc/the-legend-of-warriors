class_name StateMachine extends Node

var current_state: int = -1:
	set(state):
		owner.transition_state(current_state,state)
		current_state = state
		state_time = 0
# 注意类型！！！！！！！！！ 要么加类型float 要么设置初值为0.0 来表达float
# 否则的话 下方的 state_time+=delta 会不正确，被强转为0 导致每一帧都加不到1，永远为0
var state_time:float = 0

func _ready() -> void:
	await owner.ready
	current_state = 0


func _physics_process(delta: float) -> void:
	while true:
		var next = owner.get_next_state(current_state) as int
		if current_state == next:
			break
		current_state = next
	owner.tick_physics(current_state,delta)
	state_time+=delta
