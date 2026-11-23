#!/usr/bin/env python3
"""
Gerador Procedural de Documentos via HTML & CSS -> PNG
Estilo "Matrículas, Please!" (Papers, Please / Pixel Art)

Este script:
1. Seleciona a imagem PNG do personagem em ../sprites/personagens/ (ou caminho informado)
2. Gera dados de um candidato compatíveis com o personagem (e fraudes/irregularidades opcionais)
3. Injeta os dados e a foto PNG do personagem nos templates HTML em templates/
4. Renderiza os PNGs finais via Google Chrome Headless com suporte a CSS pixel art
5. Salva tanto os .png quanto os .html em output_docs/ para fácil edição!
"""

import sys
import os
import glob
import random
import json
import base64
import shutil
import subprocess
from pathlib import Path

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")
_P64_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "sprites", "personagens-64"))
_P85_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "sprites", "personagens-85"))
_RAW_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "sprites", "personagens"))
SPRITES_PERSONAGENS_DIR = _P64_DIR if os.path.isdir(_P64_DIR) else (_P85_DIR if os.path.isdir(_P85_DIR) else _RAW_DIR)

MALE_NAMES = [
    "Lucas", "Gabriel", "Mateus", "Enzo", "Guilherme", "Pedro", "Thiago", "Rodrigo", "Felipe", "Bruno",
    "Rafael", "Gustavo", "Vinicius", "Leonardo", "Cauã", "Daniel", "Matheus", "Arthur", "Nicolas", "Caio"
]
FEMALE_NAMES = [
    "Julia", "Beatriz", "Larissa", "Mariana", "Camila", "Fernanda", "Amanda", "Letícia", "Sofia", "Isabela",
    "Bianca", "Helena", "Alice", "Laura", "Manuela", "Clara", "Valentina", "Heloísa", "Lívia", "Giovanna"
]
FEMALE_CHARACTER_IDS = {
    "01", "02", "04", "05", "07", "08", "17", "19", "21", "24", "25",
    "28", "30", "33", "35", "37", "39", "41", "43", "45", "47"
}

LAST_NAMES = [
    "Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira", "Alves", "Pereira", "Lima", "Gomes",
    "Costa", "Ribeiro", "Martins", "Carvalho", "Almeida", "Lopes", "Soares", "Fernandes", "Vieira", "Barbosa"
]
COURSES = {
    "Medicina": {"corte": 7.0, "turno": "Integral", "vagas": 40},
    "Direito": {"corte": 7.0, "turno": "Matutino", "vagas": 60},
    "Ciência da Computação": {"corte": 7.0, "turno": "Integral", "vagas": 50},
    "Engenharia de Software": {"corte": 7.0, "turno": "Noturno", "vagas": 50},
    "Administração": {"corte": 7.0, "turno": "Noturno", "vagas": 80},
    "Filosofia": {"corte": 7.0, "turno": "Vespertino", "vagas": 40}
}
SCHOOLS = [
    "Colégio Antares",
    "Colégio Ari de Sá Cavalcante",
    "Colégio Christus",
    "Colégio Farias Brito",
    "Colégio Master",
    "Colégio 7 de Setembro",
    "Colégio Santa Cecília",
    "Colégio Santo Inácio",
    "Colégio Batista Santos Dumont",
    "Colégio Lourenço Filho",
    "Colégio Militar de Fortaleza (CMF)",
    "Colégio da Polícia Militar do Ceará (CPM)",
    "IFCE - Campus Fortaleza (Técnico Integrado)",
    "EEEP Juarez Távora",
    "EEEP Marcondes Rosa",
    "EEEP Paulo VI",
    "Liceu do Ceará",
    "EEMTI Justiniano de Serpa",
    "EEFM Julia Fialho",
    "Colégio Ateneu Fênix",
    "Centro Educacional da Juventude Padre João Piamarta",
    "Colégio Darwin",
    "Colégio Jim Wilson",
    "Colégio Nova Dimensão",
    "Colégio Gustavo Braga",
    "Colégio Integral",
    "Colégio Teleyos",
    "Colégio Espaço Aberto"
]


def list_available_characters():
    """
    Lista todos os personagens disponíveis em sprites/personagens/.
    Retorna uma lista de dicts:
      {
        "id": "01",
        "photo_png": "/caminho/para/sprite_01.png",
        "sprites": ["/caminho/para/sprite_01.png", ...]
      }
    """
    characters = []
    if not os.path.isdir(SPRITES_PERSONAGENS_DIR):
        return characters

    for entry in sorted(os.listdir(SPRITES_PERSONAGENS_DIR)):
        if entry == "nativo":
            continue
        full_path = os.path.join(SPRITES_PERSONAGENS_DIR, entry)
        if os.path.isdir(full_path):
            pngs = sorted(glob.glob(os.path.join(full_path, "*.png")))
            if pngs:
                # Prioriza sprite_01.png (pose neutra 3x4 para documento)
                default_png = next((p for p in pngs if os.path.basename(p) == "sprite_01.png"), pngs[0])
                characters.append({
                    "id": entry,
                    "photo_png": default_png,
                    "sprites": pngs
                })
        elif entry.lower().endswith(".png"):
            char_id = os.path.splitext(entry)[0]
            characters.append({
                "id": char_id,
                "photo_png": full_path,
                "sprites": [full_path]
            })

    return characters


def resolve_character_png(target=None):
    """
    Resolve a imagem PNG do personagem a partir de:
    - Caminho direto para um arquivo .png
    - Caminho para uma pasta de personagem (usa sprite_01.png)
    - ID ou número do personagem (ex: '05', '5', 'personagem_05')
    - None (sorteia um personagem aleatório de sprites/personagens/)
    """
    characters = list_available_characters()

    if target:
        # 1. Caminho direto para arquivo ou pasta existente
        if os.path.isfile(target):
            abs_file = os.path.abspath(target)
            parent_name = os.path.basename(os.path.dirname(abs_file))
            char_id = parent_name if parent_name != "personagens" else os.path.splitext(os.path.basename(abs_file))[0]
            return {
                "id": char_id,
                "photo_png": abs_file,
                "sprites": sorted(glob.glob(os.path.join(os.path.dirname(abs_file), "*.png"))) or [abs_file]
            }
        if os.path.isdir(target):
            pngs = sorted(glob.glob(os.path.join(os.path.abspath(target), "*.png")))
            if not pngs:
                raise FileNotFoundError(f"Nenhum arquivo .png encontrado na pasta: {target}")
            default_png = next((p for p in pngs if os.path.basename(p) == "sprite_01.png"), pngs[0])
            return {
                "id": os.path.basename(os.path.abspath(target).rstrip("/")),
                "photo_png": default_png,
                "sprites": pngs
            }

        # 2. ID do personagem (ex: "07", "7", "personagem_07")
        raw = target.strip().lower().replace("personagem_", "")
        candidates_to_match = {target.strip().lower(), raw}
        if raw.isdigit():
            candidates_to_match.add(f"{int(raw):02d}")
            candidates_to_match.add(f"personagem_{int(raw):02d}")

        for char in characters:
            if char["id"].lower() in candidates_to_match:
                return char

        raise FileNotFoundError(
            f"Personagem ou imagem PNG '{target}' não encontrado. "
            f"Verifique {SPRITES_PERSONAGENS_DIR}."
        )

    if not characters:
        raise FileNotFoundError(
            f"Nenhuma imagem PNG de personagem encontrada em {SPRITES_PERSONAGENS_DIR}."
        )

    return random.choice(characters)


def pick_first_name_for_character(char_id):
    norm_id = char_id.lower().replace("personagem_", "")
    if norm_id.isdigit():
        norm_id = f"{int(norm_id):02d}"
    if norm_id in FEMALE_CHARACTER_IDS:
        return random.choice(FEMALE_NAMES)
    return random.choice(MALE_NAMES)


def image_to_base64(path):
    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode("utf-8")
    ext = os.path.splitext(path)[1].lower().replace(".", "")
    if ext == "jpg":
        ext = "jpeg"
    return f"data:image/{ext};base64,{data}"


def find_chrome():
    chrome = shutil.which("google-chrome") or shutil.which("chrome")
    if chrome:
        return chrome
    if os.name == "nt":
        for variable in ("ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA"):
            root = os.environ.get(variable)
            if root:
                chrome = Path(root) / "Google" / "Chrome" / "Application" / "chrome.exe"
                if chrome.is_file():
                    return str(chrome)
    raise FileNotFoundError("Google Chrome não encontrado.")


def render_html_to_png(html_path, png_path, width, height):
    """Renderiza um arquivo HTML para PNG usando o Google Chrome headless garantindo fontes carregadas e fundo transparente"""
    cmd = [
        find_chrome(),
        "--headless=new",
        "--no-sandbox",
        "--disable-gpu",
        "--hide-scrollbars",
        "--default-background-color=00000000",
        "--force-device-scale-factor=2",
        "--virtual-time-budget=200",
        "--allow-file-access-from-files",
        "--run-all-compositor-stages-before-draw",
        f"--screenshot={png_path}",
        f"--window-size={width},{height}",
        Path(html_path).resolve().as_uri()
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)


def get_inlined_css():
    """Lê o CSS base e as fontes em base64 para embutir diretamente no HTML"""
    fonts_css_path = os.path.join(TEMPLATES_DIR, "fonts.css")
    style_css_path = os.path.join(TEMPLATES_DIR, "style_base.css")

    css_content = ""
    if os.path.exists(fonts_css_path):
        with open(fonts_css_path, "r", encoding="utf-8") as f:
            css_content += f.read() + "\n"
    if os.path.exists(style_css_path):
        with open(style_css_path, "r", encoding="utf-8") as f:
            style_code = f.read()
            # Remove linhas de @import para evitar requisições extras
            style_code = "\n".join([line for line in style_code.splitlines() if not line.strip().startswith("@import")])
            css_content += style_code + "\n"
    return f"<style>\n{css_content}\n</style>"


def generate_all_documents(photo_target=None, output_dir="output_docs", force_flaw=None):
    os.makedirs(output_dir, exist_ok=True)
    abs_output = os.path.abspath(output_dir)

    # Seleciona o personagem e sua imagem PNG
    character = resolve_character_png(photo_target)
    rg_photo_png = character["photo_png"]
    rg_photo_char_id = character["id"]

    # Sorteia dados compatíveis com o personagem
    first = pick_first_name_for_character(character["id"])
    last = random.choice(LAST_NAMES)
    nome = f"{first} {last}"
    mae = f"{random.choice(FEMALE_NAMES)} {last}"
    pai = f"{random.choice(MALE_NAMES)} {last}"

    curso = random.choice(list(COURSES.keys()))
    curso_info = COURSES[curso]
    corte = curso_info["corte"]
    nota_vestibular = round(random.uniform(7.0, 9.8), 1)
    status_vest = "CONVOCADO - 1ª CHAMADA"
    status_sub = "HABILITADO PARA MATRÍCULA IMEDIATA"
    status_class = "convocado"

    ano_val_rg = random.randint(2027, 2033)
    val_class = "valid"

    tem_carimbo_escola = True
    situacao_escola = "CONCLUÍDO COM APROVAÇÃO"
    situacao_cor = "#1a7536"
    ano_conclusao_hist = "2024"
    ano_conclusao_html = ano_conclusao_hist

    # Ficha de Matrícula (emitida no guichê pelo funcionário/usuário — nunca vem falsificada)
    nome_oficial = nome
    nome_rg = nome
    vestibular_curso = curso
    vest_nota_html = f"{nota_vestibular:.1f}"

    # Preparação das 4 Disciplinas do Ensino Médio
    SUBJECTS = [
        "LÍNGUA PORTUGUESA E LITERATURA",
        "MATEMÁTICA E SUAS TECNOLOGIAS",
        "CIÊNCIAS DA NATUREZA",
        "CIÊNCIAS HUMANAS E SOCIAIS"
    ]
    disciplinas_data = []
    for subj in SUBJECTS:
        nota_subj = round(random.uniform(7.0, 9.8), 1)
        disciplinas_data.append({"disciplina": subj, "media": f"{nota_subj:.1f}", "situacao": "APROVADO"})

    # Tratamento de Fraudes nos Documentos do Candidato
    available_candidate_flaws = [
        "rg_tachado",
        "rg_vencido",
        "rg_nome_divergente",
        "rg_foto_divergente",
        "vestibular_tachado",
        "vestibular_nota_tachada",
        "vestibular_reprovado",
        "vestibular_nota_baixa",
        "vestibular_curso_divergente",
        "historico_tachado",
        "historico_ano_tachado",
        "historico_sem_carimbo",
        "ensino_medio_incompleto"
    ]

    if force_flaw in ["nenhuma", "regular", "none"]:
        chosen_flaw = None
    elif force_flaw is None and random.random() < 0.5:
        chosen_flaw = random.choice(available_candidate_flaws)
    else:
        chosen_flaw = force_flaw

    flaw_desc = "Nenhuma. Documentação do candidato 100% regular."
    val_ano_html = str(ano_val_rg)
    vest_status_titulo = f"★ {status_vest} ★"
    vest_status_sub = status_sub

    if chosen_flaw == "rg_nome_divergente":
        sobrenome_falso = random.choice([l for l in LAST_NAMES if l != last])
        nome_rg = f"{first} {sobrenome_falso}"
        flaw_desc = f"Identidade irregular: Nome no RG ({nome_rg.upper()}) diverge do cadastro da Ficha ({nome_oficial.upper()})."
    elif chosen_flaw == "rg_foto_divergente":
        all_chars = [c for c in list_available_characters() if c["id"] != character["id"]]
        if all_chars:
            impostor = random.choice(all_chars)
            rg_photo_png = impostor["photo_png"]
            rg_photo_char_id = impostor["id"]
        flaw_desc = f"Identidade irregular: Foto 3x4 no RG (personagem {rg_photo_char_id}) não corresponde ao candidato (personagem {character['id']})."
    elif chosen_flaw == "rg_vencido":
        ano_val_rg = random.randint(2021, 2025)
        val_class = "expired"
        val_ano_html = str(ano_val_rg)
        flaw_desc = f"Identidade vencida: validade {ano_val_rg} anterior a 2026."
    elif chosen_flaw == "rg_tachado":
        ano_val_rg = 2023
        val_class = "expired"
        val_ano_html = '<span class="strike-fraud">2023</span> <span class="handwritten-fraud">2028</span>'
        flaw_desc = "Identidade adulterada: ano de validade vencido (2023) foi tachado e alterado à mão para 2028."
    elif chosen_flaw == "vestibular_reprovado":
        status_vest = "LISTA DE ESPERA / EXCEDENTE"
        vest_status_sub = "NÃO HOMOLOGADO PARA ESTA CHAMADA"
        status_class = "reprovado"
        vest_status_titulo = f"★ {status_vest} ★"
        flaw_desc = "Vestibular irregular: candidato não convocado (Status: Lista de Espera)."
    elif chosen_flaw == "vestibular_tachado":
        status_vest = "LISTA DE ESPERA"
        status_class = "reprovado"
        vest_status_titulo = '<span class="strike-fraud">LISTA DE ESPERA</span> <span class="handwritten-fraud">CONVOCADO</span>'
        vest_status_sub = '<span class="strike-fraud">NÃO APROVADO</span> <span class="handwritten-fraud">HOMOLOGADO</span>'
        flaw_desc = "Vestibular adulterado: status original 'LISTA DE ESPERA' foi tachado e adulterado para 'CONVOCADO' à mão."
    elif chosen_flaw == "vestibular_nota_tachada":
        vest_nota_html = '<span class="strike-fraud">5.2</span> <span class="handwritten-fraud">7.8</span>'
        flaw_desc = "Vestibular adulterado: nota insuficiente (5.2) foi tachada e adulterada com caneta para 7.8."
    elif chosen_flaw == "vestibular_nota_baixa":
        nota_vestibular = round(random.uniform(4.0, 6.8), 1)
        vest_nota_html = f"{nota_vestibular:.1f}"
        flaw_desc = f"Vestibular irregular: nota ({nota_vestibular:.1f}) inferior à nota de corte ({corte:.1f})."
    elif chosen_flaw == "vestibular_curso_divergente":
        outros_cursos = [c for c in COURSES.keys() if c != curso]
        vestibular_curso = random.choice(outros_cursos)
        flaw_desc = f"Vestibular divergente: convocado para {vestibular_curso.upper()}, mas requerendo matrícula para {curso.upper()}."
    elif chosen_flaw == "historico_tachado":
        alvo = random.choice(disciplinas_data)
        alvo["media"] = '<span class="strike-fraud">4.5</span> <span class="handwritten-fraud">7.5</span>'
        alvo["situacao"] = '<span class="strike-fraud">REPROVADO</span> <span class="handwritten-fraud">APROVADO</span>'
        flaw_desc = f"Histórico adulterado: disciplina {alvo['disciplina']} com reprovação tachada e adulterada com caneta."
    elif chosen_flaw == "historico_ano_tachado":
        ano_conclusao_html = '<span class="strike-fraud">2027</span> <span class="handwritten-fraud">2024</span>'
        flaw_desc = "Histórico adulterado: ano de conclusão futuro (2027) foi tachado e corrigido à mão para 2024."
    elif chosen_flaw in ["sem_carimbo", "historico_sem_carimbo"]:
        tem_carimbo_escola = False
        flaw_desc = "Histórico irregular: ausência do carimbo oficial da Secretaria de Educação."
    elif chosen_flaw == "ensino_medio_incompleto":
        situacao_escola = "CURSANDO / PENDENTE DE NOTA"
        situacao_cor = "#aa1e1e"
        flaw_desc = "Histórico irregular: Ensino Médio pendente de conclusão (não concluído)."

    foto_b64 = image_to_base64(rg_photo_png)

    # Monta tabela HTML das 4 disciplinas
    tabela_disciplinas_html = ""
    for item in disciplinas_data:
        tabela_disciplinas_html += f"""        <tr>
          <td>{item['disciplina']}</td>
          <td>{item['media']}</td>
          <td>{item['situacao']}</td>
        </tr>\n"""

    inlined_css = get_inlined_css()

    # 1. TEMPLATE: IDENTIDADE (RG / CNH)
    rg_template_path = os.path.join(TEMPLATES_DIR, "doc_identidade.html")
    with open(rg_template_path, "r", encoding="utf-8") as f:
        rg_html = f.read()

    rg_replacements = {
        "{{ORGAO_EMISSOR}}": "REPÚBLICA FEDERATIVA DO BRASIL",
        "{{TIPO_DOCUMENTO}}": "REGISTRO GERAL DE IDENTIDADE (SSP/CE)",
        "{{FOTO_URL}}": foto_b64,
        "{{NOME}}": nome_rg.upper(),
        "{{FILIACAO}}": f"{mae.upper()} / {pai.upper()}",
        "{{DATA_NASCIMENTO}}": f"{random.randint(1,28):02d}/{random.randint(1,12):02d}/2004",
        "{{NATURALIDADE}}": "FORTALEZA - CE",
        "{{NUMERO_DOCUMENTO}}": f"{random.randint(10,99)}.{random.randint(100,999)}.{random.randint(100,999)}-{random.randint(0,9)}",
        "{{CPF}}": f"{random.randint(100,999)}.{random.randint(100,999)}.{random.randint(100,999)}-{random.randint(10,99)}",
        "{{ANO_VALIDADE}}": val_ano_html,
        "{{VALIDADE_CLASSE}}": val_class,
        "<link rel=\"stylesheet\" href=\"style_base.css\">": inlined_css,
        "href=\"style_base.css\"": f"href=\"{os.path.join(TEMPLATES_DIR, 'style_base.css')}\""
    }
    for k, v in rg_replacements.items():
        rg_html = rg_html.replace(k, v)

    rg_html_file = os.path.join(abs_output, "1_documento_identidade.html")
    rg_png_file = os.path.join(abs_output, "1_documento_identidade.png")
    with open(rg_html_file, "w", encoding="utf-8") as f:
        f.write(rg_html)
    render_html_to_png(rg_html_file, rg_png_file, 440, 310)

    # 2. TEMPLATE: VESTIBULAR
    vest_template_path = os.path.join(TEMPLATES_DIR, "doc_vestibular.html")
    with open(vest_template_path, "r", encoding="utf-8") as f:
        vest_html = f.read()

    vest_replacements = {
        "{{NOME}}": nome_oficial.upper(),
        "{{CURSO}}": vestibular_curso.upper(),
        "{{TURNO}}": curso_info["turno"].upper(),
        "{{NOTA_VESTIBULAR}}": vest_nota_html,
        "{{NOTA_CORTE}}": f"{corte:.1f}",
        "{{CLASSIFICACAO}}": f"{random.randint(1, curso_info['vagas']):02d}",
        "{{TOTAL_VAGAS}}": str(curso_info["vagas"]),
        "{{STATUS_CLASSE}}": status_class,
        "{{STATUS_TITULO}}": vest_status_titulo,
        "{{STATUS_SUB}}": vest_status_sub,
        "<link rel=\"stylesheet\" href=\"style_base.css\">": inlined_css,
        "href=\"style_base.css\"": f"href=\"{os.path.join(TEMPLATES_DIR, 'style_base.css')}\""
    }
    for k, v in vest_replacements.items():
        vest_html = vest_html.replace(k, v)

    vest_html_file = os.path.join(abs_output, "2_convocacao_vestibular.html")
    vest_png_file = os.path.join(abs_output, "2_convocacao_vestibular.png")
    with open(vest_html_file, "w", encoding="utf-8") as f:
        f.write(vest_html)
    render_html_to_png(vest_html_file, vest_png_file, 440, 340)

    # 3. TEMPLATE: HISTÓRICO ENSINO MÉDIO (4 DISCIPLINAS)
    hist_template_path = os.path.join(TEMPLATES_DIR, "doc_historico.html")
    with open(hist_template_path, "r", encoding="utf-8") as f:
        hist_html = f.read()

    carimbo_escola_html = """
      <div class="round-seal">
        <span class="star">★</span>
        <span class="seal-dept">SEC. EDUCAÇÃO<br>AUTÊNTICO</span>
        <span class="seal-sub">VISTO OFICIAL</span>
      </div>
    """ if tem_carimbo_escola else """
      <div style="border: 2px dashed #aa1e1e; padding: 6px 10px; color: #aa1e1e; font-family: var(--font-pixel); font-size: 7px; text-align: center;">
        [!] CARIMBO NÃO LOCALIZADO
      </div>
    """

    hist_replacements = {
        "{{ESCOLA}}": random.choice(SCHOOLS).upper(),
        "{{NOME}}": nome_oficial.upper(),
        "{{ANO_CONCLUSAO}}": ano_conclusao_html,
        "{{SITUACAO_TEXTO}}": situacao_escola,
        "{{SITUACAO_COR}}": situacao_cor,
        "{{TABELA_DISCIPLINAS_HTML}}": tabela_disciplinas_html,
        "{{CARIMBO_OFICIAL_HTML}}": carimbo_escola_html,
        "<link rel=\"stylesheet\" href=\"style_base.css\">": inlined_css,
        "href=\"style_base.css\"": f"href=\"{os.path.join(TEMPLATES_DIR, 'style_base.css')}\""
    }
    for k, v in hist_replacements.items():
        hist_html = hist_html.replace(k, v)

    hist_html_file = os.path.join(abs_output, "3_historico_ensino_medio.html")
    hist_png_file = os.path.join(abs_output, "3_historico_ensino_medio.png")
    with open(hist_html_file, "w", encoding="utf-8") as f:
        f.write(hist_html)
    render_html_to_png(hist_html_file, hist_png_file, 440, 400)

    # 4. TEMPLATE: FICHA DE MATRÍCULA
    # (Documento oficial emitido pelo atendente / sistema — 100% autêntico, sem rasuras)
    ficha_template_path = os.path.join(TEMPLATES_DIR, "doc_ficha.html")
    with open(ficha_template_path, "r", encoding="utf-8") as f:
        ficha_html = f.read()

    carimbo_area_funcionario = """
      <div style="border: 2px dashed #887766; padding: 10px 14px; border-radius: 4px; color: #665544; font-family: var(--font-pixel); font-size: 8px; text-align: center; letter-spacing: 0.5px; background: rgba(0,0,0,0.03);">
        [ ESPAÇO RESERVADO PARA CARIMBO DO FUNCIONÁRIO ]
        <div style="font-family: var(--font-doc); font-size: 15px; margin-top: 4px; color: #443322;">AGUARDANDO CONFERÊNCIA DOCUMENTAL</div>
      </div>
    """

    ficha_replacements = {
        "{{NUMERO_PROTOCOLO}}": str(random.randint(10000, 99999)),
        "{{NOME}}": nome_oficial.upper(),
        "{{CURSO}}": curso.upper(),
        "{{TURNO}}": curso_info["turno"].upper(),
        "{{MODALIDADE}}": "AMPLA CONCORRÊNCIA",
        "{{STATUS_TAXA}}": "PAGA",
        "{{TAXA_COR}}": "#1a7536",
        "{{CARIMBO_DECISAO_HTML}}": carimbo_area_funcionario,
        "<link rel=\"stylesheet\" href=\"style_base.css\">": inlined_css,
        "href=\"style_base.css\"": f"href=\"{os.path.join(TEMPLATES_DIR, 'style_base.css')}\""
    }
    for k, v in ficha_replacements.items():
        ficha_html = ficha_html.replace(k, v)

    ficha_html_file = os.path.join(abs_output, "4_ficha_requerimento.html")
    ficha_png_file = os.path.join(abs_output, "4_ficha_requerimento.png")
    with open(ficha_html_file, "w", encoding="utf-8") as f:
        f.write(ficha_html)
    render_html_to_png(ficha_html_file, ficha_png_file, 440, 480)

    is_flawed = not flaw_desc.startswith("Nenhuma")

    # Salva Gabarito JSON
    info = {
        "personagem_id": character["id"],
        "personagem_foto_png": character["photo_png"],
        "personagem_sprites": character["sprites"],
        "rg_foto_personagem_id": rg_photo_char_id,
        "rg_foto_png": rg_photo_png,
        "candidato": nome_oficial,
        "rg_nome": nome_rg,
        "curso": curso,
        "vestibular_curso": vestibular_curso,
        "nota_vestibular": nota_vestibular,
        "nota_corte": corte,
        "status_vestibular": status_vest,
        "validade_rg": ano_val_rg,
        "carimbo_ensino_medio": tem_carimbo_escola,
        "tem_fraude": is_flawed,
        "descricao_fraude": flaw_desc
    }
    json_path = os.path.join(abs_output, "dados_candidato.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2, ensure_ascii=False)

    print(f"\n=======================================================")
    print(f"✓ DOCUMENTOS GERADOS COM SUCESSO EM: {output_dir}")
    print(f"=======================================================")
    print(f"• Personagem: {character['id']} ({os.path.relpath(rg_photo_png, BASE_DIR)})")
    print(f"• Candidato:  {nome}")
    print(f"• Status:     {'[OK] REGULAR' if not is_flawed else '[ALERTA] ' + flaw_desc}")
    print(f"\nArquivos HTML (editáveis) e PNGs gerados:")
    print(f"1. RG / CNH:        {rg_png_file}")
    print(f"2. Vestibular:      {vest_png_file}")
    print(f"3. Ensino Médio:    {hist_png_file}")
    print(f"4. Ficha Matrícula: {ficha_png_file}")
    print(f"5. Metadados JSON:  {json_path}")


if __name__ == "__main__":
    args = sys.argv[1:]
    flaw_arg = None
    out_arg = os.path.join(BASE_DIR, "output_docs")
    generate_all_chars = False
    photo_arg = None

    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--fraude" and i + 1 < len(args):
            flaw_arg = args[i + 1]
            i += 2
        elif arg in ["--personagem", "-p"] and i + 1 < len(args):
            photo_arg = args[i + 1]
            i += 2
        elif arg in ["--output", "-o"] and i + 1 < len(args):
            out_arg = args[i + 1]
            i += 2
        elif arg in ["--todos", "--all"]:
            generate_all_chars = True
            i += 1
        elif not arg.startswith("--") and photo_arg is None:
            photo_arg = arg
            i += 1
        else:
            i += 1

    if generate_all_chars:
        chars = list_available_characters()
        print(f"Gerando documentos para {len(chars)} personagens em {out_arg}...")
        for ch in chars:
            char_out = os.path.join(out_arg, ch["id"])
            generate_all_documents(photo_target=ch["photo_png"], output_dir=char_out, force_flaw=flaw_arg)
    else:
        generate_all_documents(photo_target=photo_arg, output_dir=out_arg, force_flaw=flaw_arg)
