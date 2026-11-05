class_name AimInput
extends Control
## Dedicated aim surface sits below HUD controls, so UI clicks cannot lay the gun.
signal dragged(amount: Vector2)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and event.index == 0:
		dragged.emit(event.relative)
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		dragged.emit(event.relative)
		accept_event()
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		accept_event()
