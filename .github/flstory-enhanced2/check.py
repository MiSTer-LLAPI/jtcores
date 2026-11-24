from pathlib import Path
import hashlib
import shutil
import sys
import xml.etree.ElementTree as ET

SUPPORT = Path(__file__).resolve().parent
STEM = 'jtflstory_llapi20'
SETS = {'nycaptor','victnine','rumba','flstory','flstoryo','onna34ro','onna34roa','colt','bronx'}


def menu(path, crt):
    data = bytes.fromhex(path.read_text())
    assert len(data) == 2048
    entries = data.rstrip(b'\x00').split(b';')
    for text in (
        b'-,Enhanced Core: 2.0',b'HCP3-,LLAPI Driver: 1.0.0',b'HCP3-,Immediate Repoll: On',
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
    print('FairyLand Story verified menu use', len(data.rstrip(b'\x00')), '/', len(data))


def mras(dest=None):
    md = dict(row.split('  ',1)[::-1] for row in (SUPPORT/'MRA-SHA256SUMS').read_text().splitlines())
    seen = set()
    for p in sorted((SUPPORT/'mras').rglob('*.mra')):
        rel = p.relative_to(SUPPORT/'mras')
        raw = p.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == md[rel.as_posix()]
        x = ET.fromstring(raw)
        setname = x.findtext('setname')
        assert setname in SETS and setname not in seen
        seen.add(setname)
        assert x.findtext('rbf') == 'jtflstory'
        buttons=x.find('buttons').attrib
        six=setname=='victnine'
        assert buttons['count']==('6' if six else '2')
        assert buttons['default']==('A,B,X,Y,L,R,Start,Select,L2,R2,L3' if six else 'A,B,Start,Select,L2,R2,L3')
        assert b'jtbeta.zip' not in raw and raw.count(b'<rbf>jtflstory</rbf>') == 1
        if dest is not None:
            out = dest/rel
            out.parent.mkdir(parents=True,exist_ok=True)
            replaced = raw.replace(b'<rbf>jtflstory</rbf>',f'<rbf>{STEM}</rbf>'.encode())
            out.write_bytes(replaced)
            assert replaced.replace(f'<rbf>{STEM}</rbf>'.encode(),b'<rbf>jtflstory</rbf>') == raw
    assert seen == SETS and len(md) == len(seen)
    print('FairyLand Story official MRA verified')


def package(source,dest):
    arcade = dest/'_Arcade'
    assert not dest.exists(), dest
    binary = source/'release/mister/jtflstory.rbf'
    assert binary.stat().st_size > 1_000_000
    output = arcade/'cores'/(STEM+'.rbf')
    output.parent.mkdir(parents=True)
    shutil.copyfile(binary,output)
    mras(arcade)
    sums = ''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+f.relative_to(dest).as_posix()+'\n'
                   for f in sorted(dest.rglob('*')) if f.is_file())
    assert len(sums.splitlines()) == 10
    (dest/'SHA256SUMS').write_text(sums)
    print(sums)


if sys.argv[1]=='menu': menu(Path(sys.argv[2]), '--crt' in sys.argv[3:])
elif sys.argv[1]=='mras': mras()
elif sys.argv[1]=='package': package(Path(sys.argv[2]),Path(sys.argv[3]))
else: raise SystemExit('mode: menu | mras | package')
