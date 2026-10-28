# 1943 — piloto LLAPI arcade

**Versão experimental para MiSTer.** Ainda exige teste físico com BlisSTer/LLAPI.

Base: [jotego/jtcores](https://github.com/jotego/jtcores), commit `b222692d4c0c9a26a6cb3c99c6820b1ed4a5d565`.
Protocolo e convenções arcade: [MiSTer-LLAPI/Arcade-IremM62_MiSTer](https://github.com/MiSTer-LLAPI/Arcade-IremM62_MiSTer), commit `4d63703988cfb2b8256fc3bdb1a4a09b39cceaba`.

O jogo, vídeo, som, créditos e licença do Jotego são preservados. O protocolo LLAPI mantém os tempos, comandos e formato arcade existentes. Foram corrigidos apenas aspetos de sintaxe SystemVerilog do ficheiro original: uma vírgula final numa concatenação, as declarações dos dois outputs procedimentais, as atribuições combinacionais e um ternário de enum substituído por if/else equivalente. A ponte acrescenta sincronizadores nos sinais que passam entre 50 MHz e o relógio do jogo.

A opção `JTFRAME_LLAPI` só está ativa no 1943/MiSTer. Os restantes cores e plataformas mantêm o funcionamento original. A opção Serial port permite LLAPI (predefinido), SNAC SNES, SNAC Mega Drive ou SNAC Saturn. Só o protocolo selecionado controla a porta USER; DB15 e UART nessa porta ficam indisponíveis neste piloto.

## Instalação

1. Preserva o core e o MRA oficiais que já tens.
2. Copia `cores/jt1943_llapi_snac_20261028_test.rbf` para `_Arcade/cores/` no cartão da MiSTer.
3. Copia `mra/1943-LLAPI-SNAC-Test.mra` para uma pasta de testes em `_Arcade/`.
4. Usa o teu conjunto `1943.zip` compatível com o MRA Euro oficial. Não estão incluídas ROMs neste projeto.
5. Abre o MRA identificado como **LLAPI + SNAC TEST** e começa com uma configuração nova.

O MRA deriva do Euro oficial de Jotego/JTBIN, blob `4b7d620073468fd899ec1699ef565ca76a0ad658`. Apenas o nome apresentado e o nome do RBF foram alterados; referências às ROMs, CRCs, orientação, DIP switches e créditos foram preservados.

## Comandos — convenção LLAPI arcade existente

- Direções: os quatro bits de D-pad do LLAPI.
- Disparo/Bomba: botões LLAPI 0/1; o terceiro campo de botão é reservado pelo JTFRAME neste core.
- Moeda: botão LLAPI 4 (Select), na porta respetiva.
- Start 1P: botão LLAPI 5, em qualquer porta.
- Start 2P: botão LLAPI 6, em qualquer porta, conforme a convenção arcade existente.
- Menu: **Baixo + Start 1P + primeiro botão**, em qualquer porta.

A porta física LLAPI 1 controla o jogador 1 e a porta 2 controla o jogador 2. Com apenas um comando LLAPI ligado, o primeiro comando USB preenche a outra posição. Sem LLAPI, os dois comandos USB funcionam normalmente. O teclado mantém o funcionamento do JTFRAME.

## Validação

O teste local cobre os dois jogadores independentes, moedas, Start 1P/2P, menu em cada porta, fallback USB e rejeição de dados de uma porta inválida. O módulo completo também é compilado pelo simulador, e a configuração/lista de fontes é gerada pelo JTFRAME oficial.

A compilação utiliza a imagem pública oficial `jotego/jtcore20`, com as dependências fixadas pelo Git. Pode experimentar até três seeds, mantendo a aceitação de tempos do JTFRAME. O empacotamento exige setup, hold, recovery, removal e largura mínima de pulso sem slack negativo. Os relatórios acompanham o RBF.

Teste físico a fazer: cada porta isoladamente, ambas juntas, dois disparos diferentes ao mesmo tempo, Start/moeda, menu, USB misturado com LLAPI e desligar/religar um comando.

Mantém os créditos, cabeçalhos e licenças dos projetos de origem. Isto é uma integração experimental independente; não é uma release oficial de Jotego.

## Opções SNAC digitais

Esta variante acrescenta leitores de comandos digitais através dos adaptadores SNAC e pinouts dos cores oficiais SNES, Genesis e Saturn. O menu **Serial port** usa bits 63:62 (predefinição 0 = LLAPI), sem alterar os bits originais de vídeo/UART. Durante a mudança de protocolo, todos os pinos são libertados durante 150 us; os módulos inativos não conduzem a porta.

- **SNAC SNES:** comando digital SNES. Disparo B, bomba A; Select insere moeda; Start inicia P1.
- **SNAC Mega Drive:** comandos de 3/6 botões. Disparo B, bomba A; Mode (6 botões) ou Baixo+Start insere moeda; Start inicia P1.
- **SNAC Saturn:** comando digital Saturn (ou 3D Pad na posição digital). Disparo B, bomba C; L insere moeda; Start inicia P1. O modo analógico/handshake do 3D Pad, periféricos e multitaps não estão implementados neste leitor arcade.

Menu: **Baixo + Start + disparo**, nos três modos. A combinação de menu não envia disparo/Start/moeda ao jogo. SNAC ocupa P1; o primeiro comando USB passa a P2. O teclado continua disponível. Os adaptadores/cabos SNAC têm de corresponder ao sistema selecionado. O protocolo de um adaptador SNAC não é o LLAPI de um BlisSTer.

Os leitores SNAC fazem uma leitura periódica a cada 2,5 ms, adequada ao protocolo digital e ao tempo de reposição dos comandos Mega Drive de 6 botões. Não é uma medição de latência nem a reprodução de uma interface nativa do arcade 1943.

Pinout verificado nas fontes MiSTer-devel/SNES_MiSTer (SNES.sv), Genesis_MiSTer (Genesis.sv) e Saturn_MiSTer (Saturn.sv). Ordem dos nibbles Saturn comparada também com joydb9saturn.v de Timothy Redaelli, em MiSTer-DB9/jtcores. Mantidos os créditos de todos os projetos.

Testes locais adicionais: modelos de comandos ao nível dos pinos (arestas SNES, handshake MD de 3/6 botões, identificação/nibbles Saturn), comando desligado, libertação da porta, mudança dos quatro modos, regresso ao LLAPI, fallback USB e encaminhamento de jogo/moeda/Start/menu através do leitor SNES completo. Falta teste físico desta nova variante nos três adaptadores.

### Saturn HDMI Bliss-Box com adaptador passivo

O utilizador identificou um SNAC Mini com protocolo original e autorizou preparar o perfil e o adaptador. A opção **Saturn cable** permite SNAC original (predefinido) ou **Bliss-Box (adapter)**. O segundo perfil exige o interposer documentado em `Saturn-BlissBox-adapter.md`: o Mini original não liga o pino HDMI 10 usado pelo cabo Saturn Bliss-Box. Não existe compatibilidade direta desse cabo com o Mini sem remapeamento físico.

O esquema do SNAC Mini é de blue212/SNAC, `snac/SNAC hdmi-mini.sch`. A ligação do cabo é a coluna Saturn da tabela do fabricante, publicada por ulao no tópico Cable pin-out diagram. Os links e a correspondência dos sinais estão no documento do adaptador. Os testes simulam os dois pinouts de forma independente, incluindo mudança do pinout com a porta libertada. Ainda é necessário verificar por continuidade o interposer montado e fazer o teste físico com o comando.
