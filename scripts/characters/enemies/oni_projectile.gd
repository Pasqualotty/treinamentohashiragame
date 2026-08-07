extends Area2D
## Projétil de oni à distância (usado por `oni_ranged`). Voo reto sem gravidade.
## Desenho procedural via `_draw()` — sem depender de asset novo.
## Causa dano via Hitbox filha; se autodestrói ao acertar uma Hurtbox, bater em
## parede/chão (`body_entered`) ou esgotar alcance/tempo de vida.
## NOVO — não edita nenhuma cena/script existente.

@export var direction: float = -1.0
@export var speed: float = 340.0
@export var max_range: float = 620.0
@export var lifetime: float = 2.5
@export var proj_damage: int = 6
@export var proj_knockback: Vector2 = Vector2(120.0, -30.0)
@export var core_color: Color = Color(0.55, 0.82, 1.55, 1.0)

var _traveled: float = 0.0
var _spent: bool = false
var _t: float = 0.0

@onready var hitbox: Hitbox = %Hitbox


func _ready() -> void:
	add_to_group("enemy_projectile")
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1 # mundo (chão/paredes) — soma ao colidir
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_apply_setup()
	var tree: SceneTree = get_tree()
	if tree:
		await tree.create_timer(lifetime).timeout
		if is_instance_valid(self) and not _spent:
			queue_free()


## Chamado pelo spawner (oni_ranged) logo após add_child — reconfigura em runtime.
func setup(dir: float, dmg: int, knockback: Vector2, spd: float) -> void:
	if not is_zero_approx(dir):
		direction = signf(dir)
	proj_damage = dmg
	proj_knockback = knockback
	speed = spd
	_apply_setup()


func _apply_setup() -> void:
	if hitbox:
		hitbox.team = &"enemy"
		hitbox.damage = proj_damage
		hitbox.knockback = Vector2(absf(proj_knockback.x) * direction, proj_knockback.y)
		if not hitbox.hit.is_connected(_on_hitbox_hit):
			hitbox.hit.connect(_on_hitbox_hit)
		if not hitbox.is_active():
			hitbox.enable()


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var step: float = direction * speed * delta
	position.x += step
	_traveled += absf(step)
	if _traveled >= max_range:
		_impact()


func _process(delta: float) -> void:
	if _spent:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _spent:
		return
	var pulse: float = 0.85 + 0.15 * absf(sin(_t * 18.0))
	draw_circle(Vector2.ZERO, 9.0 * pulse, Color(core_color.r, core_color.g, core_color.b, 0.35))
	draw_circle(Vector2.ZERO, 5.0 * pulse, Color(minf(core_color.r * 1.3, 2.0), minf(core_color.g * 1.15, 2.0), minf(core_color.b * 1.1, 2.0), 0.95))


func _on_body_entered(_body: Node) -> void:
	_impact()


func _on_hitbox_hit(_hurtbox: Hurtbox, _hit_data: HitData) -> void:
	_impact()


func _impact() -> void:
	if _spent:
		return
	_spent = true
	set_physics_process(false)
	set_process(false)
	if hitbox:
		hitbox.disable()
	monitoring = false
	queue_free()
