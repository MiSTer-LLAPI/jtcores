# Saturn Bliss-Box no SNAC Mini HDMI

Dois modos diferentes para comandos Saturn **digitais**. Esta variante do 1943 não implementa o handshake analógico do 3D Pad.

## A. Ligação direta (perfil Bliss-Box HDMI digital)

SNAC Mini HDMI original → cabo de entrada Saturn Bliss-Box → comando digital. Seleciona `Serial port: SNAC Saturn` e `Saturn cable: Bliss-Box HDMI digital`.

| Sinal Saturn | Pino Saturn | HDMI do cabo Bliss-Box | USER no Mini |
| --- | --- | --- | --- |
| D0 | 3 | 1 | 0 |
| D1 | 2 | 2 | 1 |
| D2 | 8 | 3 | 2 |
| D3 | 7 | 4 | 3 |
| TH | 4 | 5 | 5 |
| TR | 5 | 6 | 4 |
| TL | 6 | 10 | sem ligação |
| GND | 9 | 15 | massa |
| VCC | 1 | 16 | +5 V |

TL está no contacto HDMI10, que o Mini original não encaminha para a FPGA. Este leitor digital usa quatro fases comandadas por TH/TR e lê D0..D3; não usa TL. Por isso o perfil digital pode ser implementado sem remapeamento físico. A confirmação com cabo/comando reais ainda está pendente. O cabo não passa a suportar periféricos analógicos apenas por selecionar este perfil.

## B. Interposer passivo completo (perfil SNAC original)

Este interposer dedicado encaminha **os sete sinais**, incluindo TL, e adapta o cabo Bliss-Box à disposição SNAC Saturn original. Continua a ser necessário usar um leitor/core com suporte ao periférico pretendido; o leitor 1943 desta variante continua a ser apenas digital.

Os números abaixo são **números dos contactos HDMI**, não posições visuais esquerda/direita. Usa as marcações/folha de dados dos conectores: o lado de solda e o lado de encaixe são espelhados.

| Lado SNAC Mini, HDMI | Lado cabo Saturn Bliss-Box, HDMI | Sinal | USER |
| --- | --- | --- | --- |
| 1 | 2 | D1 | 0 |
| 2 | 1 | D0 | 1 |
| 3 | **10** | TL | 2 |
| 4 | 4 | D3 | 3 |
| 5 | 3 | D2 | 5 |
| 6 | 5 | TH | 4 |
| 7 | 6 | TR | 6 |
| 15 | 15 | GND | — |
| 16 | 16 | +5 V do SNAC para o comando | — |

Deixa os restantes contactos sem ligação neste adaptador dedicado. Não ligues o contacto 10 do cabo a uma alimentação. Mantém a conversão de níveis do SNAC Mini; não há componentes ativos adicionais nem alteração da cablagem interna do Mini ou cabo. Trata-se do cabo **de entrada** Bliss-Box, não de um cabo Bridge/output.

Com o interposer, seleciona `Saturn cable: SNAC original`. **Não uses o perfil Bliss-Box direto juntamente com este interposer**, pois o remapeamento já foi feito pelo adaptador.

Antes de alimentar, confirma com um multímetro todas as ligações e a ausência de curto entre alimentação e massa. A tabela foi derivada das fontes abaixo; a montagem física ainda não foi testada.

## Comandos no 1943

Disparo B, bomba C, moeda L, Start para P1. Baixo + Start + B abre o menu. O primeiro comando USB fica disponível para P2. LLAPI continua a predefinição da porta USER/SERIAL.

## Fontes e rastreabilidade

- [SNAC Mini HDMI original](https://github.com/blue212/SNAC/blob/master/snac/SNAC%20hdmi-mini.sch): nets HV1..HV7 e contactos K3; HDMI10 sem ligação.
- [Tabela Bliss-Box](https://docs.google.com/spreadsheets/d/1plzOQtVNC6zbs1Rfle_4Kdc9dmBwd9eQmhM2iDsm_eU/edit): coluna G, Saturn (L) #111, linhas 23–31. A imagem usa ordem inversa à numeração Saturn: pos1 é GND/pino9 e pos9 é VCC/pino1.
- [Publicação original de ulao](https://www.tapatalk.com/groups/blissbox/cable-pin-out-diagram-t303.html), que liga a tabela do fabricante.
- [Pinout e sinais Saturn, Plutiedev](https://www.plutiedev.com/io-pinout): TH=pino4, TR=pino5, TL=pino6. Não confundir TL com TH.
- [Core Saturn oficial](https://github.com/MiSTer-devel/Saturn_MiSTer/blob/main/Saturn.sv): USERJOYSTICK/USERJOYSTICKOUT, para o perfil SNAC original.

Os testes de simulação verificam as duas permutações e os quatro grupos de dados do pad; apenas o teste real confirma o comportamento do adaptador/comando montado. Não se presume compatibilidade com placas/cabos que alterem estes pinouts.
