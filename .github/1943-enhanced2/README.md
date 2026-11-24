# 1943 Kai and 1943 Mark II

This Enhanced 2.1 integration adds the remaining official MiSTer sets from the 1943 family. The existing Enhanced 1943 release used to test the GamerPRO and the separate pilot binary stay in the catalogue.

| Game | MRA set | MRA audio gain |
| --- | --- | --- |
| 1943 Kai: Midway Kaisen (Japan) | `1943kai` | 0x60 |
| 1943: The Battle of Midway Mark II (US) | `1943mii` | 0x63 |
| 1943: The Battle of Midway, regional revisions | `1943`, `1943j`, `1943ja`, `1943jah`, `1943u`, `1943ua` | 0x51 |

All eight [official MRA files](https://github.com/jotego/jtbin/tree/d2274ea43a04af815ef987291aa385abe5324372/mra) map Shoot to A and Bomb to B. The [upstream cabinet logic](https://github.com/jotego/jtcores/blob/8bc8172993b9b9488cb45ee8a913090fc4d9b143/cores/1943/hdl/jt1943_main.v#L242) also accepts a third arcade input that presses Shoot and Bomb together for the plane's loop manoeuvre. The MRA labels, button layout, DIP settings, orientation, audio gain, ROM recipe and MCU data are preserved. The eight CI entries differ from the originals only in their `jt1943_llapi21` RBF reference.

The LLAPI protocol and the controller mapping are byte-identical to [Ricardo's verified 1943 build](https://github.com/MiSTer-LLAPI/jtcores/actions/runs/45251044250). LLAPI 2P is the default and Immediate Repoll is on. The dedicated Hold button, individual player speeds and original 1943 credits page are retained. Enhanced 2.1 adds the corrected pause credits selector and the SNAC per-button turbo toggle. Hold a game button and tap and release Start three times to toggle, then repeat to turn it off.

The workflow pins the [Jotego source](https://github.com/jotego/jtcores/tree/8bc8172993b9b9488cb45ee8a913090fc4d9b143) and the image used in its [official MiSTer 1943 build](https://github.com/jotego/jtcores/actions/runs/42940934819/job/130262743357). The Quartus banner must report Lite Edition 20.1.1 Build 720. Tests check the CPU-visible cabinet registers, two independent players and all six SNAC modes, and compare each MRA with its official SHA-256. The RBF is packaged only after all five timing categories pass.

The published `1943.mra` already loads the European `1943` set. The new catalogue addition selects the other seven setnames while retaining `1943.mra`, `jt1943_llapi10.rbf` and `1943-LLAPI-SNAC.rbf`.
