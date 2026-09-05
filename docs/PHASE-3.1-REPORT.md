# PHASE 3.1 — MySQL / MariaDB Production Database Hardening

Branch: `arena/01a06d64-ideal`
Commit: `7ba99b1`
Phase 3 baseline `f0c0cb9`: confirmed an ancestor of HEAD (`git merge-base --is-ancestor` → yes)

---

## 1. Environment

| | |
|---|---|
| PHP | 8.3.32 (php-wasm, real PHP engine) |
| MySQL | **not available — see below** |
| MariaDB | **not available — see below** |
| SQL parser used | `sqlglot` 30.18.0, MySQL dialect |
| PHP parser used | `php-parser` (Node), PHP 8.1 grammar |

### MySQL could not be installed. This is the central finding of this phase.

The brief (§3) says: *"اگر MySQL واقعی در محیط موجود نیست، تست را جعل نکن"* — if real MySQL is
not available, do not fake the test. It is not available. Every route was attempted and
each failure is reproducible:

| Route | Result |
|---|---|
| `mysqld` / `mariadbd` on PATH | absent |
| `apt-get install mariadb-server` | `Unable to locate package`; no package lists |
| `sudo` | unavailable (uid 1001, no sudo) |
| Docker / Podman | not installed |
| `deb.debian.org` | `SSL_ERROR_SYSCALL` |
| `npm mysql-memory-server` (downloads a real server) | installs, but its binary source `cdn.mysql.com` is **blocked** (`ECONNRESET`) |
| `dev.mysql.com`, `archive.mariadb.org`, `mirror.mariadb.org`, `downloads.mariadb.com` | all HTTP `000` (TLS blocked) |
| `pip` MySQL packages (`testing.mysqld`, `pytest-mysql`) | install, but only *wrap* an existing `mysqld` |
| Platform fetch proxy | reaches the mirror index but returns rendered text, not a 335 MB tarball |
| `wordpress.org` / `downloads.wordpress.org` | also blocked (`000`) |

npm and PyPI are reachable; every MySQL/MariaDB **binary** distribution host is not.

**Consequence:** no live MySQL execution was performed, and none is claimed anywhere in
this report.

## 2. What was done instead

Rather than declaring the phase blocked and stopping, the SQL the plugin actually issues was
extracted and validated against **real MySQL 8 grammar**.

`tools/db-audit/render_schema.py` expands the PHP interpolation in `Database::schema()`
exactly as PHP would — table prefix, the `{$c}` charset clause from
`$wpdb->get_charset_collate()`, and the `{$now}` datetime default — so what is audited is
the SQL the plugin emits, not a paraphrase of it. 13 statements, 0 unresolved placeholders.

## 3. Schema

13 tables, all `wp_td_*`:

`models`, `print_areas`, `design_assets`, `colors`, `sizes`, `pricing_rules`, `designs`,
`design_versions`, `production_jobs`, `production_files`, `production_events`, `logs`,
`uploads`

| Property | Result |
|---|---|
| Parse as MySQL 8 | **13 / 13** |
| Parse as MariaDB | **13 / 13** |
| `utf8mb4` on every table | yes (via `get_charset_collate()`) |
| PRIMARY KEY on every table | yes |
| Exactly one AUTO_INCREMENT per table | yes |
| TEXT/BLOB with DEFAULT (illegal in MySQL) | none |
| Zero dates `'0000-00-00'` (rejected by strict mode) | none — uses `'1970-01-01 00:00:00'` |
| Largest index key under utf8mb4 | **764 bytes** (`models.slug`), limit 3072 |
| Reserved-word columns | only `status`, which is non-reserved in MySQL 8 |

### Persian text (§5)

All user-facing text columns are `varchar(191)`; the narrow columns (`hex varchar(7)`,
`status varchar(20)`, `priority`, `level`, `scope`, `rule_type`) hold ASCII enums only.

| Term | chars | utf8mb4 bytes |
|---|---|---|
| تی‌شرت | 6 | 13 |
| توت‌بگ | 6 | 13 |
| مشکی | 4 | 8 |
| سفید | 4 | 8 |
| قرمز | 4 | 8 |
| طراحی سفارشی | 12 | 23 |

`utf8mb4` stores the ZWNJ (U+200C) in تی‌شرت correctly; `utf8` (3-byte) would too, but
`utf8mb4` additionally covers 4-byte characters. Verified by mutation: forcing the schema to
`utf8` makes the audit fail.

## 4. Migrations

Two data steps: `migrate_110_product_types_and_versioning`, `migrate_120_production_jobs`.

| Check | Result |
|---|---|
| `DROP TABLE` in migrations | **0** |
| `DROP COLUMN` | **0** |
| `TRUNCATE` | **0** |
| `DELETE FROM` | **0** |
| `MODIFY COLUMN` / `CHANGE COLUMN` | **0** |
| Idempotent | yes — guarded by an applied-steps option, plus `dbDelta` for schema |
| Fresh installs | `mark_all_applied()` records steps without re-running back-fills |

Migrations are additive only, as §4 requires.

## 5. Runtime SQL

45 runtime statements extracted from `includes/` and `admin/`.

| Check | Result |
|---|---|
| Parse as MySQL 8 | **45 / 45** |
| `INSERT OR REPLACE` | 0 |
| `ON CONFLICT` | 0 |
| `AUTOINCREMENT` | 0 |
| `PRAGMA` / `sqlite_master` | 0 |
| `GROUP_CONCAT` / `STRFTIME` / SQLite `DATETIME()` | 0 |
| `GROUP BY` statements | 1 (`SELECT status, COUNT(*) … GROUP BY status`) — `ONLY_FULL_GROUP_BY` safe |

### Prepared statements (§12)

All 55 `$wpdb` query calls were scanned. Four interpolate a variable into SQL; each was
read individually and is safe:

| File | Fragment | Why safe |
|---|---|---|
| `class-asset-manager.php` | `{$where_sql}` | built from `$wpdb->prepare()`-ed clauses |
| `class-model-manager.php` | `{$where}` | same |
| `class-admin-pricing.php` | `{$scope}` | `(int)` cast before interpolation |
| `class-migrations.php` | `{$designs}` | a table name from `Database::table()` |

The non-numeric search bug from §9 is **fixed and still fixed**: `Production_Manager` guards
the numeric columns with `ctype_digit()` and uses `esc_like()`, so a text search no longer
matches every row whose `order_id`/`id`/`design_id` is 0.

## 6. Concurrency (§8)

`Production_Manager::transition()` uses an **optimistic lock** — the UPDATE carries
`WHERE id = ? AND status = <from>`, so a second concurrent transition affects 0 rows and is
rejected with *"Someone else changed this job first"* rather than silently overwriting.

This is the correct pattern and behaves identically on MySQL: `$wpdb->update()` returns the
affected-row count on both drivers. **Not executed against a live server** — the logic was
read, not run concurrently.

No explicit `START TRANSACTION` / `ROLLBACK` is used anywhere. That is a design observation,
not a defect found: the write paths are single-statement, so each is atomic in InnoDB on its
own. A multi-statement order→job→snapshot rollback would need explicit transactions, and
this remains **untested** without a live server.

## 7. Snapshot / version (§7)

The `snapshot['version']` vs `snapshot['design_version']` bug is **absent**. All seven
occurrences across `cart-manager`, `design-manager`, `production-manager` and
`production-renderer` use `design_version` consistently.

## 8. WooCommerce lifecycle (§10)

Jobs are created only from `woocommerce_payment_complete`,
`woocommerce_order_status_processing` and `woocommerce_order_status_completed`. Pending,
failed and cancelled orders never reach these hooks. A duplicate guard is present because
several of those hooks can fire for one order. No payment gateway was created.

## 9. Expected PNG dimensions (§13)

The brief's figures were checked against the real configuration rather than assumed:

| Product | Area | DPI | Computed | Brief |
|---|---|---|---|---|
| T-Shirt | 30 × 35 cm | 300 | 3543 × 4134 | 3543 × 4134 ✓ |
| Tote Bag | 28 × 32 cm | 300 | 3307 × 3780 | 3307 × 3780 ✓ |

Configuration and brief agree.

## 10. Tests — exact counts

Never estimated; every number below is the literal output of a command.

| Suite | Result |
|---|---|
| MySQL DDL audit (`mysql_audit.py`) | **18 checks, 18 passed, 0 failed** |
| MySQL DML audit (`dml_audit.py`) | **10 checks, 10 passed, 0 failed** |
| PHP unit — bounds/pricing (real PHP 8.3) | **35 tests, 0 failures** |
| PHP parse, whole plugin (PHP 8.1 grammar) | **73 files, 0 errors** |
| PHP parse under real PHP 8.3 (`token_get_all`) | **61 class files, 0 errors** |
| Autoloader class↔file resolution | **46 classes, 0 unresolvable** |
| **Total executed this phase** | **243 checks, 0 failures** |

### Regression suites that could NOT be re-run

| Suite | Count | Why |
|---|---|---|
| Core integration | 274 | needs WordPress; `wordpress.org` blocked |
| WooCommerce integration | 119 | needs WordPress + WooCommerce |
| Admin | 75 | needs WordPress |
| Production | 198 | needs WordPress |
| Customer status | 17 | needs WordPress |
| Uninstall | 19 | needs WordPress |
| Browser (Phase 3.2) | 85 | needs a running site |

These passed at commit `f3bf382` in the previous session. **They were not re-run here**, and
that is stated rather than carried forward as if verified. The sandbox was reset between
sessions and the WordPress/WooCommerce fixture could not be rebuilt because the download
hosts are blocked.

## 11. Issues found and fixed

No defects were found in the plugin's SQL. Two defects were found **in my own audit tooling**
and fixed before the results were trusted:

| # | Problem | Root cause | Fix | Re-run |
|---|---|---|---|---|
| 1 | 6 runtime statements reported as MySQL parse failures | the extractor matched a single PHP string literal, truncating SQL split across concatenations | reconstruct concatenated literals; substitute optional `{$where}` fragments with a valid predicate | 45/45 parse |
| 2 | SQLite-syntax check passed while an injected `INSERT OR REPLACE` was present | it scanned only *extracted* statements, and the injection was not extracted | also scan the raw PHP source | mutation now caught |

Both are recorded because a green audit that cannot fail is worse than no audit.

### Mutation verification

Every DDL check was proven capable of failing:

| Mutation | Detected |
|---|---|
| `utf8mb4` → `utf8` | ✓ 2 checks fail |
| `slug varchar(191)` → `varchar(1000)` (index 4000 bytes) | ✓ index-length check fails |
| `'1970-01-01'` → `'0000-00-00'` | ✓ zero-date check fails |
| inject `INSERT OR REPLACE` into PHP | ✓ after fix #2 |

## 12. Remaining limitations

1. **No live MySQL or MariaDB execution.** Static grammar validation is strong evidence of
   dialect compatibility but cannot prove runtime behaviour: `dbDelta` idempotency on a real
   server, actual `utf8mb4_unicode_520_ci` collation sorting of Persian text, InnoDB
   locking under genuine concurrency, and strict-mode/`sql_mode` rejections all remain
   unverified.
2. **Fresh-vs-existing database migration runs (§4) were not executed.** The migration code
   was read and proven additive and guarded; it was not run against MySQL twice.
3. **Transactions/rollback (§8) untested.** The optimistic lock was read, not raced.
4. **500-job dashboard performance (§9) not measured.** Indexes on `order_id`, `design_id`,
   `status`, `created_at` were confirmed present in the DDL; query plans were not.
5. **ZIP, file/DB consistency and regenerate (§11) not re-executed** — needs WordPress.
6. **739 previously-passing checks not re-run** (see §10 table).

## 13. Final status

```
Executed this phase:  243 checks, 0 failures
  MySQL DDL audit      18
  MySQL DML audit      10
  PHP unit tests       35
  PHP parse (8.1)      73
  PHP parse (8.3)      61
  Autoloader           46

Live MySQL tested:    NO — every binary source is network-blocked
Live MariaDB tested:  NO — same
Regression re-run:    NO — WordPress download hosts blocked

Git commit:   7ba99b1
Branch:       arena/01a06d64-ideal
Working tree: clean
```

### **PHASE 3.1 — BLOCKED**

§17 permits PASS only if *"MySQL واقعی تست شده"* — real MySQL has been tested. It has not,
and no amount of static analysis satisfies that condition. §3 explicitly instructs reporting
`BLOCKED` rather than fabricating the result, so that is the verdict.

This is **not** FAIL: no data corruption, migration failure, SQL incompatibility, security
issue or regression was found. Everything that could be checked without a server was checked
and is clean, including 45 runtime statements and 13 tables validated against real MySQL 8
grammar.

**To lift this to PASS**, the work is already written and committed. A `database` job was
added to `docs/ci/ci.yml` that runs against **MySQL 8.0, MySQL 8.4 and MariaDB 11.4**
service containers and performs exactly what this sandbox could not:

- applies the rendered `schema.sql` to a real server;
- re-applies it to prove idempotency;
- asserts 13 tables exist, all InnoDB and all `utf8mb4`;
- round-trips the Persian strings from §5 through `INSERT`, `SELECT` and `LIKE`;
- prints the live `sql_mode` so strict-mode behaviour is visible.

Running it requires one manual step, unchanged from Phase 3.2: the workflow lives at
`docs/ci/ci.yml` rather than `.github/workflows/` because this automation account lacks the
GitHub `workflows` permission. `docs/ci/README.md` gives the one-line `git mv`. Once that
runs green on all three engines, this phase becomes PASS.
