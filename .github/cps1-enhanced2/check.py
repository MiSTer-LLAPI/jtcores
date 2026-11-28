"""Validate the official CPS1 MRAs and package the 30 new games and Final Fight."""
from pathlib import Path
import csv
import hashlib
import shutil
import sys
import xml.etree.ElementTree as ET

SUPPORT = Path(__file__).resolve().parent
STEM = "jtcps1_llapi21"


def profiles():
    rows = list(csv.DictReader((SUPPORT / "mra-profiles.csv").open()))
    assert len(rows) == 31
    result = {row["mra"]: row for row in rows}
    assert len(result) == len(rows)
    return result


def mras(dest=None):
    expected = {}
    for line in (SUPPORT / "MRA-SHA256SUMS").read_text().splitlines():
        digest, name = line.split("  ", 1)
        expected[Path(name).name] = digest
    catalogue = profiles()
    assert set(expected) == set(catalogue)
    seen = set()
    for path in sorted((SUPPORT / "mra").glob("*.mra")):
        assert path.name in expected and path.name not in seen
        seen.add(path.name)
        raw = path.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == expected[path.name], path
        root = ET.fromstring(raw)
        row = catalogue[path.name]
        assert root.findtext("setname") == row["setname"], path
        assert root.findtext("rbf") == "jtcps1", path
        buttons = root.find("buttons").attrib
        assert int(buttons["count"]) == int(row["actions"]), path
        assert buttons["names"] == row["legend"], path
        assert row["legend"].split(",", 1)[0] not in ("", "-"), path
        header = bytes.fromhex(root.findtext("rom[@index='0']/part"))
        assert len(header) == 64, path
        assert header[34] == int(row["header34"], 16), path
        assert header[39] == int(row["header39"], 16), path
        assert b"jtbeta.zip" not in raw, path
        if dest is not None:
            target = dest / path.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw.replace(b"<rbf>jtcps1</rbf>",
                                           f"<rbf>{STEM}</rbf>".encode()))
    assert seen == set(catalogue)
    print("31 official CPS1 MRAs, actions, headers and hashes verified")


def menu(path):
    data = bytes.fromhex(path.read_text()).rstrip(b"\0")
    assert len(data) < 2048
    entries = data.split(b";")
    for required in (
        b"HDP2O[80],P3 Autofire,Off,Hold", b"HDP2O[82:81],P3 Speed,Normal,Slow,Fast",
        b"HEP2O[83],P4 Autofire,Off,Hold", b"HEP2O[85:84],P4 Speed,Normal,Slow,Fast",
        b"P2,Autofire", b"D7P2O8,P1 Autofire,Off,Hold",
        b"HFD7P2ON,P2 Autofire,Off,Hold", b"HFD9P2ORS,P2 Speed,Normal,Slow,Fast", b"P2-,Hold repeats the first action",
        b"P2-,SNAC: hold action + Start x3",
        b"OC,Show credits on pause,Off,On",
        b"HCP3-,Immediate Repoll: On", b"HCP3-,LLAPI Driver: 1.2",
        b"-,Enhanced Core: 2.1",
        b"oTV,Serial port,LLAPI 2P,SATURN 1P,DB9 1P,DB15 2P,SNES 2P,PCE 1P,NES 2P",
    ):
        assert required in entries, required
    print("CPS1 menu and LLAPI 1.2 settings verified")


def package(source, dest):
    assert not dest.exists(), dest
    binary = source / "release/mister/jtcps1.rbf"
    assert binary.stat().st_size > 1_000_000
    core = dest / "_Arcade/cores" / (STEM + ".rbf")
    core.parent.mkdir(parents=True)
    shutil.copyfile(binary, core)
    mras(dest / "_Arcade")
    sums = "".join(hashlib.sha256(f.read_bytes()).hexdigest() + "  " +
                   f.relative_to(dest).as_posix() + "\n"
                   for f in sorted(dest.rglob("*")) if f.is_file())
    assert len(sums.splitlines()) == len(profiles()) + 1
    (dest / "SHA256SUMS").write_text(sums)
    print(sums)


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "mras":
        mras()
    elif len(sys.argv) == 3 and sys.argv[1] == "menu":
        menu(Path(sys.argv[2]))
    elif len(sys.argv) == 4 and sys.argv[1] == "package":
        package(Path(sys.argv[2]), Path(sys.argv[3]))
    else:
        raise SystemExit("mode: mras | menu <cfgstr.hex> | package <source> <dest>")
