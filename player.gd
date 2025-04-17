extends CharacterBody2D

@export var walk_speed = 4.0
const TILE_SIZE = 16

@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var ray = $RayCast2D
@onready var all_interactions = []
@onready var interactLabel = $InteractionComponents/InteractLabel
@onready var dialogue = $"../dialogue/Dialogue"
enum PlayerState {
	IDLE,
	TURNING,
	WALKING,
}

enum FacingDirection {
	LEFT,
	RIGHT,
	UP,
	DOWN
}

var player_state = PlayerState.IDLE
var facing_direction = FacingDirection.DOWN
var wait_for_release = false

var initial_position = Vector2(0,0)
var input_direction = Vector2(0,0)
var is_moving = false
var is_interacting = false
var percent_moved_to_next_tile = 0.0


func _ready() :
	anim_tree.active = true
	initial_position = position
	update_interactions()
	
func _physics_process(delta: float) -> void:
		print("is_interacting:", is_interacting)
		if Input.is_action_just_pressed("ui_interact") and not is_interacting and not wait_for_release:
			execute_interaction()
		if Input.is_action_just_released("ui_interact"):
			wait_for_release = false
		if player_state == PlayerState.TURNING and not is_interacting:
			return
		elif is_moving == false and not is_interacting:
			process_player_input()
		elif input_direction != Vector2.ZERO and not is_interacting:
			anim_state.travel("Walk")
			move(delta)
		else:
			anim_state.travel("Idle")
			is_moving = false
			


func process_player_input():
	if input_direction.y == 0:
		input_direction.x = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	if input_direction.x == 0:
		input_direction.y = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	
	if input_direction != Vector2.ZERO:
		anim_tree.set("parameters/Idle/blend_position", input_direction)
		anim_tree.set("parameters/Walk/blend_position", input_direction)
		anim_tree.set("parameters/Turn/blend_position", input_direction)
		
		if need_to_turn():
			player_state = PlayerState.TURNING
			anim_state.travel("Turn")
		else:
			initial_position = position
			is_moving = true
	else:
		anim_state.travel("Idle")
		
func finished_turning():
	player_state = PlayerState.IDLE
	
func need_to_turn():
	var new_facing_direction
	if input_direction.x < 0:
		new_facing_direction = FacingDirection.LEFT
	elif input_direction.x > 0:
		new_facing_direction = FacingDirection.RIGHT
	elif input_direction.y < 0:
		new_facing_direction = FacingDirection.UP
	elif input_direction.y > 0:
		new_facing_direction = FacingDirection.DOWN
		
	if facing_direction != new_facing_direction:
		facing_direction = new_facing_direction
		return true
	facing_direction = new_facing_direction
	return false
	
func move(delta):
	var desire_step: Vector2 = input_direction * TILE_SIZE / 2
	ray.target_position = desire_step
	ray.force_raycast_update()
	if !ray.is_colliding():
		percent_moved_to_next_tile += walk_speed * delta
		if percent_moved_to_next_tile >= 1.0:
			position = initial_position + input_direction * TILE_SIZE
			percent_moved_to_next_tile = 0.0
			is_moving = false
		else:
			position = initial_position + input_direction * TILE_SIZE * percent_moved_to_next_tile
	else:
		is_moving = false
		

# Interactions

func _on_interaction_area_area_entered(area: Area2D) -> void:
	all_interactions.insert(0,area)
	update_interactions()

func _on_interaction_area_area_exited(area: Area2D) -> void:
	all_interactions.erase(area)
	update_interactions()

func update_interactions():
	if all_interactions:
		interactLabel.text = all_interactions[0].interact_label
	else:
		interactLabel.text = ""

func execute_interaction():
	print("executingInteraction")
	if all_interactions:
		var cur_interaction = all_interactions[0]
		match cur_interaction.interact_type:
			"welcome" : callDialogue("res://dialogueManager/Welcome.dialogue")
			"hello" : callDialogue("res://dialogueManager/Hello.dialogue")

func callDialogue(resource):
	var balloon = DialogueManager.show_dialogue_balloon(load(resource),"start")
	balloon.dialogue_finished.connect(_on_dialogue_finished)
	is_interacting = true

func _on_dialogue_finished():
	print("dialogue ended")
	is_interacting = false
	wait_for_release = true
