# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  LobbyManager.gd
#  역할    : 로비 UI 상태머신. MenuPanel/JoinPanel/WaitingPanel 전환.
#  연결 노드: Lobby.tscn 루트 노드
#  주요 시그널: NetworkManager.player_list_updated, game_start_received
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
extends Control

# ─── 상수 ────────────────────────────────────────
const CHARS         : String = "ABCDEFGHJKLMNPQRSTUVWXYZ"
const JOIN_TIMEOUT  : float  = 3.0

# ─── 상태 ────────────────────────────────────────
enum State { MENU, JOIN_INPUT, WAITING }

var _state         : State  = State.MENU
var _is_host       : bool   = false
var _room_code     : String = ""
var _join_timer    : float  = 0.0
var _join_checking : bool   = false

# ─── UI 노드 참조 ─────────────────────────────────
var _nickname_input  : LineEdit
var _create_btn      : Button
var _join_btn        : Button

var _code_input      : LineEdit
var _confirm_btn     : Button

var _room_code_label : Label
var _player_list     : VBoxContainer
var _status_label    : Label
var _start_btn       : Button

var _menu_panel    : Control
var _join_panel    : Control
var _waiting_panel : Control
var _error_label   : Label

# ─── 초기화 ──────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_show_menu()
	NetworkManager.player_list_updated.connect(_on_player_list_updated)
	NetworkManager.game_start_received.connect(_on_game_start_received)

func _process(delta: float) -> void:
	if _join_checking:
		_join_timer += delta
		if _join_timer >= JOIN_TIMEOUT:
			_join_checking = false
			_join_timer    = 0.0
			# 방장 없으면 안내만 — 강제 종료 없이 유저가 직접 나가기 선택
			if NetworkManager.get_current_player_count() <= 1:
				_status_label.text = "방장을 찾을 수 없습니다. 코드를 확인하세요."

# ─── UI 빌드 ─────────────────────────────────────
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_error_label = Label.new()
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_error_label.visible = false
	_error_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_error_label.position = Vector2(0, 20)
	add_child(_error_label)

	_build_menu_panel()
	_build_join_panel()
	_build_waiting_panel()

func _build_menu_panel() -> void:
	_menu_panel = _make_centered_vbox(300, 260)
	add_child(_menu_panel)

	var title := Label.new()
	title.text = "🐧 동물 숨기"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	_menu_panel.add_child(title)

	_menu_panel.add_child(_spacer(12))

	var nick_label := Label.new()
	nick_label.text = "닉네임"
	_menu_panel.add_child(nick_label)

	_nickname_input = LineEdit.new()
	_nickname_input.placeholder_text = "닉네임 입력 (최대 12자)"
	_nickname_input.max_length = 12
	_nickname_input.custom_minimum_size = Vector2(0, 36)
	_nickname_input.text_changed.connect(_on_nickname_changed)
	_menu_panel.add_child(_nickname_input)

	_menu_panel.add_child(_spacer(16))

	_create_btn = Button.new()
	_create_btn.text = "🏠  방 만들기"
	_create_btn.custom_minimum_size = Vector2(0, 44)
	_create_btn.disabled = true
	_create_btn.pressed.connect(_on_create_pressed)
	_menu_panel.add_child(_create_btn)

	_menu_panel.add_child(_spacer(8))

	_join_btn = Button.new()
	_join_btn.text = "🚪  방 참가"
	_join_btn.custom_minimum_size = Vector2(0, 44)
	_join_btn.disabled = true
	_join_btn.pressed.connect(_on_join_pressed)
	_menu_panel.add_child(_join_btn)

func _build_join_panel() -> void:
	_join_panel = _make_centered_vbox(300, 220)
	_join_panel.visible = false
	add_child(_join_panel)

	var label := Label.new()
	label.text = "방 코드 입력 (4자리)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_panel.add_child(label)

	_join_panel.add_child(_spacer(12))

	_code_input = LineEdit.new()
	_code_input.placeholder_text = "예: KFPQ"
	_code_input.max_length = 4
	_code_input.custom_minimum_size = Vector2(0, 36)
	_code_input.text_changed.connect(_on_code_changed)
	_join_panel.add_child(_code_input)

	_join_panel.add_child(_spacer(12))

	_confirm_btn = Button.new()
	_confirm_btn.text = "참가"
	_confirm_btn.custom_minimum_size = Vector2(0, 44)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_join_confirm)
	_join_panel.add_child(_confirm_btn)

	_join_panel.add_child(_spacer(8))

	var back_btn := Button.new()
	back_btn.text = "← 뒤로"
	back_btn.pressed.connect(_show_menu)
	_join_panel.add_child(back_btn)

func _build_waiting_panel() -> void:
	_waiting_panel = _make_centered_vbox(320, 380)
	_waiting_panel.visible = false
	add_child(_waiting_panel)

	var code_hint := Label.new()
	code_hint.text = "룸 코드"
	code_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	_waiting_panel.add_child(code_hint)

	_room_code_label = Label.new()
	_room_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_code_label.add_theme_font_size_override("font_size", 36)
	_room_code_label.add_theme_color_override("font_color", Color(0.5, 0.55, 1.0))
	_waiting_panel.add_child(_room_code_label)

	_waiting_panel.add_child(_spacer(12))

	var list_label := Label.new()
	list_label.text = "참가자"
	list_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_waiting_panel.add_child(list_label)

	_player_list = VBoxContainer.new()
	_player_list.custom_minimum_size = Vector2(0, 140)
	_waiting_panel.add_child(_player_list)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_waiting_panel.add_child(_status_label)

	_waiting_panel.add_child(_spacer(8))

	_start_btn = Button.new()
	_start_btn.text = "▶  게임 시작"
	_start_btn.custom_minimum_size = Vector2(0, 48)
	_start_btn.visible = false
	_start_btn.pressed.connect(_on_start_pressed)
	_waiting_panel.add_child(_start_btn)

	var leave_btn := Button.new()
	leave_btn.text = "← 나가기"
	leave_btn.custom_minimum_size = Vector2(0, 36)
	leave_btn.pressed.connect(_on_leave_waiting)
	_waiting_panel.add_child(leave_btn)

# ─── 패널 전환 ────────────────────────────────────
func _show_menu() -> void:
	_state = State.MENU
	_menu_panel.visible    = true
	_join_panel.visible    = false
	_waiting_panel.visible = false
	if _error_label != null:
		_error_label.visible = false

func _show_join() -> void:
	_state = State.JOIN_INPUT
	_menu_panel.visible    = false
	_join_panel.visible    = true
	_waiting_panel.visible = false
	_code_input.text       = ""
	_confirm_btn.disabled  = true

func _show_waiting() -> void:
	_state = State.WAITING
	_menu_panel.visible        = false
	_join_panel.visible        = false
	_waiting_panel.visible     = true
	_room_code_label.text      = _room_code
	_start_btn.visible         = _is_host
	_status_label.text         = "대기 중..." if not _is_host else "플레이어를 기다리는 중..."
	_error_label.visible       = false

# ─── 버튼 핸들러 ──────────────────────────────────
func _on_nickname_changed(text: String) -> void:
	var valid := text.strip_edges().length() > 0
	_create_btn.disabled = not valid
	_join_btn.disabled   = not valid
	_error_label.visible = false

func _on_code_changed(text: String) -> void:
	_confirm_btn.disabled = text.strip_edges().length() < 4

func _on_create_pressed() -> void:
	_is_host   = true
	_room_code = _generate_code()
	NetworkManager.join_room_with_presence(_room_code, _nickname_input.text.strip_edges(), true)
	_show_waiting()

func _on_join_pressed() -> void:
	_show_join()

func _on_join_confirm() -> void:
	_is_host       = false
	_room_code     = _code_input.text.strip_edges().to_upper()
	_join_checking = true
	_join_timer    = 0.0
	NetworkManager.join_room_with_presence(_room_code, _nickname_input.text.strip_edges(), false)
	_show_waiting()

func _on_start_pressed() -> void:
	if _is_host:
		NetworkManager.send_game_start()

func _on_leave_waiting() -> void:
	NetworkManager.leave_room()
	_join_checking = false
	_join_timer    = 0.0
	_show_menu()

func _on_player_list_updated(players: Array) -> void:
	for child in _player_list.get_children():
		child.queue_free()

	for player in players:
		var row  := HBoxContainer.new()
		var icon := Label.new()
		var name := Label.new()

		icon.text = "👑 " if player.get("is_host", false) else "🐧 "
		name.text = player.get("nickname", "???")

		if player.get("player_id", "") == NetworkManager.local_player_id:
			name.text += " (나)"
			name.add_theme_color_override("font_color", Color(0.5, 0.55, 1.0))

		row.add_child(icon)
		row.add_child(name)
		_player_list.add_child(row)

	if players.size() > 1 and _join_checking:
		_join_checking = false
		_join_timer    = 0.0

func _on_game_start_received() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# ─── 유틸 ─────────────────────────────────────────
func _generate_code() -> String:
	var code := ""
	for i in 4:
		code += CHARS[randi() % CHARS.length()]
	return code

func _make_centered_vbox(width: int, height: int) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(width, height)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left   = -width  / 2.0
	vbox.offset_right  =  width  / 2.0
	vbox.offset_top    = -height / 2.0
	vbox.offset_bottom =  height / 2.0
	return vbox

func _spacer(px: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, px)
	return s
