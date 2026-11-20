"""Check the complete TimeQuest summary and the menu Quartus actually elaborated."""

import re
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path


CHECKS = {"Setup", "Hold", "Recovery", "Removal", "Minimum Pulse Width"}


def verify_timing(path):
    lines = path.read_text().strip().splitlines()
    separator = "-" * 60
    header = [separator, "TimeQuest Timing Analyzer Summary", separator]
    if lines[:3] != header or lines[-1:] != [separator]:
        raise ValueError("Incomplete TimeQuest timing summary")

    worst_slack = {}
    for block in re.split(r"\n\s*\n", "\n".join(lines[3:-1]).strip()):
        match = re.fullmatch(
            r"Type\s*:\s*([^'\n]+?)\s+'([^'\n]+)'\n"
            r"Slack\s*:\s*(\S+)\nTNS\s*:\s*(\S+)", block
        )
        if not match:
            raise ValueError(f"Incomplete or invalid timing record: {block!r}")
        check, clock, slack_text, tns_text = match.groups()
        try:
            slack, tns = Decimal(slack_text), Decimal(tns_text)
        except InvalidOperation:
            raise ValueError(f"Invalid timing value for {check} {clock}: {block!r}") from None
        if not slack.is_finite() or slack < 0 or not tns.is_finite() or tns != 0:
            raise ValueError(f"{check} {clock}: slack {slack_text}, TNS {tns_text}")
        worst_slack[check] = min(slack, worst_slack.get(check, slack))

    if CHECKS - worst_slack.keys():
        raise ValueError(f"Missing timing checks: {sorted(CHECKS - worst_slack.keys())}")
    for check, slack in sorted(worst_slack.items()):
        print(f"{check}: worst slack {slack} ns, TNS 0")


def compiled_menu(path):
    # Dynamic controller labels contain literal control bytes, including LF and CR.
    # Quartus splits a value at LF across consecutive table rows.
    section = b"; Parameter Settings for User Entity Instance: emu:emu|hps_io:hps_io "
    with path.open("rb") as report:
        for line in report:
            if line.startswith(section):
                break
        else:
            raise ValueError("Missing hps_io parameter table")
        for line in report:
            if line.startswith(b"; Parameter Settings for User Entity Instance:"):
                break
            match = re.fullmatch(rb"; CONF_STR +; (.*?) +; String +;\r?\n", line)
            if match:
                rows = [match[1]]
                for line in report:
                    continuation = re.fullmatch(rb"; +; (.*?) +; +;\r?\n", line)
                    if not continuation:
                        break
                    rows.append(continuation[1])
                return b"\n".join(rows).split(b";")
    raise ValueError("Missing compiled hps_io CONF_STR")


def verify_menu(path):
    entries = compiled_menu(path)
    if any(re.search(rb"auto[ _-]*fire", entry, re.I) for entry in entries):
        raise ValueError("Golden Axe still exposes an Autofire menu entry or button")
    for entry in (
        b"-,Enhanced Core: 1.0",
        b"O[89:87],Serial Port,LLAPI 2P,SNAC Saturn,SNAC Mega Drive,DB15,SNAC SNES,SNAC PCE,SNAC NES,USB",
    ):
        if entries.count(entry) != 1:
            raise ValueError(f"Missing or duplicate compiled menu entry: {entry!r}")

    # Compare the complete Guide so an old diagnostic page or reversed default fails.
    guide = [entry for entry in entries if re.search(rb"P3(?!\d)", entry.split(b",", 1)[0])]
    expected = [
        b"P3,Controller Guide",
        b"H0P3-,Serial Connection: LLAPI 2P",
        b"H0P3-,TYPE: AUTO CONTROLLER ID",
        b"H0P3-,LLAPI Driver: 0.5.0",
        b"H0P3O[90],Immediate Repoll,On,Off",
        b"H0P3-,P1: " + bytes(range(1, 16)),
        b"H0P3-,P2: " + bytes(range(17, 32)),
    ]
    if guide != expected:
        raise ValueError(f"Unexpected compiled Controller Guide: {guide!r}")
    print("Compiled Enhanced 1.0 menu, LLAPI 0.5.0, defaults and both controller labels verified")


def verify_controls(path):
    report = path.read_bytes()
    if b"|jtframe_serial_arcade:controllers" not in report:
        raise ValueError("Missing Enhanced controller hierarchy in the mapping report")
    if re.search(rb"\|(?:enhanced|hold|selectable)_autofire:", report):
        raise ValueError("Golden Axe still instantiates an Autofire pulse generator")
    print("Mapped Enhanced controller hierarchy verified without Autofire pulse generators")


def verify_fit(reports):
    summary = dict(line.split(" : ", 1) for line in
                   (reports / "S32.fit.summary").read_text().splitlines() if " : " in line)
    fit_report = (reports / "S32.fit.rpt").read_bytes()
    # Use the device resource table. A later partition table can cap usage at
    # 100% even when the Fitter actually requests more LABs than the device has.
    labs = re.search(rb"^; Total LABs: +partially or completely used +; "
                     rb"([\d,]+) / ([\d,]+) +;", fit_report, re.M)
    if not labs:
        raise ValueError("Missing device LAB utilization in the Fitter report")
    used, available = (int(n.replace(b",", b"")) for n in labs.groups())
    print(f"LABs: {used:,} / {available:,} ({available - used:+,} spare)")
    for label in ("Logic utilization (in ALMs)", "Total registers", "Total block memory bits",
                  "Total RAM Blocks", "Total DSP Blocks"):
        if label not in summary:
            raise ValueError(f"Missing Fitter metric: {label}")
        print(f"{label}: {summary[label]}")
    status = summary.get("Fitter Status", "missing")
    if not status.startswith("Successful") or used > available:
        raise ValueError(f"Fitter status: {status}. LABs requested: {used} / {available}")
    if re.search(rb"^; +\|s32_dspbd:u_dspbd\| +; +[1-9]\d*(?:\.\d+)? ", fit_report, re.M):
        raise ValueError("Dedicated Golden Axe build still uses logic for the Air Rescue DSP")


if __name__ == "__main__":
    reports = Path(sys.argv[1])
    try:
        verify_fit(reports)
        verify_menu(reports / "S32.map.rpt")
        verify_controls(reports / "S32.map.rpt")
        verify_timing(reports / "S32.sta.summary")
    except (OSError, ValueError) as error:
        sys.exit(f"Build verification failed: {error}")
