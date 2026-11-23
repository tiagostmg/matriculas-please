# Sistema de Documentos — Matrículas, Please!

Agora os documentos são baseados em **HTML & CSS**, facilitando a customização visual direta no navegador ou editor de código, e convertidos automaticamente em **PNG** via Google Chrome headless.

---

## 🏛️ Papéis e Lore dos Documentos

1. **Documentos Trazidos pelo Candidato** (Depositados na **Mesa Menor / Bandeja do Balcão**):
   - **RG / CNH / Passaporte**: Identificação do candidato com foto, filiação e validade.
   - **Convocação do Vestibular**: Comprovante oficial com nota, nota de corte (corte 7.0) e classificação.
   - **Histórico Escolar do Ensino Médio**: Certificado com o nome do colégio de Fortaleza/CE no cabeçalho e **exatamente 4 disciplinas oficiais**:
     - *Língua Portuguesa e Literatura*
     - *Matemática e suas Tecnologias*
     - *Ciências da Natureza*
     - *Ciências Humanas e Sociais*
2. **Documento do Funcionário / Usuário** (Já fica na **Mesa Principal de Análise**):
   - **Ficha de Requerimento de Matrícula**: Documento interno emitido pelo guichê da universidade. **Nunca vem falsificado pelo candidato**. O atendente confere as informações e aplica os carimbos de **DEFERIDO** ou **INDEFERIDO**.

---

## ✒️ Mecânica de Fraude: Rasura & Tachado (Papers, Please Style)

Quando um candidato traz documentação adulterada, ela pode conter **rasuras / tachados feitos à mão com caneta**:
- **Histórico com Nota Tachada**: Nota insuficiente (ex: `4.5` ou `REPROVADO`) riscada e sobrescrita com caneta azul como `7.5` `APROVADO`.
- **RG com Validade Tachada**: Ano de validade vencido (ex: `2023`) riscado e puxado à mão para `2028`.
- **Vestibular com Status Tachado**: `LISTA DE ESPERA` tachado com régua/caneta e escrito `CONVOCADO`.
- **Irregularidades sutis**: Sobrenomes parecidos com uma letra diferente entre o RG e a ficha, turno divergente, validade vencida, carimbo ausente ou nota pouco abaixo do corte 7.0.
- **Normalmente apenas 1 documento falso por vez** para manter a investigação justa e focada.

---

## 🎨 Onde Editar os Templates

Todos os templates estão na pasta `templates/`:

1. **[`templates/style_base.css`](file:///home/tiago/dev/narak/documentos/templates/style_base.css)**:
   - Cores oficiais de papéis (verde RG, bege histórico, etc.)
   - Fontes pixeladas retrô (`VT323` e `Press Start 2P`)
   - Efeitos de textura guilhochê, molduras, carimbos, foto 3x4 com grampo e classes `.strike-fraud` e `.handwritten-fraud`.
2. **[`templates/doc_identidade.html`](file:///home/tiago/dev/narak/documentos/templates/doc_identidade.html)**:
   - Layout do RG / CNH com foto, filiação, números e validade.
3. **[`templates/doc_vestibular.html`](file:///home/tiago/dev/narak/documentos/templates/doc_vestibular.html)**:
   - Homologação do Vestibular com nota, corte, classificação e selo de status.
4. **[`templates/doc_historico.html`](file:///home/tiago/dev/narak/documentos/templates/doc_historico.html)**:
   - Certificado com o colégio sorteado no cabeçalho, tabela das **4 disciplinas**, assinatura e carimbo redondo oficial.
5. **[`templates/doc_ficha.html`](file:///home/tiago/dev/narak/documentos/templates/doc_ficha.html)**:
   - Requerimento oficial interno emitido no guichê com espaço reservado para carimbo do atendente.

### 👁️ Visualizar no Navegador
Abra **[`preview_templates.html`](file:///home/tiago/dev/narak/documentos/preview_templates.html)** no navegador para ver todos os documentos e a demonstração dos tachados lado a lado!

---

## 🚀 Como Gerar os PNGs (`gerar.py`)

O script preenche os templates HTML e renderiza os PNGs em `output_docs/`:

```bash
cd /home/tiago/dev/narak/documentos

# 1. Gerar documentos (sorteia automaticamente um PNG de ../sprites/personagens/):
python3 gerar.py

# 2. Gerar documentos de um personagem específico (por número, pasta ou caminho do PNG):
python3 gerar.py 10
python3 gerar.py ../sprites/personagens/10/sprite_01.png

# 3. Gerar documentos para TODOS os personagens de sprites/personagens/:
python3 gerar.py --todos

# 4. Gerar candidato regular (sem fraudes):
python3 gerar.py --fraude regular

# 5. Testar mecânicas de fraude / tachado / foto divergente:
python3 gerar.py --fraude rg_foto_divergente
python3 gerar.py --fraude historico_tachado
python3 gerar.py --fraude rg_tachado
python3 gerar.py --fraude vestibular_tachado
python3 gerar.py --fraude sem_carimbo
python3 gerar.py --fraude vestibular_nota_baixa
python3 gerar.py --fraude rg_vencido
python3 gerar.py --fraude rg_nome_divergente
```

### Arquivos Gerados em `output_docs/`:
- `1_documento_identidade.png` (e `.html`)
- `2_convocacao_vestibular.png` (e `.html`)
- `3_historico_ensino_medio.png` (e `.html`)
- `4_ficha_requerimento.png` (e `.html`)
- `dados_candidato.json` (gabarito da investigação)
