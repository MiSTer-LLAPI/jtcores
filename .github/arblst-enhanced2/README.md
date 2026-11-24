# Meta Fox

Meta Fox uses the same Jotego core as Arbalester. The first game-ROM header byte selects the board. It is 00 for Meta Fox and 01 for Arbalester. Each game has two action buttons, Shot and Bomb. The two [official MRAs](https://github.com/jotego/jtbin/tree/d2274ea43a04af815ef987291aa385abe5324372/mra) retain their ROM recipes, DIP settings, vertical screen orientation and player controls. The CI package changes only their core reference to `jtarblst_llapi21`.

Enhanced 2.1 includes the corrected pause credits selector, LLAPI 1.0.0 and per-button SNAC turbo. Hold Shot or Bomb, then press and release Start three times. Repeating the gesture disables turbo for that button. In the Autofire menu, the separate dedicated Hold function repeats Shot.

The cabinet simulation drives LLAPI and SNAC through JTFRAME's real rotation and direction-order logic and into the secondary processor. It checks both player ports at 0x1002 and 0x1006, coins at 0x1000 and the status value at 0x1004. It also checks the board-specific tile origins and the reads used by the Meta Fox startup test. The original game and video HDL come directly from the [pinned Jotego source](https://github.com/jotego/jtcores/tree/8bc8172993b9b9488cb45ee8a913090fc4d9b143/cores/arblst).

The workflow uses the container digest recorded in [Jotego's official Arbalester/Meta Fox MiSTer build](https://github.com/jotego/jtcores/actions/runs/42940934819/job/130262743834) and checks for Quartus Prime Lite Edition 20.1.1 Build 720. The RBF is packaged after checks on setup, hold, recovery, removal and minimum pulse width.

The initial catalogue addition selects only `metafox`. The existing `Arbalester.mra` and `jtarblst_llapi10.rbf` remain on the published version until their migration.
