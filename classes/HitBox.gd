class_name HitBox
extends Area2D

signal hit(hurtBox:HurtBox)


func _init() -> void:
	area_entered.connect(_on_area_enerted)

func _on_area_enerted(hurtBox:HurtBox)->void:
	print("[hit] %s => %s)"% [owner.name,hurtBox.owner.name])
	hit.emit(hurtBox)
	hurtBox.hurt.emit(self)
