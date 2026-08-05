class_name UpgradeDef
extends Resource
## Definição de um upgrade da loja (HP, dano, velocidade, dash CD, etc.).

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var max_level: int = 3
## Custo por nível a comprar (índice 0 = 1º nível). Ex.: [30, 60, 120]
@export var costs: Array[int] = [30, 60, 120]
## Chave em PlayerStats: max_hp | attack_damage | move_speed | dash_cooldown
@export var stat_key: String = ""
@export var value_per_level: float = 0.0


func cost_for_next_level(current_level: int) -> int:
	if current_level < 0 or current_level >= max_level:
		return -1
	if current_level >= costs.size():
		return -1
	return costs[current_level]


func is_maxed(current_level: int) -> bool:
	return current_level >= max_level
