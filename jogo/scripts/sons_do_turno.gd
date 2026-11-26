extends Node

const INTERVALO_MIN_MURMURIO := 10.0
const INTERVALO_MAX_MURMURIO := 20.0
const FADE_MURMURIO := 0.65

# Mesmos IDs de FEMALE_CHARACTER_IDS em documentos/gerar.py.
const PERSONAGENS_FEMININAS := [
	"01", "02", "04", "05", "07", "08", "17", "19", "21", "24", "25",
	"28", "30", "33", "35", "37", "39", "41", "43", "45", "47",
]

# Os recortes são em segundos. Ajuste inicio e duracao sem alterar o áudio original.
const EFEITOS := {
	&"microfone": {
		"audio": preload("res://assets/sfx/chiado_mic_proximo.wav"),
		"inicio": 0.28, "duracao": 0.30, "volume_db": -10.0,
	},
	&"sino": {
		"audio": preload("res://assets/sfx/sino_proximo.mp3"),
		"inicio": 3.68, "duracao": 1.1, "volume_db": -12.0,
	},
	&"papel_deslizar": {
		"audio": preload("res://assets/sfx/docs_deslizar.wav"),
		"inicio": 0.0, "duracao": 0.55, "volume_db": 3.0,
	},
	&"documento_abrir": {
		"audio": preload("res://assets/sfx/docs_abrir_fechar.wav"),
		"inicio": 0.16, "duracao": 0.32, "volume_db": -7.0,
	},
	&"documento_fechar": {
		"audio": preload("res://assets/sfx/docs_abrir_fechar.wav"),
		"inicio": 2.90, "duracao": 0.40, "volume_db": -7.0,
	},
	&"gaveta_abrir": {
		"audio": preload("res://assets/sfx/gaveta_abrir_fechar.wav"),
		"inicio": 0.0, "duracao": 1.0, "volume_db": -12.0,
	},
	&"gaveta_fechar": {
		"audio": preload("res://assets/sfx/gaveta_abrir_fechar.wav"),
		"inicio": 1.10, "duracao": 1.15, "volume_db": -12.0,
	},
	&"carimbo": {
		"audio": preload("res://assets/sfx/carimbo.wav"),
		"inicio": 0.48, "duracao": 0.45, "volume_db": -7.0,
	},
	&"decisao_incorreta": {
		"audio": preload("res://assets/sfx/decisao_incorreta.mp3"),
		"inicio": 0.0, "duracao": 0.45, "volume_db": -18.0,
	},
	&"alivio_femi": {
		"audio": preload("res://assets/sfx/alivio_femi.wav"),
		"inicio": 0.66, "duracao": 0.95, "volume_db": -12.0,
	},
	&"alivio_masc": {
		"audio": preload("res://assets/sfx/alivio_masc.wav"),
		"inicio": 1.67, "duracao": 0.62, "volume_db": -9.0,
	},
	&"frustracao_femi": {
		"audio": preload("res://assets/sfx/frustracao_femi.mp3"),
		"inicio": 0.0, "duracao": 1.25, "volume_db": -12.0,
	},
	&"frustracao_masc": {
		"audio": preload("res://assets/sfx/frustracao_masc.wav"),
		"inicio": 0.0, "duracao": 1.25, "volume_db": -12.0,
	},
	&"murmurio": {
		"audio": preload("res://assets/sfx/murmurio_ambiente.wav"),
		"inicio": 12.0, "duracao": 8.0, "volume_db": -12.0,
	},
	&"resumo": {
		"audio": preload("res://assets/sfx/resumo_do_turno.wav"),
		"inicio": 0.0, "duracao": 0.99, "volume_db": -10.0,
	},
}

var reprodutores: Dictionary = {}
var cortes: Dictionary = {}
var timer_murmurio := Timer.new()
var sorteio_murmurio := RandomNumberGenerator.new()

@export var murmurio_ativo := true


func _ready() -> void:
	timer_murmurio.one_shot = true
	timer_murmurio.timeout.connect(_tocar_murmurio)
	add_child(timer_murmurio)
	if murmurio_ativo:
		_agendar_murmurio()


func tocar(efeito: StringName) -> Tween:
	return _tocar_sequencia(efeito)


func chamar_proximo() -> void:
	_tocar_sequencia(&"microfone", &"sino")


func tocar_reacao(aprovado: bool, personagem_id: String) -> void:
	var id := personagem_id.to_lower().trim_prefix("personagem_")
	if id.is_valid_int():
		id = "%02d" % id.to_int()
	var emocao := "alivio" if aprovado else "frustracao"
	var voz := "femi" if id in PERSONAGENS_FEMININAS else "masc"
	tocar(StringName(emocao + "_" + voz))


func encerrar_ambiente() -> void:
	timer_murmurio.stop()
	var corte: Tween = cortes.get(&"murmurio")
	if corte:
		corte.kill()
	var reprodutor: AudioStreamPlayer = reprodutores.get(&"murmurio")
	if reprodutor and reprodutor.playing:
		var fade := create_tween()
		fade.tween_property(reprodutor, "volume_db", -60.0, FADE_MURMURIO)
		fade.tween_callback(reprodutor.stop)


func _tocar_sequencia(efeito: StringName, seguinte: StringName = &"") -> Tween:
	var reprodutor: AudioStreamPlayer = reprodutores.get(efeito)
	if reprodutor == null:
		reprodutor = AudioStreamPlayer.new()
		add_child(reprodutor)
		reprodutores[efeito] = reprodutor

	var corte_anterior: Tween = cortes.get(efeito)
	if corte_anterior:
		corte_anterior.kill()

	_reproduzir(reprodutor, efeito)
	var corte := create_tween()
	cortes[efeito] = corte
	_agendar_fim(corte, reprodutor, efeito)
	if seguinte != &"":
		corte.tween_callback(_reproduzir.bind(reprodutor, seguinte))
		_agendar_fim(corte, reprodutor, seguinte)
	return corte


func _reproduzir(reprodutor: AudioStreamPlayer, efeito: StringName) -> void:
	var dados: Dictionary = EFEITOS[efeito]
	var audio: AudioStream = dados["audio"]
	reprodutor.stream = audio
	reprodutor.volume_db = -60.0 if efeito == &"murmurio" else float(dados["volume_db"])
	reprodutor.play(_inicio_do_trecho(dados, audio.get_length()))


func _inicio_do_trecho(dados: Dictionary, tamanho: float) -> float:
	var inicio := maxf(0.0, float(dados["inicio"]))
	return inicio if inicio < tamanho else 0.0


func _agendar_fim(corte: Tween, reprodutor: AudioStreamPlayer, efeito: StringName) -> void:
	var dados: Dictionary = EFEITOS[efeito]
	var audio: AudioStream = dados["audio"]
	var tamanho := audio.get_length()
	var inicio := _inicio_do_trecho(dados, tamanho)
	var duracao := clampf(float(dados["duracao"]), 0.01, maxf(0.01, tamanho - inicio))
	if efeito == &"murmurio":
		var fade := minf(FADE_MURMURIO, duracao * 0.5)
		corte.tween_property(reprodutor, "volume_db", float(dados["volume_db"]), fade)
		if duracao > fade * 2.0:
			corte.tween_interval(duracao - fade * 2.0)
		corte.tween_property(reprodutor, "volume_db", -60.0, fade)
	else:
		corte.tween_interval(duracao)
	corte.tween_callback(reprodutor.stop)


func _agendar_murmurio() -> void:
	timer_murmurio.start(sorteio_murmurio.randf_range(INTERVALO_MIN_MURMURIO, INTERVALO_MAX_MURMURIO))


func _tocar_murmurio() -> void:
	_tocar_sequencia(&"murmurio").tween_callback(_agendar_murmurio)
