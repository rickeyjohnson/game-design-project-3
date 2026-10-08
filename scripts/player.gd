extends CharacterBody3D
const Geo = preload("res://scripts/geometry.gd")
signal flashlight_changed(enabled: bool)
signal step

const WALK_SPEED := 2.5
const RUN_SPEED := 4.2
const BATTERY_DRAIN := 0.42 # Almost four minutes per full charge.
var camera: Camera3D
var hand: Node3D
var lamp: SpotLight3D
var spill: OmniLight3D
var animation: AnimationPlayer
var battery_lights: Array[MeshInstance3D] = []
var battery_indicator_state := -1
var battery := 100.0
var flashlight_on := false
var control_enabled := false
var sensitivity := 0.0022
var reduce_motion := false
var pitch := 0.0
var bob_time := 0.0
var step_clock := 0.0
var toggle_cooldown := 0.0
var beam_time := 0.0
var hand_home := Vector3(0.26, -0.24, -0.42)

func _ready() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(55)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.65
	collider.shape = capsule
	collider.position.y = 0.825
	add_child(collider)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position.y = 0.25
	camera.rotation_degrees = Vector3(-20, 0, -12)
	camera.near = 0.04
	camera.far = 45
	camera.fov = 76
	camera.current = true
	add_child(camera)
	_flashlight_model()
	_opening_animation()

func _flashlight_model() -> void:
	hand = Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0.48, -0.85, 0.15)
	camera.add_child(hand)
	var rubber := Geo.material(Color("182026"), 0.3)
	var metal := Geo.material(Color("525e62"), 0.75)
	var skin := Geo.material(Color("a57e62"))
	var sleeve := Geo.material(Color("3a4545"))
	var body := Geo.cylinder(hand, Vector3.ZERO, 0.042, 0.25, rubber)
	body.rotation.x = PI / 2
	var rim := Geo.cylinder(hand, Vector3(0, 0, -0.15), 0.069, 0.09, metal)
	rim.rotation.x = PI / 2
	var lens := Geo.cylinder(hand, Vector3(0, 0, -0.2), 0.057, 0.006, Geo.material(Color("b8c7bd"), 0.2, 0.4))
	lens.rotation.x = PI / 2
	for z in [-0.07, -0.025, 0.02, 0.065]:
		var grip := Geo.cylinder(hand, Vector3(0, 0, z), 0.046, 0.009, metal)
		grip.rotation.x = PI / 2
	# The indicator is fixed to the flashlight housing, so it moves with the hand.
	Geo.box(hand, Vector3(0.033, 0.046, -0.015), Vector3(0.052, 0.016, 0.126), metal)
	for i in 4:
		var segment := Geo.box(hand, Vector3(0.033, 0.057, -0.058 + i * 0.028), Vector3(0.036, 0.008, 0.021), Geo.material(Color("23332e")))
		battery_lights.append(segment)
	update_battery_indicator()
	var palm := Geo.sphere(hand, Vector3(0.015, -0.055, 0.06), 0.064, skin)
	palm.scale = Vector3(1, 0.8, 1.25)
	for i in 4:
		var finger := Geo.cylinder(hand, Vector3(-0.031 + i * 0.022, -0.034, 0.045), 0.013, 0.082, skin)
		finger.rotation.x = 0.35
	var arm := Geo.cylinder(hand, Vector3(0.07, -0.15, 0.18), 0.072, 0.32, sleeve)
	arm.rotation_degrees = Vector3(-40, 0, 24)
	for node in hand.get_children():
		if node is GeometryInstance3D:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp = SpotLight3D.new()
	lamp.name = "Beam"
	lamp.position = Vector3(0.08, -0.04, -0.25)
	lamp.spot_range = 22
	lamp.spot_angle = 29
	lamp.spot_angle_attenuation = 1.8
	lamp.light_energy = 5.5
	lamp.light_color = Color("ede4ca")
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.03
	lamp.visible = false
	camera.add_child(lamp)
	spill = OmniLight3D.new()
	spill.position = Vector3(0.1, -0.1, -0.4)
	spill.omni_range = 2.4
	spill.light_energy = 0.22
	spill.light_color = Color("d2c5a5")
	spill.visible = false
	camera.add_child(spill)

func _track(anim: Animation, path: String, keys: Array) -> void:
	var index := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(index, NodePath(path))
	anim.track_set_interpolation_type(index, Animation.INTERPOLATION_CUBIC)
	for key in keys:
		anim.track_insert_key(index, key[0], key[1])

func _opening_animation() -> void:
	animation = AnimationPlayer.new()
	animation.name = "AnimationPlayer"
	add_child(animation)
	var library := AnimationLibrary.new()
	var wake := Animation.new()
	wake.length = 8.4
	_track(wake, "Camera:position", [[0.0, Vector3(0, 0.25, 0)], [1.8, Vector3(0, 0.3, 0)], [4.0, Vector3(0, 1.1, 0)], [5.7, Vector3(0, 1.55, 0)], [8.4, Vector3(0, 1.55, 0)]])
	_track(wake, "Camera:rotation_degrees", [[0.0, Vector3(-20, 0, -12)], [2.2, Vector3(-11, -8, -6)], [4.3, Vector3(-8, 7, 2)], [5.8, Vector3(-15, 0, 0)], [7.7, Vector3(0, 0, 0)]])
	_track(wake, "Camera/Hand:position", [[0.0, Vector3(0.48, -0.85, 0.15)], [4.7, Vector3(0.48, -0.85, 0.15)], [5.8, Vector3(0.18, -0.17, -0.32)], [6.5, Vector3(0.19, -0.15, -0.4)], [7.6, hand_home], [8.4, hand_home]])
	_track(wake, "Camera/Hand:rotation_degrees", [[0.0, Vector3(65, -25, 30)], [4.7, Vector3(65, -25, 30)], [5.8, Vector3(10, -15, -12)], [6.4, Vector3(-4, 8, 4)], [7.6, Vector3.ZERO]])
	library.add_animation("wake_up", wake)
	var toggle := Animation.new()
	toggle.length = 0.26
	_track(toggle, "Camera/Hand:rotation_degrees", [[0.0, Vector3.ZERO], [0.09, Vector3(4, 0, -4)], [0.26, Vector3.ZERO]])
	library.add_animation("switch", toggle)
	animation.add_animation_library("", library)

func begin_intro() -> void:
	animation.play("wake_up")

func finish_intro() -> void:
	animation.stop()
	camera.position = Vector3(0, 1.55, 0)
	camera.rotation = Vector3.ZERO
	hand.position = hand_home
	hand.rotation = Vector3.ZERO
	pitch = 0
	control_enabled = true
	if not flashlight_on:
		set_flashlight(true)

func set_flashlight(enabled: bool) -> void:
	flashlight_on = enabled and battery > 0
	lamp.visible = flashlight_on
	spill.visible = flashlight_on
	flashlight_changed.emit(flashlight_on)

func update_battery_indicator() -> void:
	var lit := ceili(battery / 25.0)
	var state := lit + (10 if battery < 20 else (20 if battery < 45 else 30))
	if state == battery_indicator_state:
		return
	battery_indicator_state = state
	var charge_color := Color("cd422c") if battery < 20 else (Color("d7a025") if battery < 45 else Color("2bad66"))
	for i in battery_lights.size():
		battery_lights[i].material_override = Geo.material(charge_color, 0.0, 1.3) if i < lit else Geo.material(Color("25312e"))

func _unhandled_input(event: InputEvent) -> void:
	if not control_enabled or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.35, 1.35)
		camera.rotation.x = pitch
	if event.is_action_pressed("flashlight") and toggle_cooldown <= 0:
		toggle_cooldown = 0.3
		set_flashlight(not flashlight_on)
		animation.play("switch")

func _physics_process(delta: float) -> void:
	if not control_enabled:
		return
	toggle_cooldown = maxf(0, toggle_cooldown - delta)
	beam_time += delta
	if flashlight_on:
		battery = maxf(0, battery - BATTERY_DRAIN * delta)
		update_battery_indicator()
		if battery <= 0:
			set_flashlight(false)
		# Gentle low-battery instability, never a full-screen strobe.
		lamp.light_energy = 5.5 if battery > 18 else 3.8 + sin(beam_time * 17) * 0.45
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := global_basis * Vector3(input.x, 0, input.y)
	var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 16)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 16)
	if not is_on_floor():
		velocity.y -= 19.0 * delta
	else:
		velocity.y = -0.1
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = 5.0
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3 and is_on_floor()
	if moving:
		bob_time += delta * speed * 3.4
		step_clock += delta
		if step_clock > 0.95 / speed:
			step_clock = 0
			step.emit()
	var bob := sin(bob_time) * 0.022 if moving and not reduce_motion else 0.0
	camera.position.y = lerpf(camera.position.y, 1.55 + bob, delta * 12)
	hand.position = hand.position.lerp(hand_home + Vector3(bob * 0.5, bob * 0.6, 0), delta * 10)
	camera.fov = lerpf(camera.fov, 79.0 if moving and speed > WALK_SPEED and not reduce_motion else 76.0, delta * 4)

func beam_hits(point: Vector3) -> bool:
	if not flashlight_on:
		return false
	var offset := point - camera.global_position
	if offset.length() > 18 or -camera.global_basis.z.dot(offset.normalized()) < 0.89:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
