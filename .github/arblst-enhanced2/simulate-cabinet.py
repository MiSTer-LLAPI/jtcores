"""Test the generated Meta Fox build, from the MiSTer controls to both native bus decoders."""
from pathlib import Path
import importlib.util
import subprocess
import sys

root, generated, scratch = map(Path, sys.argv[1:])
support = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("verifier", support / "verificar-autofire.py")
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
defines = checker.generated_definitions(generated / "effective.qsf")
assert defines["JTFRAME_BUTTONS"] == "2" and "JTFRAME_JOY_RLDU" in defines
assert defines["JTFRAME_HEADER"] == "16"
flags = [f"-D{k}={v}" if v else f"-D{k}" for k,v in defines.items()]
frame = root / "modules/jtframe"
hdl = frame / "target/mister/hdl"
game = root / "cores/arblst/hdl"
kb = frame / "hdl/keyboard"
image = scratch / "cabinet"
subprocess.run(["iverilog", "-g2012", "-i", "-s", "seta_controls_tb", *flags,
                "-I",frame/"hdl/inc","-I",generated,"-I",game,"-o",image,support/"cabinet_tb.sv",
                game/"jtarblst_game.v",game/"jtarblst_sub.v",game/"jtarblst_main.v",
                kb/"jtframe_joysticks.v",kb/"jtframe_multiway.v",kb/"jtframe_beta_lock.v",
                frame/"hdl/jtframe_edge.v",hdl/"jtframe_serial_arcade.sv",hdl/"jtframe_snac_turbo.sv",
                hdl/"jtframe_llapi_arcade.sv",hdl/"jtframe_llapi_protocol.sv",hdl/"joydb15.v"],check=True)
subprocess.run(["vvp","-N",image],check=True)
