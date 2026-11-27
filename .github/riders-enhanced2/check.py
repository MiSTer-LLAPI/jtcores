"""Check the official Riders MRAs and prepare an isolated Enhanced package."""
from pathlib import Path
import hashlib
import shutil
import sys
import xml.etree.ElementTree as ET

SUPPORT = Path(__file__).resolve().parent
STEM = "jtriders_llapi21"
SETS = {
    "glfgreat": ("Stance,Shot,-,-", 0x08),
    "lgtnfght": ("button 1,button 2,-,-", 0x04),
    "tmnt2": ("Shoot,Jump,-,-", 0x02),
}


def mras(dest=None):
    expected = {}
    for row in (SUPPORT / "MRA-SHA256SUMS").read_text().splitlines():
        digest, path = row.split("  ", 1)
        expected[Path(path).name] = digest
    found = set()
    for path in sorted((SUPPORT / "mra").glob("*.mra")):
        raw = path.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == expected[path.name], path
        root = ET.fromstring(raw)
        name = root.findtext("setname")
        assert name in SETS and name not in found, name
        found.add(name)
        actions, header_id = SETS[name]
        buttons = root.find("buttons").attrib
        assert int(buttons["count"]) == 2
        assert buttons["names"] == actions + ",Start,Coin,Core credits,Test,Service"
        assert buttons["default"] == "A,B,Start,Select,L2,R2,L3"
        assert root.findtext("rbf") == "jtriders"
        header = bytes.fromhex(root.findtext("rom[@index='0']/part"))
        assert header[15] == header_id, name
        assert b"jtbeta.zip" not in raw
        if dest is not None:
            target = dest / path.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw.replace(b"<rbf>jtriders</rbf>", f"<rbf>{STEM}</rbf>".encode()))
    assert found == set(SETS) and len(expected) == len(found)
    print("Three official Riders MRAs, actions, ROM headers and hashes verified")


def menu(path):
    data = bytes.fromhex(path.read_text()).rstrip(b"\0")
    assert len(data) < 2048
    entries = data.split(b";")
    for required in (
        b"P2,Autofire", b"D7P2O8,P1 Autofire,Off,Hold",
        b"D7P2ON,P2 Autofire,Off,Hold",
        b"P2-,Golfing Greats: Shot", b"P2-,Other games: first action",
        b"P2-,SNAC: hold button + Start x3",
        b"OC,Show credits on pause,Off,On",
        b"HCP3-,Immediate Repoll: On", b"HCP3-,LLAPI Driver: 1.2",
        b"-,Enhanced Core: 2.1",
        b"oTV,Serial port,LLAPI 2P,SATURN 1P,DB9 1P,DB15 2P,SNES 2P,PCE 1P,NES 2P",
    ):
        assert required in entries, required
    print("Riders menu and LLAPI 1.2 settings verified")


def package(source, dest):
    assert not dest.exists(), dest
    binary = source / "release/mister/jtriders.rbf"
    assert binary.stat().st_size > 1_000_000
    core = dest / "_Arcade/cores" / (STEM + ".rbf")
    core.parent.mkdir(parents=True)
    shutil.copyfile(binary, core)
    mras(dest / "_Arcade")
    sums = "".join(hashlib.sha256(f.read_bytes()).hexdigest() + "  " + f.relative_to(dest).as_posix() + "\n"
                   for f in sorted(dest.rglob("*")) if f.is_file())
    assert len(sums.splitlines()) == 4
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
