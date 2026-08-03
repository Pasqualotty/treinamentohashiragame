extends Control
## Splash da marca Pasqualotti → loading do jogo.

@export var hold_seconds: float = 2.2
@onready var logo: TextureRect = %Logo


func _ready() -> void:
	var path := "res://assets/branding/pasqualotti-studio-logo.png"
	if ResourceLoader.exists(path):
		logo.texture = load(path) as Texture2D
	# Som da marca quando existir: AudioStreamPlayer
	await get_tree().create_timer(hold_seconds).timeout
	SceneRouter.to_loading()
