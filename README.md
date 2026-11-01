# Ideal

A clean-room rebuild of the app Ideal, plus our own fixes and brand.

## Skills

The **Replica** skill pack is installed project-locally in [`.claude/skills/`](.claude/skills)
(MIT — https://github.com/Jakeschincariol/replica-skill). Eleven skills, run in order:

```
recon -> architect -> design -> build -> backend -> test -> diff -> entrepreneur -> brand -> launch -> deploy
```

Each one writes into `replica/` and reads what the previous one wrote.
See [`.claude/skills/README.md`](.claude/skills/README.md) for the map and the tools.

## Ground rules

Rebuild features and flows only. Never the original's code, assets, logo, copy,
catalogue or private APIs. Public pages and our own account only. Rebrand before
deploy (`replica-brand/sweep.py` must come back clean).
