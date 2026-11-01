# Installed skills — Replica pack

Source: https://github.com/Jakeschincariol/replica-skill (MIT, by Jake Schincariol).
Installed project-locally on 2026-11-01. All eleven skills, unchanged, with their
Python tools and templates.

Run in order, each reading what the last wrote into `replica/`:

    recon -> architect -> design -> build -> backend -> test -> diff -> entrepreneur -> brand -> launch -> deploy

| folder | purpose |
| --- | --- |
| replica-recon | Reverse-engineer the target app into screens, flows, components, data model, feature matrix |
| replica-architect | Stack, database schema, API plan, build order |
| replica-design | Design system as tokens (colour, type, spacing, components) |
| replica-build | Rebuild the app screen by screen |
| replica-backend | Auth, database, payments, integrations |
| replica-test | Test plan, Playwright specs, bug reports by severity |
| replica-diff | Parity score vs. the original, plus what is missing |
| replica-entrepreneur | Real user reviews -> ranked complaints, fix plan, positioning |
| replica-brand | New name, palette, logo brief, voice + rebrand sweep |
| replica-launch | Landing page, pricing, App Store / Play Store listing |
| replica-deploy | Preflight and ship to your own domain |

Tools (Python 3.8+, standard library only, no network):

    python3 .claude/skills/replica-diff/imgdiff.py original.png clone.png --out diff.png
    python3 .claude/skills/replica-diff/parity.py replica/features.csv
    python3 .claude/skills/replica-entrepreneur/reviews.py replica/reviews.csv
    python3 .claude/skills/replica-design/contrast.py replica/design/tokens.json
    python3 .claude/skills/replica-brand/sweep.py . --avoid "Original App"
    python3 .claude/skills/replica-launch/listing.py replica/launch/listing.json

Rules the pack enforces: clean-room rebuild of functionality and UX only — never
the original's code, assets, logo, copy, catalogue or private APIs; only public
pages and your own account; rebrand (clean `sweep.py`) before deploy.
