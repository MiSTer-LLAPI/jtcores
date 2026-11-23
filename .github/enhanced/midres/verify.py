"""Verify the actual generated menus, ROM metadata and physical game mapping."""
from hashlib import sha256
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

support = Path(__file__).resolve().parent
target = Path('cores/midres/mister')
menu = bytes.fromhex((target/'cfgstr.hex').read_text())
assert len(menu) == 2048
for entry in [
    'oTV,Serial port,LLAPI 2P,SATURN 1P,DB9 1P,DB15 2P,SNES 2P,PCE 1P,NES 2P;',
    'o03,Sensitivity,high,highest,lowest,low;',
    'P2,Autofire;', 'D7P2O8,P1 Autofire,Off,Hold;', 'D7P2ON,P2 Autofire,Off,Hold;',
    'P1 Speed,Normal,Slow,Fast;', 'P2 Speed,Normal,Slow,Fast;',
    'P3,CONTROLLER GUIDE;', 'HCP3-,P1: ', 'HCDEP3-,P2: ',
    'P3-,SNES: Y Shot  B Jump;', 'P3-,SNES: L/R Turn  X Autofire;',
    'HCP3-,LLAPI Driver: 1.0.0;', 'HCP3-,Immediate Repoll: On;',
    'OC,Show credits on pause,Off,On;', '-,Enhanced Core: 2.0;'
]:
    assert menu.count(entry.encode()) == 1, entry
assert all(s not in menu for s in [b'LLAPI GP', b'Legacy P1', b'LLAPI DIAGNOSTICS', b'Immediate Repoll,On,Off'])
credits = bytes((int(w,16) & 0x7f)+0x20 for w in (target/'msg.hex').read_text().split())
assert len(credits) == 3072
for name in [b'Midnight Resistance by Jotego', b'Supervised by the JTAlpha team',
             b'LLAPI Enhanced v1.0.0', b'LLAPI original: Kitrinx', b'UltimateMiSTer.com', b'(RickDangerous)']:
    assert name in credits, name
source = (support/'MidnightResistance.mra').read_bytes()
# World set 1 from jotego/jtbin d2274ea43a04af815ef987291aa385abe5324372.
assert sha256(source).hexdigest() == 'dda4576de7914ed31ed914c018d3ca2a38172ec7527a7eccac05befa959a3792'
mra = ET.fromstring(source)
assert mra.findtext('setname') == 'midres' and mra.findtext('players') == '2'
assert mra.find('buttons').get('names').split(',')[:4] == ['Shot','Jump','Turn left','Turn right']
assert mra.find('buttons').get('default').split(',')[:4] == ['Y','B','L','R']
assert mra.find("rom[@index='0']").get('asm_md5') == '3c59966af0bb84caeea5a6bc7a84e4e8'
print(f'Menu: {len(menu.rstrip(bytes([0])))} bytes. Credits: {len(credits)} characters. Official MRA verified.')
if '--package' in sys.argv:
    install = Path('install')
    folder = install/'_LLAPI Tests'
    (folder/'cores').mkdir(parents=True, exist_ok=True)
    title = 'Midnight Resistance - Enhanced 2.0 Test'
    stem = 'jtmidresenh2'
    assert source.count(b'<rbf>jtmidres</rbf>') == source.count(b'<name>Midnight Resistance (World, set 1)</name>') == 1
    wrapper = source.replace(b'<rbf>jtmidres</rbf>', f'<rbf>{stem}</rbf>'.encode()).replace(
        b'<name>Midnight Resistance (World, set 1)</name>',f'<name>{title}</name>'.encode())
    newmra = ET.fromstring(wrapper)
    assert newmra.findtext('name') == title and newmra.findtext('rbf') == stem
    newmra.find('name').text = mra.findtext('name')
    newmra.find('rbf').text = mra.findtext('rbf')
    assert ET.tostring(newmra) == ET.tostring(mra)
    rbf = Path('release/mister/jtmidres.rbf').read_bytes()
    assert len(rbf) > 1000000
    rbf_file = folder/'cores'/f'{stem}.rbf'
    mra_file = folder/f'{title}.mra'
    rbf_file.write_bytes(rbf)
    mra_file.write_bytes(wrapper)
    sums = ''.join(f'{sha256(p.read_bytes()).hexdigest()}  {p.relative_to(install)}\n' for p in [mra_file, rbf_file])
    (install/'SHA256SUMS').write_text(sums)
    print(sums)
