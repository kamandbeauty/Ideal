# Gap Analysis — what the plugin is still missing

> **STATUS: ALL SIX ISSUES RESOLVED.** This document is kept as the record of what was
> found and why it mattered. See `docs/REMEDIATION-REPORT.md` for what was done about each
> one. The findings below are preserved as originally written.

Audit of `f0c0cb9` (end of Phase 3). This is a **findings report, nothing was changed.**
Scope: production-readiness gaps, not new features. Phase 3 itself passes its own mandate;
these are things that sit *outside* the §1–§65 checklist and were therefore never required.

Severity: **HIGH** = data loss / user-visible breakage · **MEDIUM** = quality or compliance
· **LOW** = polish.

---

## 1. Uninstall leaves 5 tables and all production files behind — **HIGH**

`uninstall.php` drops 8 tables, but the plugin now creates **13**. Never dropped:

| Orphan table | Created in |
|---|---|
| `td_design_versions` | Phase 2 |
| `td_production_files` | Phase 2 |
| `td_production_jobs` | **Phase 3** |
| `td_production_events` | **Phase 3** |
| `td_logs` | Phase 2 |

`uninstall.php` also only removes the `td-uploads` upload directory. The
`td-production` directory — every print-ready PNG ever rendered — is left on disk.

Uninstalling and reinstalling therefore resurrects a site's entire old production
history, and a "clean" removal silently leaves customer artwork behind. This is also a
GDPR/erasure problem, since those PNGs are personal data.

The root cause is structural, not a typo: the table list is **hardcoded a second time** in
`uninstall.php` instead of being read from `Database::tables()`, so every new table since
Phase 2 has silently drifted out of sync. Fixing only the names would leave the same trap
for Phase 4.

## 2. 155 Phase 3 strings are untranslatable in practice — **MEDIUM**

The plugin ships a complete Persian translation (`fa_IR`, 396 strings) and correctly wraps
Phase 3 output in `__()` with the right text domain. But the catalogue was last generated
**2026-09-04 21:38**, before the production code landed. So:

- `languages/tshirt-designer.pot` — missing all 155 new strings
- `languages/tshirt-designer-fa_IR.po/.mo` — 0 hits for `Production`, `Ready for
  Production`, `Quality Check`, `Regenerate`, `Download All`, `Priority`

The result: for a Persian admin — the plugin's primary audience, given it ships Vazirmatn
and RTL CSS — the **entire new production dashboard renders in English** inside an
otherwise fully-Persian UI. The RTL layout work in §42 is real, but the words are not
translated. Needs a `.pot` regeneration plus translation of the new strings.

## 3. Customers cannot see their own order status — **MEDIUM**

§30 asks that "customers see only their own status — never files, internal notes or logs."
The restrictive half is fully enforced and proven (10/10 lockout checks). The **permissive**
half was never built: there is no customer-facing surface at all. No hook into
`woocommerce_order_details_*` or the My Account view, and no customer REST route.

So today a customer sees nothing about fulfilment — not even "Shipped". Phase 3's mandate
is arguably satisfied (it never demanded the UI), but the intent of §30 is only half met,
and this is the most visible functional hole for an end user.

## 4. `TD_VERSION` was not bumped for Phase 3 — **MEDIUM**

`TD_DB_VERSION` correctly moved to `1.2.0`, but the plugin header and `TD_VERSION` still
read **`1.1.0`** — the Phase 2 number. Phase 3 added 6 files, 2 tables and 9 REST routes
under a version string that claims nothing changed.

Consequence beyond bookkeeping: `TD_VERSION` is what asset enqueues use for cache busting,
so returning admins can get **stale cached `admin.css`** and see the new dashboard without
its styles. Should be `1.2.0`.

## 5. No `readme.txt`, `README.md` or `LICENSE` — **MEDIUM**

The repository has none of these. The plugin header declares `GPL-2.0-or-later` but no
licence text is shipped, which is a GPL distribution requirement. There is also no
WordPress-format `readme.txt` (stable tag, changelog, install steps), so the plugin cannot
be listed or updated through normal WP channels, and no `README.md` explaining setup for
anyone cloning the repo.

## 6. No automated coding-standard enforcement — **LOW**

§59 requires WPCS. The code is written to WPCS by hand (verified by eye, and `phpcs:ignore`
annotations are used correctly), but there is no `composer.json`, no `phpcs.xml`, and no CI
workflow. Compliance is currently a promise, not a check — nothing stops the next commit
from drifting. The 774 tests are also run manually via a bespoke php-wasm harness rather
than in CI.

## 7. Carry-over environment limits — unchanged, **not defects**

Both were already flagged in the Phase 2.1 and Phase 3 reports and remain true:

1. **No MySQL/MariaDB** is obtainable in this sandbox; all DB work ran on the SQLite
   drop-in. The 2 new tables and migration `1.2.0` still want a real MySQL smoke test —
   `dbDelta` behaviour around index changes differs there.
2. **No payment gateway sandbox.** Jobs key off WooCommerce's real `payment_complete()`,
   which is correct, but a hosted gateway's success/failure/cancel callbacks are
   unexercised.

---

## What is *not* missing

Worth stating plainly, so the list above is read in proportion:

- Production workflow, statuses, transitions, snapshot immutability, per-area files, ZIP,
  regeneration, notes, activity log, QC and retry are all complete and tested.
- Security is genuinely solid: admin-gated REST (9 routes), nonce-checked downloads, path
  containment, prepared SQL, and verified lockout for both anonymous and logged-in
  customers.
- HPOS / custom order tables compatibility **is** declared (`FeaturesUtil`), which is easy
  to miss and often breaks WooCommerce plugins.
- The §45–47 notification architecture is properly open — all 5 events fire as
  `do_action()` hooks with no parallel logger.
- 774 automated checks, 0 failures.

## Suggested order of work

1. Fix `uninstall.php` to read from `Database::tables()` and remove `td-production` (HIGH,
   and prevents the same drift recurring)
2. Regenerate `.pot` and translate the 155 production strings (MEDIUM, high user impact)
3. Bump `TD_VERSION` to `1.2.0` (MEDIUM, one line, fixes CSS cache busting)
4. Add customer-facing order status (MEDIUM, completes §30's intent)
5. Add `LICENSE` + `readme.txt` + `README.md` (MEDIUM, licence compliance)
6. Add `composer.json` + `phpcs.xml` + CI (LOW)
