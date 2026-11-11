extends RefCounted
## Standing places at the gate and wall: claiming, overflow, stepping forward.


func run(t: TestContext) -> void:
	var layout: LevelLayout = load("res://resources/levels/city_siege_layout.tres")
	var lines := AttackLines.new()
	lines.setup(layout)
	t.check(lines.lines.has("gate") and lines.lines.has("patch"), "the gate and the wall patch have attack lines")
	t.equal(String(lines.lines.gate.target), "gate", "the gate line damages the gate")
	t.equal(String(lines.lines.patch.target), "wall", "the patch line damages the wall")
	var gate: Dictionary = lines.lines.gate
	t.check(gate.columns >= 5 and gate.rows == 2, "the gate takes at least five abreast in two rows")
	var total: int = 0
	for line_name: String in lines.lines:
		total += lines.lines[line_name].slots.size()
	t.equal(lines.capacity(), total, "capacity counts every open slot")
	t.check(total >= 40, "the walls hold at least forty attackers (got %d)" % total)

	# Slots are spaced, in front of the wall and facing it.
	var apart: bool = true
	for line_name: String in lines.lines:
		var slots: Array = lines.lines[line_name].slots
		for i: int in slots.size():
			for j: int in range(i + 1, slots.size()):
				if slots[i].position.distance_to(slots[j].position) < 0.9:
					apart = false
	t.check(apart, "no two standing places are closer than 0.9 m")
	var first: AttackLines.Slot = gate.slots[0]
	t.check(first.facing.is_equal_approx(Vector3(1, 0, 0)), "gate attackers face the gate (+X)")
	t.check(absf(first.position.x - layout.gate_center.x) < 2.0, "gate slots stand right in front of the gate")
	var back: AttackLines.Slot = gate.slots[gate.columns]
	t.check(back.row == 1 and back.position.x < first.position.x, "the second row stands behind the first")

	# Claim order: gate front row from the middle, then the back row, then the wall on the same side.
	var claimed: Array = []
	var who: Array = []
	for index: int in gate.columns:
		var token := RefCounted.new()
		who.append(token)
		claimed.append(lines.claim(token, "gate"))
	var all_front: bool = true
	for slot: AttackLines.Slot in claimed:
		if slot == null or slot.line != "gate" or slot.row != 0:
			all_front = false
	t.check(all_front, "the first claims fill the gate's front row")
	var middle: int = (gate.columns - 1) / 2
	t.check(absi(claimed[0].column - middle) <= 1, "the first attacker takes the middle of the gate")
	var unique: Dictionary = {}
	for slot: AttackLines.Slot in claimed:
		unique[slot.column] = true
	t.equal(unique.size(), gate.columns, "no slot is handed out twice")
	var next: AttackLines.Slot = lines.claim(RefCounted.new(), "gate")
	t.check(next != null and next.line == "gate" and next.row == 1, "with the front full the next one queues in the second row")
	for index: int in gate.columns - 1:
		lines.claim(RefCounted.new(), "gate")
	var overflow: AttackLines.Slot = lines.claim(RefCounted.new(), "gate")
	t.check(overflow != null and overflow.line != "gate", "a full gate overflows to another line")
	t.equal(overflow.side, "right", "the overflow stays on the gate's side of the court")
	t.equal(overflow.target, "wall", "overflowing attackers damage the wall")
	t.equal(lines.occupied("gate"), gate.columns * 2, "the gate line is counted as full")

	# Wall preference.
	var wall_slot: AttackLines.Slot = lines.claim(RefCounted.new(), "wall")
	t.equal(wall_slot.line, "patch", "wall attackers go for the patched breach first")

	# Stepping forward when a front place opens.
	var freed: AttackLines.Slot = claimed[2]
	lines.release(freed)
	t.check(freed.occupant == null, "release frees the slot")
	var moves: Array = lines.advance_rows("gate")
	t.equal(moves.size(), 1, "one attacker steps forward into the gap")
	t.check(moves[0][1] == freed and freed.occupant == moves[0][0], "the one behind takes the freed front place")
	t.equal(lines.occupied("gate"), gate.columns * 2 - 1, "one back-row place is now free")

	# Closing a line (its target fell).
	var displaced: Array = lines.close("gate")
	t.equal(displaced.size(), gate.columns * 2 - 1, "closing the line returns everyone who stood there")
	t.equal(lines.occupied("gate"), 0, "a closed line holds nobody")
	var after: AttackLines.Slot = lines.claim(RefCounted.new(), "gate")
	t.check(after == null or after.line != "gate", "a closed line hands out no places")

	# Everything full returns null instead of failing.
	var fresh := AttackLines.new()
	fresh.setup(layout)
	var handed: int = 0
	for index: int in fresh.capacity() + 5:
		if fresh.claim(RefCounted.new(), "any") != null:
			handed += 1
	t.equal(handed, fresh.capacity(), "exactly `capacity` places can be claimed")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var waiting: Vector3 = fresh.waiting_point("gate", rng)
	t.check(waiting.x < first.position.x - 1.0, "the waiting area is behind the gate rows")
