extends "res://tests/part5_exploration_runtime_test.gd"
## Native recording of the exact fresh two-branch runtime driver, muted.
func _secret() -> bool:
	if not await super._secret():return false
	if branch!="rescue":return true
	await _key(KEY_M)
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	var journal: QuestJournal=screen.journal
	_check(journal.quest_buttons.has(&"opening_exploration"),"Actual M list exposes optional exploration instructions")
	(journal.quest_buttons[&"opening_exploration"] as Button).grab_focus();await _key(KEY_ENTER)
	_check(journal.selected_id==&"opening_exploration" and "SC01" in journal.objective_label.text,"Real focused button selects current discovery and shortcut instructions")
	var original: Vector2i=root.content_scale_size
	for dims: Vector2i in [Vector2i(1152,648),Vector2i(800,600)]:
		if dims.x==800:root.content_scale_size=dims
		root.size=dims;await _frames(5)
		_check(root.get_visible_rect().grow(2).encloses(screen.panel.get_global_rect()),"Journal frame fits native/explicit compact logical viewport")
		journal.detail_scroll.scroll_vertical=0;await _frames(3);await mark("exploration_journal_%d"%dims.x,90)
	root.content_scale_size=original;root.size=Vector2i(1152,648);await _frames(5)
	await _key(KEY_ESCAPE)
	return true
