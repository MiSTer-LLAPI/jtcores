from pathlib import Path
import hashlib
import shutil
import sys
import xml.etree.ElementTree as ET

SUPPORT = Path(__file__).resolve().parent
STEM = 'jtshouse_llapi21'
SETS = set("""
bakutotu berabohm berabohmb blastoff blazer boxyboy boxyboya
dangseed dspirit dspirit1 dspirit2 faceoff galaga88 galaga88a
galaga88j mmaze mmaze2 pacmania pacmaniaj pacmaniao pistoldm
quester questers rompers romperso shadowld soukobdx splatter
splatter2 splatterj tankfrce tankfrce4 tankfrcej wldcourt ws
ws89 ws90 youkaidk1 youkaidk2
""".split())


def menu(path, crt):
    data = bytes.fromhex(path.read_text())
    assert len(data) == 2048
    entries = data.rstrip(b'\x00').split(b';')
    for text in (
        b'hCP3-,SNAC: Hold action + Start x3',b'hCP3-,Repeat to turn turbo off',b'-,Enhanced Core: 2.1',b'HCP3-,LLAPI Driver: 1.0.0',b'HCP3-,Immediate Repoll: On',
        b'OC,Show credits on pause,Off,On',
        b'P3,CONTROLLER GUIDE',b'o03,Sensitivity,high,highest,lowest,low',
        b'oTV,Serial port,LLAPI 2P,SATURN 1P,DB9 1P,DB15 2P,SNES 2P,PCE 1P,NES 2P',
    ):
        assert text in entries, text
    for prefix in (b'HCP3-,P1: ', b'HCDEP3-,P2: '):
        assert any(e.startswith(prefix) for e in entries)
    if crt:
        for text in (b'HFP1O[65:64],CRT deflicker', b'HFP1O[69:67],CRT height'):
            assert any(e.startswith(text) for e in entries)
    assert not any(b'Immediate Repoll,On' in e or b'DB15 OSD Combo' in e for e in entries)
    print('Namco System 1 verified menu use', len(data.rstrip(b'\x00')), '/', len(data))


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
        assert x.findtext('rbf') == 'jtshouse'
        header = bytes.fromhex(x.find('./rom[@index="0"]/part').text)
        assert len(header) == 8
        control = (header[0] >> 4) & 3
        expected_mode = (1 if setname in {'faceoff','tankfrce4'} else
                         2 if setname in {'berabohm','berabohmb'} else
                         3 if setname in {'quester','questers'} else 0)
        assert control == expected_mode, (setname, control)
        assert x.find('nvram').attrib == {'index':'2', 'size':'63552'}
        buttons = x.find('buttons').attrib
        names = buttons['names'].split(',')
        assert names[6:] == ['Start', 'Coin', 'Core credits', 'Test', 'Service']
        assert [n for n in names[:6] if n != '-']
        if setname in {'berabohm', 'berabohmb'}:
            assert names[:6] == ['Small Jump', 'Mid Jump', 'High Jump',
                                 'Weak Attack', 'Mid Attack', 'Strong Attack']
        if setname in {'quester', 'questers'}:
            assert names[:6] == ['Start', '-', '-', '-', '-', '-']
        assert b'jtbeta.zip' not in raw and raw.count(b'<rbf>jtshouse</rbf>') == 1
        if dest is not None:
            out = dest/rel
            out.parent.mkdir(parents=True,exist_ok=True)
            replaced = raw.replace(b'<rbf>jtshouse</rbf>',f'<rbf>{STEM}</rbf>'.encode())
            out.write_bytes(replaced)
            assert replaced.replace(f'<rbf>{STEM}</rbf>'.encode(),b'<rbf>jtshouse</rbf>') == raw
    assert seen == SETS and len(md) == len(seen)
    print('Namco System 1 official MRA verified')


def package(source,dest):
    arcade = dest/'_Arcade'
    assert not dest.exists(), dest
    binary = source/'release/mister/jtshouse.rbf'
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
