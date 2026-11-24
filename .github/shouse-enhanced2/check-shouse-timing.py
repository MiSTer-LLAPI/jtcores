"""Accept an RBF only after all reported worst-case slack values are >= 0."""
from pathlib import Path
import json
import re
import shutil

reports = list(Path('cores/shouse/mister').rglob('jtshouse.sta.rpt'))
if len(reports) != 1:
    raise SystemExit(f'Expected one timing report, found {len(reports)}')
project = Path('cores/shouse/mister')
for pattern in ('jtshouse.sta.rpt', 'jtshouse.sta.summary', 'jtshouse.fit.summary', 'jtshouse.qsf', 'cfgstr.hex'):
    for evidence in project.rglob(pattern):
        shutil.copy2(evidence, Path('pilot-reports') / evidence.name)
report = reports[0].read_text(errors='replace')
values = [(kind.strip(), float(value)) for kind, value in re.findall(
    r'Worst-case ([A-Za-z ]+?) slack is\s+(-?\d+(?:\.\d+)?)', report)]
required = {'setup', 'hold', 'recovery', 'removal', 'minimum pulse width'}
found = {kind for kind, _ in values}
if not required.issubset(found):
    raise SystemExit(f'Missing timing categories: {required - found}')
result = {'report': str(reports[0]), 'worst_slack_ns': {kind: min(v for k, v in values if k == kind) for kind in sorted(found)},
          'accepted': all(value >= 0 for _, value in values)}
Path('pilot-reports/timing-acceptance.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
if not result['accepted']:
    raise SystemExit('Timing failed: no test RBF will be packaged.')
