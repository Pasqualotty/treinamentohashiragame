extends CharacterBody2D
## DEPRECATED — player de combate legado.
## Use o player canônico unificado:
##   scenes/characters/player/player.tscn
##   scripts/characters/player.gd
##
## Este script permanece só para não quebrar referências antigas em diffs/docs.
## Sandboxes apontam para o player canônico. Não estenda este arquivo.

const CANONICAL_SCENE := "res://scenes/characters/player/player.tscn"
const CANONICAL_SCRIPT := "res://scripts/characters/player.gd"


func _ready() -> void:
	push_warning(
		"player_combat.gd está deprecado. Use %s (%s)." % [CANONICAL_SCENE, CANONICAL_SCRIPT]
	)
