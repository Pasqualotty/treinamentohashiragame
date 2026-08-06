extends Control
## Tela de creditos / aviso fan game.


func _ready() -> void:
	var back := get_node_or_null("Back") as Button
	if back and not back.pressed.is_connected(_on_back):
		back.pressed.connect(_on_back)


func _on_back() -> void:
	SceneRouter.to_hub()
