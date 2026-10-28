# Saturn Bliss-Box no SNAC Mini HDMI — adaptador passivo

Esta ligação destina-se ao **SNAC Mini HDMI original de blue212** e ao **cabo de entrada Saturn Bliss-Box**. Não é um cabo Bridge/output nem uma ligação de vídeo HDMI. O perfil do core chama-se `Bliss-Box (adapter)`.

## Porque é necessário

O esquema do Mini liga as linhas de sinal HDMI 1 a 7, mas não liga o pino 10 à FPGA. A tabela de cabos Bliss-Box coloca um dos sinais Saturn nesse pino 10. O adaptador abaixo encaminha a sétima linha disponível para esse sinal; o core trata da ordem dos outros sinais. Não há componentes ativos adicionais: mantém-se a conversão de níveis do SNAC Mini.

## Ligações do interposer (apenas Saturn)

Os números são **números dos contactos HDMI**, não posições visuais esquerda/direita. Usa as marcações/folha de dados dos conectores, pois o lado de solda e o lado de encaixe são espelhados.

| Lado SNAC Mini, HDMI | Lado cabo Saturn Bliss-Box, HDMI | Sinal | USER da FPGA |
| --- | --- | --- | --- |
| 1 | 1 | D0 | 0 |
| 2 | 2 | D1 | 1 |
| 3 | 3 | D2 | 2 |
| 4 | 4 | D3 | 3 |
| 5 | 5 | TL, entrada/libertada neste leitor digital | 5 |
| 6 | 6 | TR, seleção | 4 |
| 7 | **10** | TH, seleção | 6 |
| 15 | 15 | GND | — |
| 16 | 16 | +5 V do SNAC para o comando | — |

Deixa os restantes contactos sem ligação neste adaptador dedicado, incluindo o pino 7 do lado do cabo. Não ligues o pino 10 do cabo a uma alimentação. Não alteres a cablagem interna do Mini nem do cabo Bliss-Box.

Antes de ligar alimentação, confirma com um multímetro todas as ligações da tabela e a ausência de curto entre alimentação e massa. O esquema foi derivado das fontes abaixo e validado por modelos digitais; a montagem física ainda não foi testada.

## Menu e comandos

1. Liga o SNAC Mini à porta USER/SERIAL.
2. Liga este interposer entre o Mini HDMI e o cabo Saturn Bliss-Box.
3. No 1943, seleciona `Serial port: SNAC Saturn` e `Saturn cable: Bliss-Box (adapter)`.
4. Usa um comando Saturn digital, ou um 3D Pad na posição digital. O modo analógico não está implementado neste leitor.
5. Disparo B, bomba C, moeda L, Start para P1. Baixo + Start + B abre o menu. O primeiro comando USB fica disponível para P2.

Para um adaptador/cabo SNAC Saturn original, usa `Saturn cable: SNAC original` e não uses este interposer. O modo `Serial port: LLAPI` continua a ser a predefinição e usa hardware LLAPI, como BlisSTer.

## Fontes e rastreabilidade

- Esquema [SNAC Mini HDMI original](https://github.com/blue212/SNAC/blob/master/snac/SNAC%20hdmi-mini.sch): nets HV1..HV7 e contactos K3. Pino HDMI 10 sem ligação.
- [Tabela de cabos do fabricante Bliss-Box](https://docs.google.com/spreadsheets/d/1plzOQtVNC6zbs1Rfle_4Kdc9dmBwd9eQmhM2iDsm_eU/edit): coluna G, Saturn (L) #111, linhas 23–31; numeração da imagem do conector convertida para os sinais Saturn.
- [Publicação original de ulao](https://www.tapatalk.com/groups/blissbox/cable-pin-out-diagram-t303.html) que liga a tabela do fabricante.
- [Pinout do core Saturn oficial](https://github.com/MiSTer-devel/Saturn_MiSTer/blob/main/Saturn.sv): USERJOYSTICK/USERJOYSTICKOUT, para o perfil SNAC original.

Apenas a continuidade elétrica e um teste com o adaptador real confirmam a montagem final. Não é uma promessa de compatibilidade com variantes de hardware que alterem os pinouts acima.
