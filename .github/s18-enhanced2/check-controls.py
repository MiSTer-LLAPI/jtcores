"""Check the Enhanced input mux against the actual S18 ports and generated definitions."""
import importlib.util
import re
import sys
from pathlib import Path

support = Path(__file__).resolve().parent
core, menu, qsf = map(Path, sys.argv[1:])
checker = importlib.util.spec_from_file_location("checker", support / "verificar-autofire.py")
checks = importlib.util.module_from_spec(checker)
checker.loader.exec_module(checks)
defines = checks.generated_definitions(qsf)
assert defines["JTFRAME_BUTTONS"] == "4"
for key in ("DUAL_RATE", "JTFRAME_MOUSE", "JTFRAME_LIGHTGUN", "JTFRAME_DIAL", "JTFRAME_JOY_LRUD"):
    assert key in defines, key

options = checks.status_options(menu)
for field, bit in (("Video timing", 14), ("Sinden Lightgun", 31), ("Sinden Crosshair", 9)):
    assert [bits for label, _, bits in options if label == field] == [{bit}]
    assert [label for label, _, bits in options if bit in bits] == [field]
flags = [f"-D{key}={value}" for key, value in defines.items()]
framework = core / "modules/jtframe/target/mister/hdl/jtframe_mister.sv"
top = checks.preprocessed(framework, flags)
game = (core / "cores/s18/hdl/jts18_game.v").read_text()
assert re.search(r"assign\s+req_57Hz\s*=\s*status\[14\]", game)
assert re.search(r"gun_border_en\s*=\s*gun_border_selected\s*&&\s*lightgun_en", top)

def connection(source, port, signal):
    pattern = r"\." + port + r"\s*\(\s*" + re.escape(signal) + r"\s*\)"
    assert re.search(pattern, source), (port, signal)

for p in (3, 4):
    connection(top, f"joystick_{p-1}", f"joystick{p}")
    connection(top, f"board_joystick{p}", f"joystick{p}")
for signal in ("joystick1", "joystick2", "joystick3", "gun_1p_x", "gun_1p_y", "gun_2p_x", "gun_2p_y", "dial_x", "dial_y"):
    connection(game, signal, signal)
for signal in ("coin", "cab_1p"):
    connection(game, signal, signal+"[2:0]")
print("PASS S18 cabinet: native third player, two gun axes per player, trackball, independent timing and lightgun controls")
