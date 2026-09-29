extends RigidBody2D
class_name PenFlickPen

var player_id: int = 0
var player_name: String = "Player"
var pen_color: Color = Color.WHITE
var eliminated: bool = false
var pen_length: float = 96.0
var pen_width: float = 18.0

func setup(id: int, pname: String, color: Color) -> void:
    player_id = id
    player_name = pname
    pen_color = color
    mass = 1.0
    gravity_scale = 0.0
    linear_damp = 1.8
    angular_damp = 2.8
    continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
    contact_monitor = true
    max_contacts_reported = 8
    var material := PhysicsMaterial.new()
    material.friction = 0.72
    material.bounce = 0.16
    physics_material_override = material

    var shape_node := CollisionShape2D.new()
    var shape := CapsuleShape2D.new()
    shape.radius = pen_width * 0.5
    shape.height = pen_length
    shape_node.shape = shape
    shape_node.rotation = PI * 0.5
    add_child(shape_node)
    queue_redraw()

func launch(direction: Vector2, strength: float) -> void:
    sleeping = false
    apply_central_impulse(direction.normalized() * strength)
    apply_torque_impulse(direction.angle() * strength * 0.006)

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

func _rounded_box(color: Color, radius: float) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.corner_radius_top_left = int(radius)
    box.corner_radius_top_right = int(radius)
    box.corner_radius_bottom_left = int(radius)
    box.corner_radius_bottom_right = int(radius)
    return box
