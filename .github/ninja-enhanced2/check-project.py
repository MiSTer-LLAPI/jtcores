"""Verify the generated synthesis project on the host that runs the FPGA simulations."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


root = Path(sys.argv[1]).resolve()
support = Path(__file__).resolve().parent
project = root / "cores/ninja/mister"
hdl = root / "modules/jtframe/target/mister/hdl"
cfgstr = project / "cfgstr.hex"
qsf = project / "jtninja.qsf"

# Quartus runs inside a container in CI. The same project is mounted at /jtcores.
entries = []
for line in (project / "files.qip").read_text().splitlines():
    if line.startswith("set_global_assignment -name "):
        path = Path(line.split(" ", 3)[-1].strip('"'))
        if path.is_relative_to("/jtcores"):
            path = root / path.relative_to("/jtcores")
        if not (project / path).is_file():
            raise SystemExit(f"missing QIP source {path}")
        entries.append(path.name)
for required in ("jtninja_game_sdram.v", "jtcop_game.v", "llapi_arcade.sdc",
                 "jtframe_serial_arcade.sv", "jtframe_llapi_protocol.sv", "jtframe_cab_stream.v"):
    if required not in entries:
        raise SystemExit(f"{required} missing from synthesis QIP")
print(f"PASS {len(entries)} QIP source assignments including DEC0, SDRAM, hardware regression and LLAPI", flush=True)

flags = []
for line in qsf.read_text().splitlines():
    macro = re.fullmatch(r'set_global_assignment -name VERILOG_MACRO "(.*)"', line.strip())
    if macro:
        flags.append("-D" + macro.group(1))
if "-DJTFRAME_CREDITS_PAGES=3" not in flags:
    raise SystemExit("expected the three credit pages selected by the project")
pages = [(project / f"msg{page}.hex").read_text().splitlines() for page in range(3)]
if any(len(page) != 1024 for page in pages) or sum(pages, []) != (project / "msg.hex").read_text().splitlines():
    raise SystemExit("generated credit pages do not match the selected credit ROM")
print("PASS three complete credit pages in the project", flush=True)
modules = [hdl / file for file in ("jtframe_mister.sv", "jtframe_serial_arcade.sv",
    "jtframe_llapi_arcade.sv", "jtframe_llapi_protocol.sv", "joydb15.v",
    "jtframe_mister_status.v", "jtframe_mister_dwnld.v", "sys/hps_io.sv")]
with tempfile.TemporaryDirectory() as tmp:
    # Elaborate the actual host and controller interfaces. JTFRAME subblocks and
    # FPGA vendor primitives outside this interface remain black boxes here.
    test_image = Path(tmp) / "mister.vvp"
    subprocess.run(["iverilog", "-g2012", "-i", "-s", "mra_profile_tb", "-o",
                    test_image, *flags, support / "mra_profile_tb.sv", *modules,
                    root / "modules/jtframe/hdl/jtframe_board.v"], cwd=project, check=True)
    for mra in sorted((support / "mras").rglob("*.mra")):
        game = ET.parse(mra).getroot()
        profile, volume = bytes.fromhex(game.findtext("rom[@index='1']/part"))
        rotary = int("Turn left" in game.find("buttons").attrib["names"].split(","))
        subprocess.run(["vvp", "-N", test_image, f"+mod={profile:02x}", f"+vol={volume:02x}",
                        f"+rotary={rotary}"], cwd=project, check=True)
print("PASS elaboration of MiSTer, HPS, board and serial integration", flush=True)

for test, top in (("autofire_tb.sv", "autofire_tb"), ("snac_controls_tb.sv", "snac_readers_tb"),
                  ("rotary_modifier_tb.sv", "rotary_modifier_tb")):
    subprocess.run([sys.executable, support / "verificar-autofire.py", cfgstr, qsf,
                    hdl / "jtframe_mister.sv", "--tb", support / test, "--top", top], check=True)
subprocess.run([sys.executable, support / "check.py", "menu", cfgstr], check=True)
