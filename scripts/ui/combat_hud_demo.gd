extends Control
## Sandbox mínimo: só testa o CombatHud (HP / breath / moedas da run).
## Abrir no editor: F6 com esta cena como main, ou Scene → Run Current Scene.

@onready var combat_hud: CanvasLayer = $CombatHud
@onready var status: Label = %StatusLabel


func _ready() -> void:
	# Estado limpo de run para a demo (não mexe em coins_banked / save).
	Game.lose_run_coins()
	Game.breath = 0.0
	Game.breath_changed.emit(Game.breath, Game.breath_max)
	if combat_hud.has_method("set_hp"):
		combat_hud.set_hp(100.0, 100.0)
	_set_status("Demo HUD — use os botões. Escopo: só UI, sem combate real.")


func _on_dmg_pressed() -> void:
	if not combat_hud.has_method("set_hp"):
		return
	var hp: float = combat_hud.get_hp()
	var mx: float = combat_hud.get_hp_max()
	combat_hud.set_hp(hp - 10.0, mx)
	_set_status("HP -10 → %.0f / %.0f" % [combat_hud.get_hp(), mx])


func _on_heal_pressed() -> void:
	if not combat_hud.has_method("set_hp"):
		return
	var hp: float = combat_hud.get_hp()
	var mx: float = combat_hud.get_hp_max()
	combat_hud.set_hp(hp + 15.0, mx)
	_set_status("HP +15 → %.0f / %.0f" % [combat_hud.get_hp(), mx])


func _on_breath_pressed() -> void:
	Game.add_breath_from_hit(10.0)
	_set_status("Breath +10 → %.0f / %.0f" % [Game.breath, Game.breath_max])


func _on_ult_pressed() -> void:
	if Game.is_ultimate_ready():
		Game.consume_ultimate()
		_set_status("Ultimate consumida.")
	else:
		Game.breath = Game.breath_max
		Game.breath_changed.emit(Game.breath, Game.breath_max)
		_set_status("Breath cheia (ULT pronta).")


func _on_coins_pressed() -> void:
	Game.add_run_coins(5)
	_set_status("Moedas da run +5 → %d" % Game.coins_run)


func _on_reset_pressed() -> void:
	Game.lose_run_coins()
	Game.breath = 0.0
	Game.breath_changed.emit(Game.breath, Game.breath_max)
	if combat_hud.has_method("set_hp"):
		combat_hud.set_hp(100.0, 100.0)
	_set_status("Reset demo.")


func _set_status(msg: String) -> void:
	status.text = msg
