extends ColorRect

signal reinicio_solicitado
signal menu_solicitado
signal opcao_resumo_destacada
signal leitura_aberta
signal leitura_fechada

const TITULOS_DOCUMENTOS := {
	"rg": "Identidade",
	"vestibular": "Convocação do vestibular",
	"historico": "Histórico escolar",
	"ficha": "Ficha de requerimento",
}

@onready var titulo: Label = %Titulo
@onready var fechar: Button = %Fechar
@onready var manual: ScrollContainer = %Manual
@onready var proporcao: AspectRatioContainer = %Proporcao
@onready var copia_documento = %CopiaDocumento
@onready var resumo: VBoxContainer = %Resumo
@onready var totais: Label = %Totais


func _ready() -> void:
	copia_documento.bloquear_interacao()
	%NovoTurno.mouse_entered.connect(opcao_resumo_destacada.emit)
	%Menu.mouse_entered.connect(opcao_resumo_destacada.emit)


func mostrar_manual() -> void:
	titulo.text = "Manual de balcão"
	manual.show()
	proporcao.hide()
	resumo.hide()
	fechar.show()
	show()
	manual.scroll_vertical = 0
	fechar.grab_focus()
	leitura_aberta.emit()


func mostrar_documento(documento) -> void:
	titulo.text = TITULOS_DOCUMENTOS.get(documento.tipo_documento, "Documento")
	manual.hide()
	proporcao.show()
	resumo.hide()
	fechar.show()
	copia_documento.texture = documento.texture
	proporcao.ratio = float(documento.texture.get_width()) / documento.texture.get_height()
	copia_documento.carimbo.hide()
	if documento.carimbo.visible:
		copia_documento.carimbar(documento.deferido)
	show()
	fechar.grab_focus()
	leitura_aberta.emit()


func mostrar_resumo(atendidos: int, acertos: int, avaliados: int) -> void:
	titulo.text = "Fim do turno"
	manual.hide()
	proporcao.hide()
	fechar.hide()
	resumo.show()
	totais.text = "%d candidatos atendidos\nAcertos %d  •  Erros %d" % [
		atendidos, acertos, avaliados - acertos,
	]
	if avaliados < atendidos:
		totais.text += "\n%d sem avaliação" % (atendidos - avaliados)
	show()
	%NovoTurno.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and fechar.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_fechar()


func _fechar() -> void:
	var mostrando_leitura := visible and fechar.visible
	hide()
	copia_documento.texture = null
	if mostrando_leitura:
		leitura_fechada.emit()


func _on_novo_turno_pressed() -> void:
	reinicio_solicitado.emit()


func _on_menu_pressed() -> void:
	menu_solicitado.emit()
