# PHASE 2.1 — Hardening & Production Readiness Report

Commit: `8d0bd18` — `phase-2.1: harden integrations and validate production readiness`
Branch: `arena/01a06d64-ideal`

---

## 1. Environment

| Component | Version / Detail |
|---|---|
| PHP | 8.3.32 (php-wasm, SAPI `wasm`; gd, imagick, mbstring, mysqli, pdo_mysql, pdo_sqlite, zip) |
| WordPress | 6.9 |
| WooCommerce | 9.4.2 (+ Action Scheduler 3.8.2) |
| Database | SQLite drop-in (`sqlite-database-integration` 2.1.16). **No MySQL/MariaDB server obtainable** — see §4. |
| Browser | **Chromium 149.0.7827.0 (real headless Chrome)**, WebGL 2.0 via ANGLE/SwiftShader (Vulkan 1.3), `MAX_TEXTURE_SIZE` 8192 |
| Emulated devices | Desktop 1920/1440/1280; Android (Pixel 7 UA) 390 & 412 |
| OS | Linux x86_64 sandbox |

---

## 2. Automated Tests

| Suite | Result |
|---|---|
| Unit (bounds & pricing) | **35 / 35 PASS** |
| Core WP integration | **274 / 274 PASS** |
| WooCommerce integration | **119 / 119 PASS** |
| Admin integration | **75 / 75 PASS** |
| **PHP total** | **503 / 503 PASS, 0 FAIL** |
| **Real-browser checks** | **29 / 29 PASS, 0 FAIL** |

Baseline was 463; the suite grew to 503 (+10 test-isolation hardening, +21 migration/schema, +9 frontend-rendering regressions). **No regressions.**

---

## 3. Integration Tests

| Area | Status |
|---|---|
| T-Shirt (model, 4 print areas, colors, sizes) | **PASS** — renders in real Chrome with correct 30×35 / 10×20 cm labels |
| Tote Bag | **PASS** — selectable, model + preview load |
| Cart | **PASS** (PHP integration suite) |
| Checkout | **PASS** (PHP integration suite, real WooCommerce) |
| Payment | **NOT RUN** — no gateway sandbox reachable (§12 was conditional on availability) |
| Production files | **PASS** — T-Shirt 3543×4134, Tote 3307×3780 @300 DPI, alpha preserved |

---

## 4. Database (§4) — environment limitation

A real MySQL/MariaDB server **could not be provisioned**: no server binaries or `sudo`, empty apt cache, no Docker/Podman, npm carries only *clients*, GitHub release-asset downloads are TLS-blocked, and no Go toolchain to build from source. All :3306 probes closed.

Compensating validation performed against the **real DDL** emitted by `Database::schema()` (11 tables):

- utf8mb4 on all 11 tables; no `ENGINE=`; no zero-dates; no TEXT/BLOB defaults.
- Widest index = `wp_td_models.slug` varchar(191) = **764 bytes**, well under the 3072-byte InnoDB limit.
- Migration `1.1.0` run **3×**: no duplicate designs/versions, every row byte-identical, DB version restored.
- Legacy Phase-1 row upgrade verified: design code, version 1, product type inherited, price preserved exactly, layer index + opacity added, geometry untouched, **exactly one** v1 snapshot and no duplicate on re-run.

---

## 5. Security

| Check | Status |
|---|---|
| Pricing manipulation | **PASS** — server Pricing Engine authoritative |
| Upload validation | **PASS** — and hardened, see Issue #1 |
| Ownership / IDOR | **PASS** |
| REST permission callbacks | **PASS** |
| Admin-only production | **PASS** |
| Test-shim leakage | **FIXED** — see Issues #1 and #2 |

---

## 6. Issues Found

### Issue #1 — Test constant could bypass upload validation *(Severity: HIGH — security)*
- **File:** `includes/class-media-manager.php`
- **Problem:** `is_test_context()` was gated solely on `defined('TD_TESTING')` and is used to **bypass `is_uploaded_file()`**.
- **Root cause:** A test-only escape hatch with no environment check; any code path defining that constant would let an attacker nominate an arbitrary server path as an "upload".
- **Fix:** Now additionally requires a CLI-style SAPI, absence of `REMOTE_ADDR`/`HTTP_USER_AGENT`, and a non-empty existing `$tmp_name`.
- **Regression test:** reflection-based tests proving it refuses when either request header is present and recovers when unset.

### Issue #2 — Test harness was web-reachable *(Severity: HIGH — security)*
- **File:** `tests/*.php` (5 files)
- **Problem:** `tests/` ships **inside** the plugin folder, so `bootstrap-wp.php` — which defines `TD_TESTING` — was reachable over HTTP.
- **Root cause:** Test files colocated with shipped code and no entry-point guard. (Note: an `ABSPATH` grep is a false positive here.)
- **Fix:** Added an identical `403 + exit` guard to all 5 files.
- **Regression test:** asserts every one of the 5 files contains the guard.

### Issue #3 — `NOT NULL` columns without defaults *(Severity: MEDIUM — MySQL strict mode)*
- **File:** `includes/class-database.php`
- **Problem:** 5 `name varchar(191) NOT NULL` columns had no `DEFAULT`; `prepare_row()` only emits supplied keys, so any caller omitting `name` errors under STRICT mode.
- **Fix:** `NOT NULL DEFAULT ''`, matching the existing `file_name`/`original_name` convention.
- **Regression test:** asserts no `NOT NULL` column in the DDL lacks a default.

### Issue #4 — Fatal error on every designer page render *(Severity: CRITICAL)*
- **File:** `includes/class-assets.php`
- **Problem:** `templates/designer.php` calls `Assets::enqueue_designer()` statically, but it was an instance method → **`Error: Non-static method cannot be called statically`**, HTTP 500 on every render of `[tshirt_designer]`.
- **Root cause:** No test had ever rendered the shortcode over real HTTP; PHP-only tests never executed the template.
- **Fix:** Made the method `static` (it uses no instance state, matching sibling `boot_data()`).
- **Regression test:** reflection assertion + `do_shortcode()` render check.

### Issue #5 — Second fatal: `$plugin` undefined in template *(Severity: CRITICAL)*
- **File:** `includes/class-shortcode.php`
- **Problem:** The template documents `$plugin` as its contract, but `render()` never defined it → `boot_data(): Argument #1 must be of type Plugin, null given`.
- **Fix:** `$plugin = $this->plugin;` before the `require`.
- **Regression test:** asserts the assignment exists and that boot data carries both REST roots plus a nonce.

### Issue #6 — `Editor2D.render()` crashed on null print area *(Severity: MEDIUM)*
- **File:** `assets/js/designer/editor2d.js:404`
- **Problem:** The 5 cm grid loop dereferenced `this.area.max_width_cm` with no guard, throwing on every first paint, model load, and color apply (caught by the subscriber, so it never surfaced as an uncaught error).
- **Fix:** Early return when `this.area` is null, consistent with `_resizeCanvas()`.
- **Regression test:** asserts the guard is present.

### Issue #7 — 3D viewport collapsed to 47 px *(Severity: HIGH — UX)*
- **File:** `assets/css/designer.css`
- **Problem:** The 3-column grid collapses via **viewport** media queries, but the designer is a widget inside a theme-constrained column (~605 px on a 1920 px viewport). The 3D stage was crushed to **47 px** and the loading text clipped.
- **Root cause:** Viewport-based breakpoints cannot see the app's real available width.
- **Fix:** Added a container query (`container-type: inline-size` + `@container tdapp (max-width: 980px)`) so the layout collapses on the app's own width. Stage went 47 px → 605×756.
- **Regression test:** asserts the container query is present.
- **Note:** Found only by *looking at a screenshot* — the numeric "canvas has non-zero size" assertion passed on the broken layout.

---

## 7. Production

| Check | Status |
|---|---|
| PNG dimensions | **PASS** — T-Shirt 3543×4134, Tote 3307×3780 |
| DPI | **PASS** — 300 |
| Alpha / transparency | **PASS** |
| Snapshot immutability | **PASS** |
| Regeneration | **PASS** |

---

## 8. Final Status

### **PHASE 2.1 — PASS WITH WARNINGS**

All 503 PHP tests and 29 real-browser checks pass, and seven defects were found and fixed — including **two CRITICAL fatals that made the designer page return HTTP 500 on every render** and two HIGH-severity security holes.

Warnings (environment limitations, not product defects):

1. **No MySQL/MariaDB server available.** §4 was satisfied by static DDL analysis plus SQLite-backed migration idempotency tests. The schema should still be smoke-tested against real MySQL before production.
2. **No payment gateway sandbox** — §12 could not be executed.
3. WooCommerce's compiled CSS/JS bundles are absent from the source checkout (build artifacts); their 404s are a harness artifact.

The two CRITICAL fatals are the headline finding: the plugin could not render its own shortcode, and **no amount of PHP-only testing had caught it** — it required serving real WordPress over HTTP to a real browser.
