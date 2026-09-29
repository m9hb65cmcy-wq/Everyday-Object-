## TEMPLATE FILE ############################
# This file is the main script that enables the central workings of XR in Godot.
# This file specifically hinges on the fact that Godot propagates _ready() signals
# up through children, so all things are done in order.
#############################################

extends Node3D
var xr_interface: OpenXRInterface
var desktop_camera: Camera3D
var desktop_yaw := 0.0
var desktop_pitch := 0.0
const DESKTOP_SPEED := 2.7
const DESKTOP_MOUSE_SENSITIVITY := 0.003

## Preferred refresh rate. Will fallback to what the headset reports
@export var target_refresh_rate := 72.0
@export var desktop_preview := false

func _ready() -> void:
	if desktop_preview:
		_enable_desktop_preview()
		return

	# First, we get the current xr_interface. This is defined in the settings, and if undefined, you likely
	# have not enalbed XR in settings.
	xr_interface = XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr_interface == null:
		_enable_desktop_preview()
		return

	# A headset is optional while building. Fall back to a desktop camera when none is connected.
	if not xr_interface.is_initialized() and not xr_interface.initialize():
		_enable_desktop_preview()
		return

	print("Main|INFO: OpenXR initialised successfully")

	# XR runtime frame pacing
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	get_viewport().use_xr = true

	xr_interface.session_begun.connect(_on_session_begun)


func _on_session_begun() -> void:
	var rates := xr_interface.get_available_display_refresh_rates()
	if target_refresh_rate in rates:
		xr_interface.display_refresh_rate = target_refresh_rate
	elif not rates.is_empty():
		print("Main|WARN: %s Hz unavailable, runtime offers %s" % [target_refresh_rate, rates])

	# Match physics to the actual rate.
	var actual: float = xr_interface.display_refresh_rate
	if actual > 0.0:
		Engine.physics_ticks_per_second = int(round(actual))
	print("Main|INFO: running at %s Hz" % Engine.physics_ticks_per_second)


func _enable_desktop_preview() -> void:
	desktop_preview = true
	print("Main|INFO: desktop 3D preview enabled")
	var camera := Camera3D.new()
	camera.name = "DesktopPreviewCamera"
	camera.position = Vector3(0.0, 1.7, 1.1)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.1, -0.85), Vector3.UP)
	desktop_camera = camera
	desktop_yaw = camera.rotation.y
	desktop_pitch = camera.rotation.x
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if not desktop_preview or desktop_camera == null:
		return
	var movement := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		movement.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		movement.z += 1.0
	if Input.is_key_pressed(KEY_A):
		movement.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		movement.x += 1.0
	if Input.is_key_pressed(KEY_Q):
		movement.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		movement.y += 1.0
	if movement.length() > 0.0:
		desktop_camera.position += desktop_camera.global_transform.basis * movement.normalized() * DESKTOP_SPEED * delta


func _input(event: InputEvent) -> void:
	if not desktop_preview:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and desktop_camera != null:
		desktop_yaw -= event.relative.x * DESKTOP_MOUSE_SENSITIVITY
		desktop_pitch = clamp(desktop_pitch - event.relative.y * DESKTOP_MOUSE_SENSITIVITY, -1.35, 1.35)
		desktop_camera.rotation = Vector3(desktop_pitch, desktop_yaw, 0.0)
