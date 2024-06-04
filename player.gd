## The controller for a 2d platformer with coyote-time and dodge rolling.
class_name PlayerCharacter
extends CharacterBody2D

#region CONSTs and Vars
const SPEED = 120.0
const JUMP_VELOCITY = -340.0
const MAX_COYOTE_TIME : float = 0.33
const COYOTE_HANG_TIME: int = 0.066
const ROLL_BOOST = 1.5
const AIR_SPEED_MULT = 1.15

var is_dead = false ## Track death state. True when killed.
var is_rolling = false   ## Track rolling state. True while a roll in in progress.
var is_jumping = false ## Track jumping state. True while in the air.
var direction = 0 ## Equals 1 when facing right, -1 when facing left.
var coyote_time = 0 ## A value that ticks down to 0 when in the air.

## Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
#endregion

func _ready() -> void:
	Engine.time_scale = 1

func _process(delta: float) -> void:
	if not is_on_floor():
		coyote_time -= delta
	else:
		coyote_time = MAX_COYOTE_TIME

func _physics_process(delta: float) -> void:
	
	player_input() 
	
#region Direction Logic
	if is_dead:
		direction = 0 
	elif is_rolling: 
		if is_on_floor():
			direction = -1 if animated_sprite.flip_h else 1 # Roll moves in the facing direction if we are on the floor, in the air we can flip without forcing movement.
		else:
			direction = Input.get_axis("move_left", "move_right")
	else: 
		direction = Input.get_axis("move_left", "move_right")	
	# Modify air speed.
	if not is_on_floor():
		direction = direction*AIR_SPEED_MULT		
#endregion
	
#region State Decision Tree	
	# Alternate states
	if is_rolling or is_dead:
		pass # Override all other states if rolling or dead.
	
	# Grounded
	elif is_on_floor():
		is_jumping = false
		if direction == 0: 
			idle() # Doing nothing...
		else:
			run() # All other states are false and we're moving on the ground, must be running...
	
	# In the air.
	elif coyote_time > 0:
		animated_sprite.play("hang")
	else:
		animated_sprite.play("jump")	
#endregion
	
#region Motion handling
	# Horizontal motion with smooth stop 
	if direction:
		if direction < 0:
			animated_sprite.flip_h = true
		elif direction > 0:
			animated_sprite.flip_h = false
		velocity.x = direction * SPEED * (ROLL_BOOST if is_rolling else 1)
	else:
		velocity.x = move_toward(velocity.x, 0, delta*SPEED*(SPEED*0.1))

	# Add the gravity.
	if not is_on_floor() and coyote_time < MAX_COYOTE_TIME-COYOTE_HANG_TIME:
		velocity.y += (gravity * delta)
		if velocity.y > 0:
			velocity.y += (gravity * delta)

	move_and_slide()
#endregion

func player_input():
	
	# Handle roll. We dont want to roll if in a roll or dead...
	if Input.is_action_just_pressed("roll") and not is_rolling and not is_dead:
		roll()
	
	# Handle jump. If coyote_time is on, we are on the ground or just left it.
	if Input.is_action_just_pressed("jump") and coyote_time > 0 and not is_dead:
		jump()
	
	# Jump shaping for variable jump height. Release jump early to fall.
	if Input.is_action_just_released("jump"):
		if velocity.y < 0 : velocity.y *= 0.5

## Dodge roll ability
func roll():
	is_rolling = true # Turn on the roll state.
	collision_layer = 4 # Become undetectable by moving to another layer
	animated_sprite.play("roll") # Play the animation. 5 frames at 15 fps.
	$Sounds/Roll.play() # Play the sound Roll in sounds node.
	await animated_sprite.animation_finished # The roll ends when the animation stops, change the roll timing by changing the animation.
	collision_layer = 2 # Become detectable again.
	is_rolling = false # Turn off the roll state

func idle():
	animated_sprite.play("idle")

func run():	
	# Run animation is 16 frames at 10 fps.
	animated_sprite.play("run")
	if not $Sounds/Step.is_playing():
		$Sounds/Step.play()

func jump():
	is_jumping = true
	$Sounds/Jump.play()
	velocity.y = JUMP_VELOCITY
	coyote_time = 0

func kill():
	is_dead = true
	$Sounds/Die.play()
	animated_sprite.play("die")
	$CollisionShape2D.queue_free()
	Engine.time_scale = 0.5
	
