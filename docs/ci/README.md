# CI workflow — needs to be installed manually

`ci.yml` in this directory is a ready-to-use GitHub Actions workflow. It is parked here
rather than at `.github/workflows/ci.yml` because the automation account that produced this
branch does not hold the GitHub `workflows` permission, so pushing a file to
`.github/workflows/` is rejected outright:

```
refusing to allow a GitHub App to create or update workflow
.github/workflows/ci.yml without `workflows` permission
```

Nothing is wrong with the file — it simply cannot be pushed from here.

## Installing it

```bash
mkdir -p .github/workflows
git mv docs/ci/ci.yml .github/workflows/ci.yml
git commit -m "ci: enable GitHub Actions"
git push
```

Do that from an account with the `workflows` scope (a normal human push works fine).

## What it runs

| Job | Blocking | What it does |
|---|---|---|
| `lint` | yes | `php -l` on every PHP file, against PHP 8.1, 8.2 and 8.3 |
| `coding-standards` | **no, advisory at first** | phpcs against `phpcs.xml` (WPCS + PHPCompatibility) |
| `translations` | yes | Regenerates the catalogue, fails on missing Persian strings or a stale committed catalogue |

## Why phpcs starts advisory

The code was written to WPCS by hand and has never been machine-checked — there is no PHP
binary in the environment this branch was built in, so phpcs could not be run to confirm it
is clean. Making it blocking immediately would very likely have wedged CI on formatting
nits at the first push.

The intended sequence is: run it once, read the annotations, fix what it finds, then delete
the `continue-on-error: true` line in the `Run phpcs` step so standards become enforced.
The step is commented to that effect.

## Note on the translation check

It deliberately does **not** use `git diff` to detect a stale catalogue. The generator
rewrites `POT-Creation-Date` on every run, so a plain diff is always dirty and the check
would fail permanently. It compares `msgid`/`msgstr` content with the timestamp headers
stripped instead. This was verified both ways: it passes on the current tree and fails on a
deliberately mutated catalogue.
