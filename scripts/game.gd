extends Node3D
const Geo = preload("res://scripts/geometry.gd")
const PlayerScript = preload("res://scripts/player.gd")
const WorldScript = preload("res://scripts/world.gd")
const HUDScript = preload("res://scripts/hud.gd")
const StalkerScript = preload("res://scripts/stalker.gd")

var player: CharacterBody3D
var world: Node3D
var hud: Control
var stalker: Node3D
var phase := "home"
var intro_time := 0.0
var elapsed := 0.0
var fuses := 0
var spare_cells := 2
var power_on := false
var objective := "Find the three emergency fuses"
var prompt := ""
var message := ""
var message_time := 0.0
var show_performance := false
var low_quality := false
var items: Array[Dictionary] = []
var current_item := -1
var interaction_clock := 0.0
var sounds: Dictionary = {}
var breaker_lamp: MeshInstance3D
var intro_clicked := false
var ambient: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_inputs()
	_environment()
	world = Node3D.new()
	world.set_script(WorldScript)
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.position = Vector3(0, 0.56, 4.7)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	stalker = Node3D.new()
	stalker.set_script(StalkerScript)
	stalker.player = player
	stalker.world = world
	stalker.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(stalker)
	stalker.caught.connect(func(): finish(false))
	_items()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Control.new()
	hud.set_script(HUDScript)
	hud.game = self
	canvas.add_child(hud)
	hud.lens_material.set_shader_parameter("darkness", 0.0)
	_audio()
	player.flashlight_changed.connect(func(_enabled: bool): sound("click"))
	player.step.connect(func(): sound("step", randf_range(0.86, 1.13)))
	_show_home_view()
	hud.show_menu("home")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("RONALD'S: %d source meshes -> %d static batches; 720 balls -> 1 MultiMesh." % [world.source_mesh_count, world.batch_count])

func _bind_inputs() -> void:
	var bindings := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "flashlight": KEY_F, "interact": KEY_E, "reload_cell": KEY_R}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)

func _environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("030609")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("788795")
	environment.ambient_light_energy = 0.19
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("111b20")
	environment.fog_light_energy = 0.2
	environment.fog_density = 0.019
	var node := WorldEnvironment.new()
	node.environment = environment
	add_child(node)

func _items() -> void:
	var brass := Geo.material(Color("bea56e"), 0.6)
	var ceramic := Geo.material(Color("cac9b5"))
	for pos in [Vector3(-6.2, 0.95, -1.52), Vector3(6.2, 0.95, 3.52), Vector3(9.8, 0.95, -6.0)]:
		var item := Node3D.new()
		item.position = pos
		add_child(item)
		var fuse := Geo.cylinder(item, Vector3.ZERO, 0.055, 0.28, ceramic)
		fuse.rotation.z = PI / 2
		for x in [-0.12, 0.12]:
			var cap := Geo.cylinder(item, Vector3(x, 0, 0), 0.059, 0.06, brass)
			cap.rotation.z = PI / 2
		world._light(pos + Vector3(0, 0.1, 0), Color("82b8a5"), 0.35, 1.25)
		items.append({"node": item, "kind": "fuse", "label": "E  /  Take emergency fuse", "taken": false})
	# Third fuse sits on an added maintenance crate in the open side aisle.
	Geo.box(world, Vector3(9.8, 0.4, -6), Vector3(1.0, 0.8, 0.8), Geo.material(Color("534938")))
	world.solid(Vector3(9.8, 0.4, -6), Vector3(1, 0.8, 0.8))
	for pos in [Vector3(-6.2, 0.98, 4.88), Vector3(6.2, 0.98, -2.88)]:
		var cell := Node3D.new()
		cell.position = pos
		add_child(cell)
		Geo.box(cell, Vector3.ZERO, Vector3(0.18, 0.1, 0.12), Geo.material(Color("899d7b"), 0.3, 0.15))
		items.append({"node": cell, "kind": "cell", "label": "E  /  Take spare battery", "taken": false})
	var breaker := Node3D.new()
	breaker.position = Vector3(11.65, 1.6, -5.6)
	breaker.rotation.y = -PI / 2
	add_child(breaker)
	Geo.box(breaker, Vector3.ZERO, Vector3(0.75, 0.95, 0.18), Geo.material(Color("3e514f"), 0.5))
	Geo.box(breaker, Vector3(0, -0.1, 0.17), Vector3(0.09, 0.3, 0.09), brass)
	breaker_lamp = Geo.sphere(breaker, Vector3(0.22, 0.25, 0.13), 0.04, Geo.material(Color("ad5840"), 0, 1))
	Geo.label(breaker, "EMERGENCY\nPOWER", Vector3(0, 0.67, 0.13), 20, Color("b9c4b8"))
	items.append({"node": breaker, "kind": "breaker", "label": "E  /  Restore emergency power", "taken": false})
	var exit_marker := Node3D.new()
	exit_marker.position = Vector3(0, 1.5, 8.6)
	add_child(exit_marker)
	items.append({"node": exit_marker, "kind": "exit", "label": "E  /  Open front door", "taken": false})
	# Added crate must be included in the navigation data.
	world._navigation()

func _audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(0.8))
	for key in ["click", "step", "pickup", "breath", "sting", "power"]:
		var audio := AudioStreamPlayer.new()
		audio.stream = load("res://audio/%s.wav" % key)
		audio.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(audio)
		sounds[key] = audio
	ambient = AudioStreamPlayer.new()
	var stream := load("res://audio/room.wav") as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	ambient.stream = stream
	ambient.volume_db = -9
	ambient.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(ambient)
	if DisplayServer.get_name() != "headless":
		ambient.play()

func sound(key: String, pitch: float = 1.0) -> void:
	# The dummy headless audio driver cannot consume playback buffers.
	if sounds.has(key) and DisplayServer.get_name() != "headless":
		sounds[key].pitch_scale = pitch
		sounds[key].play()

func say(words: String, duration: float = 4.0) -> void:
	message = words
	message_time = duration

func _show_home_view() -> void:
	player.control_enabled = false
	player.position = Vector3(0, 0, 16.5)
	player.rotation = Vector3.ZERO
	player.camera.position = Vector3(0, 2.7, 0)
	player.camera.rotation = Vector3.ZERO
	player.hand.hide()
	player.lamp.hide()
	player.spill.hide()

func start_game() -> void:
	if phase != "home":
		return
	phase = "intro"
	intro_time = 0.0
	intro_clicked = false
	player.position = Vector3(0, 0.56, 4.7)
	player.velocity = Vector3.ZERO
	player.camera.position = Vector3(0, 0.25, 0)
	player.camera.rotation_degrees = Vector3(-20, 0, -12)
	player.hand.show()
	player.begin_intro()
	hud.lens_material.set_shader_parameter("darkness", 1.0)
	hud.show_menu("")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	sound("breath")
	say("Cold plastic. Stale air. Where is everyone?", 4.3)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	message_time = maxf(0, message_time - delta)
	if phase == "intro":
		intro_time += delta
		var darkness := 1.0
		if intro_time > 0.5:
			darkness = clampf(1.0 - (intro_time - 0.5) / 1.4, 0, 1)
		if intro_time > 2.2 and intro_time < 3.1:
			darkness = sin((intro_time - 2.2) / 0.9 * PI) * 0.85
		hud.lens_material.set_shader_parameter("darkness", darkness)
		if intro_time >= 4.5 and intro_time < 4.5 + delta:
			say("My flashlight. Still in my pocket.", 2.7)
		if intro_time >= 6.55 and not intro_clicked:
			intro_clicked = true
			player.set_flashlight(true)
		if intro_time >= 8.4:
			finish_intro()
	elif phase == "play":
		elapsed += delta
		interaction_clock -= delta
		if interaction_clock <= 0:
			interaction_clock = 0.1
			_find_interaction()
		var distance: float = player.global_position.distance_to(stalker.global_position)
		hud.lens_material.set_shader_parameter("danger", clampf(1.0 - distance / 5.0, 0, 1) if stalker.active else 0.0)
		world.flicker_light.light_energy = 0.65 + sin(elapsed * 1.8) * 0.06
		if player.global_position.y < -5:
			player.position = Vector3(0, 0.56, 4.7)

func finish_intro() -> void:
	phase = "play"
	player.finish_intro()
	hud.lens_material.set_shader_parameter("darkness", 0.0)
	say("Find three fuses. Restore the breaker. Get outside.", 6.0)

func _find_interaction() -> void:
	current_item = -1
	prompt = ""
	var best := 2.5
	for i in items.size():
		var item := items[i]
		if item.taken:
			continue
		var offset: Vector3 = item.node.global_position - player.camera.global_position
		var distance := offset.length()
		if distance > best or -player.camera.global_basis.z.dot(offset.normalized()) < 0.82:
			continue
		var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position, item.node.global_position, 1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		best = distance
		current_item = i
		prompt = item.label

func interact() -> void:
	_find_interaction()
	if current_item < 0:
		return
	var item := items[current_item]
	match item.kind:
		"fuse":
			item.taken = true
			item.node.hide()
			fuses += 1
			sound("pickup")
			if fuses == 1:
				stalker.awaken()
				sound("sting")
				say("Something moved. Keep your flashlight on it.", 6)
			elif fuses == 3:
				objective = "Restore power at the side breaker"
				say("All three. The breaker is on the right wall, by the counter.", 6)
			else:
				say("Two fuses. One more.")
		"cell":
			item.taken = true
			item.node.hide()
			spare_cells += 1
			sound("pickup")
			say("Spare battery collected. Press R to replace the cell.")
		"breaker":
			if fuses < 3:
				say("Three fuses are missing. Check the booths and maintenance crate.", 5)
			elif not power_on:
				power_on = true
				item.taken = true
				breaker_lamp.material_override = Geo.material(Color("72b58d"), 0, 2)
				world.exit_light.light_energy = 2.4
				stalker.speed = 1.7
				objective = "Reach the front door behind the pit"
				sound("power")
				say("The door has power. He's moving faster. Go.", 5)
		"exit":
			if power_on:
				finish(true)
			else:
				say("The magnetic lock has no power. Find the emergency fuses.")
	_find_interaction()

func replace_cell() -> void:
	if spare_cells <= 0:
		say("No spare cells. Check the booth tables.")
	elif player.battery >= 95:
		say("This cell still has plenty of charge.", 2)
	else:
		spare_cells -= 1
		player.battery = 100
		player.update_battery_indicator()
		player.set_flashlight(true)
		player.animation.play("switch")
		sound("pickup")
		say("Fresh battery.", 2)

func finish(escaped: bool) -> void:
	if phase != "play":
		return
	phase = "won" if escaped else "dead"
	player.control_enabled = false
	stalker.active = false
	message_time = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if escaped:
		var tween := create_tween()
		tween.tween_property(world.exit_door, "rotation:y", -1.2, 1.5)
		sound("power")
	else:
		sound("sting", 0.7)
	hud.queue_redraw()

func pause_game(paused: bool) -> void:
	if phase == "home":
		return
	get_tree().paused = paused
	hud.show_menu("pause" if paused else "")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func set_quality(low: bool) -> void:
	low_quality = low
	player.lamp.shadow_enabled = not low
	get_viewport().scaling_3d_scale = 0.75 if low else 1.0
	if is_instance_valid(hud):
		hud.quality_button.set_pressed_no_signal(low)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F11:
				var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_F1:
				show_performance = not show_performance
			KEY_F3:
				set_quality(not low_quality)
			KEY_ESCAPE:
				if phase in ["won", "dead"]:
					get_tree().quit()
				elif phase == "home":
					if hud.menu_mode == "options_home":
						hud.show_menu("home")
				elif hud.menu_mode == "options_pause":
					hud.show_menu("pause")
				else:
					pause_game(not get_tree().paused)
			KEY_ENTER:
				if phase in ["won", "dead"]:
					restart()
				elif phase == "intro" and not get_tree().paused:
					finish_intro()
			KEY_SPACE:
				if phase == "intro" and not get_tree().paused:
					finish_intro()
	if phase == "play" and not get_tree().paused:
		if event.is_action_pressed("interact"):
			interact()
		if event.is_action_pressed("reload_cell"):
			replace_cell()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and phase in ["intro", "play"]:
		pause_game(true)

func _exit_tree() -> void:
	# Release PCM playback before the audio server shuts down or restarts.
	if is_instance_valid(ambient):
		ambient.stop()
	for audio in sounds.values():
		if is_instance_valid(audio):
			audio.stop()
