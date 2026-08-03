extends Control
## Estado padrão (hub estilo Brawl): personagem centro, laterais, JOGAR → mapa.

@onready var coins_label: Label = %CoinsLabel
@onready var character_name: Label = %CharacterName


func _ready() -> void:
	_refresh()
	if not Game.coins_changed.is_connected(_on_coins_changed):
		Game.coins_changed.connect(_on_coins_changed)


func _refresh() -> void:
	coins_label.text = "🪙 %d" % Game.coins_banked
	character_name.text = "Tanjiro"  # MVP


func _on_coins_changed(_total: int) -> void:
	_refresh()


func _on_play_pressed() -> void:
	# JOGAR → mapa do mundo (decisão A)
	SceneRouter.to_world_map()


func _on_shop_pressed() -> void:
	# Stub loja — fase D
	pass


func _on_characters_pressed() -> void:
	# Stub select — MVP só Tanjiro
	pass


func _on_settings_pressed() -> void:
	pass
