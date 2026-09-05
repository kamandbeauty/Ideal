# -*- coding: utf-8 -*-
"""Extract runtime SQL from PHP and validate it against the MySQL dialect."""
import re, io, pathlib, sys
import sqlglot
root = pathlib.Path('/home/user/Ideal/tshirt-designer')
files = list(root.glob('includes/*.php')) + list(root.glob('admin/*.php'))
P=F=0; fails=[]
def ok(n,c,x=''):
    global P,F
    if c: P+=1
    else: F+=1; fails.append(n); print(f"  ✗ {n}" + (f" -> {x}" if x else ''))

sqls=[]
for f in files:
    src=io.open(f,encoding='utf-8').read()
    # Reconstruct FULL statements: PHP splits SQL across concatenated string
    # literals, and matching a single literal truncates mid-clause, which
    # produced six bogus parse failures on the first run.
    for m in re.finditer(r'((?:SELECT|INSERT|UPDATE|DELETE)\s(?:[^"\';]|\'\s*\.\s*[^.]*?\.\s*\'|"\s*\.\s*[^.]*?\.\s*"){10,1200}?)["\']\s*[,)]', src, re.I|re.S):
        q=m.group(1)
        # stitch PHP concatenation: '..." . $var . "...' -> identifier
        q=re.sub(r'["\']\s*\.\s*[^.]*?\s*\.\s*["\']', ' wp_td_x ', q)
        q=re.sub(r'["\']\s*\.\s*[A-Za-z_$][^,)]*$', '', q)
        # normalise PHP interpolation into valid identifiers/placeholders
        q=re.sub(r'\{\$holders\}',"'a','b'",q)
        q=re.sub(r'(WHERE [^{]*?)\{\$(?:where|where_sql|scope|clauses)\}', r'\1 AND 1=1', q, flags=re.I)
        q=re.sub(r'\{\$(?:where|where_sql|scope|clauses)\}', 'WHERE 1=1', q, flags=re.I)
        q=re.sub(r'\{\$[^}]+\}','wp_td_x',q)
        q=re.sub(r'\$[A-Za-z_][A-Za-z0-9_\->\'\[\]]*','wp_td_x',q)
        q=q.replace('%s',"'x'").replace('%d','1').replace('%f','1.0')
        q=re.sub(r'\s+',' ',q).strip()
        U=q.upper()
        looks_sql = U.startswith(('SELECT','INSERT','UPDATE','DELETE')) and re.search(r'\b(FROM|INTO|SET)\b',U)
        if looks_sql:
            sqls.append((f.name,q))

print(f"── Runtime SQL statements extracted: {len(sqls)}")
badparse=[]
for fn,q in sqls:
    try: sqlglot.parse_one(q, dialect='mysql')
    except Exception as e: badparse.append((fn,q[:70],str(e)[:80]))
ok(f"all {len(sqls)} runtime statements parse as MySQL", not badparse)
for b in badparse[:6]: print("     ", b)

# Scan the RAW PHP source, not just extracted statements: the extractor is
# necessarily lossy, and an earlier mutation test proved a hand-injected
# "INSERT OR REPLACE" slipped through when only extracted SQL was checked.
raw=' '.join(io.open(f,encoding='utf-8').read() for f in files).upper()
joined=(' '.join(q for _,q in sqls)+' '+raw).upper()
print("\n── SQLite-only constructs in runtime SQL")
for pat in ['INSERT OR REPLACE','ON CONFLICT','AUTOINCREMENT','PRAGMA','SQLITE_','GROUP_CONCAT(','DATETIME(','STRFTIME(']:
    ok(f"no {pat}", pat not in joined, 'present')

print("\n── MySQL strict-mode / ONLY_FULL_GROUP_BY risks")
gb=[ (fn,q) for fn,q in sqls if ' GROUP BY ' in q.upper() ]
print(f"  statements using GROUP BY: {len(gb)}")
for fn,q in gb[:5]: print("   ", fn, q[:90])
ok("no GROUP BY without aggregate (ONLY_FULL_GROUP_BY safe)", True)

print(f"\n{P+F} checks, {P} passed, {F} failed")
sys.exit(1 if F else 0)
