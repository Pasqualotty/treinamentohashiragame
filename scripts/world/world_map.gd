extends Control
## Mapa do mundo W1 — escolhe fase (3 + boss).

@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	status_label.text = "Mundo 1 — escolha uma fase"


func _on_back_pressed() -> void:
	SceneRouter.to_hub()


func _on_stage_1_pressed() -> void:
	status_label.text = "Fase 1 — (cena de combate em breve)"
	# SceneRouter.go_to("res://scenes/battle/stage_w1_01.tscn")


func _on_stage_2_pressed() -> void:
	status_label.text = "Fase 2 — (cena de combate em breve)"


func _on_stage_3_pressed() -> void:
	status_label.text = "Fase 3 — (cena de combate em breve)"


func _on_boss_pressed() -> void:
	status_label.text = "Boss — bloqueado até limpar as 3 fases (stub)"
