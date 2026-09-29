extends RigidBody2D
class_name PenFlickPen

var player_id: int = 0
var player_name: String = "Player"
var pen_color: Color = Color.WHITE
var eliminated: bool = false
var pen_length: float = 96.0
var pen_width: float = 18.0
var last_hit_strength: float = 0.0
var total_hits: int = 0

func setup(id: int, pname: String, color: Color) -> void:
    player_id = id
    player_name = pname
    pen_color = color
    mass = 1.0
    gravity_scale = 0.0
    linear_damp = 1.55
    angular_damp = 1.65
    inertia = 0.62
    continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
    contact_monitor = true
    max_contacts_reported = 12
    center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass = Vector2(0.0, 0.0)

    var material := PhysicsMaterial.new()
    material.friction = 0.58
    material.bounce = 0.22
    physics_material_override = material

    var shape_node := CollisionShape2D.new()
    var shape := CapsuleShape2D.new()
    shape.radius = pen_width * 0.5
    shape.height = pen_length
    shape_node.shape = shape
    shape_node.rotation = PI * 0.5
    add_child(shape_node)

    body_entered.connect(_on_body_entered)
    queue_redraw()

func launch(direction: Vector2, strength: float) -> void:
    sleeping = false
    var impulse := direction.normalized() * strength
    apply_central_impulse(impulse)
    # A tiny initial roll makes the pen feel physical without overpowering
    # the collision-generated torque.
    apply_torque_impulse(strength * 0.0018 * direction.angle())
    queue_redraw()

func _on_body_entered(body: Node) -> void:
    var other := body as PenFlickPen
    if other == null or other.eliminated:
        return

    total_hits += 1
    var relative_velocity: Vector2 = linear_velocity - other.linear_velocity
    var impact_speed: float = relative_velocity.length()
    last_hit_strength = impact_speed

    # Off-centre impacts naturally create angular momentum. The visible
    # centre dot represents the approximate centre of mass/contact region.
    var to_other: Vector2 = other.global_position - global_position
    if to_other.length() > 0.01:
        var normal: Vector2 = to_other.normalized()
        var tangent: Vector2 = Vector2(-normal.y, normal.x)
        var tangential_speed: float = abs(relative_velocity.dot(tangent))
        var spin: float = tangential_speed * 0.035 + impact_speed * 0.008
        var side: float = sign(relative_velocity.dot(tangent))
        if side == 0.0:
            side = 1.0
        apply_torque_impulse(side * spin * mass)

    queue_redraw()

func eliminate() -> void:
    if eliminated:
        return
    eliminated = true
    freeze = true
    linear_velocity = Vector2.ZERO
    angular_velocity = 0.0
    modulate = Color(0.45, 0.45, 0.45, 0.5)
    queue_redraw()

func _draw() -> void:
    var half := pen_length * 0.5
    var body_rect := Rect2(-half + 8.0, -pen_width * 0.5, pen_length - 18.0, pen_width)
    draw_style_box(_rounded_box(pen_color, 7.0), body_rect)

    var tip := PackedVector2Array([
        Vector2(half - 10.0, -pen_width * 0.5),
        Vector2(half + 10.0, 0.0),
        Vector2(half - 10.0, pen_width * 0.5)
    ])
    draw_colored_polygon(tip, pen_color.lightened(0.18))

    draw_circle(Vector2(-half + 5.0, 0.0), pen_width * 0.43, pen_color.darkened(0.22))
    draw_line(Vector2(-half + 18.0, -pen_width * 0.28), Vector2(half - 17.0, -pen_width * 0.28), Color(1,1,1,0.28), 2.0)

    if not eliminated:
        draw_circle(Vector2.ZERO, 5.0, Color(1,1,1,0.75))
        draw_circle(Vector2.ZERO, 9.0, Color(1,1,1,0.08), false, 2.0)

func _rounded_box(color: Color, radius: float) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.corner_radius_top_left = int(radius)
    box.corner_radius_top_right = int(radius)
    box.corner_radius_bottom_left = int(radius)
    box.corner_radius_bottom_right = int(radius)
    return box
