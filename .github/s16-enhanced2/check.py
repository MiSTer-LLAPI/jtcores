from pathlib import Path
import csv
import hashlib
import shutil
import sys
import xml.etree.ElementTree as ET

SUPPORT = Path(__file__).resolve().parent
STEM = 'jts16_llapi21'
SETS = ['aceattaca', 'afighter', 'afightera', 'afighterb', 'afighterc', 'afighterd', 'alexkidd', 'alexkidd1', 'aliensyn2', 'aliensyn5', 'aliensynjo', 'bodyslam', 'dumpmtmt', 'fantzone', 'fantzone1', 'fantzonee', 'fantzonep', 'fantzonepr', 'mjleague', 'passsht16a', 'quartet', 'quartet2', 'quartet2a', 'quarteta', 'sdi', 'sdia', 'shinobi', 'shinobi1', 'sjryuko1', 'tetris', 'tetris3', 'timescan1', 'wb31', 'wb35']


def menu(path, crt):
    data = bytes.fromhex(path.read_text())
    assert len(data) == 2048
    entries = data.rstrip(b'\x00').split(b';')
    for text in (
        b'hCP3-,SNAC: Hold action + Start x3',b'hCP3-,Repeat to turn turbo off',b'-,Enhanced Core: 2.1',b'HCP3-,LLAPI Driver: 1.0.0',b'HCP3-,Immediate Repoll: On',
        b'OC,Show credits on pause,Off,On',
        b'P3,CONTROLLER GUIDE', 
        b'oTV,Serial port,LLAPI 2P,SATURN 1P,DB9 1P,DB15 2P,SNES 2P,PCE 1P,NES 2P',
    ):
        assert text in entries, text
    for prefix in (b'HCP3-,P1: ', b'HCDEP3-,P2: '):
        assert any(e.startswith(prefix) for e in entries)
    if crt:
        for text in (b'HFP1O[65:64],CRT deflicker', b'HFP1O[69:67],CRT height'):
            assert any(e.startswith(text) for e in entries)
    assert not any(b'Immediate Repoll,On' in e or b'DB15 OSD Combo' in e for e in entries)
    print('Sega System 16A verified menu use', len(data.rstrip(b'\x00')), '/', len(data))


def mras(dest=None):
    md = dict(row.split('  ',1)[::-1] for row in (SUPPORT/'MRA-SHA256SUMS').read_text().splitlines())
    with (SUPPORT / 'controlos-oficiais.csv').open(newline='') as file:
        layouts = {row['set']: row for row in csv.DictReader(file)}
    assert set(SETS) == set(layouts)
    seen = set()
    for p in sorted((SUPPORT/'mras').rglob('*.mra')):
        rel = p.relative_to(SUPPORT/'mras')
        raw = p.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == md[rel.as_posix()]
        x = ET.fromstring(raw)
        setname = x.findtext('setname')
        assert setname in SETS and setname not in seen
        seen.add(setname)
        assert x.findtext('rbf') == 'jts16'
        buttons = x.find('buttons').attrib
        expected = layouts[setname]
        assert buttons['count'] == expected['acoes_no_mra']
        assert buttons['names'] == expected['controlos']
        assert buttons['default'] == expected['botoes_mister']
        assert b'jtbeta.zip' not in raw and raw.count(b'<rbf>jts16</rbf>') == 1
        if dest is not None:
            out = dest/rel
            out.parent.mkdir(parents=True,exist_ok=True)
            replaced = raw.replace(b'<rbf>jts16</rbf>',f'<rbf>{STEM}</rbf>'.encode())
            out.write_bytes(replaced)
            assert replaced.replace(f'<rbf>{STEM}</rbf>'.encode(),b'<rbf>jts16</rbf>') == raw
    assert seen == set(SETS) and len(md) == len(seen)
    print('Sega System 16A official MRA verified')


def package(source,dest):
    arcade = dest/'_Arcade'
    assert not dest.exists(), dest
    binary = source/'release/mister/jts16.rbf'
    assert binary.stat().st_size > 1_000_000
    output = arcade/'cores'/(STEM+'.rbf')
    output.parent.mkdir(parents=True)
    shutil.copyfile(binary,output)
    mras(arcade)
    sums = ''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+f.relative_to(dest).as_posix()+'\n'
                   for f in sorted(dest.rglob('*')) if f.is_file())
    assert len(sums.splitlines()) == len(SETS) + 1
    (dest/'SHA256SUMS').write_text(sums)
    print(sums)


if sys.argv[1]=='menu': menu(Path(sys.argv[2]), '--crt' in sys.argv[3:])
elif sys.argv[1]=='mras': mras()
elif sys.argv[1]=='package': package(Path(sys.argv[2]),Path(sys.argv[3]))
else: raise SystemExit('mode: menu | mras | package')
