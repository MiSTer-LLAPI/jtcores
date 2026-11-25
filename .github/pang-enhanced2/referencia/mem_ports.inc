`ifdef JTFRAME_SRAM
    output    [16:0]  sram_addr,
    output    [15:0]  sram_din,
    input     [15:0]  sram_dout,
    output            sram_wen,
    output    [ 1:0]  sram_dsn,
    input             sram_ok,
`endif
    // Audio channels
    
    output signed [13:0] pcm,
    output signed [15:0] fm,
    // Memory ports
`ifdef JTFRAME_SDRAM_XL
    input   [23:0]  prog_addr,
`elsif JTFRAME_SDRAM_LARGE
    input   [22:0]  prog_addr,
`else
    input   [21:0]  prog_addr,
`endif
    input   [ 7:0]  prog_data,
    input           prog_we,
    input   [ 1:0]  prog_ba,
`ifdef JTFRAME_SDRAM_XL
    input   [26:0]  ioctl_addr,
`else
    input   [25:0]  ioctl_addr,
`endif
    input           prom_we,
`ifdef JTFRAME_HEADER
    input           header,
`endif
`ifdef JTFRAME_IOCTL_RD
    input           ioctl_wr,
    output   [ 7:0] ioctl_din,
    input    [ 7:0] ioctl_dout, `endif
    input           ioctl_ram,
    input           ioctl_cart,
    // Explicit ports
    // Buses to BRAM

    // Buses to SDRAM
    input    [ 7:0] main_data,
    output          main_cs,
    output   [19:0] main_addr,
    input           main_ok,

    input    [ 7:0] pcm_data,
    output          pcm_cs,
    output   [17:0] pcm_addr,
    input           pcm_ok,

    input    [31:0] char_data,
    output          char_cs,
    output   [20:2] char_addr,
    input           char_ok,

    input    [31:0] obj_data,
    output          obj_cs,
    output   [17:2] obj_addr,
    input           obj_ok
