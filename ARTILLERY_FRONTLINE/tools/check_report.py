#!/usr/bin/env python3
import json,sys,pathlib
p=pathlib.Path(sys.argv[1]);d=json.loads(p.read_text())
assert d['passed'] and d['checks']>80 and not d['failures'],d
print('PASS:',d['checks'],'assertions;',d['scope'])
