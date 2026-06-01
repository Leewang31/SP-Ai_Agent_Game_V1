extends CanvasLayer

const LOBBY_SCENE : String = "res://scenes/Lobby.tscn"

# Frosted Glass 색상
const COL_PANEL       : Color = Color(0.039, 0.078, 0.059, 0.72)
const COL_BORDER      : Color = Color(1.0,   1.0,   1.0,   0.14)
const COL_GREEN       : Color = Color(0.290, 0.871, 0.502, 1.0)
const COL_DANGER_BG   : Color = Color(0.937, 0.267, 0.267, 0.2)
const COL_DANGER_TEXT : Color = Color(0.973, 0.529, 0.443, 1.0)

var _win_screen  : Control = null
var _pause_menu  : Control = null
var _death_hud   : Control = null
var _time_label  : Label   = null
var _kills_label : Label   = null
var _sens_slider : HSlider = null
var _player      : Node    = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_parent().get_node_or_null("Player")
	_build_win_screen()
	_build_pause_menu()
	_build_death_hud()

# ── 공개 API ────────────────────────────────────────────────────────

func show_win_screen(elapsed_sec: float, kills: int) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player:
		_player.set_physics_process(false)
		_player.set_process_input(false)
	var mins := int(elapsed_sec) / 60
	var secs := int(elapsed_sec) % 60
	_time_label.text  = "생존 시간: %d분 %02d초" % [mins, secs]
	_kills_label.text = "처치: %d명" % kills
	_win_screen.show()

func show_death_screen() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_death_hud.show()

func toggle_pause_menu() -> void:
	if _win_screen.visible or _death_hud.visible:
		return
	if _pause_menu.visible:
		_close_pause_menu()
	else:
		_open_pause_menu()

# ── 내부 ────────────────────────────────────────────────────────────

func _open_pause_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	_pause_menu.show()

func _close_pause_menu() -> void:
	_pause_menu.hide()
	get_tree().paused = false
	if not _death_hud.visible and not _win_screen.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _leave_game() -> void:
	get_tree().paused = false
	NetworkManager.leave_room()
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_sensitivity_changed(value: float) -> void:
	if _player:
		_player.mouse_sensitivity = value

# ── 스타일 헬퍼 ─────────────────────────────────────────────────────

func _make_panel_style(bg: Color = COL_PANEL, radius: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                   = bg
	s.border_color               = COL_BORDER
	s.set_border_width_all(1)
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	return s

func _make_button(label: String, bg: Color, fg: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_color_override("font_color", fg)
	btn.custom_minimum_size = Vector2(200, 40)
	var _make_style := func(col: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color                   = col
		s.corner_radius_top_left     = 8
		s.corner_radius_top_right    = 8
		s.corner_radius_bottom_left  = 8
		s.corner_radius_bottom_right = 8
		return s
	btn.add_theme_stylebox_override("normal",  _make_style.call(bg))
	btn.add_theme_stylebox_override("hover",   _make_style.call(bg.lightened(0.15)))
	btn.add_theme_stylebox_override("pressed", _make_style.call(bg.darkened(0.15)))
	btn.add_theme_stylebox_override("focus",   _make_style.call(bg))
	return btn

# ── UI 빌드: 승리 화면 ───────────────────────────────────────────────

func _build_win_screen() -> void:
	_win_screen = Control.new()
	_win_screen.name = "WinScreen"
	_win_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win_screen.hide()
	add_child(_win_screen)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win_screen.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_top", "margin_bottom", "margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var trophy := Label.new()
	trophy.text = "🏆 승리!"
	trophy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trophy.add_theme_font_size_override("font_size", 32)
	vbox.add_child(trophy)

	var sub := Label.new()
	sub.text = "최후의 1인으로 살아남았습니다"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	sub.add_theme_font_size_override("font_size", 13)
	vbox.add_child(sub)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(sep)

	_time_label = Label.new()
	_time_label.text = "생존 시간: --"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	vbox.add_child(_time_label)

	_kills_label = Label.new()
	_kills_label.text = "처치: --"
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kills_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	vbox.add_child(_kills_label)

	var sep2 := Control.new()
	sep2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(sep2)

	var lobby_btn := _make_button("로비로 돌아가기", COL_GREEN, Color(0, 0, 0, 1))
	lobby_btn.pressed.connect(_leave_game)
	vbox.add_child(lobby_btn)

# ── UI 빌드: ESC 설정창 ──────────────────────────────────────────────

func _build_pause_menu() -> void:
	_pause_menu = Control.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.hide()
	add_child(_pause_menu)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_top", "margin_bottom", "margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "설정"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var sens_lbl := Label.new()
	sens_lbl.text = "마우스 감도"
	sens_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	sens_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(sens_lbl)

	_sens_slider = HSlider.new()
	_sens_slider.min_value = 0.001
	_sens_slider.max_value = 0.010
	_sens_slider.step      = 0.0005
	_sens_slider.value     = _player.mouse_sensitivity if _player else 0.003
	_sens_slider.custom_minimum_size = Vector2(192, 24)
	_sens_slider.value_changed.connect(_on_sensitivity_changed)
	vbox.add_child(_sens_slider)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(sep)

	var resume_btn := _make_button("계속하기", Color(1, 1, 1, 0.1), Color(1, 1, 1, 1))
	resume_btn.pressed.connect(_close_pause_menu)
	vbox.add_child(resume_btn)

	var leave_btn := _make_button("게임 나가기", COL_DANGER_BG, COL_DANGER_TEXT)
	leave_btn.pressed.connect(_leave_game)
	vbox.add_child(leave_btn)

# ── UI 빌드: 사망 화면 ───────────────────────────────────────────────

func _build_death_hud() -> void:
	_death_hud = Control.new()
	_death_hud.name = "DeathHUD"
	_death_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_hud.hide()
	add_child(_death_hud)

	# 상단 배지
	var badge := PanelContainer.new()
	badge.set_anchor(SIDE_LEFT,   0.5)
	badge.set_anchor(SIDE_RIGHT,  0.5)
	badge.set_anchor(SIDE_TOP,    0.0)
	badge.set_anchor(SIDE_BOTTOM, 0.0)
	badge.set_offset(SIDE_LEFT,   -54)
	badge.set_offset(SIDE_RIGHT,   54)
	badge.set_offset(SIDE_TOP,    16)
	badge.set_offset(SIDE_BOTTOM, 48)
	var badge_style := _make_panel_style(Color(0.937, 0.267, 0.267, 0.18), 20)
	badge_style.border_color = Color(0.937, 0.267, 0.267, 0.35)
	badge.add_theme_stylebox_override("panel", badge_style)
	_death_hud.add_child(badge)

	var badge_lbl := Label.new()
	badge_lbl.text = "💀 사망"
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_color_override("font_color", COL_DANGER_TEXT)
	badge_lbl.add_theme_font_size_override("font_size", 13)
	badge.add_child(badge_lbl)

	# 하단 바
	var bar := Panel.new()
	bar.set_anchor(SIDE_LEFT,   0.0)
	bar.set_anchor(SIDE_RIGHT,  1.0)
	bar.set_anchor(SIDE_TOP,    1.0)
	bar.set_anchor(SIDE_BOTTOM, 1.0)
	bar.set_offset(SIDE_TOP,    -64)
	bar.set_offset(SIDE_BOTTOM,   0)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color          = Color(0.039, 0.078, 0.059, 0.82)
	bar_style.border_color      = Color(0.937, 0.267, 0.267, 0.25)
	bar_style.border_width_top  = 1
	bar.add_theme_stylebox_override("panel", bar_style)
	_death_hud.add_child(bar)

	var hmargin := MarginContainer.new()
	hmargin.set_anchors_preset(Control.PRESET_FULL_RECT)
	hmargin.add_theme_constant_override("margin_left",   24)
	hmargin.add_theme_constant_override("margin_right",  24)
	hmargin.add_theme_constant_override("margin_top",     8)
	hmargin.add_theme_constant_override("margin_bottom",  8)
	bar.add_child(hmargin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hmargin.add_child(hbox)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.alignment             = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(left_vbox)

	var dead_lbl := Label.new()
	dead_lbl.text = "사망했습니다"
	dead_lbl.add_theme_color_override("font_color", COL_DANGER_TEXT)
	dead_lbl.add_theme_font_size_override("font_size", 14)
	left_vbox.add_child(dead_lbl)

	var watch_lbl := Label.new()
	watch_lbl.text = "다른 플레이어를 관전 중..."
	watch_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	watch_lbl.add_theme_font_size_override("font_size", 11)
	left_vbox.add_child(watch_lbl)

	var leave_btn := _make_button("게임 나가기", COL_DANGER_BG, COL_DANGER_TEXT)
	leave_btn.custom_minimum_size = Vector2(120, 36)
	leave_btn.pressed.connect(_leave_game)
	hbox.add_child(leave_btn)
