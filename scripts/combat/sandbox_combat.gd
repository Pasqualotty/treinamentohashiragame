extends Node2D
## Sandbox de combate: player canônico + dummy.
## Controles documentados no Label da cena e no header de player.gd.


func _ready() -> void:
	print("[SandboxCombat] player unificado + dummy")
	print("  A/D move · Espaço pulo · Shift/F dash")
	print("  Z/J attack_basic · X/K skill_1 (Corte em Arco) · C/L skill_2 (Investida)")
	print("  V/I ultimate (requer breath full) · R reload se dead")
	var player: Node = get_node_or_null("Player")
	if player and player.has_signal("died"):
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
	if player and player.has_signal("hp_changed"):
		if not player.hp_changed.is_connected(_on_player_hp):
			player.hp_changed.connect(_on_player_hp)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event as InputEventKey
		if key.physical_keycode == KEY_R:
			get_tree().reload_current_scene()


func _on_player_died() -> void:
	print("[SandboxCombat] player dead — pressione R para reiniciar")


func _on_player_hp(current: int, max_hp: int) -> void:
	print("[SandboxCombat] player HP %d/%d" % [current, max_hp])
