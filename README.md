# Custom Product Designer

A product-agnostic 3D product designer for WooCommerce, with server-computed pricing and a
print-ready production and fulfilment workflow.

Customers personalise a physical product in the browser on a real 3D model; every paid order
line becomes a tracked production job with print-ready PNG files rendered from an immutable
snapshot of the design.

Two product types ship out of the box — **T-Shirt** and **Tote Bag** — but nothing about the
plugin is T-Shirt specific: models, colours, sizes and print areas are all data.

## Requirements

| | |
|---|---|
| WordPress | 6.0+ |
| PHP | 8.1+ |
| WooCommerce | 8.0+ |
| PHP extensions | GD (image rendering), ZipArchive (ZIP export) |

HPOS / High-Performance Order Storage is explicitly supported.

## Installation

```bash
git clone https://github.com/kamandbeauty/Ideal.git
cp -r Ideal/tshirt-designer /path/to/wp-content/plugins/
```

Activate the plugin in wp-admin. Tables and default content are created on activation.
Add the designer to a page with the `[tshirt_designer]` shortcode or the bundled block.

## Repository layout

```
tshirt-designer/          the plugin itself
  includes/               domain classes (design, pricing, cart, orders, production)
  admin/                  admin controllers
    views/                admin templates
  assets/                 css, js (Three.js designer), fonts, sample artwork
  templates/              front-end templates
  languages/              .pot + Persian (fa_IR) .po/.mo
  tests/                  integration and unit suites
docs/                     phase reports and audits
tools/                    asset and translation generators
```

## Architecture

The plugin is deliberately split so that commerce and fulfilment do not bleed into each
other:

- **WooCommerce is the commerce source.** It owns the cart, checkout and payment. It only
  *notifies* the production side.
- **Production is the fulfilment source.** It owns jobs, statuses, files and history. No
  production logic lives inside WooCommerce hooks.

Key classes:

| Class | Responsibility |
|---|---|
| `Product_Type_Registry` | Product types, models, colours, sizes, print areas |
| `Design_Manager` | Saving, validating and versioning designs |
| `Pricing_Engine` | Server-side price calculation (never trusts the client) |
| `Cart_Manager` / `Order_Manager` | WooCommerce cart and order integration |
| `Production_Manager` | Job lifecycle, status transitions, events |
| `Production_Status` | The typed state machine |
| `Production_Renderer` | Renders print-ready PNGs from a snapshot |
| `Production_Service` | File listing, downloads, ZIP export |
| `Rest_Production` | Admin-gated REST endpoints |

### Snapshot immutability

When an order is paid, the design is snapshotted onto the order line. Every production
render reads that snapshot — never the live catalogue. Renaming a model, resizing a print
area or changing a price afterwards cannot alter a purchased order or its print files.
This is covered by a regression test that vandalises the catalogue after purchase and
asserts the regenerated file is byte-identical.

### Production statuses

```
new → paid → ready_for_production → in_production → printed
    → quality_check → packed → shipped → completed
```

Plus `cancelled` (reachable from any live state) and `production_error` (which can be
retried back into the pipeline). A failed quality check returns the job to
`in_production` and requires a note. Transitions are validated server-side and applied
with an optimistic lock, so concurrent admins cannot double-advance a job.

## REST API

Namespace `custom-product-designer/v1`. All production routes require the
`manage_options` capability and a valid nonce.

| Method | Route |
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

## Extending

The plugin fires action hooks for every production event, so notifications (email, SMS,
webhooks) can be added without modifying it:

```php
add_action( 'td_production_status_changed', function ( $job_id, $from, $to ) {
    // notify the customer, call a webhook, ...
}, 10, 3 );
```

Available: `td_production_created`, `td_production_status_changed`,
`td_production_completed`, `td_production_failed`, `td_production_file_generated`.

## Translation

All strings use the `tshirt-designer` text domain. A complete Persian (`fa_IR`) translation
is bundled and the admin is RTL-aware.

To regenerate the catalogue after adding or changing strings:

```bash
python3 tools/make_translations.py
```

The script extracts every translatable string, rewrites the `.pot`, and reports any missing
or unused Persian entries. It refuses to leave the catalogue silently out of date.

## Tests

The suites run against a real WordPress + WooCommerce install and drive real flows —
design → cart → checkout → payment → production — then verify the produced PNGs on disk.

```
tests/unit-bounds-pricing.php        pricing and print-area bounds
tests/integration-suite.php          designs, models, product types, REST
tests/integration-woocommerce.php    cart, checkout, orders, snapshot, ZIP
tests/integration-admin.php          admin screens
tests/integration-production.php     the production workflow
tests/integration-uninstall.php      uninstall cleanup (destructive; run alone)
```

`integration-uninstall.php` drops the plugin schema by design, so run it in its own
process, never alongside the others.

## Uninstall

Deleting the plugin removes data **only** if "Delete all data on uninstall" is enabled in
the plugin settings. When it is, every plugin table, both upload directories
(`td-uploads` and `td-production`), the plugin options and its scheduled events are
removed. With the setting off, only bookkeeping options are cleared and all customer data
is preserved.

## Licence

GPL-2.0-or-later. See [LICENSE](LICENSE).
