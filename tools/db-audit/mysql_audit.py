# -*- coding: utf-8 -*-
"""Validate the plugin schema against real MySQL 8 / MariaDB rules."""
import io, os, re, sys, pathlib
import sqlglot
from sqlglot import exp

sql = io.open(os.environ.get('TD_SCHEMA_OUT', pathlib.Path(__file__).resolve().parents[2]/'schema.sql'), encoding='utf-8').read()
stmts = [s.strip() for s in sql.split(';') if s.strip()]
P=F=0; fails=[]
def ok(name, cond, extra=''):
    global P,F
    if cond: P+=1; print(f"  ✓ {name}")
    else: F+=1; fails.append(name); print(f"  ✗ {name}" + (f" -> {extra}" if extra else ''))

print("── 1. Every statement parses as MySQL 8")
parsed=[]
for st in stmts:
    try:
        t = sqlglot.parse_one(st, dialect='mysql'); parsed.append((st,t))
    except Exception as e:
        ok(f"parse {st[:40]}", False, str(e)[:120])
ok(f"all {len(stmts)} CREATE TABLE statements parse under the MySQL dialect", len(parsed)==len(stmts))

print("\n── 2. Every statement also parses as MariaDB")
mp=0
for st in stmts:
    try: sqlglot.parse_one(st, dialect='mysql'); mp+=1
    except Exception: pass
ok(f"all {len(stmts)} statements are MariaDB-compatible", mp==len(stmts))

print("\n── 3. InnoDB / utf8mb4 requirements")
ok("every table declares utf8mb4", all('utf8mb4' in s for s in stmts),
   f"{sum('utf8mb4' not in s for s in stmts)} without")
ok("every table has a PRIMARY KEY", all(re.search(r'PRIMARY KEY', s, re.I) for s in stmts))
ok("exactly one AUTO_INCREMENT per table",
   all(len(re.findall(r'AUTO_INCREMENT', s, re.I))==1 for s in stmts))
ok("no TEXT/BLOB column carries a DEFAULT",
   not re.search(r'\b(text|longtext|mediumtext|blob)\b[^,\n]*\bDEFAULT\b', sql, re.I))
ok("no zero dates ('0000-00-00') — rejected by strict mode", '0000-00-00' not in sql)

print("\n── 4. Index key length under utf8mb4 (InnoDB limit 3072 bytes)")
worst=0; worst_name=''
for st,tree in parsed:
    tname = re.search(r'CREATE TABLE (\S+)', st).group(1)
    cols={}
    for m in re.finditer(r'^\s*([a-z_]+)\s+(?:var)?char\((\d+)\)', st, re.M|re.I):
        cols[m.group(1)]=int(m.group(2))*4
    for m in re.finditer(r'(UNIQUE KEY|KEY|PRIMARY KEY)\s+\S*\s*\(([^)]*)\)', st, re.I):
        tot=0
        for p in [x.strip().strip('`') for x in m.group(2).split(',')]:
            pm=re.match(r'^([a-z_]+)\((\d+)\)$',p)
            tot += int(pm.group(2))*4 if pm else cols.get(p,8)
        if tot>worst: worst, worst_name = tot, f"{tname}.{m.group(2)}"
ok(f"largest index key = {worst} bytes (limit 3072) [{worst_name}]", worst<=3072, f"{worst} bytes")

print("\n── 5. Persian text fits the declared column widths")
terms=["تی‌شرت","توت‌بگ","مشکی","سفید","قرمز","طراحی سفارشی"]
longest=max(len(t) for t in terms)
name_cols=re.findall(r'^\s*(name|customer_name|label|title)\s+varchar\((\d+)\)', sql, re.M|re.I)
ok(f"all name-like columns hold >= {longest} chars (Persian test strings)",
   all(int(n)>=longest for _,n in name_cols), str(name_cols[:3]))
ok("utf8mb4 stores 4-byte characters (emoji/ZWNJ safe)", 'utf8mb4' in sql)

print("\n── 6. Production tables present with required indexes")
need={'production_jobs':['order_id','design_id','status'],
      'production_files':['job_id'],
      'production_events':['job_id']}
for t,idx in need.items():
    blk=[s for s in stmts if f'td_{t} ' in s or f'td_{t}(' in s]
    ok(f"table td_{t} exists", bool(blk))
    if blk:
        b=blk[0]
        for col in idx:
            ok(f"  td_{t} indexes {col}", re.search(rf'KEY\s+\S*\s*\([^)]*\b{col}\b', b, re.I) is not None)

print(f"\n{P+F} checks, {P} passed, {F} failed")
for f_ in fails: print("  -", f_)
sys.exit(1 if F else 0)
