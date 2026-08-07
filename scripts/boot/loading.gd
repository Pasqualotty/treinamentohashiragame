extends Control
## Loading com barra; depois → hub (estado padrão).

@onready var bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel
@onready var keyart: TextureRect = get_node_or_null("%KeyArt") as TextureRect
@onready var tip_label: Label = get_node_or_null("%TipLabel") as Label

var _progress: float = 0.0
var _tip_i: int = 0
var _tip_timer: float = 0.0

const KEYART_PATH := "res://assets/ui/loading/keyart_w1.png"
const TIP_INTERVAL := 2.2
const TIPS: Array[String] = [
	"Dica: o dash tem cooldown — cronometre antes de atravessar o boss.",
	"Dica: respiração cheia libera o ULT — acerte hits para enchê-la.",
	"Dica: fases limpas ficam marcadas no mapa do mundo.",
	"Dica: gaste moedas banked na loja entre fases para evoluir o Tanjiro.",
]


func _ready() -> void:
	# Textura já vem no .tscn; reforça em runtime se sumir
	if keyart:
		if keyart.texture == null and ResourceLoader.exists(KEYART_PATH):
			keyart.texture = load(KEYART_PATH) as Texture2D
		if keyart.texture == null:
			push_warning("Loading: keyart não carregou (%s)" % KEYART_PATH)
	bar.value = 0.0
	status_label.text = "Carregando…"
	await _run_load()
	SceneRouter.to_hub()


func _run_load() -> void:
	var steps := [
		"Preparando o dojo…",
		"Carregando personagem…",
		"Quase lá…",
	]
	var i := 0
	if tip_label and TIPS.size() > 0:
		_tip_i = randi() % TIPS.size()
		tip_label.text = TIPS[_tip_i]
	while _progress < 100.0:
		_progress = minf(_progress + randf_range(8.0, 18.0), 100.0)
		bar.value = _progress
		if i < steps.size() and _progress > (i + 1) * 30.0:
			status_label.text = steps[i]
			i += 1
		_tip_timer += 0.12
		if tip_label and TIPS.size() > 1 and _tip_timer >= TIP_INTERVAL:
			_tip_timer = 0.0
			_tip_i = (_tip_i + 1) % TIPS.size()
			tip_label.text = TIPS[_tip_i]
		await get_tree().create_timer(0.12).timeout
	status_label.text = "Pronto!"
	await get_tree().create_timer(0.25).timeout
