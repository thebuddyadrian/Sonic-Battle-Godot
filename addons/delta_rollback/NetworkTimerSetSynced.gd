extends Node
class_name NetworkTimerSetSynced
## The GDScript timer that NetworkTimer replaced, its state recorded with
## SyncManager.set_synced().
##
## Not reset for reuse ("Reuse Despawned Nodes"), as NetworkTimer is: in a
## reused node, it goes on from where it was, and autostart doesn't start it
## again. Stop it in the node's _network_prepare_for_reuse(), or start it in
## its _network_spawn().

@export var autostart := false
@export var one_shot := false
@export var wait_ticks := 0
@export var hash_state := true

var ticks_left := 0

var _paused: = false
var _running := false

signal timeout ()

func _ready() -> void:
	add_to_group('network_sync')
	SyncManager.sync_stopped.connect(_on_SyncManager_sync_stopped)
	if autostart:
		start()

func is_stopped() -> bool:
	return not _running

func start(ticks: int = -1) -> void:
	if ticks > 0:
		SyncManager.set_synced(self, "wait_ticks", ticks)
	SyncManager.set_synced(self, "ticks_left", wait_ticks)
	SyncManager.set_synced(self, "_running", true)
	SyncManager.set_synced(self, "_paused", false)

func stop():
	SyncManager.set_synced(self, "_running", false)
	SyncManager.set_synced(self, "ticks_left", 0)

func pause() -> void:
	SyncManager.set_synced(self, "_paused", true)

func unpause() -> void:
	SyncManager.set_synced(self, "_paused", false)

func _on_SyncManager_sync_stopped() -> void:
	stop()

func _network_process(_input: Dictionary) -> void:
	if not _running or _paused:
		return
	if ticks_left <= 0:
		SyncManager.set_synced(self, "_running", false)
		return
	
	SyncManager.set_synced(self, "ticks_left", ticks_left - 1)
	
	if ticks_left == 0:
		if not one_shot:
			SyncManager.set_synced(self, "ticks_left", wait_ticks)
		emit_signal("timeout")
