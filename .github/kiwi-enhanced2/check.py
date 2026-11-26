"""Validate the six official Kiwi MRAs, generated menu and CI package."""
from pathlib import Path
import hashlib
import shutil
import sys
import xml.etree.ElementTree as ET

SUPPORT = Path(__file__).resolve().parent
STEM = "jtkiwi_llapi21"
SETS = {
    "arknoid2": (1, "Shoot,-,-", "A", "03 03"),
    "chukatai": (2, "Fire,Magic Bomb,-", "A,B", "41 24"),
    "drtoppel": (2, "button 1,button 2,-", "A,B", "03 10"),
    "extrmatn": (2, "Fire,Warp,-", "A,B", "03 00"),
    "insectx": (2, "Fire,Warp,-", "A,B", "40 00"),
    "kageki": (2, "Left jab,Right hook,-", "A,B", "08 00"),
}


def mras(dest=None):
    expected = {}
    for row in (SUPPORT / "MRA-SHA256SUMS").read_text().splitlines():
        digest, name = row.split("  ", 1)
        expected[name] = digest
    found = set()
    for path in sorted((SUPPORT / "mras").glob("*.mra")):
        raw = path.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == expected[path.name]
        root = ET.fromstring(raw)
        name = root.findtext("setname")
        assert name in SETS and name not in found, name
        found.add(name)
        count, actions, default, header = SETS[name]
        buttons = root.find("buttons").attrib
        assert int(buttons["count"]) == count
        assert buttons["names"] == actions + ",Start,Coin,Core credits,Test,Service"
        assert buttons["default"].startswith(default + ",Start,Select")
        assert root.findtext("rbf") == "jtkiwi"
        part = root.findtext("rom[@index='0']/part")
        assert part is not None and bytes.fromhex(part)[:2] == bytes.fromhex(header)
        assert b"jtbeta.zip" not in raw
        if dest is not None:
            target = dest / path.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw.replace(b"<rbf>jtkiwi</rbf>", f"<rbf>{STEM}</rbf>".encode()))
    assert found == set(SETS) and len(expected) == len(found)
    print("Six official Kiwi MRAs, actions and board headers verified")


def menu(path):
    data = bytes.fromhex(path.read_text()).rstrip(b"\0")
    assert len(data) < 2048
    entries = data.split(b";")
    for required in (
        b"OD,Button aid,Off,On", b"o03,Sensitivity,high,highest,lowest,low",
        b"P2,Autofire", b"D7P2O8,P1 Autofire,Off,Hold",
        b"D7P2ON,P2 Autofire,Off,Hold", b"P2-,SNAC: hold button + Start x3",
        b"OC,Show credits on pause,Off,On", b"HCP3-,Immediate Repoll: On",
        b"HCP3-,LLAPI Driver: 1.2", b"-,Enhanced Core: 2.1",
        b"oTV,Serial port,LLAPI 2P,SATURN 1P,DB9 1P,DB15 2P,SNES 2P,PCE 1P,NES 2P",
    ):
        assert required in entries, required
    assert not any(b"Sinden Lightgun" in e for e in entries)
    assert not any(b"JTFRAME_ROADF" in e for e in entries)
    print("Kiwi menu, spinner sensitivity, button aid and LLAPI settings verified")


def package(source, dest):
    assert not dest.exists(), dest
    binary = source / "release/mister/jtkiwi.rbf"
    assert binary.stat().st_size > 1_000_000
    core = dest / "_Arcade/cores" / (STEM + ".rbf")
    core.parent.mkdir(parents=True)
    shutil.copyfile(binary, core)
    mras(dest / "_Arcade")
    sums = "".join(hashlib.sha256(f.read_bytes()).hexdigest() + "  " + f.relative_to(dest).as_posix() + "\n"
                   for f in sorted(dest.rglob("*")) if f.is_file())
    assert len(sums.splitlines()) == 7
    (dest / "SHA256SUMS").write_text(sums)
    print(sums)


if sys.argv[1] == "mras":
    mras()
elif sys.argv[1] == "menu":
    menu(Path(sys.argv[2]))
elif sys.argv[1] == "package":
    package(Path(sys.argv[2]), Path(sys.argv[3]))
else:
    raise SystemExit("mode: mras | menu | package")
