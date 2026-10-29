# 1944: The Loop Master — LLAPI / SNAC experimental

Independent MiSTer-LLAPI integration of Jotego's CPS2 core, configured specifically for 1944 (Europe 000620). Original author notices and licenses are retained. This is not an official Jotego release. No game ROMs, keys or QSound firmware binaries are included; supply your own compatible 1944.zip and qsound.zip. The MRA references and loader metadata remain those of the official Euro MRA.

Requires a compatible MiSTer with at least 64 MB SDRAM for 1944's graphics. Keep the physical DE10-Nano SW1 OFF for SNAC, as the standard framework uses some USER pins for I2S when it is ON.

| USER / Serial port mode | Players |
| --- | --- |
| LLAPI 2P — default | 2 |
| SNAC SATURN 1P | 1 SNAC + optional USB / GAMEPORT P2 |
| SNAC DB9 1P (Mega Drive 3/6-button) | 1 SNAC + optional USB / GAMEPORT P2 |
| SNAC DB15 2P (Ultimate SNAC DB15) | 2 |
| SNAC SNES 2P | 2, with a compatible dual-port SNAC adapter |

The OSD pauses the game while open; closing it resumes unless manual pause is active. Physical hardware validation of this 1944 integration is pending. Tests of the 1943 version do not establish that 1944 works on hardware. Saturn is digital only; no Bliss-Box cable profiles, analog handshake or multitap.

Two game buttons: Shot and Bomb. SNES B shoots and A bombs; Select inserts that player's coin and Start starts that player. DB15 A/B are Shot/Bomb, Select/Start are per player. Mega Drive B shoots, A bombs, Mode (6-button) or Down+Start inserts a coin; release and use Start alone to start P1. Keyboard 5 inserts P1 coin; F5 lowers volume. The serial readers and existing LLAPI arcade start/coin convention are reused from 1943.

Menu: SNES Down+Start+B, DB15 Start+C, Mega Drive Down+Start+B and Saturn Down+Start+B. SNES two-player wiring: shared latch USER0, P1 clock/data USER1/5, P2 clock/data USER3/6. Use an adapter for the selected protocol. See preserved source notices for LLAPI and the original Jotego/Antonio Villena DB15 reader.

Install matching RBF into _Arcade/cores/ and MRA into _Arcade/. The 1944 pilot uses a separate RBF prefix and does not replace 1943. Compilation and strict setup/hold/recovery/removal/pulse-width checks must pass before an experimental download is published. Reports, source commit and SHA256 manifest accompany the binaries. Please support https://patreon.com/jotego.
