# 1943 — piloto LLAPI arcade

**Versão experimental para MiSTer.** Ainda exige teste físico com BlisSTer/LLAPI.

Base: [jotego/jtcores](https://github.com/jotego/jtcores), commit `b222692d4c0c9a26a6cb3c99c6820b1ed4a5d565`.
Protocolo e convenções arcade: [MiSTer-LLAPI/Arcade-IremM62_MiSTer](https://github.com/MiSTer-LLAPI/Arcade-IremM62_MiSTer), commit `4d63703988cfb2b8256fc3bdb1a4a09b39cceaba`.

O jogo, vídeo, som, créditos e licença do Jotego são preservados. O protocolo LLAPI mantém os tempos, comandos e formato arcade existentes. Foram corrigidos apenas aspetos de sintaxe SystemVerilog do ficheiro original: uma vírgula final numa concatenação, as declarações dos dois outputs procedimentais, as atribuições combinacionais e um ternário de enum substituído por if/else equivalente. A ponte acrescenta sincronizadores nos sinais que passam entre 50 MHz e o relógio do jogo.

A opção `JTFRAME_LLAPI` só está ativa no 1943/MiSTer. Os restantes cores e plataformas mantêm o funcionamento original. A porta USER fica reservada ao LLAPI; DB15 e UART nessa porta ficam indisponíveis neste piloto.

## Instalação

1. Preserva o core e o MRA oficiais que já tens.
2. Copia `cores/jt1943_llapi_20261028_test.rbf` para `_Arcade/cores/` no cartão da MiSTer.
3. Copia `mra/1943-LLAPI-Test.mra` para uma pasta de testes em `_Arcade/`.
4. Usa o teu conjunto `1943.zip` compatível com o MRA Euro oficial. Não estão incluídas ROMs neste projeto.
5. Abre o MRA identificado como **LLAPI TEST** e começa com uma configuração nova.

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
