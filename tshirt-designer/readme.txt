=== Custom Product Designer ===
Contributors: studiojavid
Tags: woocommerce, product designer, 3d, print on demand, customization
Requires at least: 6.0
Tested up to: 6.8
Requires PHP: 8.1
Stable tag: 1.2.0
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Product-agnostic 3D product designer for WooCommerce with server-computed pricing and a print-ready production workflow.

== Description ==

Custom Product Designer lets customers personalise physical products in the browser on a real
3D model, then turns each paid order line into a tracked production job with print-ready files.

The plugin ships with two product types — T-Shirt and Tote Bag — and is product-agnostic:
models, colours, sizes and print areas are all data, so more product types can be added
without touching code.

**Designing**

* Real-time 3D preview (Three.js) with a 2D editing surface
* Multiple print areas per product (T-Shirt front, back and both sleeves; Tote front and back)
* Artwork library, customer uploads and text with font, colour, size, rotation and opacity
* Layers keep their position, scale, rotation, opacity and order
* Designs are saved, versioned and re-orderable from My Account

**Pricing**

* Price is computed on the server, never trusted from the browser
* Per-product-type base price with rules by artwork size, print area and item count
* Area rules override global rules

**Production and fulfilment**

* One production job per designed order line, created on payment
* An immutable snapshot of the design is taken at payment; production always renders from
  the snapshot, never from the current catalogue, so later catalogue edits cannot change a
  purchased order
* Per-print-area PNG files at physical print size × DPI, with transparency preserved
* Typed status pipeline: New, Paid, Ready for Production, In Production, Printed,
  Quality Check, Packed, Shipped, Completed, plus Cancelled and Production Error
* Transitions are validated on the server, so no arbitrary jumps
* Admin dashboard with status tabs, filters, search, bulk actions and priorities
* Per-job detail view with previews, dimensions, per-area downloads and a ZIP export
* Quality check pass/fail, internal notes, retry, and a full activity log
* REST API for the whole production workflow, gated by capability

**Privacy**

The plugin stores designs, uploaded artwork and rendered production files. Nothing is sent
to any third-party service; all rendering happens on your own server.

== Installation ==

1. Install and activate WooCommerce 8.0 or newer.
2. Upload the plugin to `/wp-content/plugins/` or install it through Plugins → Add New.
3. Activate it through the Plugins screen. Tables and default content are created on activation.
4. Place the designer on a page with the `[tshirt_designer]` shortcode, or use the
   "T-Shirt Designer" block.
5. Configure models, colours, sizes, print areas, artwork and pricing under the plugin's
   admin menu.

== Frequently Asked Questions ==

= Does it require WooCommerce? =

Yes. Pricing, cart, checkout and production jobs are all built on WooCommerce.

= What happens to an existing order if I change a product later? =

Nothing. The design is snapshotted at payment and every production file is rendered from
that snapshot, so editing a model, print area or price afterwards never alters a purchased
order or its print files.

= Can customers see the production files? =

No. Production files, internal notes and the activity log are restricted to users with the
`manage_options` capability. Customers never receive file access.

= Is it translation ready? =

Yes. All strings are translatable and a complete Persian (fa_IR) translation is bundled,
including full RTL support in the admin.

= Is it compatible with HPOS / High-Performance Order Storage? =

Yes, compatibility is declared explicitly.

== Changelog ==

= 1.2.0 =
* New: production and fulfilment workflow — one job per designed order line, created on payment.
* New: typed production status pipeline with server-validated transitions.
* New: immutable design snapshot taken at payment; all production renders from the snapshot.
* New: per-print-area print-ready PNG files with a ZIP export.
* New: admin production dashboard with tabs, filters, search, bulk actions and priorities.
* New: job detail view with previews, downloads, regeneration, notes, quality check and activity log.
* New: production REST API, gated by capability.
* New: complete Persian translation of the production interface.
* Fix: uninstall now removes every plugin table, production files and scheduled events.

= 1.1.0 =
* New: product-agnostic product types, with a bundled Tote Bag alongside the T-Shirt.
* New: design versioning and an order-again flow.
* New: print-ready file generation for paid orders.
* Improved: server-side pricing rules per print area.

= 1.0.0 =
* Initial release: 3D T-Shirt designer, artwork library, uploads, text, pricing and cart integration.

== Upgrade Notice ==

= 1.2.0 =
Adds the production and fulfilment workflow. Database tables are added automatically and
existing orders are backfilled as production jobs. No existing data is removed.
