# PHASE 3.2 — Professional Customer Mockup & Pre-Order Preview

Branch: `arena/01a06d64-ideal`
Commits: `267ef2f` (viewer) → `3b51305` (tests) → `3c3fb25` (visual fixes) → this report

---

## 1. Implementation summary

A customer-facing mockup preview now sits between the designer and the cart. Clicking
**Add to cart** opens a full-screen dialog showing the finished product on the real 3D
model, with view switching, zoom, a design summary and an explicit approval action. Only
after approval does the existing add-to-cart flow run.

The central decision: **the mockup owns no rendering code**. It instantiates the same
`Viewer` and `Compositor` the designer already uses and feeds them the same design data.
That is what makes the "mockup matches the design" guarantee structural rather than a thing
to be maintained — there is only one implementation of placement, one text engine, one
transform system.

**No new REST endpoint, no new database table, no migration, no new namespace.** The
mockup needed none: everything it displays is already in the boot payload and the model
REST response.

## 2. Files added

| File | Purpose |
|---|---|
| `assets/js/designer/mockup.js` | The mockup presentation layer (~430 lines) |
| `tests/browser/mockup-tshirt.mjs` | T-Shirt flow, design + camera integrity |
| `tests/browser/mockup-tote-mobile.mjs` | Tote flow, product-type isolation, mobile |
| `tests/browser/mockup-cleanup-a11y.mjs` | Three.js disposal, accessibility, breakpoints |
| `tests/browser/mockup-security.mjs` | XSS and attack-surface checks |
| `tests/browser/README.md` | How to run them, and three harness traps |
| `docs/img/*.png` | Screenshots |

## 3. Files modified

| File | Change |
|---|---|
| `assets/js/designer/main.js` | `previewThenCart()` inserted before `addToCart()`; instance exposed on its own DOM node |
| `assets/css/designer.css` | Mockup styles, design tokens, responsive rules |
| `includes/class-assets.php` | 18 mockup i18n strings + `productTypes` label map |
| `tools/make_translations.py` | 12 new Persian translations |
| `languages/*` | Regenerated: 516 strings, fa_IR 100% |

## 4. Architecture

```
Designer ──► Design JSON (single source of truth)
                  │
                  ├──► Compositor + Viewer ──► designer 3D preview
                  │
                  └──► Mockup (deep copy) ──► Compositor + Viewer ──► customer preview
                                                      │
                                                Customer approval
                                                      │
                                                      ▼
                                    existing addToCart() ──► WooCommerce
```

The mockup receives a **deep copy** of the design and never writes to `State`. It has no
`fetch`, no server calls, and no reference to any production or admin endpoint — verified by
test, not just by inspection.

Production is untouched: the immutable snapshot is still taken at payment, and print files
are still produced by `Production_Renderer`. **A mockup can never become a production file** —
it has no export path at all (see Known limitations).

## 5. Mockup rendering approach

Reuses `Compositor` (2048² texture atlas: garment colour, then every item drawn in
centimetre coordinates with x/y/scale/rotation/opacity in layer order) and `Viewer`
(GLB load, PMREM environment lighting, ACES tone mapping, OrbitControls).

Because artwork is painted **into the texture**, it follows the fabric when the model
rotates rather than floating over it. Text is whatever `textrender.js` produced — the same
raster the designer shows.

## 6. Product type support

| Product | Views | Verified |
|---|---|---|
| T-Shirt | FRONT, BACK, LEFT_SLEEVE, RIGHT_SLEEVE | yes |
| Tote Bag | FRONT, BACK | yes |

Views are derived from the model's own `print_areas`, so isolation is structural: a Tote has
no sleeve areas and therefore cannot render sleeve buttons. No new product types were added.

## 7. View support

Buttons appear only for print areas the current model actually has, in a fixed order. Each
switch animates the shared `Viewer` camera to that area's preset.

## 8. REST changes

**None.** No new routes, no changes to existing ones, no new namespace. Ownership continues
to be enforced by the existing `Design_Manager::get_design( $id, $user_id, $guest_token )`,
which the mockup inherits because it adds no path of its own.

## 9. Security

| Concern | Result |
|---|---|
| XSS via design content | All interpolation escaped; verified with a live payload |
| Arbitrary GLB URL | Model URL comes from the server payload only |
| Path traversal / filesystem | No filesystem access; no server code added |
| IDOR / unauthorized design | Existing ownership check; verified cross-customer |
| Production data exposure | No reference to any production or admin endpoint |

Cross-customer test: Alice saves a design, Bob requests it → **denied (null)**; Alice reads
her own → allowed.

XSS test injects `"><img src=x onerror=alert(1)><script>alert(2)</script>` into the model
name, product type, colour, size and print-area names. No `alert()`, 0 injected elements,
payload rendered as inert text. **Verified by mutation**: removing `esc()` fires the alert
and injects 5 `<img>` and 5 `<script>` elements, so the test genuinely detects the flaw.

## 10. Performance

- The 3D scene is built only when the customer opens the mockup — nothing is loaded up front.
- Only the active view is rendered; switching moves the camera rather than reloading.
- No API calls of its own.
- Disposal goes beyond `Viewer.dispose()`, which leaves behind the PMREM environment map,
  cached shader programs and the GL context. Those are released explicitly, plus the 2048²
  canvas backing store.

## 11. Browser tests

| Suite | Checks |
|---|---|
| T-Shirt flow, four views, zoom, design integrity, camera integrity, cart | 15 |
| Tote flow, product-type isolation, decline path, mobile | 31 |
| Three.js disposal, accessibility, desktop breakpoints | 30 |
| Security | 9 |
| **Total** | **85** |

Design integrity (§29) and camera integrity (§30): the design JSON is captured before the
mockup opens and compared after opening, switching all four views, zooming in, zooming out,
resetting and approving. **Byte-identical.**

## 12. Mobile tests

360×800, 390×844, 412×915 — each verified for: no horizontal overflow, canvas renders,
dialog fits the viewport, confirm button ≥40px tall, all four views present, view switching
works, zero JS errors. Desktop 768/1024/1440 verified the same way.

## 13. Regression tests

| Suite | Result |
|---|---|
| Unit (bounds/pricing) | 35 / 35 |
| Core | 274 / 274 |
| WooCommerce | 119 / 119 |
| Admin | 75 / 75 |
| **Production** | **198 / 198** |
| Customer status | 17 / 17 |
| Uninstall | 19 / 19 |

Production snapshot immutability, PNG dimensions, DPI, ZIP generation, events and status
transitions all still pass unchanged.

## 14. Known limitations

1. **No mockup export (§21).** The brief made this optional ("only if it can be implemented
   safely"). It was deliberately skipped: the honest way to produce a downloadable image is
   a canvas snapshot, and any such file invites being mistaken for a print file. The
   requirement it protects — *never let a mockup become a production file* — is better served
   by there being no export at all. Easy to add later behind a watermark.
2. **Pinch-zoom is whatever OrbitControls provides.** Not separately implemented; the
   existing touch handling is inherited. Buttons cover the required zoom in/out/reset.
3. **Persian UI not screenshot-verified.** `is_rtl()` and the `dir` attribute were verified
   programmatically, and all 516 translations were confirmed to load through WordPress's own
   MO reader, but WordPress core `fa_IR` language files are not installable in this sandbox,
   so the dialog could not be *photographed* in Persian.
4. **Carry-over, unchanged:** no MySQL/MariaDB in this environment (SQLite drop-in), and no
   payment gateway sandbox.

## 15. Screenshots

| | |
|---|---|
| Desktop T-Shirt | `docs/img/mockup-desktop-front.png` |
| Mobile 390×844 | `docs/img/mockup-mobile.png` |
| Tote Bag | `docs/img/mockup-tote.png` |

The Tote screenshot doubles as visual proof of §31: only Front and Back are offered.

## 16. Final status

```
PHP tests:        737   (35 unit + 274 core + 119 wc + 75 admin + 198 production
                         + 17 customer status + 19 uninstall)
Browser tests:     54   (15 T-Shirt + 30 cleanup/a11y/desktop + 9 security)
Mobile tests:      21   (360×800, 390×844, 412×915 — 7 checks each)
REST tests:         0   (no REST changes were made in this phase)
Security tests:    10   (9 browser + 1 cross-customer ownership)
Regression tests: 737   (the full PHP suite above, all pre-existing)
Total checks:     822
Failures:           0
Warnings:           4   (the known limitations in §14)

Git commit:  3c3fb25
Branch:      arena/01a06d64-ideal
Working tree: clean
```

### **PHASE 3.2 — PASS WITH WARNINGS**

Not a clean PASS, for one reason I want to be explicit about: **mockup export (§21) is not
implemented**. It was optional in the brief and I judged omitting it safer than shipping a
downloadable image that could be mistaken for a print file — but it is an unimplemented
requirement, and calling this a clean PASS would misrepresent that. The three other warnings
are environmental.

Every mandatory acceptance criterion in §43 is implemented and tested against a real browser
and a real WooCommerce install.

---

## Notes on how this was verified

Three tests were found to be **incapable of failing** and were fixed before being trusted:

1. The leak test counted `<canvas>` elements. Deleting the entire disposal path still passed,
   because the dialog is removed from the DOM either way. It now asserts on
   `renderer.info.memory`, three.js's own live resource count, and was confirmed to fail
   (canvases 3→7) when teardown is broken.
2. The first replacement instrumented `createTexture`/`deleteTexture` globally, which
   conflated the designer's long-lived renderer with the mockup's short-lived one and
   reported a leak that did not exist.
3. The XSS test was confirmed by removing `esc()` and watching it fail.

Two apparent product bugs turned out to be **test races**, and are documented in
`tests/browser/README.md` so they are not rediscovered:

- `loadModel()` resets `state.areas` to `{}` on completion, so a model load still in flight
  wipes artwork added afterwards — which presents exactly as "the mockup mutated the design".
- The asset grid re-renders on every state change, so a captured button can be detached
  before its click handler runs.

The dark-on-dark approve button was found by **looking at the screenshots**, not by the
tests — 85 passing checks said nothing about whether the primary call-to-action was visible.
