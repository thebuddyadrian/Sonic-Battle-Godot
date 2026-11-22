extends Node
class_name NetworkRandomNumberGenerator
## Random numbers that roll back: seed it the same on every peer.
##
## In a spawned scene, seed it in _network_spawn(): a new generator starts
## from a random seed, and with "Reuse Despawned Nodes" a reused one isn't
## reset, but keeps its state and the tick it was last used. set_seed() sets
## both.
## Random numbers that roll back: seed it the same on every peer.

## A generator unused for this many ticks switches itself off (activate_sync),
## and then costs nothing until it is used again: it is not saved, loaded or
## processed. Most generators are only drawn from now and then, but were saved
## every tick.
const TICKS_BEFORE_SLEEP := 30

var generator: RandomNumberGenerator
var _last_used_tick := 0

func _ready() -> void:
	generator = RandomNumberGenerator.new()
	add_to_group('network_sync')

# Before any change to the generator: switching on records the state that a
# rollback to before this use restores, so it must still be the old one.
func _wake() -> void:
	if Engine.is_editor_hint():
		return
	if not SyncManager.sync_booster.is_sync_active(self):
		SyncManager.activate_sync(self, true)
	# Before the match, current_tick is still the previous match's last tick,
	# which differs between peers. Switching off must happen on the same tick
	# everywhere, as a node that is off is missing from the hashed state.
	_last_used_tick = SyncManager.current_tick if SyncManager.started else 0

func _network_process(_input: Dictionary) -> void:
	if SyncManager.current_tick - _last_used_tick > TICKS_BEFORE_SLEEP:
		SyncManager.activate_sync(self, false)

func set_seed(new_seed: int) -> void:
	_wake()
	generator.seed = new_seed

func get_seed() -> int:
	return generator.seed

func _save_state() -> Dictionary:
	return {
		state = generator.state,
		# Only decides when to switch off, which does not change any value.
		_last_used_tick = _last_used_tick,
	}

func _load_state(state: Dictionary) -> void:
	generator.state = state['state']
	_last_used_tick = state.get('_last_used_tick', _last_used_tick)

func randomize() -> void:
	_wake()
	generator.randomize()

func randi() -> int:
	_wake()
	return generator.randi()

func randi_range(from: int, to: int) -> int:
	_wake()
	return generator.randi_range(from, to)

func shuffle(t: Array) -> void:
	_wake()
	var n: = t.size()
	for i in range(n - 1, 0, -1):
		var j: = generator.randi_range(0, i)
		var e = t[j]
		t[j] = t[i]
		t[i] = e
