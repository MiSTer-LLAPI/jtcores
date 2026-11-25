#!/usr/bin/env python3
"""Check the generated MiSTer OSD against the RTL selected by the Quartus definitions."""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile

FIELDS = {
    "P1 Autofire": ("autofire_enable", ("Off", "Hold")),
    "P2 Autofire": ("autofire_enable2", ("Off", "Hold")),
    "P1 Speed": ("autofire_rate1", ("Normal", "Slow", "Fast")),
    "P2 Speed": ("autofire_rate2", ("Normal", "Slow", "Fast")),
}
OPTION = re.compile(
    r"(?:[hHdD][0-9A-V]|P[0-9A-V])*([OoRrTt])"
    r"(?:\[(\d+)(?::(\d+))?\]|([0-9A-V])([0-9A-V])?)"
)
STATUS = re.compile(r"\bstatus(?:_full)?\s*\[\s*(\d+)(?:\s*:\s*(\d+))?\s*\]")
ASSIGNMENT = re.compile(r'set_global_assignment\s+-name\s+VERILOG_MACRO\s+"(\w+)=(.*)"')


def generated_definitions(path):
    defines = {}
    for line in path.read_text().splitlines():
        if "VERILOG_MACRO" not in line or line.lstrip().startswith("#"):
            continue
        m = ASSIGNMENT.fullmatch(line.strip())
        if not m:
            raise ValueError(f"unrecognised Quartus macro assignment: {line}")
        key, value = m.groups()
        if key in defines and defines[key] != value:
            raise ValueError(f"conflicting Quartus definitions for {key}")
        defines[key] = value
    if not {"CORENAME", "JTFRAME_BUTTONS", "JTFRAME_ENHANCED_CONTROLS"} <= defines.keys():
        raise ValueError("expected effective Quartus definitions for the Enhanced core")
    return defines


def status_options(path):
    data = bytes.fromhex(path.read_text()).rstrip(b"\0")
    if not data or b"\0" in data:
        raise ValueError("empty or damaged cfgstr.hex")
    options = []
    for entry in data.decode("latin1").split(";"):
        opcode, *fields = entry.split(",")
        match = OPTION.fullmatch(opcode)
        if not match or not fields:
            continue
        kind, num1, num2, char1, char2 = match.groups()
        if num1:
            start, end = int(num1), int(num2 or num1)
        else:
            start, end = int(char1, 32), int(char2 or char1, 32)
        offset = 32 if kind.islower() else 0
        bits = set(range(min(start, end) + offset, max(start, end) + offset + 1))
        options.append((fields[0], tuple(fields[1:]), bits))
    return options


def preprocessed(path, flags):
    result = subprocess.run(["iverilog", "-g2012", *flags, "-E", "-o", "-", str(path)],
                            capture_output=True, text=True, check=True)
    return re.sub(r"//[^\n]*|/\*.*?\*/", "", result.stdout, flags=re.S)


def indexes(expression):
    bits = set()
    for hi, lo in STATUS.findall(expression):
        most, least = int(hi), int(lo or hi)
        if least > most:
            raise ValueError(f"reversed RTL status field: {expression}")
        bits.update(range(least, most + 1))
    return bits


def check_fields(options, defines, top, status_rtl, manual):
    errors = []
    controls = {name for name, _, _ in options if name in FIELDS}
    if manual:
        if controls or any("autofire" in name.lower() for name, _, _ in options):
            errors.append("manual-only core exposes Autofire")
    else:
        for macro in ("JTFRAME_LLAPI_HOLD_AUTOFIRE", "JTFRAME_LLAPI_AUTOFIRE_OPTIONS"):
            if macro not in defines:
                errors.append(f"{macro} missing in effective Quartus definitions")
        for name, (port, choices) in FIELDS.items():
            matches = [(values, bits) for label, values, bits in options if label == name]
            if len(matches) != 1:
                errors.append(f"expected one {name} option, found {len(matches)}")
                continue
            values, bits = matches[0]
            if values != choices or len(bits) != (len(choices) - 1).bit_length():
                errors.append(f"{name}: wrong choices or status width")
            for other, _, other_bits in options:
                conflict = bits & other_bits
                if other != name and conflict:
                    errors.append(f"{name} / {other}: shared status bits {sorted(conflict)}")
            ports = re.findall(r"\." + port + r"\s*\(([^;]*?)\)\s*[,)]", top)
            if len(ports) != 1 or indexes(ports[0]) != bits:
                errors.append(f"{name}: generated menu {sorted(bits)} disagrees with .{port}{ports}")
    if "JTFRAME_LIGHTGUN" in defines:
        borders = [bits for label, _, bits in options if label == "Sinden Lightgun"]
        if len(borders) == 1:
            for label, _, bits in options:
                overlap = bits & borders[0]
                if label != "Sinden Lightgun" and label not in FIELDS and overlap:
                    errors.append(f"Sinden Lightgun / {label}: shared status bits {sorted(overlap)}")
        assignments = re.findall(r"\bassign\s+gun_border_en\s*=\s*([^;]+);", status_rtl)
        if len(borders) != 1 or len(assignments) != 1 or indexes(assignments[0]) != borders[0]:
            errors.append("Sinden Lightgun OSD selector disagrees with active gun_border_en logic")
    if errors:
        raise ValueError("\n".join(errors))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cfgstr_hex", type=Path)
    parser.add_argument("quartus_definitions", type=Path)
    parser.add_argument("jtframe_mister_sv", type=Path)
    parser.add_argument("--manual-only", action="store_true", help="explicit manual-only game policy")
    parser.add_argument("--static-only", action="store_true", help="skip simulation for inventory")
    parser.add_argument("--tb", type=Path, help="game-specific integration testbench")
    parser.add_argument("--top", default="autofire_tb", help="Icarus module name of the testbench")
    args = parser.parse_args()
    defines = generated_definitions(args.quartus_definitions)
    flags = [f"-D{k}={v}" if v else f"-D{k}" for k, v in defines.items()]
    hdl = args.jtframe_mister_sv.parent
    status_file = hdl / "jtframe_mister_status.v"
    check_fields(status_options(args.cfgstr_hex), defines, preprocessed(args.jtframe_mister_sv, flags),
                 preprocessed(status_file, flags), args.manual_only)
    if "JTFRAME_SIMSON_AUTOFIRE" not in defines:
        raise ValueError("missing Escape Kids cabinet profile")
    with tempfile.TemporaryDirectory() as directory:
        image = Path(directory) / "profile.vvp"
        subprocess.run(["iverilog", "-g2012", "-i", *flags, "-s", "profile_tb", "-o", image,
                        Path(__file__).with_name("profile_tb.sv"), args.jtframe_mister_sv,
                        hdl / "jtframe_serial_arcade.sv"], check=True)
        subprocess.run(["vvp", "-N", image], check=True)
    if args.static_only:
        print("OSD and active RTL match; gameplay simulation was skipped.")
        return
    if not args.tb and (args.manual_only or int(defines["JTFRAME_BUTTONS"]) not in (2, 3)):
        raise ValueError("supply --tb for this manual-only or nonstandard control map")
    bench = args.tb or Path(__file__).with_name("autofire_tb.sv")
    sources = [hdl / name for name in ("jtframe_serial_arcade.sv", "jtframe_llapi_arcade.sv",
                                      "jtframe_llapi_protocol.sv", "jtframe_snac_turbo.sv", "joydb15.v")]
    with tempfile.TemporaryDirectory() as directory:
        image = Path(directory) / "test.vvp"
        subprocess.run(["iverilog", "-g2012", *flags, "-s", args.top, "-o", image,
                        bench, status_file, *sources], check=True)
        subprocess.run(["vvp", "-N", image], check=True)
    print("Generated OSD, active RTL and real-configuration simulation passed.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))
