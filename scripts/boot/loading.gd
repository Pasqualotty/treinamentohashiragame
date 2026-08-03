extends Control
## Loading com barra; depois → hub (estado padrão).

@onready var bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel

var _progress: float = 0.0


func _ready() -> void:
	bar.value = 0.0
	status_label.text = "Carregando…"
	# Simula carga real + piso mínimo de tempo (não piscar a tela).
	await _run_load()
	SceneRouter.to_hub()


func _run_load() -> void:
	var steps := [
		"Preparando o dojo…",
		"Carregando personagem…",
		"Quase lá…",
	]
	var i := 0
	while _progress < 100.0:
		_progress = minf(_progress + randf_range(8.0, 18.0), 100.0)
		bar.value = _progress
		if i < steps.size() and _progress > (i + 1) * 30.0:
			status_label.text = steps[i]
			i += 1
		await get_tree().create_timer(0.12).timeout
	status_label.text = "Pronto!"
	await get_tree().create_timer(0.25).timeout
