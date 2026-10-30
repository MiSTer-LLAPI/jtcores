# MiSTer-LLAPI — 1943 and 1944 controller support

This fork adds selectable LLAPI and SNAC controllers to **Jotego's 1943: The Battle of Midway (Euro)** on MiSTer. The 1943 integration is described below; a separate 1944 CPS2 integration with hold-to-autofire is also available. These integrations do not add LLAPI to every game in jtcores.

[Download the current experimental release](https://github.com/MiSTer-LLAPI/jtcores/releases/tag/v1943-llapi-snac-20261030-freebuttons-experimental) · [Integration source](https://github.com/MiSTer-LLAPI/jtcores/tree/llapi-1943-test) · [LLAPI Update All folder](https://github.com/MiSTer-LLAPI/LLAPI_folder_MiSTer)

The current build automatically pauses while the OSD menu is open and resumes when it closes. A manual pause remains active after closing OSD. The OSD-pause change passed regression tests and timing checks and was physically confirmed working by UltimateMiSTer. The 1943 credits page is intentionally static, as in upstream Jotego.

| USER / Serial port mode | Players |
| --- | --- |
| **LLAPI 2P — default** | 2 |
| SNAC SATURN 1P | 1 SNAC + optional USB / GAMEPORT P2 |
| SNAC DB9 1P (Mega Drive) | 1 SNAC + optional USB / GAMEPORT P2 |
| SNAC DB15 2P (Ultimate SNAC DB15) | 2 |
| SNAC SNES 2P | 2, with a compatible dual-port SNAC adapter |

LLAPI uses a dedicated USER-port controller path and synchronizes polling to the core's frame timing. No measured end-to-end latency claim is made. Only the selected protocol owns the physical port. The original Jotego DB15 splitter is retained. The Bliss-Box Saturn cable profile is currently removed.

The SNES two-player adapter needs shared latch USER0, P1 clock/data USER1/USER5 and P2 clock/data USER3/USER6. B shoots, A bombs, Select inserts the corresponding coin and Start starts that player. Down+Start+B opens the menu from either SNES controller. DB15 uses Select/Start per player and Start+C for the menu. See the release instructions for all modes.

Automated controller tests, FPGA compilation and all required timing checks passed. **The preceding SNES 2P build was physically tested and confirmed working by UltimateMiSTer in all controller modes: LLAPI 2P, SNAC SATURN 1P, SNAC DB9 1P (Mega Drive three-button and six-button), SNAC DB15 2P (Ultimate SNAC DB15), and SNAC SNES 2P.** Saturn support is digital only; analog 3D handshake, multitaps and Bliss-Box cable profiles are not included.

Install through Update All with LLAPI enabled, or download the RBF and MRA together from the release. Supply your own compatible game ROMs; no ROM data is included. Reselect the serial-port mode after upgrading from earlier pilots.

### Mega Drive controls — hardware tested

Both three-button and six-button Mega Drive controllers have been tested successfully by UltimateMiSTer. On a six-button controller, **Mode inserts a coin**. On either controller, **Down+Start inserts a coin**; release the combination, then press **Start alone to start P1**. Start was confirmed working on both controller types. **Keyboard: press 5 to insert a P1 coin (not F5; F5 lowers the volume).**

This is an independent experimental MiSTer-LLAPI fork, not an official Jotego release. Original authorship, history, source notices and licenses are preserved below and throughout the repository. Please support Jotego's FPGA research.

## Hold-to-autofire — 1943 and 1944

Both current experimental builds add autofire while preserving the previous shot, bomb, 1943 third-button loop, coin, Start and menu mappings. **Hold the autofire button to shoot repeatedly; release it to stop.** It is not a toggle. Manual firing remains available; OSD inhibits firing.

| Controller path | Autofire button |
| --- | --- |
| LLAPI SNES | X (packet bit 3 in the current SNES reference core) |
| LLAPI Mega Drive six-button | Y (packet bit 3 in the current Genesis reference core) |
| SNAC SNES | X |
| SNAC Mega Drive six-button | X, after a valid six-button handshake |

LLAPI adapters with custom or alternate mappings may use a different physical label. Packet bit 3 was unused by the preceding arcade mapping. The 1943 bit-2 third-button loop remains unchanged; the already tested 1944 bit-2 autofire alias is retained. Mega Drive three-button controls remain unchanged and do not gain autofire. Other SNAC modes retain their prior controls without a new autofire assignment.

Both revisions passed controller regression tests, FPGA compilation and timing checks. **Physical validation of these new free-button revisions is pending.** UltimateMiSTer confirmed the earlier 1944 autofire; that confirmation does not establish hardware validation of the added mappings. Previous 1943 controller modes and OSD pause were physically confirmed as described above. The reported 1944 LLAPI port-2 issue is deferred; routing is unchanged in these revisions.

## 1944: The Loop Master — experimental hold-to-autofire

[Download 1944 with autofire](https://github.com/MiSTer-LLAPI/jtcores/releases/tag/v1944-llapi-snac-20261030-freebuttons-experimental) · [1944 source and controls](https://github.com/MiSTer-LLAPI/jtcores/blob/llapi-1944-test/tests/llapi/1944-README.md)

Available through **Update All with LLAPI enabled**, using `_LLAPI/_Arcade/1944-LLAPI-Test.mra`. Install the matching MRA and RBF together when downloading manually. Requires at least 64 MB SDRAM; no game ROMs or keys are included.

See the shared autofire table above for LLAPI and SNAC button assignments. Both 1943 and 1944 now include hold-to-autofire on available buttons.

The 1944 build offers the same LLAPI/Saturn/DB9/DB15/SNES serial modes listed above. **UltimateMiSTer confirmed LLAPI P1 and SNAC SNES 2P on the preceding build. LLAPI port 2 has a reported issue and is deferred; this revision does not change its routing.** The earlier autofire was physically confirmed by UltimateMiSTer. This new free-button revision passed automated tests, FPGA compilation and timing checks; physical validation of its added mappings is pending. Do not treat all 1944 controller modes as hardware validated.

---

# JTCORES FPGA Arcade Hardware by Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

Yes, you always wanted to have an arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, JT cores are here to the rescue.

I hope you will have as much fun with this project as I had while working on it!

## Wanna play?

You can find the list of supported games in [jtbin/game_list](https://github.com/jotego/jtbin/blob/master/game_list.md). That list is actually an output of the source code of this repository and gets updated every release. There are 1250+ supported titles at the moment ( September 2026 ).

The compiled versions for some FPGA platforms are in [JTBIN](https://github.com/jotego/jtbin). Most cores are released early for [patrons](https://patreon.com/jotego) so check it out too. [JTFRAME](modules/jtframe/README.md) supports more FPGA platforms than the ones publised in JTBIN. You are welcome to compile the cores for the other platforms. Distribution of the core binary files together with copyrighted ROM files is not permitted.

# Compilation - JTFRAME

Refer to [JTFRAME](modules/jtframe/README.md) for compilation instructions and general information about how the cores are organized.

## Private Support Files

Set the `JOTEGO` environment variable to the directory used for private JTCORES support files, including core-regression and scene-regression data used by privately run GitHub Actions. Scene data is stored below `$JOTEGO/scenes/<core-name>/<set-name>`.

When `jtsim -s <scene>` is run from a core verification folder such as `cores/rastan/ver/rbisland`, it requires `JOTEGO` and creates `scenes` as a symbolic link to `$JOTEGO/scenes/rastan/rbisland`. Define `JOTEGO` before running scene simulations.

Master branch health:
[![Compile all MiSTer cores](https://github.com/jotego/jtcores/actions/workflows/compile_mister.yaml/badge.svg)](https://github.com/jotego/jtcores/actions/workflows/compile_mister.yaml)
[![Verilator linter](https://github.com/jotego/jtcores/actions/workflows/linter.yaml/badge.svg)](https://github.com/jotego/jtcores/actions/workflows/linter.yaml)
[![Unit tests](https://github.com/jotego/jtcores/actions/workflows/simunit.yaml/badge.svg)](https://github.com/jotego/jtcores/actions/workflows/simunit.yaml)

# Schematics

Some core have KiCAD schematics for the arcade PCB. This is part of the core research effort and it is important on its own. The schematics folders are called *sch* and can be found in some core folders.

All schematics use the same set of symbol components from [JTKICAD](modules/jtkicad/README.md)

## Troubleshooting

* If you have in-game problems, please read the text file specific to that core. Sometimes it's just that the games has more buttons than you think
* Continue the game: some early arcade games require you to hold the fire button while pressing 1P to continue

## Keyboard

For MiST and MiSTer: games can be controlled with both game pads and keyboard. The keyboard follows the same layout as MAME's default.

    F2      Service mode
    F3      Game reset
    T       Tilt
    P       Pause (in some games, you can disable the credits screen by pressing 1P)
    1,2,3,4 1P..4O start buttons
    5,6     Left and right coin inputs
    9       Service

    cursors 1P direction
    CTRL    1P button 1
    ALT     1P button 2
    space   1P button 3

    R,F,G,D 2P direction
    Q,S,A   2P buttons 3,2 and 1

# Credits

Jose Tejada Gomez. Twitter @topapate
The project is hosted in http://www.github.com/jotego/jtcores
License: GPL3, you are obligued to publish your code if you use mine


Thank you all!
```
+--------------------------------------------------------------------------------+
|oooooooooooooooooooooooooooooooooo+++++++++++ooooooooooooooooooooooooooooooooooo|
|ooooooooooooooooooooooooooooooooo+. .    . .+ooooooooooooooooooooooooooooooooooo|
|ooooooooooooooooooooooooooooooooo~         :o++ooooooooooooooooooooooooooooooooo|
|oooooooooooooooooooooooooooo+ooo+.        .++.:oo+oo+oooooo+o+oo+oooooo++ooooooo|
|ooooooooooooooooooooooooo+.......          .. .............................:oooo|
|oooooooooooooooooooooooo+.                                                .+o+oo|
|oooooooooooooooooooooooo:                                                 :o:.+o|
|ooooooooooooooooooooooo+.                                                .++.:oo|
|ooooooooooooooooooooooo:.....           ...........          ....... ....:o~.+oo|
|oooooooooooooooooooooooo+++++~         ~+++:++:++++.         ++++++++++++++.+ooo|
|oooooooooooooooooooooooooo+:~         .++.~:::::::.         .o+.~:::::::::::+ooo|
|oooooooooooooooooooooooooooo:         :o~.+oooooo+.         ++.~oooooooooooooooo|
|ooo~........~oooooooooooooo+.        .++.:ooooooo+         ~o:.+oooooooooooooooo|
|oo:         ~o++ooooooooooo.         +o~.ooooooo+.        .++.~ooooooooooooooooo|
|oo.         :+.:ooooooooo+.         ~o+.+ooooooo:         ~o:.+ooooooooooooooooo|
|oo.         ...~:::::::..          .++.~ooooooo+.        .o+.:oooooooooooooooooo|
|oo~                               ~o+..+ooooooo~         +o~.+oooooooooooooooooo|
|oo+.                           .~+o+..+ooooooo+.        .o+.+ooooooooooooooooooo|
|oooo~.                       .:+o+..:+oooooooo.         +o..oooooooooooooooooooo|
|ooooo+:...              ..~:+++:..:+ooooooooo+         .o+.+oooooooooooooooooooo|
|ooooooo+++::::::::::++++++++~~.~++ooooooooooo+:+:::::+:++.~ooooooooooooooooooooo|
|ooooooooo+++:::::::::~:~~~~:++oooooooooooooooooo+::::~::~.+ooooooooooooooooooooo|
|oooooooooooooo+o+oo++++o+ooooooooooooooooooooooo+o+++o++o+oooooooooooooooooooooo|
+--------------------------------------------------------------------------------+
```


