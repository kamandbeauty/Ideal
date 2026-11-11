# Source integrity and recovery report

## Scope and result

The original reported revision **has not been recovered or verified**. The current `zombie-evolution-rebuild/` files remain in the working tree; no reset, clean, overwrite, deletion, checkout of another branch, reconstruction of commit history, or remote push was performed. This report and `SOURCE_MANIFEST.sha256` are new evidence, not proof that these files are identical to the missing revision. `TESTING.md` was updated to record this audit.

## Git evidence

- Current branch: `arena/70907c19-ideal`.
- Current HEAD and most recent locally available revision: `e2f4de4ee3bdbadb07ed424218cb82445242ac52` (`Initial commit`). The repository is shallow (`git rev-parse --is-shallow-repository` returned `true`); HEAD is marked `grafted`.
- The base tree contains only `README.md`; `git ls-tree -r --name-only e2f4de4ee3bdbadb07ed424218cb82445242ac52 -- zombie-evolution-rebuild` produced no entries. The whole rebuild directory is untracked in this checkout. The root README is modified, and other unrelated files are also untracked; they were preserved.
- `git cat-file -t 5fcbed0` returned `fatal: Not a valid object name 5fcbed0`. The available earlier report recorded only this seven-character identifier, so its full object ID cannot be independently established here. `git cat-file -t 30c9e9b20afbc8eb80a68e102962a62c440b50e1` also failed. No local ref or reflog entry identifies either reported commit.
- `git fsck --full --no-reflogs` returned exit 0 and reported 45 dangling blobs, with no other messages; it reported no dangling commits or trees. Every one of the 22 pre-report project files had a content-identical blob in the object database when tested with `git hash-object <path>` and `git cat-file -e <hash>`. Blob presence verifies the object exists for those current bytes only; it does **not** establish a path, revision, history, or provenance for those bytes. `fsck` exit 0 is not proof of completeness of this shallow repository or authenticity of the working tree.
- Remote: `origin` is `https://github.com/kamandbeauty/Ideal.git`. `git ls-remote --heads origin` succeeded; remote `main` is `e2f4de4ee3bdbadb07ed424218cb82445242ac52`. There was no remote head named `arena/70907c19-ideal` in the returned list. Other remote branches were listed but not checked out or modified.
- `gh api repos/kamandbeauty/Ideal/commits/5fcbed0` and `gh api repos/kamandbeauty/Ideal/commits/30c9e9b20afbc8eb80a68e102962a62c440b50e1` returned HTTP 422, “No commit found for SHA”. `gh api 'repos/kamandbeauty/Ideal/commits?sha=main&per_page=10'` returned the base commit above. This does not rule out an inaccessible external copy or a different repository.
- The branch reflog records creation from the base in the current checkout and no later local commits. The checkout is shallow and the previously reported commits are not present locally or found by the remote API. The exact cause of their absence is unknown; do not infer corruption or assert that they were never created.

## Origin, comparison and reproducibility

The available conversation and preserved `TESTING.md` describe the files as authored during this session, but no matching commit tree or signed reference exists here to independently verify that account. Relative to the only locally available source revision, all rebuild project files are additions; there is no earlier tracked version of these paths to compare. Their identity against the previously reported commit is therefore **unknown**.

`SOURCE_MANIFEST.sha256` records SHA-256 hashes for 21 current project files, including the project configuration, scenes, scripts, tests, font, preset and README. It deliberately excludes itself, this report, and the mutable `TESTING.md`. From the repository root run `sha256sum -c zombie-evolution-rebuild/SOURCE_MANIFEST.sha256`. The checksums were generated from the current unverified files in this audit; they establish a baseline for *future* comparison, not authenticity or equivalence to `5fcbed0`.

To recover the reported revision, obtain the original full commit ID and an independently trusted repository/ref, bundle or source archive containing its commit and tree. Compare the tree and individual blobs with this baseline before asserting equivalence. Preserve the current working files while doing so.

## CI baseline check — subsequent run

On the current branch `arena/70907c19-ideal`, `git rev-parse HEAD` again returned `e2f4de4ee3bdbadb07ed424218cb82445242ac52`; `git cat-file -t 5fcbed0` again failed. Origin remains `https://github.com/kamandbeauty/Ideal.git`; `git status --short` shows the rebuild directory and the new workflow as untracked, with unrelated pre-existing changes preserved. No missing history was reconstructed.

The existing `SOURCE_MANIFEST.sha256` was not modified. Its own SHA-256 is `91eb09119c7c8b26b5387d9dacf2720aa481de028ef263be4eff2e97db971280`; `sha256sum -c zombie-evolution-rebuild/SOURCE_MANIFEST.sha256` passed for all 21 listed files. This comparison checks the previously recorded local baseline, not the unavailable commit. New `ci/` files, this report, `TESTING.md`, and `VALIDATION_REPORT.md` are not covered by that original manifest. The project's source files are not yet tracked by HEAD, so a clean CI checkout cannot contain them until the appropriate files are committed and pushed to the current branch. No such push was performed in this run.
