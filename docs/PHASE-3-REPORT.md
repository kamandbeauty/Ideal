# PHASE 3 — Production Management & Fulfillment

Branch: `arena/01a06d64-ideal`
Commits: `f3184e1` (workflow) → `c40f2bd` (files/ZIP/REST/tests) → `739fa1a` (dashboard)

---

## 1. Architecture

**Preserved (untouched public APIs):** Core, Product Type Registry, Design Manager, Pricing Engine, Cart Manager, Order Manager, Snapshot system, REST `tshirt-designer/v1` and `custom-product-designer/v1`, WooCommerce integration, Logger, Text Engine.

**Extended:**
- `Production_Renderer` — added per-area metadata (cm, mime, size, SHA-256 hash, job link) and hardened `build_zip()`. Rendering logic itself unchanged.
- `Order_Manager::on_payment_complete()` — one added line that opens production jobs.
- `Database::schema()` — two new tables + new columns on the existing `td_production_files`.
- `Migrations` — new versioned step `1.2.0`.
- Admin menu + WooCommerce order panel — a "View Production" link.

**Changed (bug fixes only):** `Production_Manager::query()` search (see Issues).

**New:** `Production_Status` (state machine), `Production_Manager` (lifecycle), `Production_Service` (files/downloads), `Rest_Production`, `Admin_Production` + 2 views.

Separation of responsibility is respected (§27): WooCommerce is the commerce source and only *notifies*; all fulfilment logic lives in the production classes.

---

## 2. Database

**New tables:** `wp_td_production_jobs`, `wp_td_production_events`.

Per §33 I checked the existing schema first: `wp_td_production_files` **already existed**, so it was extended rather than duplicated, and the suggested `production_logs` + `production_notes` tables were **deliberately not created** — notes and history are the same append-only event stream, so one `production_events` table serves both.

**Migration:** `1.2.0` (`TD_DB_VERSION` 1.1.0 → 1.2.0), additive only, repeat-safe, no `DROP`. Back-fills jobs for orders paid before Phase 3.

**Indexes:** jobs — `UNIQUE(order_id, order_item_id)` (the idempotency guarantee) plus `order_id`, `design_id`, `status`, `priority`, `product_type`, `model_id`, `customer_email`, `created_at`. Events — `job_id`, `event_type`, `created_at`. Files — added `job_id`.

---

## 3. Production

- **Jobs:** one per designed order line, created on `payment_complete`.
- **Statuses (11):** new, paid, ready_for_production, in_production, printed, quality_check, packed, shipped, completed, cancelled, production_error.
- **Transitions:** table-driven; cancellation from any live state; QC failure returns to in_production (note mandatory); production_error can requeue; completed/cancelled are terminal. **Backend authoritative** and concurrency-safe via an optimistic `WHERE status = <from>` lock.
- **Snapshots:** always read from the order item, never the live catalogue.
- **Files:** per-area PNGs, only for designed areas, deterministic names, SHA-256 recorded.

---

## 4. Admin

Dashboard with 10 status tabs + counts; filters for status, product type, model, priority, date range and sort; search across order/customer/email/design/job ID; pagination (20/page). Detail page shows order, product, design, status actions, per-area files with dimensions/DPI/size, downloads, ZIP, regenerate, retry, notes and a full activity timeline. Bulk transitions validate and log each job individually. RTL-aware CSS, no JS framework.

---

## 5. API

All under `custom-product-designer/v1`, all admin-gated:

| Method | Endpoint |
|---|---|
| GET | `/production` |
| GET | `/production/{id}` |
| POST | `/production/{id}/status` |
| POST | `/production/{id}/quality-check` |
| POST | `/production/{id}/regenerate` |
| POST | `/production/{id}/retry` |
| GET | `/production/{id}/files` |
| POST | `/production/{id}/notes` |
| GET | `/production/{id}/history` |

Plus two admin-post download endpoints (single file, ZIP), both nonce-protected.

---

## 6. Tests

| Suite | Before | After |
|---|---|---|
| Unit | 35 | 35 |
| Core WP | 274 | 274 |
| WooCommerce | 119 | 119 |
| Admin | 75 | 75 |
| **Production (new)** | — | **199** |
| **PHP total** | 503 | **702** |
| Browser — designer | 29 | 29 |
| Browser — admin UI (new) | — | 12 |
| Browser — REST (new) | — | 21 |
| Browser — customer lockout (new) | — | 10 |
| **Total** | 532 | **774** |

**Failures: 0.**

---

## 7. Real Acceptance Tests

| Scenario | Result |
|---|---|
| T-Shirt §63 (design → cart → checkout → payment → job → full pipeline → completed) | **PASS** |
| Tote Bag §64 (front+back → payment → job → files → ZIP) | **PASS** |
| Production workflow (all transitions, illegal moves refused) | **PASS** |
| Snapshot immutability under catalogue/pricing/model change | **PASS** |
| Regeneration (byte-identical, SHA-256 verified) | **PASS** |
| ZIP export (contents + traversal safety) | **PASS** |
| Security (anon, customer, IDOR, traversal, injection) | **PASS** |

**Verified on real files:** T-Shirt FRONT/BACK 3543×4134 @300 DPI, Tote FRONT/BACK 3307×3780 @300 DPI, corner alpha = 127 (fully transparent, no background), confirmed with `getimagesize()` and `imagecolorat()` on the actual PNGs.

**The key regression test (§53):** after purchase I renamed the model, shrank the front print area to 10×10 cm and raised the WooCommerce price to 999999, then regenerated. Output stayed **3543×4134 and byte-identical** to the purchased file.

---

## 8. Issues Found

### Issue #1 — Search matched unrelated jobs *(MEDIUM)*
- **File:** `includes/class-production-manager.php`
- **Root cause:** A non-numeric search term fell back to `0` for the `order_id`/`id`/`design_id` comparisons, so any job with a zero in those columns matched every text search.
- **Fix:** Only add the numeric clauses when the term is actually numeric.
- **Test:** the SQL-injection search case, which now correctly returns 0 rows.

### Issue #2 — Wrong snapshot key would have pinned every job to v1 *(MEDIUM, caught pre-merge)*
- **File:** `includes/class-production-manager.php`
- **Root cause:** I read `$snapshot['version']`; the real key is `design_version`, so `design_version` would have silently defaulted to 1 for every job — quietly wrong on the exact field §38 depends on.
- **Fix:** read `design_version`.
- **Test:** "the job records the design version".

### Issue #3 — ZIP entries and file paths were not containment-checked *(MEDIUM, hardening)*
- **File:** `includes/class-production-renderer.php`, `includes/class-production-service.php`
- **Root cause:** `build_zip()` trusted the `file_path` column and used `file_name` directly as the archive entry. A tampered row could have escaped the uploads directory.
- **Fix:** `realpath()` containment under the production dir, `is_file()` check, and flat sanitised entry names.
- **Test:** tampered-path and traversal-path cases, plus per-entry ZIP name assertions.

### Non-issue worth recording
`wp-admin` appeared reachable without cookies. I did **not** patch anything: restarting the server proved a cold request correctly 302s to `wp-login.php`. The leak was my own php-wasm harness reusing one PHP instance across requests, so `$current_user` persisted. Recorded so nobody "fixes" a bug that does not exist.

---

## 9. Definition of Done (§62)

All 33 boxes satisfied: job system, statuses, transitions, snapshot, T-Shirt + Tote production, per-area files, dashboard, search, filters, detail, preview, download, ZIP, regenerate, regeneration history, notes, activity log, quality check, retry, error handling, WooCommerce integration, REST API, security permissions, file access protection, snapshot immutability, backward compatibility, migration, unit tests, integration tests, regression tests, no fake data, no rewrite, git clean.

---

## 10. Final Status

### **PHASE 3 — PASS**

774 automated checks pass with zero failures. Both acceptance scenarios were executed end-to-end against real WooCommerce with real payment completion, and the resulting PNGs were verified on disk for dimensions, DPI and transparency. Snapshot immutability is proven by hash against a deliberately vandalised catalogue.

Two carry-over environment limitations from Phase 2.1 remain and are **not** Phase 3 defects:

1. **No MySQL/MariaDB server** is obtainable in this sandbox; all DB work ran on the SQLite drop-in. The two new tables and the `1.2.0` migration should get a real MySQL smoke test before production.
2. **No payment gateway sandbox.** Payment is driven through WooCommerce's real `payment_complete()`, which is the hook production jobs key off, but a hosted gateway's success/failure/cancel callbacks are still unexercised.
