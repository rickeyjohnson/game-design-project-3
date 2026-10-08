extends Node3D
const Geo = preload("res://scripts/geometry.gd")
var active := false
var player: CharacterBody3D
var world: Node3D
var torso: Node3D
var left_arm: Node3D
var right_arm: Node3D
var path := PackedVector2Array()
var path_timer := 0.0
var clock := 0.0
var frozen := false
var grace := 4.0
var speed := 1.25
signal caught

func _ready() -> void:
	var soot := Geo.material(Color("14191a"))
	var old_fabric := Geo.material(Color("46473b"))
	var eyes := Geo.material(Color("decba2"), 0, 1.5)
	torso = Node3D.new()
	add_child(torso)
	var body := Geo.sphere(torso, Vector3(0, 1.15, 0), 0.43, soot)
	body.scale = Vector3(1, 1.6, 0.65)
	Geo.sphere(torso, Vector3(0, 2.03, 0), 0.38, old_fabric)
	Geo.sphere(torso, Vector3(-0.3, 2.35, 0), 0.17, old_fabric)
	Geo.sphere(torso, Vector3(0.3, 2.35, 0), 0.17, old_fabric)
	Geo.sphere(torso, Vector3(-0.13, 2.09, 0.33), 0.052, eyes)
	Geo.sphere(torso, Vector3(0.13, 2.09, 0.33), 0.052, eyes)
	Geo.box(torso, Vector3(0, 1.88, 0.33), Vector3(0.3, 0.08, 0.06), soot)
	left_arm = _limb(torso, Vector3(-0.47, 1.55, 0), soot)
	right_arm = _limb(torso, Vector3(0.47, 1.55, 0), soot)
	Geo.cylinder(torso, Vector3(-0.2, 0.35, 0), 0.13, 0.7, soot)
	Geo.cylinder(torso, Vector3(0.2, 0.35, 0), 0.13, 0.7, soot)
	visible = false

func _limb(parent: Node3D, pos: Vector3, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	Geo.cylinder(pivot, Vector3(0, -0.45, 0), 0.1, 0.95, mat)
	return pivot

func awaken() -> void:
	if active:
		return
	position = Vector3(3.5, 0, -4.4)
	active = true
	visible = true
	grace = 4.0

func _physics_process(delta: float) -> void:
	if not active or not player.control_enabled:
		return
	clock += delta
	grace = maxf(0, grace - delta)
	frozen = player.beam_hits(global_position + Vector3(0, 1.6, 0))
	var target := player.global_position
	target.y = global_position.y
	if target.distance_to(global_position) > 0.1:
		look_at(target, Vector3.UP, true)
	if frozen or grace > 0:
		return
	path_timer -= delta
	if path_timer <= 0:
		path_timer = 0.5
		path = world.route(global_position, player.global_position)
		if path.size() > 1:
			path.remove_at(0)
	if not path.is_empty():
		var waypoint := Vector3(path[0].x, 0, path[0].y)
		position = position.move_toward(waypoint, speed * delta)
		if position.distance_to(waypoint) < 0.08:
			path.remove_at(0)
	torso.position.y = sin(clock * 7) * 0.035
	left_arm.rotation.x = sin(clock * 5) * 0.24
	right_arm.rotation.x = -sin(clock * 5) * 0.24
	if global_position.distance_to(player.global_position) < 0.85:
		active = false
		caught.emit()
