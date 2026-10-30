# 1943 LLAPI + SNAC — hold autofire experimental

Hold X on a SNES controller via LLAPI or SNAC SNES for autofire; release X to stop. This is not a toggle. The pulse timing is the same as the hardware-tested 1944 autofire implementation (three frames per half-period, about 10 shots per second). X is reserved for autofire and does not activate the 1943 third-button loop shortcut through LLAPI. Manual firing, bomb and menu shortcuts remain available. Other controller modes keep their previous mappings.

LLAPI 2P is the default. Serial modes: LLAPI 2P; SNAC SATURN 1P; SNAC DB9 1P (Mega Drive 3/6-button); SNAC DB15 2P (Ultimate SNAC DB15); SNAC SNES 2P with a compatible dual-port adapter. Saturn is digital only; no Bliss-Box cable profile, analog 3D handshake or multitap. Keep DE10-Nano SW1 OFF.

The game pauses while OSD is open and resumes when it closes, preserving manual pause. The original upstream 1943 credits page is static by design. All controller modes and OSD pause were physically confirmed by UltimateMiSTer in preceding 1943 builds. UltimateMiSTer physically confirmed the same hold-autofire feature on 1944. This new 1943 autofire build still requires physical validation; successful automated tests and timing checks do not establish hardware validation of this revision.

SNES: B shoots, A bombs, X held autofires, Select inserts that player's coin, Start starts that player, Down+Start+B opens OSD. SNES dual-port wiring: shared latch USER0; P1 clock/data USER1/USER5, P2 USER3/USER6. DB15 retains Jotego's original reader and pinout; Select/Start per player, Start+C opens OSD. Mega Drive: Mode (6-button) or Down+Start inserts a coin, release then Start alone starts P1. Keyboard 5 inserts P1 coin; F5 lowers volume.

Install the matching MRA and RBF together, in _Arcade/ and _Arcade/cores/. The LLAPI Update All entry is _LLAPI/_Arcade/1943-LLAPI-Test.mra once its catalogue update is verified. Supply your own compatible Euro 1943.zip. No ROM data is included.

Independent experimental MiSTer-LLAPI integration of Jotego's core. Original credits, licenses, LLAPI notices and source history are preserved. Please support https://patreon.com/jotego.
