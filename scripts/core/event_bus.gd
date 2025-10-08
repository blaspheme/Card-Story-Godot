# EventBus - 全局事件总线
extends Node

# 卡牌相关事件
signal card_created(card: Card, position: Vector2)
signal card_destroyed(card: Card)
signal card_moved(card: Card, from_position: Vector2, to_position: Vector2)
signal card_transformed(old_card: Card, new_card: Card)
signal card_aspects_changed(card: Card, added_aspects: Array, removed_aspects: Array)
signal card_decay_started(card: Card, decay_time: float)
signal card_decay_completed(card: Card, result_card: Card)

# Fragment相关事件
signal fragment_created(fragment: Fragment, location: int)
signal fragment_destroyed(fragment: Fragment)
signal fragment_count_changed(fragment: Fragment, old_count: int, new_count: int)

# 规则相关事件
signal rule_executed(rule: Rule, context: Context)
signal rule_condition_met(rule: Rule, context: Context)
signal rule_condition_failed(rule: Rule, context: Context)

# 游戏状态事件
signal warmth_changed(new_warmth: int, old_warmth: int)
signal turn_advanced(turn_number: int)
signal game_started()
signal game_paused()
signal game_resumed()
signal game_ended(reason: String)

# 测试相关事件
signal test_evaluated(test: Test, result: bool, context: Context)
signal requirement_checked(test: Test, passed: bool)

# 修改器相关事件
signal modifier_executed(modifier: Resource, context: Context)
signal card_modifier_executed(modifier: Resource, target_cards: Array)

# UI相关事件
signal ui_card_selected(card_viz: Node)
signal ui_card_deselected(card_viz: Node)
signal ui_card_hovered(card_viz: Node)
signal ui_card_clicked(card_viz: Node)
signal ui_card_double_clicked(card_viz: Node)
signal ui_card_dragged(card_viz: Node, from_pos: Vector2, to_pos: Vector2)

# 动画相关事件
signal animation_started(target: Node, animation_name: String)
signal animation_completed(target: Node, animation_name: String)
signal particle_effect_started(effect_name: String, position: Vector2)

# 音频相关事件
signal sound_requested(sound_name: String, position: Vector2)
signal music_change_requested(track_name: String, fade_time: float)

# 调试相关事件
signal debug_info_updated(info: Dictionary)
signal debug_log(message: String, level: String)

# 发送卡牌事件的便捷方法
func emit_card_created(card: Card, position: Vector2 = Vector2.ZERO) -> void:
	emit_signal("card_created", card, position)

func emit_card_destroyed(card: Card) -> void:
	emit_signal("card_destroyed", card)

func emit_card_moved(card: Card, from_pos: Vector2, to_pos: Vector2) -> void:
	emit_signal("card_moved", card, from_pos, to_pos)

func emit_card_transformed(old_card: Card, new_card: Card) -> void:
	emit_signal("card_transformed", old_card, new_card)

func emit_card_aspects_changed(card: Card, added: Array = [], removed: Array = []) -> void:
	emit_signal("card_aspects_changed", card, added, removed)

func emit_card_decay_started(card: Card, decay_time: float) -> void:
	emit_signal("card_decay_started", card, decay_time)

func emit_card_decay_completed(card: Card, result_card: Card) -> void:
	emit_signal("card_decay_completed", card, result_card)

# 发送Fragment事件的便捷方法
func emit_fragment_created(fragment: Fragment, location: int = 2) -> void:
	emit_signal("fragment_created", fragment, location)

func emit_fragment_destroyed(fragment: Fragment) -> void:
	emit_signal("fragment_destroyed", fragment)

func emit_fragment_count_changed(fragment: Fragment, old_count: int, new_count: int) -> void:
	emit_signal("fragment_count_changed", fragment, old_count, new_count)

# 发送规则事件的便捷方法
func emit_rule_executed(rule: Rule, context: Context) -> void:
	emit_signal("rule_executed", rule, context)

func emit_rule_condition_met(rule: Rule, context: Context) -> void:
	emit_signal("rule_condition_met", rule, context)

func emit_rule_condition_failed(rule: Rule, context: Context) -> void:
	emit_signal("rule_condition_failed", rule, context)

# 发送游戏状态事件的便捷方法
func emit_warmth_changed(new_warmth: int, old_warmth: int) -> void:
	emit_signal("warmth_changed", new_warmth, old_warmth)

func emit_turn_advanced(turn_number: int) -> void:
	emit_signal("turn_advanced", turn_number)

func emit_game_started() -> void:
	emit_signal("game_started")

func emit_game_paused() -> void:
	emit_signal("game_paused")

func emit_game_resumed() -> void:
	emit_signal("game_resumed")

func emit_game_ended(reason: String = "") -> void:
	emit_signal("game_ended", reason)

# 发送测试事件的便捷方法
func emit_test_evaluated(test: Test, result: bool, context: Context) -> void:
	emit_signal("test_evaluated", test, result, context)

func emit_requirement_checked(test: Test, passed: bool) -> void:
	emit_signal("requirement_checked", test, passed)

# 发送修改器事件的便捷方法
func emit_modifier_executed(modifier: Resource, context: Context) -> void:
	emit_signal("modifier_executed", modifier, context)

func emit_card_modifier_executed(modifier: Resource, target_cards: Array) -> void:
	emit_signal("card_modifier_executed", modifier, target_cards)

# 发送UI事件的便捷方法
func emit_ui_card_selected(card_viz: Node) -> void:
	emit_signal("ui_card_selected", card_viz)

func emit_ui_card_deselected(card_viz: Node) -> void:
	emit_signal("ui_card_deselected", card_viz)

func emit_ui_card_hovered(card_viz: Node) -> void:
	emit_signal("ui_card_hovered", card_viz)

func emit_ui_card_clicked(card_viz: Node) -> void:
	emit_signal("ui_card_clicked", card_viz)

func emit_ui_card_double_clicked(card_viz: Node) -> void:
	emit_signal("ui_card_double_clicked", card_viz)

func emit_ui_card_dragged(card_viz: Node, from_pos: Vector2, to_pos: Vector2) -> void:
	emit_signal("ui_card_dragged", card_viz, from_pos, to_pos)

# 发送动画事件的便捷方法
func emit_animation_started(target: Node, animation_name: String) -> void:
	emit_signal("animation_started", target, animation_name)

func emit_animation_completed(target: Node, animation_name: String) -> void:
	emit_signal("animation_completed", target, animation_name)

func emit_particle_effect_started(effect_name: String, position: Vector2) -> void:
	emit_signal("particle_effect_started", effect_name, position)

# 发送音频事件的便捷方法
func emit_sound_requested(sound_name: String, position: Vector2 = Vector2.ZERO) -> void:
	emit_signal("sound_requested", sound_name, position)

func emit_music_change_requested(track_name: String, fade_time: float = 1.0) -> void:
	emit_signal("music_change_requested", track_name, fade_time)

# 发送调试事件的便捷方法
func emit_debug_info_updated(info: Dictionary) -> void:
	emit_signal("debug_info_updated", info)

func emit_debug_log(message: String, level: String = "INFO") -> void:
	emit_signal("debug_log", message, level)
	
	# 同时打印到控制台
	match level.to_upper():
		"ERROR":
			print_rich("[color=red][ERROR][/color] ", message)
		"WARNING":
			print_rich("[color=yellow][WARNING][/color] ", message)
		"INFO":
			print_rich("[color=cyan][INFO][/color] ", message)
		"DEBUG":
			print_rich("[color=gray][DEBUG][/color] ", message)
		_:
			print("[", level, "] ", message)

# 批量连接事件的便捷方法
func connect_card_events(target: Object) -> void:
	if target.has_method("_on_card_created"):
		card_created.connect(target._on_card_created)
	if target.has_method("_on_card_destroyed"):
		card_destroyed.connect(target._on_card_destroyed)
	if target.has_method("_on_card_moved"):
		card_moved.connect(target._on_card_moved)
	if target.has_method("_on_card_transformed"):
		card_transformed.connect(target._on_card_transformed)

func connect_game_events(target: Object) -> void:
	if target.has_method("_on_warmth_changed"):
		warmth_changed.connect(target._on_warmth_changed)
	if target.has_method("_on_turn_advanced"):
		turn_advanced.connect(target._on_turn_advanced)
	if target.has_method("_on_game_started"):
		game_started.connect(target._on_game_started)
	if target.has_method("_on_game_ended"):
		game_ended.connect(target._on_game_ended)

func connect_ui_events(target: Object) -> void:
	if target.has_method("_on_ui_card_selected"):
		ui_card_selected.connect(target._on_ui_card_selected)
	if target.has_method("_on_ui_card_clicked"):
		ui_card_clicked.connect(target._on_ui_card_clicked)
	if target.has_method("_on_ui_card_dragged"):
		ui_card_dragged.connect(target._on_ui_card_dragged)