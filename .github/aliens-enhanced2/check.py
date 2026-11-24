from pathlib import Path
import hashlib
import shutil
import sys
import xml.etree.ElementTree as ET

SUPPORT = Path(__file__).resolve().parent
STEM = 'jtaliens_llapi21'
SETS = set("""
aliens aliens2 aliens3 aliens4 aliensa aliensj aliensj2 aliensu
crimfght crimfghtj crimfghtu crazycop gbusters gbustersa
scontra scontraa scontraj thunderx thunderxa thunderxb thunderxj
""".split())


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
    print('Konami Aliens verified menu use', len(data.rstrip(b'\x00')), '/', len(data))


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
        assert x.findtext('rbf') == 'jtaliens'
        buttons = x.find('buttons').attrib
        if setname.startswith('aliens'):
            game_header, actions = 0, ['Shoot standing', 'Shoot crouching']
        elif setname.startswith('scontra'):
            game_header, actions = 2, ['Shoot', 'Jump']
        elif setname.startswith('crimfght'):
            game_header, actions = 6, ['Punch', 'Kick', 'Back Kick']
        elif setname.startswith('thunderx'):
            game_header, actions = 4, ['Shoot', 'Option adjust']
        else:
            assert setname in {'gbusters', 'gbustersa', 'crazycop'}
            game_header, actions = 5, ['Shoot', 'Super shot']
        header = bytes.fromhex(x.find('./rom[@index="0"]/part').text)
        assert len(header) == 8 and header[1] == game_header
        assert buttons['count'] == str(len(actions))
        slots = actions + ['-'] * (3-len(actions))
        assert buttons['names'].split(',') == slots+['Start','Coin','Core credits','Test','Service']
        assert buttons['default'].split(',') == ['A','B','X'][:len(actions)] + ['Start','Select','L2','R2','L3']
        assert b'jtbeta.zip' not in raw and raw.count(b'<rbf>jtaliens</rbf>') == 1
        if dest is not None:
            out = dest/rel
            out.parent.mkdir(parents=True,exist_ok=True)
            replaced = raw.replace(b'<rbf>jtaliens</rbf>',f'<rbf>{STEM}</rbf>'.encode())
            out.write_bytes(replaced)
            assert replaced.replace(f'<rbf>{STEM}</rbf>'.encode(),b'<rbf>jtaliens</rbf>') == raw
    assert seen == SETS and len(md) == len(seen)
    print('Konami Aliens official MRA verified')


def package(source,dest):
    arcade = dest/'_Arcade'
    assert not dest.exists(), dest
    binary = source/'release/mister/jtaliens.rbf'
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


def project(qip):
    files = [qip.parent / line.split(' ',3)[-1] for line in qip.read_text().splitlines()
             if line.startswith('set_global_assignment ')]
    missing = [str(f) for f in files if not f.is_file()]
    assert files and not missing, missing
    assert {'jtaliens_game.v','jtaliens_main.v','jtkcpu.v','jtkcpu_ucode.v','jt51.v',
            'jt007232.v','jtframe_snac_turbo.sv','jtframe_llapi_protocol.sv'} <= {p.name for p in files}
    print('Verified', len(files), 'Quartus project references')


if sys.argv[1]=='menu': menu(Path(sys.argv[2]), '--crt' in sys.argv[3:])
elif sys.argv[1]=='project': project(Path(sys.argv[2]))
elif sys.argv[1]=='mras': mras()
elif sys.argv[1]=='package': package(Path(sys.argv[2]),Path(sys.argv[3]))
else: raise SystemExit('mode: menu | mras | package')
