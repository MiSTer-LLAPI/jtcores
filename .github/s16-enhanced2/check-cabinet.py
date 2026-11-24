"""Simulate the actual System 16A cabinet using the generated Quartus game IDs."""
import re
import subprocess
import sys
from pathlib import Path

core, qsf, temp = map(Path, sys.argv[1:])
game = core / 'cores/s16/hdl'
hps = core / 'modules/jtframe/target/mister/hdl'
assignments = re.findall(r'"(GAME_[A-Z0-9_]+)=([^"]+)"', qsf.read_text())
required = {'GAME_QUARTET', 'GAME_SDI', 'GAME_PASSSHT', 'GAME_AFIGHTAN', 'GAME_TIMESCAN'}
if not required <= {key for key, _ in assignments}:
    raise ValueError('Missing System 16A board identifiers in generated QSF')
binary = temp / 's16-cabinet.vvp'
subprocess.run(['iverilog', '-g2012', '-i', '-DJTFRAME_LLAPI_EXTRA_ACTIONS',
                *['-D' + key + '=' + value for key, value in assignments],
                '-s','s16_controls_tb','-o',binary,Path(__file__).with_name('s16_controls_tb.sv'),
                hps/'jtframe_llapi_arcade.sv',game/'jts16_main.v', game/'jts16_trackball.v'],check=True)
subprocess.run(['vvp','-N',binary],check=True)
