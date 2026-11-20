"""Simulate the patched System 32 input path with Icarus. Pass the core checkout."""
import re
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory


def main(core):
    top = (core / "S32.sv").read_text()
    qsf = (core / "S32.qsf").read_text()
    macros = re.findall(r'^set_global_assignment -name VERILOG_MACRO "([^"]+)"', qsf, re.M)
    assert not any("AUTOFIRE" in macro for macro in macros)
    menu = top.split("localparam CONF_STR =", 1)[1].split("};", 1)[0].lower()
    assert "autofire" not in menu
    assert all(field in menu for field in ("enhanced core: 1.0", "llapi driver: 0.5", "immediate repoll,on,off"))

    # Quartus allows early references to nets. Icarus needs these upstream
    # declarations before the first reference. Move only declarations in the
    # simulation copy, leaving all assignments, connections and logic intact.
    declaration = re.compile(
        r"^wire +(?:\[\d+:\d+\] +)?\w+(?: *, *\w+)*;|^reg dl_q = 0;", re.M
    )
    early = declaration.findall(top)
    top = declaration.sub("", top)
    header_end = top.index(");", top.index("module emu")) + 2
    with TemporaryDirectory() as temporary:
        tmp = Path(temporary)
        source = tmp / "S32.sv"
        source.write_text(top[:header_end] + "\n" + "\n".join(early) + top[header_end:])
        (tmp / "build_id.v").write_text('`define BUILD_DATE "test"\n')
        bench = Path(__file__).with_name("tb_controls.sv").resolve()
        output = tmp / "tb"
        # -i leaves unrelated video/CPU/PLL IP uninstantiated.
        subprocess.run(["iverilog", "-g2012", "-i", "-s", "tb_controls",
                        "-I", str(tmp), *["-D" + macro for macro in macros],
                        "-o", str(output), str(bench), str(source),
                        "enhanced/jtframe_serial_arcade.sv", "enhanced/jtframe_llapi_arcade.sv",
                        "enhanced/joydb15.v"], cwd=core, check=True)
        subprocess.run(["vvp", str(output)], check=True)


if __name__ == "__main__":
    main(Path(sys.argv[1]).resolve())
