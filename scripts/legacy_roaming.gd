class_name LegacyRoaming
extends SimSystem
## Roaming's stand-in for the F5 game until Naomi's system replaces it. The
## mock's Ronald (scripts/stalker.gd) walks where the Ruleset says, at its
## speed, on the mock's navigation grid, and this reports back on the board.
## He picks his own patrol spots, and poses where he stands (the F5
## restaurant has no statue bench yet). He's woken once, when the rules wake
## him; if the game later takes him out of play (active = false), he stays put.

const ARRIVE := 0.5 # m: this close to the target counts as there
const PATROL_AREA := Rect2(-33, -22, 66, 44) # where he picks patrol spots, as the mock
const PATROL_MIN_LEG := 5.0 # m
const PATROL_RETRY := 1.0 # s to wait after failing to find a patrol spot
## Modes where he stands still facing his target while his speed is zero:
## waiting to seek, camping at the pit rim, the stare.
const FACES_TARGET: Array[BoardTypes.Mode] = [BoardTypes.Mode.SEEK, BoardTypes.Mode.CAMP, BoardTypes.Mode.CATCH]

## The mock's Ronald: his body. It has awaken(), update_locomotion(),
## table_approach_target(), and the active, driven and chasing flags.
var stalker: Node3D
## The mock's level (scripts/world.gd): route() and STALKER_SPAWN.
var world: Node3D
var rng := RandomNumberGenerator.new()

var _path := PackedVector2Array()
var _goal := Vector3.INF # where _path leads
var _mode: BoardTypes.Mode = BoardTypes.Mode.DORMANT
var _patrol_wait := 0.0
var _woken := false


func _init() -> void:
	system_id = &"roaming"


func setup(board: Blackboard) -> void:
	rng.randomize()
	stalker.set("driven", true) # his own brain stays off: the board drives him
	board.enemy_position = stalker.global_position


func tick(board: Blackboard, delta: float) -> void:
	board.target_unreachable = false
	var mode := board.ronald_mode
	if board.game_state != BoardTypes.Game.PLAYING or mode == BoardTypes.Mode.DORMANT:
		board.enemy_velocity = Vector3.ZERO
		board.at_target = false
		stalker.set("chasing", false)
		return
	if not _woken:
		_woken = true
		if not bool(stalker.get("active")):
			stalker.call("awaken")
	elif not bool(stalker.get("active")):
		board.enemy_velocity = Vector3.ZERO
		board.at_target = false
		stalker.set("chasing", false)
		return
	# The F5 cutaway owns the actor's turn and spoken warning. The board
	# must not translate or rotate him until that presentation releases him.
	if bool(stalker.get("cinematic_turning")):
		board.enemy_position = stalker.global_position
		board.enemy_velocity = Vector3.ZERO
		board.at_target = false
		stalker.set("chasing", false)
		stalker.call("update_locomotion", 0.0, delta)
		return
	if mode != _mode:
		_mode = mode
		_path.clear()
		_goal = Vector3.INF
	var before := stalker.global_position
	if mode == BoardTypes.Mode.PATROL:
		_patrol(board.move_speed, delta)
		board.at_target = false
	elif mode == BoardTypes.Mode.POSE:
		board.at_target = true
	else:
		var goal := _reach_point(board)
		if _flat(goal, _goal) > ARRIVE:
			_plan(goal)
		_walk(board.move_speed, delta)
		var there := _flat(stalker.global_position, board.target_position) <= ARRIVE
		board.at_target = there
		board.target_unreachable = not there and _path.is_empty()
		if board.move_speed <= 0.0 and FACES_TARGET.has(mode):
			_face(board.target_position - stalker.global_position)
	var moved := stalker.global_position - before
	board.enemy_position = stalker.global_position
	board.enemy_velocity = moved / delta if delta > 0.0 else Vector3.ZERO
	stalker.set("chasing", mode == BoardTypes.Mode.CHASE or mode == BoardTypes.Mode.CATCH)
	stalker.call("update_locomotion", moved.length(), delta)


## Where to walk to reach the target. A hidden player is under a table, so he
## heads for the table's open side instead (the mock's own choice of side).
func _reach_point(board: Blackboard) -> Vector3:
	var at_the_player := _flat(board.target_position, board.player_position) <= ARRIVE
	if board.hide_state == BoardTypes.Hide.HIDDEN and at_the_player:
		return stalker.call("table_approach_target") as Vector3
	return board.target_position


func _plan(goal: Vector3) -> void:
	_goal = goal
	_path = world.route(stalker.global_position, goal)
	if not _path.is_empty():
		_path.remove_at(0) # the cell he's standing on


## Walks along the path, past as many waypoints as the frame allows.
func _walk(speed: float, delta: float) -> void:
	var budget := maxf(speed * delta, 0.0)
	while budget > 0.0 and not _path.is_empty():
		var waypoint := Vector3(_path[0].x, world.STALKER_SPAWN.y, _path[0].y)
		var to := waypoint - stalker.global_position
		to.y = 0.0
		var distance := to.length()
		_face(to)
		if distance <= budget:
			stalker.global_position = waypoint
			budget -= distance
			_path.remove_at(0)
		else:
			stalker.global_position += to / distance * budget
			budget = 0.0


func _patrol(speed: float, delta: float) -> void:
	_patrol_wait = maxf(0.0, _patrol_wait - delta)
	if _path.is_empty() and _patrol_wait <= 0.0 and not _pick_patrol_spot():
		_patrol_wait = PATROL_RETRY
	_walk(speed, delta)


func _pick_patrol_spot() -> bool:
	for attempt in 16:
		var spot := Vector3(
			rng.randf_range(PATROL_AREA.position.x, PATROL_AREA.end.x),
			world.STALKER_SPAWN.y,
			rng.randf_range(PATROL_AREA.position.y, PATROL_AREA.end.y))
		var route: PackedVector2Array = world.route(stalker.global_position, spot)
		if route.size() < 2:
			continue
		var end := Vector3(route[-1].x, world.STALKER_SPAWN.y, route[-1].y)
		if _flat(stalker.global_position, end) < PATROL_MIN_LEG:
			continue
		_path = route
		_path.remove_at(0)
		_goal = end
		return true
	return false


func _face(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		stalker.look_at(stalker.global_position + direction, Vector3.UP)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
