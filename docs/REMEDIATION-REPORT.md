# Remediation Report — the six gap-analysis issues

Every issue from `docs/GAP-ANALYSIS.md` fixed, one commit each, each verified.

| # | Issue | Severity | Commit | Status |
|---|---|---|---|---|
| 1 | Uninstall orphaned 5 tables + all production files | HIGH | `8be93cf` | **FIXED** |
| 4 | `TD_VERSION` not bumped | MEDIUM | `7be082c` | **FIXED** |
| 2 | 97 Phase 3 strings untranslated | MEDIUM | `fa36c76` | **FIXED** |
| 5 | No LICENSE / readme.txt / README.md | MEDIUM | `b66d65a` | **FIXED** |
| 3 | Customers could not see their own status | MEDIUM | `c542ae1` | **FIXED** |
| 6 | No coding-standard enforcement | LOW | `34c3aeb` | **FIXED** (one manual step) |

---

## 1. Uninstall cleanup — `8be93cf`

The table list in `uninstall.php` was a hardcoded duplicate of `Database::tables()` that had
silently drifted, orphaning `td_design_versions`, `td_production_files`,
`td_production_jobs`, `td_production_events` and `td_logs`. The `td-production` directory —
every print-ready PNG — was also left on disk, so a reinstall resurrected old customer
artwork.

**Fix:** delegate to the existing `Database::drop()`, which nothing had ever called. The
list can no longer drift because there is now only one. Also clears both upload
directories, the `td_version` option and leftover cron events (`td_cleanup_designs`,
`td_generate_production_files`), the latter mattering because a site can be deleted without
being deactivated first.

**Consequences considered:** the opt-in guard is untouched — with "delete all data" off,
nothing is removed. That half is explicitly tested, because a destructive fix that becomes
trigger-happy would be far worse than the original bug.

**Verification:** new `tests/integration-uninstall.php`, 19 checks. Proven by mutation
testing: reverting to the old hardcoded list makes it fail with 7 failures naming all 5
orphan tables and the directory.

> During this work the test itself was found to be lying. It originally `eval()`d a copy of
> `uninstall.php`, but inside `eval()` `__DIR__` resolves to the test's directory, so the
> real code path was never reached and a defensive fallback silently did the work — the
> test passed even with the entire drop path deleted. It now `require`s the real file.

## 2. Persian translations — `fa36c76`

The catalogue predated the production code, so the whole dashboard rendered in English
inside an otherwise fully-Persian RTL admin.

**Fix:** 97 production strings translated; catalogue regenerated to 501 strings; fa_IR
coverage 100%. Three stale entries (`ID`, `Saved designs`, `No saved designs yet.`) removed
after confirming their source strings were reworded in earlier phases rather than lost.

**Verification:** 0 placeholder mismatches across all 501 entries — checked programmatically,
because a mismatched `%1$s` is a runtime `sprintf` error, not a cosmetic issue. The compiled
`.mo` was parsed with WordPress's own `MO` reader: 501 entries, correct Persian returned.

## 3. Customer-facing status — `c542ae1`

The restrictive half of the customer rule was enforced and proven; the permissive half did
not exist, so a customer could not see even "Shipped".

**Fix:** new `Customer_Status` class rendering a coarse label under each designed line item.
Internal states collapse on purpose: `printed` and `quality_check` both read "In
production", and `production_error` is deliberately **indistinguishable from normal
progress** — an internal failure the shop recovers from must never alarm a customer.
Ownership is checked by customer ID or WooCommerce order key, so guest order-received pages
still work.

Kept as a standalone class rather than logic inside `Order_Manager`, honouring the
commerce/fulfilment separation rule.

**Verification:** 17 unit checks (including an assertion that no label contains internal
vocabulary such as "error", "quality" or "job") plus 15 real-browser checks: the owner sees
the status on three orders, a logged-out stranger sees nothing, and none of
`production_error`, `quality_check`, `ready_for_production`, `Activity log`, `Regenerate`,
`Download all`, `.png` or `job_id` appears anywhere on a customer page.

## 4. Version bump — `7be082c`

`TD_VERSION` still read `1.1.0` while `TD_DB_VERSION` had moved to `1.2.0`. Beyond being
wrong, `TD_VERSION` is the asset cache-busting string, so returning admins could be served a
stale `admin.css` and see the new dashboard unstyled.

**Consequences checked:** migrations key off `TD_DB_VERSION`, not `TD_VERSION`, so the bump
cannot re-trigger or skip a migration. Confirmed before changing it.

## 5. Licence and readme — `b66d65a`

The header declared GPL-2.0-or-later while shipping no licence text, which GPL distribution
requires.

**Fix:** verbatim GPL-2.0 taken from WordPress's own bundled copy (rather than retyped, so
it is byte-accurate) and spot-checked against the FSF text; a WordPress-format `readme.txt`
with stable tag `1.2.0` matching `TD_VERSION`; and a developer `README.md`.

Two claims were removed after checking them: a `== Screenshots ==` section (no screenshot
assets ship) and incorrect test filenames in the README. The backfill claim was kept only
after confirming `migrate_120_production_jobs()` genuinely exists.

## 6. Coding standards and CI — `34c3aeb`

**Fix:** `composer.json` (WPCS + PHPCompatibility), a `phpcs.xml` ruleset, and a CI workflow
covering PHP 8.1/8.2/8.3 syntax linting, phpcs, and translation freshness.

**Two honest caveats:**

1. **The workflow is at `docs/ci/ci.yml`, not `.github/workflows/`.** The automation account
   used for this branch lacks the GitHub `workflows` permission and the push is rejected
   outright. `docs/ci/README.md` gives the one-line `git mv` to enable it. This is a
   credential limitation, not a broken file.
2. **phpcs is advisory on its first run.** There is no PHP binary in this environment, so
   phpcs could not actually be run to confirm the codebase is clean. Making it blocking
   immediately would likely wedge CI on style nits. The step is commented with the intended
   sequence: run once, fix the annotations, remove `continue-on-error`.

The translation check deliberately avoids `git diff` (the generator rewrites
`POT-Creation-Date` every run, so a diff is always dirty) and compares `msgid` content
instead. Verified both directions: passes on the current tree, fails on a mutated catalogue.

---

## Test totals

| Suite | Before | After |
|---|---|---|
| Unit (bounds/pricing) | 35 | 35 |
| Core | 274 | 274 |
| WooCommerce | 119 | 119 |
| Admin | 75 | 75 |
| Production | 198 | 198 |
| **Customer status (new)** | — | **17** |
| **Uninstall (new)** | — | **19** |
| **PHP total** | 701 | **737** |
| Browser — designer / admin / REST / lockout | 72 | 72 |
| **Browser — customer status (new)** | — | **15** |
| **Total** | 773 | **824** |

**Failures: 0.** Every PHP file lints clean; `git diff --check` is clean.

## Remaining limitations

Unchanged from Phase 3 and still not defects:

1. **No MySQL/MariaDB** in this sandbox; all DB work ran on the SQLite drop-in. The two
   Phase 3 tables and migration `1.2.0` want a real MySQL smoke test before production.
2. **No payment gateway sandbox.** Jobs key off WooCommerce's real `payment_complete()`, but
   a hosted gateway's success/failure/cancel callbacks are unexercised.
3. **phpcs never actually executed** — see caveat 2 above.

## Note on the test harness

Twice during this work the php-wasm harness produced alarming results that were **not**
plugin bugs: `wp-admin` appeared reachable without cookies, and a logged-out visitor
appeared to see another customer's status. Both are the same artifact — the harness reuses a
single PHP instance, so `$current_user` leaks between requests. Both were confirmed by
restarting the server and issuing a cold request, and the customer-status browser test now
runs its anonymous check *first*, before any login, with a comment explaining why. Recorded
so nobody "fixes" a bug that does not exist.
