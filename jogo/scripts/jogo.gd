extends Control

const CENA_DOCUMENTO := preload("res://scenes/documento.tscn")
const SCRIPT_BONEQUINHO := preload("res://scripts/bonequinho_fila.gd")
const CANDIDATOS_POR_TURNO := 5
const DICAS_DOCUMENTOS := {
	"rg": "Abra a identidade com dois cliques. Compare a foto com o rosto no guichê e confira a validade.",
	"ficha": "Abra a ficha e compare o nome com o da identidade.",
	"vestibular": "Abra a convocação. Compare o curso com a ficha e confira a nota de corte.",
	"historico": "Abra o histórico. Confira a conclusão do ensino médio e o carimbo oficial.",
}

@onready var fila_externa: Control = $FilaExterna
@onready var janela_guiche: Control = $Janela
@onready var pessoa_sprite: TextureRect = $Janela/Pessoa
@onready var fala_candidato: Label = $Janela/FalaCandidato
@onready var area_documentos: Control = $AreaDocumentos
@onready var btn_proximo: Button = $BtnProximo
@onready var painel_decisao: VBoxContainer = $PainelDecisao
@onready var btn_aprovar: Button = $PainelDecisao/Botoes/Aprovar
@onready var btn_reprovar: Button = $PainelDecisao/Botoes/Reprovar
@onready var resultado_decisao: Label = $PainelDecisao/Resultado
@onready var btn_manual: Button = $PainelTurno/Cabecalho/Manual
@onready var progresso_turno: Label = $PainelTurno/Cabecalho/Progresso
@onready var dica_turno: Label = $PainelTurno/Dica
@onready var sobreposicao = $SobreposicaoTurno

## Quantidade de bonequinhos visíveis na fila lá fora
@export var tamanho_fila: int = 10
## Posição proporcional (0.0 a 1.0 da tela) onde os documentos do candidato pousam no balcão
@export var pos_bandeja_relativa: Vector2 = Vector2(0.08, 0.72)
## Posição proporcional (0.0 a 1.0 da tela) da fresta por onde os documentos saem
@export var pos_fresta_relativa: Vector2 = Vector2(0.11, 0.65)
## Posição proporcional (0.0 a 1.0 da tela) onde a Ficha de Requerimento aparece na mesa
@export var pos_ficha_relativa: Vector2 = Vector2(0.66, 0.36)

var em_transicao: bool = true
var tem_candidato_no_guiche: bool = false
var decisao_registrada: bool = false
var ficha_atual: TextureRect
var bonecos_fila: Array[Control] = []
var atendidos: int = 0
var avaliados: int = 0
var acertos: int = 0
var documentos_consultados: Dictionary = {}

## Lista dinâmica com todos os personagens (01 a 48) descobertos na pasta assets/personagens
var todos_personagens: Array[String] = []
var baralho_personagens: Array[String] = []
var candidato_atual_id: String = ""
var dados_candidato_atual: Dictionary = {}

## Sistema de Pré-carregamento em Background (Fila de Buffer)
var fila_prontos: Array[Dictionary] = []
var gerando_em_background: bool = false
var slot_buffer_indice: int = 0
var aguardando_buffer_para_entrar: bool = false
var candidatos_preparados: int = 0


func _ready() -> void:
	randomize()
	btn_aprovar.pressed.connect(_registrar_decisao.bind(true))
	btn_reprovar.pressed.connect(_registrar_decisao.bind(false))
	btn_manual.pressed.connect(sobreposicao.mostrar_manual)
	sobreposicao.reinicio_solicitado.connect(func(): get_tree().reload_current_scene())
	sobreposicao.menu_solicitado.connect(func(): get_tree().change_scene_to_file("res://scenes/inicio.tscn"))
	progresso_turno.text = "Atendidos 0/%d" % CANDIDATOS_POR_TURNO
	dica_turno.text = "Clique em Próximo para chamar o primeiro candidato."
	pessoa_sprite.visible = false
	pessoa_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_descobrir_personagens()
	
	# Assim que o jogo inicia, já dispara o pré-carregamento da 1ª pessoa em background sem travar nada!
	_disparar_precarregamento_background()
	
	await get_tree().process_frame
	_inicializar_fila_externa()
	em_transicao = false
	btn_proximo.disabled = false


func _descobrir_personagens() -> void:
	todos_personagens.clear()
	var dir := DirAccess.open("res://assets/personagens")
	if dir:
		dir.list_dir_begin()
		var nome_pasta := dir.get_next()
		while nome_pasta != "":
			if dir.current_is_dir() and not nome_pasta.begins_with("."):
				if FileAccess.file_exists("res://assets/personagens/" + nome_pasta + "/sprite_01.png"):
					todos_personagens.append(nome_pasta)
			nome_pasta = dir.get_next()
		dir.list_dir_end()
	todos_personagens.sort()
	_reembaralhar_personagens()


func _reembaralhar_personagens() -> void:
	baralho_personagens = todos_personagens.duplicate()
	baralho_personagens.shuffle()


func _sortear_proximo_personagem() -> String:
	if baralho_personagens.is_empty():
		_reembaralhar_personagens()
	if baralho_personagens.is_empty():
		return "01"
	return baralho_personagens.pop_back()


## Dispara a geração procedural de um candidato em uma thread separada do WorkerThreadPool
func _disparar_precarregamento_background() -> void:
	if gerando_em_background or fila_prontos.size() >= 2 or candidatos_preparados >= CANDIDATOS_POR_TURNO:
		return
	
	gerando_em_background = true
	candidatos_preparados += 1
	var id_sorteado := _sortear_proximo_personagem()
	slot_buffer_indice = (slot_buffer_indice + 1) % 4
	
	var dir_projeto := ProjectSettings.globalize_path("res://")
	var dir_documentos := dir_projeto.path_join("../documentos").simplify_path()
	var script_gerar := dir_documentos.path_join("gerar.py")
	var slot := "slot_%d" % slot_buffer_indice
	var pasta_saida := ProjectSettings.globalize_path("user://documentos/" + slot)
	var pasta_exemplo := dir_projeto.path_join("assets/documentos_exemplo/" + slot)
	
	WorkerThreadPool.add_task(_tarefa_gerar_candidato_thread.bind(id_sorteado, script_gerar, pasta_saida, pasta_exemplo))


func _tarefa_gerar_candidato_thread(id_char: String, script_gerar: String, pasta_saida: String, pasta_exemplo: String) -> void:
	var pasta_documentos := pasta_exemplo
	if FileAccess.file_exists(script_gerar):
		var saida := []
		var python := "python" if OS.get_name() == "Windows" else "python3"
		var codigo := OS.execute(python, ["-X", "utf8", script_gerar, id_char, "--output", pasta_saida], saida, true)
		if codigo == 0:
			pasta_documentos = pasta_saida
	
	# Lê as 4 imagens PNG e o JSON diretamente na thread de background (Image é thread-safe!)
	var img_rg := Image.new()
	var img_vest := Image.new()
	var img_hist := Image.new()
	var img_ficha := Image.new()
	
	img_rg.load(pasta_documentos.path_join("1_documento_identidade.png"))
	img_vest.load(pasta_documentos.path_join("2_convocacao_vestibular.png"))
	img_hist.load(pasta_documentos.path_join("3_historico_ensino_medio.png"))
	img_ficha.load(pasta_documentos.path_join("4_ficha_requerimento.png"))
	
	var dados_json: Dictionary = {}
	var json_path := pasta_documentos.path_join("dados_candidato.json")
	if FileAccess.file_exists(json_path):
		var texto := FileAccess.get_file_as_string(json_path)
		var parsed = JSON.parse_string(texto)
		if parsed is Dictionary:
			dados_json = parsed
	
	var pacote := {
		"id": String(dados_json.get("personagem_id", id_char)),
		"dados": dados_json,
		"img_rg": img_rg,
		"img_vest": img_vest,
		"img_hist": img_hist,
		"img_ficha": img_ficha,
	}
	
	call_deferred("_ao_terminar_precarregamento", pacote)


func _ao_terminar_precarregamento(pacote: Dictionary) -> void:
	gerando_em_background = false
	
	# Converte os objetos Image em ImageTexture na main thread (instantâneo, < 1ms)
	pacote["tex_rg"] = ImageTexture.create_from_image(pacote["img_rg"]) if not pacote["img_rg"].is_empty() else null
	pacote["tex_vest"] = ImageTexture.create_from_image(pacote["img_vest"]) if not pacote["img_vest"].is_empty() else null
	pacote["tex_hist"] = ImageTexture.create_from_image(pacote["img_hist"]) if not pacote["img_hist"].is_empty() else null
	pacote["tex_ficha"] = ImageTexture.create_from_image(pacote["img_ficha"]) if not pacote["img_ficha"].is_empty() else null
	
	fila_prontos.append(pacote)
	
	# Se o jogador clicou muito rápido antes do buffer terminar, exibe o candidato imediatamente agora
	if aguardando_buffer_para_entrar:
		aguardando_buffer_para_entrar = false
		_mostrar_candidato_do_buffer()
	elif fila_prontos.size() < 2:
		# Mantém sempre até 2 candidatos prontos no buffer em background
		_disparar_precarregamento_background()


func _obter_posicao_slot_fila(indice: int) -> Vector2:
	var tela := get_viewport_rect().size
	var base_x := tela.x * 0.42
	var base_y := tela.y * 0.20
	var espacamento_x := tela.x * 0.043
	var variacao_y := float((indice % 2) * 3 - 1)
	return Vector2(base_x - (indice * espacamento_x), base_y + variacao_y)


func _criar_bonequinho() -> Control:
	var b := Control.new()
	b.set_script(SCRIPT_BONEQUINHO)
	var fator := clampf(get_viewport_rect().size.x / 1152.0, 1.0, 2.0)
	b.scale = Vector2(fator, fator)
	fila_externa.add_child(b)
	return b


func _inicializar_fila_externa() -> void:
	for b in bonecos_fila:
		if is_instance_valid(b):
			b.queue_free()
	bonecos_fila.clear()
	
	for i in range(mini(tamanho_fila, CANDIDATOS_POR_TURNO)):
		var b := _criar_bonequinho()
		b.position = _obter_posicao_slot_fila(i)
		bonecos_fila.append(b)


func _on_btn_proximo_pressed() -> void:
	chamar_proximo_candidato()


func chamar_proximo_candidato() -> void:
	if em_transicao or sobreposicao.visible or (tem_candidato_no_guiche and not decisao_registrada):
		return

	em_transicao = true
	btn_proximo.disabled = true
	painel_decisao.hide()
	dica_turno.hide()
	
	if tem_candidato_no_guiche:
		_recolher_documentos_e_sair_candidato()
	else:
		_avancar_fila_e_entrar_novo()


func _registrar_decisao(aprovado: bool) -> void:
	if em_transicao or sobreposicao.visible or not tem_candidato_no_guiche or decisao_registrada:
		return

	decisao_registrada = true
	atendidos += 1
	progresso_turno.text = "Atendidos %d/%d" % [atendidos, CANDIDATOS_POR_TURNO]
	dica_turno.hide()
	btn_aprovar.disabled = true
	btn_reprovar.disabled = true
	if is_instance_valid(ficha_atual):
		ficha_atual.carimbar(aprovado)
		ficha_atual.move_to_front()
	_animar_reacao_candidato(aprovado)

	var resultado := "Matrícula aprovada" if aprovado else "Matrícula reprovada"
	var tem_fraude: Variant = dados_candidato_atual.get("tem_fraude")
	if tem_fraude is bool:
		avaliados += 1
		var decisao_correta: bool = aprovado != tem_fraude
		if decisao_correta:
			acertos += 1
		var motivo := "Documentação regular."
		if tem_fraude:
			motivo = String(dados_candidato_atual.get("descricao_fraude", "")).strip_edges()
			if motivo.is_empty():
				motivo = "A documentação tem uma irregularidade."
		resultado += "\n%s\n%s" % ["Decisão correta" if decisao_correta else "Decisão incorreta", motivo]
	else:
		resultado += "\nCaso sem avaliação."
	resultado_decisao.text = resultado
	resultado_decisao.show()


func _animar_reacao_candidato(aprovado: bool) -> void:
	em_transicao = true
	definir_expressao_candidato(2)
	fala_candidato.text = "Consegui! Que alívio!" if aprovado else "Como assim? Tem certeza?"
	fala_candidato.modulate.a = 0.0
	fala_candidato.show()

	var repouso := pessoa_sprite.position
	pessoa_sprite.pivot_offset = pessoa_sprite.size * Vector2(0.5, 0.9)
	var reacao := create_tween()
	reacao.tween_property(fala_candidato, "modulate:a", 1.0, 0.16)
	if aprovado:
		var altura_salto := janela_guiche.size.y * 0.08
		reacao.parallel().tween_property(pessoa_sprite, "position:y", repouso.y - altura_salto, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reacao.tween_callback(definir_expressao_candidato.bind(1))
		reacao.tween_property(pessoa_sprite, "position:y", repouso.y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		var recuo := janela_guiche.size.x * 0.06
		reacao.parallel().tween_property(pessoa_sprite, "position:x", repouso.x - recuo, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reacao.parallel().tween_property(pessoa_sprite, "rotation", -0.12, 0.18)
		reacao.tween_callback(definir_expressao_candidato.bind(3))
		reacao.tween_property(pessoa_sprite, "position:x", repouso.x, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		reacao.parallel().tween_property(pessoa_sprite, "rotation", 0.0, 0.24)
	reacao.tween_interval(0.35)
	reacao.tween_callback(func():
		em_transicao = false
		if atendidos == CANDIDATOS_POR_TURNO:
			btn_proximo.text = "RESUMO"
		btn_proximo.disabled = false
	)


func _recolher_documentos_e_sair_candidato() -> void:
	fala_candidato.hide()
	var tela := get_viewport_rect().size
	var pos_fresta := tela * pos_fresta_relativa
	
	for filho in area_documentos.get_children():
		filho.bloquear_interacao()
		var t_doc := create_tween()
		t_doc.tween_property(filho, "position", pos_fresta, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t_doc.parallel().tween_property(filho, "modulate:a", 0.0, 0.25)
		t_doc.tween_callback(filho.queue_free)
	
	var larg_janela := janela_guiche.size.x
	var alt_janela := janela_guiche.size.y
	var pos_saida_x := larg_janela + 30.0
	var pos_y_base := alt_janela * 0.05
	var duracao_saida := 0.55
	
	var tween_saida := create_tween()
	tween_saida.tween_property(pessoa_sprite, "position:x", pos_saida_x, duracao_saida).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	var tween_passos := create_tween()
	var tempo_passo := duracao_saida / 6.0
	for _p in range(3):
		tween_passos.tween_property(pessoa_sprite, "position:y", pos_y_base - 7.0, tempo_passo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween_passos.tween_property(pessoa_sprite, "position:y", pos_y_base, tempo_passo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	_animar_silhueta_saindo_linha_amarela()
	
	tween_saida.tween_callback(func():
		pessoa_sprite.visible = false
		tem_candidato_no_guiche = false
		if atendidos == CANDIDATOS_POR_TURNO:
			sobreposicao.mostrar_resumo(atendidos, acertos, avaliados)
		else:
			_avancar_fila_e_entrar_novo()
	)


func _animar_silhueta_saindo_linha_amarela() -> void:
	var tela := get_viewport_rect().size
	var b_saindo := _criar_bonequinho()
	b_saindo.position = Vector2(tela.x * 0.565, tela.y * 0.105)
	b_saindo.modulate.a = 0.0
	b_saindo.caminhando = true
	
	var t := create_tween()
	t.tween_property(b_saindo, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(b_saindo, "position", Vector2(tela.x * 0.580, tela.y * 0.210), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(b_saindo, "position", Vector2(tela.x * 0.820, tela.y * 0.220), 0.85).set_trans(Tween.TRANS_LINEAR)
	t.tween_property(b_saindo, "position", Vector2(tela.x * 0.915, tela.y * 0.165), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(b_saindo, "modulate:a", 0.0, 0.35).set_delay(0.1)
	t.tween_callback(b_saindo.queue_free)


func _avancar_fila_e_entrar_novo() -> void:
	var tela := get_viewport_rect().size
	
	if bonecos_fila.size() > 0:
		var primeiro: Control = bonecos_fila.pop_front()
		primeiro.caminhando = true
		var t_entrar := create_tween()
		t_entrar.tween_property(primeiro, "position", Vector2(tela.x * 0.515, tela.y * 0.195), 0.30).set_trans(Tween.TRANS_LINEAR)
		t_entrar.tween_property(primeiro, "position", Vector2(tela.x * 0.530, tela.y * 0.105), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t_entrar.parallel().tween_property(primeiro, "modulate:a", 0.0, 0.22).set_delay(0.06)
		t_entrar.tween_callback(primeiro.queue_free)
	
	if bonecos_fila.size() < mini(tamanho_fila, CANDIDATOS_POR_TURNO - atendidos - 1):
		var novo_boneco := _criar_bonequinho()
		novo_boneco.position = _obter_posicao_slot_fila(bonecos_fila.size())
		bonecos_fila.append(novo_boneco)
	
	for i in range(bonecos_fila.size()):
		var b: Control = bonecos_fila[i]
		var pos_alvo := _obter_posicao_slot_fila(i)
		var atraso := i * 0.04
		var t_fila := create_tween()
		if atraso > 0.0:
			t_fila.tween_interval(atraso)
		t_fila.tween_callback(func(): b.caminhando = true)
		t_fila.tween_property(b, "position", pos_alvo, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t_fila.tween_callback(func(): b.caminhando = false)
	
	var timer_entrada := get_tree().create_timer(0.48)
	timer_entrada.timeout.connect(_entrar_candidato_na_janela)


func _carregar_textura_png(caminho: String) -> Texture2D:
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(caminho))
	if err == OK:
		return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(caminho):
		return load(caminho) as Texture2D
	return null


## Permite mudar a expressão do candidato atual no guichê:
## 1 = Feliz (sprite_01), 2 = Surpreso/Assustado (sprite_02), 3 = Bravo (sprite_03)
func definir_expressao_candidato(numero_foto: int) -> void:
	if candidato_atual_id == "":
		return
	var nome_arquivo := "sprite_%02d.png" % clampi(numero_foto, 1, 3)
	var caminho := "res://assets/personagens/" + candidato_atual_id + "/" + nome_arquivo
	var tex := _carregar_textura_png(caminho)
	if tex:
		pessoa_sprite.texture = tex


func _entrar_candidato_na_janela() -> void:
	if fila_prontos.is_empty():
		# Caso o jogador tenha clicado nos primeiros milissegundos após abrir a cena, aguarda o thread terminar
		aguardando_buffer_para_entrar = true
		_disparar_precarregamento_background()
		return
	
	_mostrar_candidato_do_buffer()


func _mostrar_candidato_do_buffer() -> void:
	var pacote: Dictionary = fila_prontos.pop_front()
	candidato_atual_id = pacote["id"]
	dados_candidato_atual = pacote["dados"]
	tem_candidato_no_guiche = true
	decisao_registrada = false
	ficha_atual = null
	
	# Assim que a pessoa atual entra no guichê, já dispara em background o carregamento da próxima!
	_disparar_precarregamento_background()
	
	# Sempre entra feliz (foto 1: sprite_01.png)
	var caminho_feliz := "res://assets/personagens/" + candidato_atual_id + "/sprite_01.png"
	var tex_candidato := _carregar_textura_png(caminho_feliz)
	if tex_candidato:
		pessoa_sprite.texture = tex_candidato
		pessoa_sprite.visible = true
		
		var larg_janela := janela_guiche.size.x
		var alt_janela := janela_guiche.size.y
		var pos_final_x := larg_janela * 0.20
		var pos_final_y := alt_janela * 0.05
		var larg_pessoa := larg_janela * 0.60
		
		var pos_inicial_x := -larg_pessoa - 20.0
		pessoa_sprite.position = Vector2(pos_inicial_x, pos_final_y)
		
		var duracao_entrada := 0.65
		var tween_pessoa := create_tween()
		tween_pessoa.tween_property(pessoa_sprite, "position:x", pos_final_x, duracao_entrada).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		var tween_passos := create_tween()
		var tempo_passo := duracao_entrada / 6.0
		for _p in range(3):
			tween_passos.tween_property(pessoa_sprite, "position:y", pos_final_y - 7.0, tempo_passo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween_passos.tween_property(pessoa_sprite, "position:y", pos_final_y, tempo_passo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		tween_pessoa.tween_callback(_entregar_documentos.bind(pacote))
	else:
		_entregar_documentos(pacote)


func _entregar_documentos(pacote: Dictionary) -> void:
	var tela := get_viewport_rect().size
	var pos_fresta := tela * pos_fresta_relativa
	var pos_bandeja := tela * pos_bandeja_relativa
	var pos_ficha := tela * pos_ficha_relativa
	
	var docs_candidato := [
		{"tex": pacote.get("tex_rg"), "tipo": "rg"},
		{"tex": pacote.get("tex_vest"), "tipo": "vestibular"},
		{"tex": pacote.get("tex_hist"), "tipo": "historico"},
	]
	
	for i in range(docs_candidato.size()):
		var info: Dictionary = docs_candidato[i]
		var tex: Texture2D = info["tex"]
		if tex:
			var doc := CENA_DOCUMENTO.instantiate()
			area_documentos.add_child(doc)
			doc.ampliacao_solicitada.connect(_ampliar_documento)
			var desvio_destino := Vector2(i * 22.0, i * 6.0)
			doc.configurar(tex, info["tipo"], pos_fresta, false)
			doc.animar_chegada(pos_fresta, pos_bandeja + desvio_destino, i * 0.12, 0.35)
	
	var tex_ficha: Texture2D = pacote.get("tex_ficha")
	if tex_ficha:
		var doc_ficha := CENA_DOCUMENTO.instantiate()
		area_documentos.add_child(doc_ficha)
		doc_ficha.ampliacao_solicitada.connect(_ampliar_documento)
		ficha_atual = doc_ficha
		var origem_ficha := Vector2(pos_ficha.x, tela.y + 50.0)
		doc_ficha.configurar(tex_ficha, "ficha", origem_ficha, true)
		doc_ficha.animar_chegada(origem_ficha, pos_ficha, 0.15, 0.45)
	
	var timer := get_tree().create_timer(0.6)
	timer.timeout.connect(func():
		em_transicao = false
		resultado_decisao.hide()
		btn_aprovar.disabled = false
		btn_reprovar.disabled = false
		painel_decisao.show()
		if atendidos == 0:
			_atualizar_dica_primeiro_candidato()
	)


func _ampliar_documento(documento) -> void:
	if em_transicao or sobreposicao.visible:
		return

	sobreposicao.mostrar_documento(documento)
	if atendidos == 0:
		documentos_consultados[documento.tipo_documento] = true
		_atualizar_dica_primeiro_candidato()


func _atualizar_dica_primeiro_candidato() -> void:
	dica_turno.show()
	for tipo in DICAS_DOCUMENTOS:
		if not documentos_consultados.has(tipo):
			dica_turno.text = DICAS_DOCUMENTOS[tipo]
			return
	dica_turno.text = "Terminou a conferência? Escolha Aprovar ou Reprovar."
