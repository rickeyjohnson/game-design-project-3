class_name RonaldTuning
extends Resource
## Ronald's numbers (systems/ruleset/SYSTEM.md §6). Edit ronald_tuning.tres, not this file.

@export_group("Speeds (m/s)")
@export var patrol_speed := 1.4
@export var search_speed := 2.0 # INVESTIGATE, SEEK, walking to the pit rim
@export var chase_speed := 4.6 # ~10% over the kid's run (demo run: 4.2). Update when Lionel picks his.
@export var sprint_speed := 8.0 # the lunge at the end of the stare
@export_group("Timing (s)")
@export var lose_track_after := 2.0
@export var search_time := 5.0
@export var stare_time := 2.0 # silent stare before the sprint
@export var seek_min_warning := 5.0 # stationary warning before approaching the leaked spot
@export var camp_time := 10.0 # waiting at the ball-pit rim
@export_group("Distances (m)")
@export var catch_range := 3.0 # chasing this close starts the stare
@export var caught_range := 0.8 # the sprint reaching this close ends the run
@export_group("Posing")
@export var pose_check_every := 45.0 # seconds of patrol between rolls ("1 in 4 patrol loops")
@export var pose_chance := 0.25
@export var pose_time_min := 20.0
@export var pose_time_max := 40.0
@export var pose_wake_range := 1.0 # an exposed player this close wakes him
@export var pose_wake_time := 1.0
@export_group("Ball pit")
@export var pit_spot_ids: Array[StringName] = [&"ball_pit"] # hiding-spot ids he never enters (agree with Lionel)
