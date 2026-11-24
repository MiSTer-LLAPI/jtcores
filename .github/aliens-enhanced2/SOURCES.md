# Konami Aliens Enhanced 2.1

The integration targets Jotego's five cartridge configurations for this board. It uses the official [jtcores source at 8bc81729](https://github.com/jotego/jtcores/tree/8bc8172993b9b9488cb45ee8a913090fc4d9b143/cores/aliens) and all 21 [jtbin game definitions at d2274ea4](https://github.com/jotego/jtbin/tree/d2274ea43a04af815ef987291aa385abe5324372/mra). Each MRA's SHA-256, cartridge header, button labels and game set are checked before compilation. Packaging changes only the RBF reference to `jtaliens_llapi21`.

The official [MiSTer build log](https://github.com/jotego/jtcores/actions/runs/42940934819/job/130262743430) records `jotego/jtcore20` with digest `sha256:a0397645aeac483f90718c89e5fd491c4889db6e4202bcba7f7f7770e14beb6b`. The Enhanced workflow pins that image, checks Quartus Prime Lite 20.1.1 Build 720 at runtime, and retains the compiler and timing reports with the future build. The synthesis project resolves 237 files, including the original Konami CPU and JT51 audio submodules.

## Cabinet controls

| Official MRA group | Variants | Action buttons |
| --- | ---: | --- |
| Aliens | 8 | Shoot standing, shoot crouching |
| Super Contra | 3 | Shoot, jump |
| Crime Fighters | 3 | Punch, kick, back kick |
| Gang Busters / Crazy Cop | 3 | Shoot, super shot |
| Thunder Cross | 4 | Shoot, option adjust |

Crime Fighters World and Japan use a two-player layout with three buttons and Start. The US four-player MRA has the same button labels. The [cabinet reference included by Jotego](https://github.com/jotego/jtcores/blob/8bc8172993b9b9488cb45ee8a913090fc4d9b143/cores/aliens/doc/crimfght.cpp#L216-L256) describes the US board with two buttons per player and four independent coin inputs. On hardware, test joining each position using its coin input. P1 and P2 can use LLAPI. P3 and P4 use native MiSTer inputs.

The default serial mode is LLAPI 2P. Immediate Repoll is on. Show Credits on Pause can be switched on and defaults to off. SNAC modes use the same three-tap Start gesture to enable and disable rapid fire for one held action. Releasing the action stops firing. Saturn, DB9, DB15 and SNES expose three cabinet actions; PCE and NES expose two. DB15, SNES and NES support testing P2 on the serial adapter.

## Verification and update scope

The family test writes the actual cartridge-header register, drives CPU bus reads through the five game configurations, and checks 640 mixed input cases. It exercises active-low direction order, every button combination, P1 through P4, individual coin and Start inputs, service, LLAPI's menu chord, two-player USB fallback, and SNAC turbo toggling and release on all supported ports. The shared tests cover credits and pause, controller names, mode changes and long-ACK repoll. These are simulations. Real-controller tests and Quartus acceptance belong to the candidate build.

The public [Update All index at 2e33302c](https://github.com/MiSTer-LLAPI/LLAPI_folder_MiSTer/tree/2e33302cfa76c1027762c96b08a78bc12f06826c) and the project's set/ROM filter select 19 new entries, including three main titles. Existing `Aliens.mra` and `Super Contra.mra` match their official counterparts by set name, assembled ROM MD5 and recipe. See `catalogue-selection.csv`. Run the same filter against the then-current index before promotion, preserving the existing entries and their core references.
