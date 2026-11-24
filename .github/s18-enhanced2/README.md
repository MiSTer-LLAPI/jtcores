# System 18 Enhanced 2.1

This candidate uses LLAPI 1.0.0 and the thirty original [Jotego game descriptions](https://github.com/jotego/jtbin/tree/d2274ea43a04af815ef987291aa385abe5324372/mra). The build checks each description against its recorded SHA-256 and changes the RBF reference for installation.

The local test of revision `03aa05a7c8c2cbb5942322e57487eed2d0098783` resolved all 313 generated synthesis file references, including the SDRAM interface and 8051 microcode. It exercised the third-player input, two lightguns, the trackball, the original video timing control, both LLAPI ports, and the six SNAC selections. The original three input paths also apply to the D. D. Crew four-player variant.

The workflow uses the pinned Jotego toolchain and verifies the Quartus Lite 20.1.1 Build 720 banner. It packages the core after timing analysis and saves the compiler and timing reports as separate artifacts. Real controller and display behavior still needs a MiSTer test.
