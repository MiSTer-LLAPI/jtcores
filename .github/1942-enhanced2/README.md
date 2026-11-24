# 1942, Pirate Ship Higemaru and Vulgus

This integration adds Enhanced 2.1 and LLAPI 1.0.0 to Jotego's three-board 1942 family. The game logic, ROM layouts, DIP switches and screen orientations come from the upstream core and MRAs.

| Board ID | Titles | Arcade action buttons |
| --- | --- | --- |
| 00 | 1942 and its revisions | A shoots, B rolls |
| 01 | Vulgus and Mach-9 | A shoots, B drops a bomb |
| 02 | Pirate Ship Higemaru | A performs the action |

The second header byte selects the orientation variant for Vulgus set 2 and Higemaru. In Vulgus the original Flip Screen DIP also acts on the picture. The SNAC mapper samples the board ID from the first game ROM byte. With Higemaru, pressing the unused second button and Start leaves Start available to the game. On each supported action button, hold the button and tap and release Start three times to toggle turbo. Repeat to turn it off.

## Reproducible inputs

- The workflow applies `enhanced.patch` to the [official jtcores revision](https://github.com/jotego/jtcores/tree/8bc8172993b9b9488cb45ee8a913090fc4d9b143).
- The 10 original MRAs are pinned to the [official jtbin snapshot](https://github.com/jotego/jtbin/tree/d2274ea43a04af815ef987291aa385abe5324372/mra). Their SHA-256 values are in `MRA-SHA256SUMS`. The package replaces only the RBF reference in each file with `jt1942_llapi21`.
- The [official MiSTer 1942 build](https://github.com/jotego/jtcores/actions/runs/42940934819/job/130262743398) used `jotego/jtcore20` at image digest `sha256:a0397645aeac483f90718c89e5fd491c4889db6e4202bcba7f7f7770e14beb6b`. The candidate workflow checks the Quartus banner for Lite Edition 20.1.1 Build 720 and retains seed and timing reports.
- The [original Enhanced 1942 build](https://github.com/MiSTer-LLAPI/jtcores/tree/bd628e9c067a7e7194accc5bb1bafd8fa1cac225) targeted the 1942 entry. The existing published MRA is `1942.mra` and uses `jt1942_llapi10.rbf`.

## Catalogue scope

After timing and artifact verification, the initial catalogue addition uses the nine new setnames. They are `higemaru`, `vulgus`, `vulgusj`, `vulgusa`, `mach9`, `1942a`, `1942b`, `1942w` and `1942h`. The full CI archive also contains the upstream entry for setname `1942` for verification. Its existing catalogue entry and RBF are retained for the later release migration.

## Pre-build test

Revision `74cf9e2b3cd20cb97ece4fa2b80f86b6f3f98fd1` passed the cabinet simulation for all three board IDs, including Vulgus set 2 with its alternate orientation header. The tests covered both players, all six SNAC interfaces and the extended ACK cases with repoll enabled and disabled.
