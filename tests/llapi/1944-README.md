# 1944 LLAPI + SNAC — free-button autofire experimental

Hold the autofire button to shoot repeatedly; release it to stop. This is not a toggle. Manual fire, bomb, the 1943 third-button loop, coin, Start and menu shortcuts retain their previous mappings.

LLAPI uses previously unused packet bit 3: SNES X and Mega Drive six-button Y in the current MiSTer-LLAPI SNES/Genesis reference cores. Custom adapter mappings can change the physical label. The existing 1944 bit-2 autofire alias is retained; 1943 bit 2 retains its original third-button loop. SNAC SNES uses X; SNAC Mega Drive six-button uses X only after a valid six-button handshake. Three-button Mega Drive controls are unchanged and do not gain autofire.

LLAPI 2P is the default. Other serial modes: SNAC SATURN 1P (digital only), SNAC DB9 1P (Mega Drive), SNAC DB15 2P (Ultimate SNAC DB15), SNAC SNES 2P (compatible dual-port adapter required). Keep DE10-Nano SW1 OFF. No Bliss-Box cable profile, analog Saturn handshake or multitaps. OSD pause is retained. No controller routing changes are included.

New free-button revisions require physical validation. UltimateMiSTer confirmed the previous 1944 autofire, LLAPI P1 and SNAC SNES 2P; the reported 1944 LLAPI port-2 issue is deferred. Previous 1943 controller modes and OSD pause were physically confirmed; its upstream credits page is intentionally static. Automated tests and Quartus timing checks do not establish hardware validation of this revision.

Install matching MRA and RBF together. Supply your own compatible game ROMs. No ROM data is included. Independent experimental MiSTer-LLAPI integration of Jotego's cores; original credits, licenses and source history are preserved. Please support https://patreon.com/jotego.

Mapping references: https://github.com/MiSTer-LLAPI/SNES_MiSTer/blob/master/SNES.sv and https://github.com/MiSTer-LLAPI/Genesis_MiSTer/blob/master/Genesis.sv
