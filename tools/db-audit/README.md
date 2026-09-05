# MySQL / MariaDB schema audit

Static validation of the plugin's SQL against real MySQL 8 grammar, using
`sqlglot`'s MySQL dialect parser. These do **not** replace running against a
live server — they exist because this build environment has no route to a
MySQL binary (see `docs/PHASE-3.1-REPORT.md`).

```bash
pip install --break-system-packages sqlglot
python3 tools/db-audit/render_schema.py   # PHP schema() -> schema.sql
python3 tools/db-audit/mysql_audit.py     # 18 DDL checks
python3 tools/db-audit/dml_audit.py       # 10 runtime-SQL checks
```

`render_schema.py` expands the PHP string interpolation in `Database::schema()`
exactly as PHP would (table prefix, `{$c}` charset clause, `{$now}` default),
so the audited SQL is the SQL the plugin actually issues.

Every check was verified by mutation — breaking utf8mb4, oversizing an index,
introducing a zero date or injecting `INSERT OR REPLACE` each makes the
relevant assertion fail. The DML scan deliberately reads the raw PHP source as
well as extracted statements: an early version only scanned extracted SQL and
a hand-injected `INSERT OR REPLACE` slipped through.
