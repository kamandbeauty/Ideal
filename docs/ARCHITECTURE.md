# Architecture

The empty bootstrap scene starts `GameBootstrap`; runtime systems build a deterministic vertical slice from data definitions. Visual roots are explicitly named `*_ReplaceableVisual`. Replacing them with licensed prefabs does not alter player, army, combat, gate, stage, save, or UI code.

- `PlayerController`: Input System EnhancedTouch drag and bounded smooth movement.
- `ArmyManager`: pooled real units, adaptive formation, count/capacity and group firepower.
- `SoldierController`: delayed follow, target selection, aim and projectile fire.
- `ProjectileSystem`: warmed object pool, real travel, damage and impact VFX.
- `EnemyController`: proximity activation, movement, melee/ranged tuning and death.
- `GatePairController`: immediate one-shot lane decision and arithmetic.
- `StageManager`: modular environment, data-driven gate pairs/waves, victory/loss.
- Services: save, upgrades, skins, reward, ads, audio and performance remain independent.

Ten stage definitions are currently synthesized as `StageDefinition` ScriptableObjects at bootstrap. Production designers can persist equivalent assets through Unity's Create Asset menu without changing consumers. Stage 1 is the priority vertical slice; later stages are balancing content, not separate hard-coded gameplay classes.
