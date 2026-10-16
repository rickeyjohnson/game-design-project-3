class_name RonaldRules
extends RefCounted
## Ronald's brain as plain logic: reads the board, decides his mode, target,
## speed and the run's state. No nodes, so tests need no scene.
## RulesetSystem copies the results onto the board each frame.

var tuning: RonaldTuning
var mode: BoardTypes.Mode = BoardTypes.Mode.DORMANT
var target := Vector3.ZERO
var speed := 0.0
var game_state: BoardTypes.Game = BoardTypes.Game.PLAYING
## One-off cues raised this frame: &"honk", &"whisper", &"scream".
var cues: Array[StringName] = []
## Returns 0 to 1. Tests replace it to make posing predictable.
var roll: Callable = func() -> float: return randf()

var _unseen_time := 0.0
var _search_time := 0.0
var _stare_time := 0.0
var _sprinting := false
var _seek_fired := false
var _seek_spot: StringName = &""
var _seek_wait := 0.0
var _seek_elapsed := 0.0
var _camp_time := 0.0
var _patrol_time := 0.0
var _pose_length := 0.0
var _pose_time := 0.0
var _wake_time := 0.0


func _init(rules_tuning: RonaldTuning) -> void:
	tuning = rules_tuning


func step(board: Blackboard, delta: float) -> void:
	cues.clear()
	if game_state != BoardTypes.Game.PLAYING:
		return
	if board.player_at_exit and board.breaker_on: # escaping beats everything (D-019)
		game_state = BoardTypes.Game.ESCAPED
		return
	if mode == BoardTypes.Mode.DORMANT:
		_dormant(board)
		return
	if mode == BoardTypes.Mode.CATCH:
		_catching(board, delta)
		return
	if mode == BoardTypes.Mode.CAMP:
		_camping(board, delta)
		return
	if mode == BoardTypes.Mode.POSE:
		_posing(board, delta)
		return
	_hunt(board, delta)


## Asleep until the player picks up the first fuse (D-019).
func _dormant(board: Blackboard) -> void:
	if board.fuses_collected >= 1:
		_patrol(board)


## The stare, then the sprint (SYSTEM.md §6 Q6). Nothing interrupts it.
func _catching(board: Blackboard, delta: float) -> void:
	target = board.player_position
	if not _sprinting:
		_stare_time += delta
		if _stare_time >= tuning.stare_time:
			_sprinting = true
			speed = tuning.sprint_speed
			cues.append(&"scream")
	elif _distance_to_player(board) <= tuning.caught_range or _arrived(board):
		game_state = BoardTypes.Game.CAUGHT # as close as he can get still counts: no softlock


func _hunt(board: Blackboard, delta: float) -> void:
	# A leak fires once per visit; a visit ends when the player comes out or changes spots.
	if board.hide_state == BoardTypes.Hide.EXPOSED or board.hide_spot != _seek_spot:
		_seek_fired = false
	var safely_hidden: bool = board.hide_state == BoardTypes.Hide.HIDDEN and not board.location_leaked
	var seen: bool = board.detection == BoardTypes.Detect.SEEN and not safely_hidden
	var hunting_you := mode == BoardTypes.Mode.CHASE or mode == BoardTypes.Mode.SEEK
	if safely_hidden and not _in_pit(board) and mode != BoardTypes.Mode.SEEK:
		_patrol(board)
	elif hunting_you and _in_pit(board):
		_camp(board)
	elif mode == BoardTypes.Mode.CHASE and seen and _distance_to_player(board) <= tuning.catch_range:
		_catch(board)
	elif seen:
		_chase(board)
	elif board.location_leaked and not _seek_fired:
		_seek(board)
	elif mode == BoardTypes.Mode.SEEK:
		_seeking(board, delta)
	elif mode == BoardTypes.Mode.CHASE:
		target = board.last_known_position
		_unseen_time += delta
		if _unseen_time >= tuning.lose_track_after:
			_investigate(board.last_known_position)
	elif board.detection == BoardTypes.Detect.HEARD:
		_investigate(board.last_known_position)
	elif mode == BoardTypes.Mode.INVESTIGATE:
		if _arrived(board):
			_search_time += delta
			if _search_time >= tuning.search_time:
				_patrol(board)
	else:
		var was_patrolling := mode == BoardTypes.Mode.PATROL
		_patrol(board)
		if was_patrolling: # one mode change per frame
			_maybe_pose(delta)


## Every pose_check_every seconds of patrol, a pose_chance roll to sit on a
## bench like a statue (SYSTEM.md §6 Q9). Roaming picks the bench.
func _maybe_pose(delta: float) -> void:
	_patrol_time += delta
	if _patrol_time < tuning.pose_check_every:
		return
	_patrol_time = 0.0
	if roll.call() < tuning.pose_chance:
		mode = BoardTypes.Mode.POSE
		speed = tuning.patrol_speed
		_pose_length = lerpf(tuning.pose_time_min, tuning.pose_time_max, roll.call())
		_pose_time = 0.0
		_wake_time = 0.0


## Walking to the bench he reacts normally; seated he ignores sight and sound,
## and only an exposed player within pose_wake_range wakes him.
func _posing(board: Blackboard, delta: float) -> void:
	if not board.at_target:
		if board.detection != BoardTypes.Detect.NONE:
			_hunt(board, delta)
		return
	var close := _distance_to_player(board) <= tuning.pose_wake_range
	if board.hide_state == BoardTypes.Hide.EXPOSED and close:
		_wake_time += delta
		if _wake_time >= tuning.pose_wake_time:
			_chase(board)
			return
	else:
		_wake_time = 0.0
	_pose_time += delta
	if _pose_time >= _pose_length:
		_patrol(board)


func _chase(board: Blackboard) -> void:
	if mode != BoardTypes.Mode.CHASE:
		cues.append(&"honk")
	mode = BoardTypes.Mode.CHASE
	target = board.player_position
	speed = tuning.chase_speed
	_unseen_time = 0.0


## "I see you": wait the full warning before walking to the spot.
func _seek(board: Blackboard) -> void:
	_seek_fired = true
	_seek_spot = board.hide_spot
	cues.append(&"whisper")
	if _in_pit(board):
		_camp(board)
		return
	mode = BoardTypes.Mode.SEEK
	target = board.player_position
	_seek_elapsed = 0.0
	_seek_wait = tuning.seek_min_warning
	speed = 0.0 if _seek_wait > 0.0 else tuning.search_speed


func _seeking(board: Blackboard, delta: float) -> void:
	_seek_elapsed += delta
	# Already beside the spot (or as close as he gets) still counts only once
	# the warning has run: the whisper always comes seek_min_warning first.
	if _arrived(board) and _seek_elapsed >= tuning.seek_min_warning:
		var still_there := board.hide_state == BoardTypes.Hide.HIDDEN and board.hide_spot == _seek_spot
		if still_there:
			_catch(board)
		else:
			_investigate(target)
		return
	_seek_wait -= delta
	speed = 0.0 if _seek_wait > 0.0 else tuning.search_speed


## He never enters the ball pit: he walks to the rim (Roaming stops him at the
## nearest reachable point) and waits there (SYSTEM.md §6 Q3).
func _camp(board: Blackboard) -> void:
	mode = BoardTypes.Mode.CAMP
	target = board.player_position
	speed = tuning.search_speed
	_camp_time = 0.0


func _camping(board: Blackboard, delta: float) -> void:
	if board.detection == BoardTypes.Detect.SEEN:
		_chase(board)
	elif _arrived(board):
		_camp_time += delta
		if _camp_time >= tuning.camp_time:
			_patrol(board)


func _catch(board: Blackboard) -> void:
	mode = BoardTypes.Mode.CATCH
	target = board.player_position
	speed = 0.0
	_stare_time = 0.0
	_sprinting = false


func _investigate(at: Vector3) -> void:
	mode = BoardTypes.Mode.INVESTIGATE
	target = at
	speed = tuning.search_speed
	_search_time = 0.0


func _patrol(board: Blackboard) -> void:
	if mode != BoardTypes.Mode.PATROL:
		_patrol_time = 0.0
	mode = BoardTypes.Mode.PATROL
	target = board.enemy_position # ignored by Roaming in PATROL
	speed = tuning.patrol_speed


func _distance_to_player(board: Blackboard) -> float:
	return board.enemy_position.distance_to(board.player_position)


func _in_pit(board: Blackboard) -> bool:
	return board.hide_state == BoardTypes.Hide.HIDDEN and tuning.pit_spot_ids.has(board.hide_spot)


## At the target, or as close as Roaming can get (the ball pit, a spot off the
## navmesh). Either way he stops walking, so the rules must move on.
func _arrived(board: Blackboard) -> bool:
	return board.at_target or board.target_unreachable
