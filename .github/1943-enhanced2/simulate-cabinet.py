"""Verify the three-button 1943 interface, its original LLAPI implementation and its physical input map."""
from pathlib import Path
import hashlib
import importlib.util
import subprocess
import sys

root, generated, scratch = map(Path, sys.argv[1:])
support = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("verifier", support / "verificar-autofire.py")
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
defines = checker.generated_definitions(generated / "effective.qsf")
assert defines["JTFRAME_BUTTONS"] == "3"
assert defines["JTFRAME_CREDITS_PAGES"] == "1"
assert "JT1943_MCU_HLE" not in defines
hdl = root / "modules/jtframe/target/mister/hdl"
for name, expected in {
    "jtframe_llapi_protocol.sv": "33b37643c94f0f49c66c38504328821481f5f153ffd903a72f647b5cc89805aa",
    "jtframe_llapi_arcade.sv": "90d86d4fb9a81f4a60cb2167e91f5c95e2c5754780a2537bb936b5bdf97ca363",
}.items():
    assert hashlib.sha256((hdl / name).read_bytes()).hexdigest() == expected, name
flags = [f"-D{k}={v}" if v else f"-D{k}" for k,v in defines.items()]
image = scratch / "cabinet"
subprocess.run(["iverilog", "-g2012", "-i", "-s", "controls1943_tb", *flags,
                "-o", image, support / "cabinet_tb.sv", root / "cores/1943/hdl/jt1943_main.v",
                hdl / "jtframe_serial_arcade.sv", hdl / "jtframe_snac_turbo.sv",
                hdl / "jtframe_llapi_arcade.sv", hdl / "jtframe_llapi_protocol.sv",
                hdl / "joydb15.v"], check=True)
subprocess.run(["vvp", "-N", image], check=True)
