# -*- coding: utf-8 -*-
"""Render the plugin's schema() exactly as PHP would, without running PHP."""
import re, io, json, os, pathlib
# Resolve paths relative to the repo so this runs in CI as well as locally.
REPO = pathlib.Path(__file__).resolve().parents[2]
SRC  = REPO / 'tshirt-designer' / 'includes' / 'class-database.php'
OUT  = pathlib.Path(os.environ.get('TD_SCHEMA_OUT', REPO / 'schema.sql'))
s = io.open(SRC, encoding='utf-8').read()

# tables() keys -> real names, mirroring table(): $wpdb->prefix . 'td_' . $key
m = re.search(r'public function tables\(\): array \{(.*?)\n\t\}', s, re.S)
keys = re.findall(r"'([a-z_]+)'", m.group(1))
PREFIX = 'wp_'
def tbl(k): return f"{PREFIX}td_{k}"

body = re.search(r'public function schema\(\): array \{(.*)\n\t\}\n\}', s, re.S).group(1)
# MySQL 8 / MariaDB utf8mb4 clause exactly as get_charset_collate() returns
C = 'DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci'
NOW = '1970-01-01 00:00:00'

stmts = re.findall(r'"(CREATE TABLE .*?;)"', body, re.S)
out = []
for st in stmts:
    st = st.replace('{$c}', C).replace('{$now}', NOW)
    st = re.sub(r"\{\$this->table\('([a-z_]+)'\)\}", lambda mm: tbl(mm.group(1)), st)
    st = st.replace('\\"', '"')
    out.append(st.strip())
io.open(OUT,'w',encoding='utf-8').write(';\n\n'.join(out) + ';\n')
print(f"tables() keys: {len(keys)}")
print(f"CREATE TABLE statements rendered: {len(out)}")
print(f"unresolved placeholders: {sum('{$' in o for o in out)}")
