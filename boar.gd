extends Enemy

enum State {
	IDLE,
	WALKING,
	RUNNING,
	HURT,
	DYING,
}

const KNOCKBACK_AMOUNT := 512.0

var pending_damage: Damage

@onready var wall_checker: RayCast2D = $Graphics/WallChecker
@onready var player_checker: RayCast2D = $Graphics/PlayerChecker
@onready var floor_checker: RayCast2D = $Graphics/FloorChecker
@onready var calm_down_timer: Timer = $CalmDownTimer

func can_see_player() -> bool:
	if not player_checker.is_colliding():
		return false
	return player_checker.get_collider() is Player

func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE, State.HURT, State.DYING:
			move(0.0, delta)

		State.WALKING:
			move(max_speed / 3, delta)

		State.RUNNING:
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				direction *= -1
			move(max_speed, delta)
			if player_checker.is_colliding():
				calm_down_timer.start()

func get_next_state(state: State) -> State:
	if stats.health == 0:
		return State.DYING

	if pending_damage:
		return State.HURT

	match state:
		State.IDLE:
			if can_see_player():
				return State.RUNNING
			if state_machine.state_time > 2:
				return State.WALKING

		State.WALKING:
			if can_see_player():
				return State.RUNNING
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				return State.IDLE

		State.RUNNING:
			if not can_see_player() and calm_down_timer.is_stopped():
				return State.WALKING

		State.HURT:
			if not animation_player.is_playing():
				return State.RUNNING

	return state

func transition_state(from: State, to: State) -> void:
	print('[%s] %s => %s' % [
		Engine.get_physics_frames(),
		State.keys()[from] if from != -1 else '<START>',
		State.keys()[to],
	])

	match to:
		State.IDLE:
			animation_player.play("idle")
			if wall_checker.is_colliding():
				direction *= -1

		State.WALKING:
			animation_player.play("walking")
			if not floor_checker.is_colliding():
				direction *= -1
				floor_checker.force_raycast_update()

		State.RUNNING:
			animation_player.play("running")

		State.HURT:
			animation_player.play("hit")
			stats.health -= pending_damage.amount

			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_AMOUNT

			if dir.x > 0:
				direction = Direction.LEFT
			else:
				direction = Direction.RIGHT

			pending_damage = null

		State.DYING:
			animation_player.play("die")


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
