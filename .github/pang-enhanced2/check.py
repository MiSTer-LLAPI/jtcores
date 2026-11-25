"""Verify the official Pang-family input profiles, including dial revisions."""
from hashlib import sha256
from pathlib import Path
import shutil
import sys
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parent
PROFILES = {
    "spang": 0,
    "spangj": 0,
    "sbbros": 0,
    "dokaben": 0,
    "dokaben2": 0,
    "blockj": 1,
    "blockr1": 1,
    "blockr2": 1,
    "cworld": 2,
    "block": 3,
}

def mras(dest=None):
    digests = {}
    for line in (ROOT / "MRA-SHA256SUMS").read_text().splitlines():
        digest, name = line.split("  ", 1)
        assert name not in digests, name
        digests[name] = digest
    seen = set()
    for mra in sorted((ROOT / "mras").rglob("*.mra")):
        name = mra.relative_to(ROOT / "mras").as_posix()
        data = mra.read_bytes()
        assert sha256(data).hexdigest() == digests.pop(name), name
        xml = ElementTree.fromstring(data)
        setname = xml.findtext("setname")
        assert xml.findtext("rbf") == "jtpang" and b"jtbeta.zip" not in data.lower()
        assert setname not in seen and setname in PROFILES, name
        header = bytes.fromhex(xml.findtext("rom[@index='0']/part"))
        profile = PROFILES[setname]
        assert len(header) == 16 and header[-1] == profile, name
        assert xml.find("buttons").get("count") == "2", name
        seen.add(setname)
        if dest is not None and profile != 1:
            old, new = b"<rbf>jtpang</rbf>", b"<rbf>jtpang_llapi21</rbf>"
            assert data.count(old) == 1
            out = dest / name
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(data.replace(old, new))
            assert out.read_bytes().replace(new, old) == data
    assert seen == set(PROFILES) and not digests
    print("PASS 10 official MRA hashes, set identities and native cabinet profiles")


def package(source, dest):
    arcade = dest / "_Arcade"
    assert not dest.exists(), dest
    binary = source / "release/mister/jtpang.rbf"
    assert binary.stat().st_size > 1000000
    generated_ports = source / "cores/pang/mister/mem_ports.inc"
    assert generated_ports.read_bytes() == (ROOT / "referencia/mem_ports.inc").read_bytes()
    output = arcade / "cores/jtpang_llapi21.rbf"
    output.parent.mkdir(parents=True)
    shutil.copyfile(binary, output)
    mras(arcade)
    files = sorted(p for p in dest.rglob("*") if p.is_file())
    assert len(files) == 8, files
    (dest / "SHA256SUMS").write_text("".join(
        sha256(p.read_bytes()).hexdigest() + "  " + p.relative_to(dest).as_posix() + "\n"
        for p in files
    ))


def menu(path):
    data = bytes.fromhex(path.read_text())
    assert len(data) == 2048
    entries = data.rstrip(b"\0").split(b";")
    for entry in (
        b"-,Enhanced Core: 2.1", b"HCP3-,LLAPI Driver: 1.0.0",
        b"HCP3-,Immediate Repoll: On", b"OC,Show credits on pause,Off,On",
        b"P2-,Quiz: 4 buttons or directions", b"P2-,SNAC: hold button + Start x3",
        b"P2-,Repeat to turn turbo off", b"P3,CONTROLLER GUIDE",
        b"oTV,Serial port,LLAPI 2P,SATURN 1P,DB9 1P,DB15 2P,SNES 2P,PCE 1P,NES 2P",
    ):
        assert entries.count(entry) == 1, entry
    print("PASS Pang generated menu, %d / %d bytes" % (len(data.rstrip(b"\0")), len(data)))


if __name__ == "__main__":
    if sys.argv[1] == "menu":
        menu(Path(sys.argv[2]))
    elif sys.argv[1] == "mras":
        mras()
    elif sys.argv[1] == "package":
        package(Path(sys.argv[2]), Path(sys.argv[3]))
    else:
        raise SystemExit("mode: mras | menu | package")
