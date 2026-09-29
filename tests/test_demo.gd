extends SceneTree

var errors := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		printerr("FAIL: ", message)
	else:
		print("PASS: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.desktop_preview = true
	root.add_child(scene)
	for i in 5:
		await physics_frame
	var game = scene.get_node("EverydayObjectFinder")
	check(game._targets.size() == 3, "All three targets initialized")
	check(game._status_label.text == "Find the cup", "First round starts")
	for target in game._targets:
		check(target.global_position.y > 0.8 and target.global_position.z < -0.6, target.object_id + " retains its table position")
		check(target._materials.size() > 0, target.object_id + " has detailed model materials")
	var cup = game._targets[0]
	var phone = game._targets[1]
	var color: Color = cup._materials[0].albedo_color
	game.cycle_detail_level()
	game.cycle_detail_level()
	check(cup._materials[0].albedo_color != color, "Detail control changes materials")
	check(not phone._detail_meshes[0].visible, "Level 3 hides phone details")
	game.cycle_detail_level()
	check(cup._materials[0].albedo_color == color and phone._detail_meshes[0].visible, "Detail 1 restores original materials and details")
	var controller := XRController3D.new()
	var grabber := XRGrabber.new()
	grabber.haptics = false
	grabber.required_group = "training_targets"
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.08
	collision.shape = sphere
	grabber.add_child(collision)
	controller.add_child(grabber)
	scene.get_node("XROrigin3D").add_child(controller)
	controller.global_position = phone.global_position
	for i in 4:
		await physics_frame
	grabber._grab()
	check(game._score == 0 and game._status_label.text == "Try again", "Wrong physical grab gives retry without scoring")
	check(grabber._held == null, "Wrong object detaches safely")
	await create_timer(0.7).timeout
	for target in game._targets:
		controller.global_position = target.global_position
		for i in 4:
			await physics_frame
		grabber._grab()
		check(grabber._held == target, target.object_id + " is held by controller")
		await create_timer(1.0).timeout
		check(grabber._held == null and not target.freeze, target.object_id + " releases cleanly at round transition")
	check(game._score == 3 and game._status_label.text.begins_with("Session complete"), "Three correct grabs complete the game")
	scene.get_node("XROrigin3D/XRControllerRight").button_pressed.emit("ax_button")
	check(game._score == 0 and game._round_index == 0, "A restarts the session")
	game._on_target_grabbed(cup)
	game.restart_session()
	await create_timer(1.0).timeout
	check(game._score == 0 and game._status_label.text == "Find the cup", "Restart cancels old delayed round callbacks")
	# The same ownership reset must release a pinched object, not leave a ghost hold.
	var hand := XRHandGrabber.new()
	var hand_shape := CollisionShape3D.new()
	hand_shape.shape = sphere
	hand.add_child(hand_shape)
	scene.get_node("XROrigin3D").add_child(hand)
	hand.set_physics_process(false)
	hand.global_position = cup.global_position
	for i in 4:
		await physics_frame
	hand._grab()
	check(hand._held == cup and game._score == 1, "Hand pinch uses the same selection logic")
	game.restart_session()
	check(hand._held == null, "Restart releases hand-owned targets")
	await create_timer(1.0).timeout
	print("DEMO_TEST_RESULT: ", "PASS" if errors == 0 else "FAIL", " (", errors, " failures)")
	scene.queue_free()
	await process_frame
	quit(0 if errors == 0 else 1)
