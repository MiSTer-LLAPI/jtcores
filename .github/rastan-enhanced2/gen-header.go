// Generate the official Rastan ROM header register module from mame2mra.toml.
package main

import (
    "os"
    "path/filepath"

    "jotego/jtframe/macros"
    "jotego/jtframe/mra"
)

func main() {
    macros.MakeMacros("rastan", "mister")
    cfg, err := mra.ParseTomlFile("rastan")
    if err != nil { panic(err) }
    data, err := cfg.Header.MakeVerilog("rastan")
    if err != nil { panic(err) }
    target := filepath.Join(os.Getenv("CORES"), "rastan", "hdl", "jtrastan_header.v")
    if err := os.WriteFile(target, data, 0644); err != nil { panic(err) }
}
