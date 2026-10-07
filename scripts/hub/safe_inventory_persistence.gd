class_name SafeInventoryPersistence
extends Node
## Atomic safe-Hub ledger, including ordinary click swaps. Run ownership is moved.
var economy: EconomySession
var _busy: bool = false
var committed: Dictionary = {}

func initialize(session: EconomySession) -> void:
	economy = session
	economy.persist_safe_inventory = true
	committed = GearInventoryCodec.encode(economy.inventory)
	economy.inventory.changed.connect(_on_changed)
	economy.changed.connect(_on_commit)
	_on_changed()

func _on_commit() -> void:
	committed = economy.profile.hub_inventory.duplicate(true)

func _on_changed() -> void:
	if _busy or not economy.hub_access or economy._busy: return
	_busy = true
	if economy._save_safe():
		committed = economy.profile.hub_inventory.duplicate(true)
	else:
		var previous: GearInventory = GearInventoryCodec.decode(committed)
		if previous != null: GearInventoryCodec.copy_into(economy.inventory, previous)
	_busy = false

func _exit_tree() -> void:
	if economy == null: return
	if economy.inventory.changed.is_connected(_on_changed): economy.inventory.changed.disconnect(_on_changed)
	if economy.changed.is_connected(_on_commit): economy.changed.disconnect(_on_commit)
