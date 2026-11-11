class_name Layers
extends RefCounted
## 3D physics layers. Rounds are ray-swept, so nothing here ever resolves contacts.

const WORLD: int = 1
const ZOMBIE_BODY: int = 2
const ZOMBIE_HEAD: int = 4
const DEFENSES: int = 8
const ZOMBIE: int = ZOMBIE_BODY | ZOMBIE_HEAD
const BULLET_MASK: int = WORLD | ZOMBIE | DEFENSES
## A grenade bounces off the ground and the walls but drops between the zombies.
const GRENADE_MASK: int = WORLD | DEFENSES
