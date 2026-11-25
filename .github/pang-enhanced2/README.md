# Pang Enhanced 2.1 / LLAPI 1.0.0

Candidato para sete entradas digitais novas. A origem do core é `jotego/jtcores@8bc8172993b9b9488cb45ee8a913090fc4d9b143`. Os dez MRAs de referência são de `jotego/jtbin@d2274ea43a04af815ef987291aa385abe5324372`.

| Placa | Entradas selecionadas | Controlos |
| --- | --- | --- |
| Super Pang | World, Japan e Super Buster Bros. USA | Direções e ações. A inicialização da EEPROM segue a lógica oficial. |
| Dokaben e Dokaben 2 | Japan, um MRA por jogo | Direções e duas ações. |
| Capcom World | Japan | As quatro direções permitem escolher as quatro respostas. Comandos LLAPI/SNAC com quatro botões disponíveis também podem usar os quatro botões. O atalho Start ×3 funciona nos botões SNAC. O perfil desativa o Hold do menu para manter a quarta resposta independente da primeira. |
| Block Block | World 911219 Joystick | Placa digital identificada pelo valor 3 no byte 15 do cabeçalho. |

Os ficheiros `blockj`, `blockr1` e `blockr2` estão nas referências locais para testes de dial. Todos selecionam o perfil 1 do hardware, incluindo a revisão 911106 cujo título diz “Joystick”. O empacotamento seleciona os sete perfis digitais e muda unicamente a referência ao RBF. O Pang já publicado segue na sua versão anterior.

O hardware expõe uma entrada de moeda partilhada. A integração Enhanced aceita a moeda de qualquer uma das duas portas. O RBF previsto chama-se `jtpang_llapi21.rbf`.

## Verificação local

O registo das simulações executadas está em `validacao-local.txt`. Com a fonte oficial e `enhanced.patch` aplicado, `simulate.sh <jtcores>` verifica os MRAs, o registo do armário, os créditos na pausa e os sinais dos seis protocolos SNAC. O teste `verificar-autofire.py <cfgstr.hex> <defines.qsf> <jtframe_mister.sv>` usa as definições geradas para repetir as verificações entre a entrada de comando e o barramento do Z80, com o seletor de interface e perfil de ROM reais.

O fluxo oficial MiSTer usa a imagem `jotego/jtcore20`. O registo de compilação do Pang anterior identifica Quartus Prime Lite 20.1.1 Build 720. O fluxo de 2.1 regista e compara a versão executada, exige o relatório de temporização e verifica as cinco categorias de margem antes de gerar o pacote. Nesta preparação local foram verificados os 244 ficheiros do projeto de síntese. A compilação FPGA e a validação na MiSTer estão pendentes.
