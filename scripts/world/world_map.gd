extends Control
## Mapa do mundo W1 — escolhe fase (3 + boss).
## IDs cleared: w1_01, w1_02, w1_03, w1_boss

const STAGE_W1_01 := "res://scenes/battle/stage_w1_01.tscn"
const STAGE_W1_02 := "res://scenes/battle/stage_w1_02.tscn"
const STAGE_W1_03 := "res://scenes/battle/stage_w1_03.tscn"
const STAGE_W1_BOSS := "res://scenes/battle/stage_w1_boss.tscn"

const ID_STAGE_1 := "w1_01"
const ID_STAGE_2 := "w1_02"
const ID_STAGE_3 := "w1_03"
const ID_BOSS := "w1_boss"

@onready var status_label: Label = %StatusLabel
@onready var stage1_btn: Button = $Stages/Stage1
@onready var stage2_btn: Button = $Stages/Stage2
@onready var stage3_btn: Button = $Stages/Stage3
@onready var boss_btn: Button = $Stages/Boss


func _ready() -> void:
	_refresh_stage_buttons()


func _refresh_stage_buttons() -> void:
	_apply_cleared_label(stage1_btn, "Fase 1", ID_STAGE_1)
	_apply_cleared_label(stage2_btn, "Fase 2", ID_STAGE_2)
	_apply_cleared_label(stage3_btn, "Fase 3", ID_STAGE_3)

	var boss_unlocked := _is_boss_unlocked()
	boss_btn.disabled = not boss_unlocked
	var boss_label := "Boss"
	if Game.is_stage_cleared(ID_BOSS):
		boss_label = "Boss ✓"
	elif not boss_unlocked:
		boss_label = "Boss 🔒"
	boss_btn.text = boss_label

	if boss_unlocked:
		status_label.text = "Mundo 1 — escolha uma fase (boss liberado)"
	else:
		status_label.text = "Mundo 1 — limpe as 3 fases para liberar o boss"


func _apply_cleared_label(btn: Button, base: String, stage_id: String) -> void:
	if btn == null:
		return
	if Game.is_stage_cleared(stage_id):
		btn.text = "%s ✓" % base
	else:
		btn.text = base


func _is_boss_unlocked() -> bool:
	return (
		Game.is_stage_cleared(ID_STAGE_1)
		and Game.is_stage_cleared(ID_STAGE_2)
		and Game.is_stage_cleared(ID_STAGE_3)
	)


func _on_back_pressed() -> void:
	SceneRouter.to_hub()


func _on_stage_1_pressed() -> void:
	status_label.text = "Entrando na Fase 1…"
	SceneRouter.go_to(STAGE_W1_01)


func _on_stage_2_pressed() -> void:
	status_label.text = "Entrando na Fase 2…"
	SceneRouter.go_to(STAGE_W1_02)


func _on_stage_3_pressed() -> void:
	status_label.text = "Entrando na Fase 3…"
	SceneRouter.go_to(STAGE_W1_03)


func _on_boss_pressed() -> void:
	if not _is_boss_unlocked():
		status_label.text = "Boss bloqueado — complete Fase 1, 2 e 3"
		return
	status_label.text = "Entrando no Boss…"
	SceneRouter.go_to(STAGE_W1_BOSS)
