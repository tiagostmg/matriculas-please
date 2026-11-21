# Desafios de Desenvolvimento — Matrículas, Please!

## 1. Lentidão na Geração Procedural de Documentos em Tempo Real

### O Problema
Os 4 documentos de cada candidato (`RG`, `Convocação do Vestibular`, `Histórico Escolar` e `Ficha de Requerimento`) são gerados proceduralmente a partir de templates **HTML & CSS** e convertidos em **PNG** via **Google Chrome Headless** (`documentos/gerar.py`).

Quando o jogo executava `OS.execute("python3", ["gerar.py", ...])` de forma **síncrona** na thread principal do Godot no momento em que o jogador clicava no botão **PRÓXIMO**:
1. O Chrome Headless era aberto 4 vezes seguidas (uma para cada documento), levando cerca de **1,5s a 3s** no total.
2. Como a chamada bloqueava a thread principal, a animação das silhuetas na fila e a interface do jogo davam uma "congelada" perceptível antes de o candidato entrar no guichê.

### A Solução Implementada (Pré-carregamento Assíncrono em Background + Otimização de Tempo)
1. **Geração em Thread Separada (`WorkerThreadPool` / `Thread`) no Godot:**
   - Assim que a cena do jogo inicia (`_ready()`), uma tarefa em background já começa a gerar o **1º candidato** em uma pasta de buffer (`buffer_proximo`) sem travar a interface nem as animações.
   - Quando o jogador clica em **PRÓXIMO** e o candidato pré-carregado entra no guichê (consumindo os PNGs que já estavam prontos instantaneamente), o jogo dispara imediatamente em background a geração do **próximo candidato da fila**.
   - Enquanto o jogador analisa os documentos do candidato atual, o próximo já fica 100% pronto esperando no buffer.
2. **Redução do `--virtual-time-budget` no Chrome Headless:**
   - Como as fontes (`PressStart2P` e `VT323`) e a foto 3x4 (`personagens-64`) já estão embutidas em **Base64 inline** dentro do HTML gerado, não há requisições externas de rede. Reduzimos o tempo de espera virtual do Chrome Headless para acelerar cada captura.
