extends Node2D

const PenScene := preload("res://scripts/pen.gd")

const TABLE := Rect2(80, 105, 1120, 530)
const MAX_FORCE := 1250.0
const MIN_FORCE := 120.0
const SETTLE_SPEED := 8.0
const SETTLE_DELAY := 0.65

var pens: Array[PenFlickPen] = []
var active_player := 0
var player_count := 2
var vs_ai := true
var turn_in_progress := false
var settle_timer := 0.0
var game_over := false

var aim_start := Vector2.ZERO
var aim_current := Vector2.ZERO
var aiming := false
var aim_pen: PenFlickPen

var title_label: Label
var status_label: Label
var force_label: Label
var mode_label: Label
var turn_label: Label
var help_label: Label
var menu_layer: CanvasLayer
var game_layer: CanvasLayer

var colors := [
    Color("#39D98A"),
    Color("#FF5C77"),
    Color("#4DA3FF"),
    Color("#FFC857")
]

func _ready() -> void:
    get_viewport().set_embedding_subwindows(false)
    queue_redraw()
    _show_menu()

func _process(delta: float) -> void:
    if game_over:
        queue_redraw()
        return

    if turn_in_progress:
        settle_timer += delta
        if settle_timer >= SETTLE_DELAY and _all_pens_settled():
            turn_in_progress = false
            _check_eliminations()
            if not game_over:
                _advance_turn()
    else:
        _check_eliminations()

    if aiming:
        queue_redraw()

func _draw() -> void:
    # Background
    draw_rect(Rect2(0, 0, 1280, 720), Color("#091018"))
    # Table shadow
    draw_style_box(_box(Color(0,0,0,0.35), 24), Rect2(TABLE.position + Vector2(0, 16), TABLE.size))
    # Table
    draw_style_box(_box(Color("#6B4428"), 18), TABLE)
    draw_style_box(_box(Color("#B87843"), 12), TABLE.grow(-12))
    draw_style_box(_box(Color("#C98A50"), 8), TABLE.grow(-23))

    # Subtle tabletop lines
    for y in range(int(TABLE.position.y + 55), int(TABLE.end.y - 20), 48):
        draw_line(Vector2(TABLE.position.x + 25, y), Vector2(TABLE.end.x - 25, y), Color(0.35,0.18,0.08,0.08), 2)

    # Edge highlight
    draw_line(TABLE.position + Vector2(18, 14), Vector2(TABLE.end.x - 18, TABLE.position.y + 14), Color(1,1,1,0.12), 3)
    draw_line(Vector2(TABLE.position.x + 18, TABLE.end.y - 14), TABLE.end - Vector2(18, 14), Color(0,0,0,0.2), 5)

    if aiming and aim_pen and not aim_pen.eliminated:
        var pull := aim_start - aim_current
        var strength_ratio := clamp(pull.length() / 230.0, 0.0, 1.0)
        var dir := pull.normalized() if pull.length() > 0.1 else Vector2.RIGHT
        var preview_len := lerp(80.0, 330.0, strength_ratio)
        draw_dashed_line(aim_pen.global_position, aim_pen.global_position + dir * preview_len, Color(1,1,1,0.72), 4.0, 10.0)
        draw_circle(aim_pen.global_position + dir * preview_len, 7.0, Color(1,1,1,0.6))
        draw_line(aim_pen.global_position, aim_current, Color(1,1,1,0.38), 3.0)
        draw_circle(aim_current, 9.0, Color(1,1,1,0.72))

func _box(color: Color, radius: int) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.corner_radius_top_left = radius
    box.corner_radius_top_right = radius
    box.corner_radius_bottom_left = radius
    box.corner_radius_bottom_right = radius
    return box

func _show_menu() -> void:
    menu_layer = CanvasLayer.new()
    add_child(menu_layer)

    var panel := Panel.new()
    panel.position = Vector2(335, 105)
    panel.size = Vector2(610, 510)
    panel.add_theme_stylebox_override("panel", _box(Color("#111B25"), 26))
    menu_layer.add_child(panel)

    var title := Label.new()
    title.text = "PEN FLICK"
    title.position = Vector2(70, 48)
    title.size = Vector2(470, 70)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 54)
    title.add_theme_color_override("font_color", Color("#F3F7FA"))
    panel.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "TABLETOP PEN BATTLE"
    subtitle.position = Vector2(70, 115)
    subtitle.size = Vector2(470, 30)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 15)
    subtitle.add_theme_color_override("font_color", Color("#7F94A8"))
    panel.add_child(subtitle)

    var single := _menu_button("SINGLE PLAYER", Vector2(105, 185), Vector2(400, 70))
    single.pressed.connect(func(): _start_game(true, 2))
    panel.add_child(single)

    var multi := _menu_button("LOCAL MULTIPLAYER", Vector2(105, 275), Vector2(400, 70))
    multi.pressed.connect(func(): _show_player_picker())
    panel.add_child(multi)

    var info := Label.new()
    info.text = "Flick • collide • survive"
    info.position = Vector2(80, 405)
    info.size = Vector2(450, 30)
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.add_theme_font_size_override("font_size", 17)
    info.add_theme_color_override("font_color", Color("#8FA5B8"))
    panel.add_child(info)

func _show_player_picker() -> void:
    if menu_layer:
        menu_layer.queue_free()
    menu_layer = CanvasLayer.new()
    add_child(menu_layer)

    var panel := Panel.new()
    panel.position = Vector2(335, 135)
    panel.size = Vector2(610, 450)
    panel.add_theme_stylebox_override("panel", _box(Color("#111B25"), 26))
    menu_layer.add_child(panel)

    var title := Label.new()
    title.text = "CHOOSE PLAYERS"
    title.position = Vector2(70, 45)
    title.size = Vector2(470, 55)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", Color("#F3F7FA"))
    panel.add_child(title)

    for i in range(3):
        var count := i + 2
        var b := _menu_button(str(count) + " PLAYERS", Vector2(105, 125 + i * 82), Vector2(400, 62))
        b.pressed.connect(func(): _start_game(false, count))
        panel.add_child(b)

    var back := Button.new()
    back.text = "BACK"
    back.position = Vector2(255, 375)
    back.size = Vector2(100, 40)
    back.pressed.connect(func():
        menu_layer.queue_free()
        _show_menu()
    )
    panel.add_child(back)

func _menu_button(text_value: String, pos: Vector2, size_value: Vector2) -> Button:
    var b := Button.new()
    b.text = text_value
    b.position = pos
    b.size = size_value
    b.add_theme_font_size_override("font_size", 22)
    b.add_theme_color_override("font_color", Color("#F3F7FA"))
    b.add_theme_stylebox_override("normal", _box(Color("#1D2A38"), 16))
    b.add_theme_stylebox_override("hover", _box(Color("#26394B"), 16))
    b.add_theme_stylebox_override("pressed", _box(Color("#17222D"), 16))
    return b

func _start_game(ai_mode: bool, count: int) -> void:
    vs_ai = ai_mode
    player_count = count
    game_over = false
    active_player = 0
    turn_in_progress = false
    aiming = false
    settle_timer = 0.0

    if menu_layer:
        menu_layer.queue_free()
        menu_layer = null

    _clear_pens()
    _build_hud()
    _spawn_pens()
    _update_hud()

func _build_hud() -> void:
    if game_layer:
        game_layer.queue_free()
    game_layer = CanvasLayer.new()
    add_child(game_layer)

    var top := Panel.new()
    top.position = Vector2(28, 20)
    top.size = Vector2(1224, 62)
    top.add_theme_stylebox_override("panel", _box(Color("#0E1720"), 18))
    game_layer.add_child(top)

    title_label = Label.new()
    title_label.text = "PEN FLICK"
    title_label.position = Vector2(22, 12)
    title_label.size = Vector2(190, 38)
    title_label.add_theme_font_size_override("font_size", 25)
    title_label.add_theme_color_override("font_color", Color("#F3F7FA"))
    top.add_child(title_label)

    mode_label = Label.new()
    mode_label.position = Vector2(215, 14)
    mode_label.size = Vector2(250, 34)
    mode_label.add_theme_font_size_override("font_size", 15)
    mode_label.add_theme_color_override("font_color", Color("#8197AA"))
    top.add_child(mode_label)

    turn_label = Label.new()
    turn_label.position = Vector2(470, 11)
    turn_label.size = Vector2(330, 38)
    turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    turn_label.add_theme_font_size_override("font_size", 22)
    top.add_child(turn_label)

    force_label = Label.new()
    force_label.position = Vector2(840, 14)
    force_label.size = Vector2(210, 34)
    force_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    force_label.add_theme_font_size_override("font_size", 16)
    force_label.add_theme_color_override("font_color", Color("#A9BBCB"))
    top.add_child(force_label)

    var restart := Button.new()
    restart.text = "MENU"
    restart.position = Vector2(1080, 11)
    restart.size = Vector2(120, 40)
    restart.pressed.connect(func():
        _clear_pens()
        if game_layer:
            game_layer.queue_free()
            game_layer = null
        _show_menu()
    )
    top.add_child(restart)

    help_label = Label.new()
    help_label.text = "DRAG BACK FROM YOUR PEN • RELEASE TO FLICK"
    help_label.position = Vector2(360, 672)
    help_label.size = Vector2(560, 28)
    help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    help_label.add_theme_font_size_override("font_size", 14)
    help_label.add_theme_color_override("font_color", Color("#8197AA"))
    game_layer.add_child(help_label)

func _spawn_pens() -> void:
    var positions: Array[Vector2] = []
    if player_count == 2:
        positions = [Vector2(310, 370), Vector2(970, 370)]
    elif player_count == 3:
        positions = [Vector2(300, 260), Vector2(980, 260), Vector2(640, 530)]
    else:
        positions = [Vector2(300, 245), Vector2(980, 245), Vector2(300, 520), Vector2(980, 520)]

    for i in range(player_count):
        var pen := PenScene.new()
        add_child(pen)
        pen.setup(i, "Player " + str(i + 1), colors[i])
        pen.position = positions[i]
        pens.append(pen)

func _clear_pens() -> void:
    for pen in pens:
        if is_instance_valid(pen):
            pen.queue_free()
    pens.clear()

func _unhandled_input(event: InputEvent) -> void:
    if game_over or turn_in_progress or not aim_allowed():
        return

    if vs_ai and active_player != 0:
        return

    if event is InputEventScreenTouch:
        if event.pressed:
            _begin_aim(event.position)
        else:
            _release_aim(event.position)
    elif event is InputEventScreenDrag:
        if aiming:
            aim_current = event.position
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _begin_aim(event.position)
        else:
            _release_aim(event.position)
    elif event is InputEventMouseMotion and aiming:
        aim_current = event.position

func aim_allowed() -> bool:
    return active_player >= 0 and active_player < pens.size() and not pens[active_player].eliminated

func _begin_aim(point: Vector2) -> void:
    if not aim_allowed():
        return
    var pen := pens[active_player]
    if pen.global_position.distance_to(point) > 85.0:
        return
    aiming = true
    aim_pen = pen
    aim_start = pen.global_position
    aim_current = point
    queue_redraw()

func _release_aim(point: Vector2) -> void:
    if not aiming or not aim_pen:
        return
    aim_current = point
    var pull := aim_start - aim_current
    var distance := clamp(pull.length(), 0.0, 230.0)
    if distance < 18.0:
        aiming = false
        queue_redraw()
        return

    var strength := lerp(MIN_FORCE, MAX_FORCE, distance / 230.0)
    var direction := pull.normalized()
    aiming = false
    aim_pen.launch(direction, strength)
    turn_in_progress = true
    settle_timer = 0.0
    queue_redraw()

func _physics_process(_delta: float) -> void:
    if game_over:
        return

    if not turn_in_progress and vs_ai and active_player != 0 and not pens[active_player].eliminated:
        _ai_take_turn()

    _check_eliminations()

func _ai_take_turn() -> void:
    turn_in_progress = true
    settle_timer = 0.0
    await get_tree().create_timer(0.45).timeout
    if game_over or active_player >= pens.size() or pens[active_player].eliminated:
        turn_in_progress = false
        return

    var shooter := pens[active_player]
    var target := _choose_ai_target(shooter)
    if target == null:
        turn_in_progress = false
        return

    var to_target := target.global_position - shooter.global_position
    var distance := to_target.length()
    var direction := to_target.normalized()
    var edge_bias := _nearest_edge_direction(target.global_position)
    if distance > 300.0:
        direction = direction.lerp(edge_bias, 0.22).normalized()

    var strength := clamp(560.0 + distance * 0.75, MIN_FORCE, MAX_FORCE)
    shooter.launch(direction, strength)
    settle_timer = 0.0

func _choose_ai_target(shooter: PenFlickPen) -> PenFlickPen:
    var best: PenFlickPen = null
    var best_score := INF
    for pen in pens:
        if pen == shooter or pen.eliminated:
            continue
        var score := shooter.global_position.distance_to(pen.global_position)
        score -= _edge_risk(pen.global_position) * 170.0
        if score < best_score:
            best_score = score
            best = pen
    return best

func _edge_risk(p: Vector2) -> float:
    var d := min(min(p.x - TABLE.position.x, TABLE.end.x - p.x), min(p.y - TABLE.position.y, TABLE.end.y - p.y))
    return 1.0 - clamp(d / 220.0, 0.0, 1.0)

func _nearest_edge_direction(p: Vector2) -> Vector2:
    var left := p.x - TABLE.position.x
    var right := TABLE.end.x - p.x
    var top := p.y - TABLE.position.y
    var bottom := TABLE.end.y - p.y
    var smallest := min(min(left, right), min(top, bottom))
    if smallest == left:
        return Vector2(-1, 0)
    if smallest == right:
        return Vector2(1, 0)
    if smallest == top:
        return Vector2(0, -1)
    return Vector2(0, 1)

func _all_pens_settled() -> bool:
    for pen in pens:
        if pen.eliminated:
            continue
        if pen.linear_velocity.length() > SETTLE_SPEED or abs(pen.angular_velocity) > 0.18:
            return false
    return true

func _check_eliminations() -> void:
    if pens.is_empty():
        return

    for pen in pens:
        if pen.eliminated:
            continue
        var p := pen.global_position
        if p.x < TABLE.position.x - 42 or p.x > TABLE.end.x + 42 or p.y < TABLE.position.y - 42 or p.y > TABLE.end.y + 42:
            pen.eliminate()

    var alive := 0
    var winner := -1
    for i in range(pens.size()):
        if not pens[i].eliminated:
            alive += 1
            winner = i

    if alive <= 1:
        game_over = true
        turn_in_progress = false
        _show_winner(winner)

func _advance_turn() -> void:
    if game_over:
        return

    for step in range(player_count):
        active_player = (active_player + 1) % player_count
        if not pens[active_player].eliminated:
            break
    _update_hud()

func _update_hud() -> void:
    if not turn_label:
        return
    var p := pens[active_player]
    turn_label.text = p.player_name + "'s turn"
    turn_label.add_theme_color_override("font_color", colors[active_player])
    mode_label.text = ("VS AI" if vs_ai else str(player_count) + " PLAYER LOCAL")
    force_label.text = "POWER  •  DRAG DISTANCE"

func _show_winner(winner: int) -> void:
    if not game_layer:
        return

    var overlay := ColorRect.new()
    overlay.position = Vector2.ZERO
    overlay.size = Vector2(1280, 720)
    overlay.color = Color(0.02, 0.04, 0.06, 0.78)
    game_layer.add_child(overlay)

    var panel := Panel.new()
    panel.position = Vector2(365, 205)
    panel.size = Vector2(550, 300)
    panel.add_theme_stylebox_override("panel", _box(Color("#111B25"), 28))
    game_layer.add_child(panel)

    var winner_text := "DRAW"
    if winner >= 0:
        winner_text = pens[winner].player_name + " WINS!"

    var label := Label.new()
    label.text = winner_text
    label.position = Vector2(35, 55)
    label.size = Vector2(480, 70)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 42)
    if winner >= 0:
        label.add_theme_color_override("font_color", colors[winner])
    panel.add_child(label)

    var sub := Label.new()
    sub.text = "Last pen standing"
    sub.position = Vector2(35, 125)
    sub.size = Vector2(480, 32)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_font_size_override("font_size", 18)
    sub.add_theme_color_override("font_color", Color("#91A5B7"))
    panel.add_child(sub)

    var again := _menu_button("PLAY AGAIN", Vector2(75, 190), Vector2(400, 58))
    again.pressed.connect(func():
        if game_layer:
            game_layer.queue_free()
            game_layer = null
        _start_game(vs_ai, player_count)
    )
    panel.add_child(again)
