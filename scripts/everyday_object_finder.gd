extends Node3D

const TargetObjectScene := preload("res://scripts/target_object.gd")

@export_range(1, 3, 1) var therapist_detail_level := 1

var _targets: Array[TargetObject] = []
var _round_order := ["cup", "phone", "fork"]
var _round_index := 0
var _score := 0
var _round_locked := false
var _status_label: Label3D
var _score_label: Label3D
var _help_label: Label3D
var _session_id := 0


func _ready() -> void:
	# Wait for the sibling room and target spawn transforms to be ready.
	call_deferred("_initialize_game")


func _initialize_game() -> void:
	for node in get_tree().get_nodes_in_group("training_targets"):
		if node is TargetObject:
			var target := node as TargetObject
			target.grabbed.connect(_on_target_grabbed)
			_targets.append(target)
	for controller in get_tree().get_nodes_in_group("demo_controllers"):
		controller.button_pressed.connect(_on_controller_button.bind(controller.name == "XRControllerRight"))
	_build_instruction_panel()
	_apply_detail_level()
	_start_round()


func _build_instruction_panel() -> void:
	_status_label = _label(Vector3(0.0, 1.85, -1.65), 46)
	_score_label = _label(Vector3(0.0, 1.65, -1.65), 28)
	_help_label = _label(Vector3(0.0, 1.44, -1.65), 22)
	_help_label.text = "Reach + squeeze side grip to select\nA: restart   X: detail level   B: passthrough"


func _label(position: Vector3, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.position = position
	label.pixel_size = 0.0024
	label.font_size = font_size
	label.outline_size = 6
	label.modulate = Color(1.0, 0.95, 0.80)
	label.no_depth_test = false
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	return label


func _unhandled_input(event: InputEvent) -> void:
	# A left-click performs the desktop equivalent of grabbing a virtual object in XR.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var origin := camera.project_ray_origin(event.position)
			var end := origin + camera.project_ray_normal(event.position) * 100.0
			var query := PhysicsRayQueryParameters3D.create(origin, end)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.get("collider") is TargetObject:
				_on_target_grabbed(hit.get("collider") as TargetObject)
			return

	# Keyboard choices provide a desktop-only way to test the same round logic as XR grabbing.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			restart_session()
			return
		if event.keycode == KEY_L:
			cycle_detail_level()
			return
		var choice := -1
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			choice = 0
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			choice = 1
		elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
			choice = 2
		if choice >= 0 and choice < _targets.size():
			_on_target_grabbed(_targets[choice])


func _start_round() -> void:
	if _round_index >= _round_order.size():
		for target in _targets:
			target.reset_to_start()
		_status_label.text = "Session complete - well done!"
		_score_label.text = "Correct: %d / %d  |  Detail: %d / 3" % [_score, _round_order.size(), therapist_detail_level]
		return
	_round_locked = false
	for target in _targets:
		target.reset_to_start()
	_status_label.text = "Find the %s" % _round_order[_round_index]
	_score_label.text = "Correct: %d / %d  |  Detail: %d / 3" % [_score, _round_order.size(), therapist_detail_level]


func _on_target_grabbed(target: TargetObject) -> void:
	if _round_locked or _round_index >= _round_order.size():
		return
	_round_locked = true
	var active_session := _session_id
	if target.object_id == _round_order[_round_index]:
		_score += 1
		_status_label.text = "Correct: %s" % target.display_name.capitalize()
		_round_index += 1
		await get_tree().create_timer(0.9).timeout
		if active_session != _session_id:
			return
		_start_round()
	else:
		_status_label.text = "Try again"
		target.reset_to_start()
		await get_tree().create_timer(0.6).timeout
		if active_session != _session_id:
			return
		_round_locked = false
		_status_label.text = "Find the %s" % _round_order[_round_index]


func _apply_detail_level() -> void:
	for target in _targets:
		target.set_detail_level(therapist_detail_level)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material


func _on_controller_button(action: String, right_hand: bool) -> void:
	if action == "ax_button":
		if right_hand:
			restart_session()
		else:
			cycle_detail_level()

func restart_session() -> void:
	_session_id += 1
	_round_index = 0
	_score = 0
	_round_locked = false
	_start_round()

func cycle_detail_level() -> void:
	therapist_detail_level = therapist_detail_level % 3 + 1
	_apply_detail_level()
	_score_label.text = "Correct: %d / %d  |  Detail: %d / 3" % [_score, _round_order.size(), therapist_detail_level]
