# Sega System 16A Enhanced 2.1

The candidate uses LLAPI 1.0.0 and the original System 16A game hardware from Jotego revision `8bc8172993b9b9488cb45ee8a913090fc4d9b143`. The 34 regional game entries come from jtbin revision `d2274ea43a04af815ef987291aa385abe5324372`. Each packaged MRA differs from the original only in its core reference.

LLAPI 2P is the default serial mode. Immediate Repoll stays on. The credits selector defaults to Off. To program an action on a supported SNAC pad, hold the action and tap Start three times. Repeat the gesture to restore manual input. Analog axes, trackball inputs and the conventional third and fourth player inputs follow the original cabinet.

The Japanese four-player Passing Shot MRA contains board identifier 0x02. The System 16A cabinet decoder now recognizes it alongside its existing identifier. The cabinet simulation checks that each of the four controller ports supplies its own buttons to the game. Other checks exercise standard digital inputs, Quartet, Action Fighter analog controls, the SDI trackball, and the Time Scanner auxiliary DIP switches. The official MRA records the original names and number of exposed buttons for each variant.

Jotego's official System 16A job used the jtcore20 image with digest `a0397645aeac483f90718c89e5fd491c4889db6e4202bcba7f7f7770e14beb6b`. The candidate requires Quartus Prime Lite 20.1.1 build 720 and checks every reported worst-case timing category before packaging. [Official compiler job](https://github.com/jotego/jtcores/actions/runs/42940934819/job/130262750571)
