# Browser tests — customer mockup preview (Phase 3.2)

Real-Chrome tests for the mockup. They drive the live designer, so they need a running
WordPress with WooCommerce, the plugin active, and a page containing the
`[tshirt_designer]` shortcode. Each script discovers that page itself rather than
hardcoding an ID.

| File | Checks | Covers |
|---|---|---|
| `mockup-tshirt.mjs` | 15 | T-Shirt flow, four views, zoom, design integrity (§29), camera integrity (§30), cart |
| `mockup-tote-mobile.mjs` | 31 | Tote front/back, product-type isolation (§31), decline path, 360/390/412 mobile (§33) |
| `mockup-cleanup-a11y.mjs` | 30 | Three.js disposal (§34), accessibility (§25), desktop breakpoints (§24) |
| `mockup-security.mjs` | 9 | XSS through design content, no network/production surface (§22) |

Run with a Puppeteer-capable Chrome:

```bash
node mockup-tshirt.mjs
```

## Three traps these tests hit, recorded so they are not re-introduced

1. **`loadModel()` resets `state.areas` to `{}` when it finishes.** Waiting only for the
   print-area buttons to appear is not enough — a load still in flight completes later and
   wipes artwork added in the meantime. That looks exactly like the mockup mutating the
   design. Always wait for `modelLoading` to clear.
2. **The asset grid re-renders on every state change.** A button captured a moment earlier
   can be detached before its click handler runs, so adding artwork must retry until the
   item count actually increases.
3. **Counting `<canvas>` elements does not detect GPU leaks.** The dialog is removed from
   the DOM whether or not resources are disposed, so that assertion passed even with
   disposal deleted entirely (verified by mutation). `renderer.info.memory` is three.js's
   own live count and is what the cleanup test asserts on.

All four suites were verified by mutation testing: breaking disposal, escaping, or the
dialog teardown makes the relevant assertions fail.
