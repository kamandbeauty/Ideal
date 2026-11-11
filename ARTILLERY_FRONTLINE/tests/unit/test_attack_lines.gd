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

	# Wide occupants: several places side by side in a front row, taken by shoving.
	var wide := AttackLines.new()
	wide.setup(layout)
	var columns: int = wide.lines.gate.columns
	var standing: Array = []
	for index: int in columns:
		var walker := RefCounted.new()
		standing.append(walker)
		wide.claim(walker, "gate")
	t.equal(wide.occupied("gate"), columns, "the front row of the gate is full")
	var brute := RefCounted.new()
	var polite: AttackLines.Slot = wide.claim(brute, "gate", "", 0.0, 2, false)
	t.check(polite == null or polite.line != "gate", "a polite wide claim goes to another wall rather than take places that are held")
	t.check(wide.displaced.is_empty(), "and pushes nobody")
	wide.release(polite)
	var before: int = wide.occupied("gate")
	var group: AttackLines.Slot = wide.claim(brute, "gate", "", 0.0, 2, true)
	t.check(group != null and group.members.size() == 2 and group.row == 0 and group.line == "gate", "a shoving claim takes two places in the front row")
	t.equal(wide.displaced.size(), 2, "and pushes two occupants off them")
	t.check(standing.has(wide.displaced[0]) and standing.has(wide.displaced[1]) and wide.displaced[0] != wide.displaced[1], "the two it names are the ones who stood there")
	t.equal(wide.occupied("gate"), before, "the places changed hands; none appeared or vanished")
	t.check(group.members[0].occupant == brute and group.members[1].occupant == brute, "both places are held by the newcomer")
	t.equal(absi(group.members[0].column - group.members[1].column), 1, "they are neighbours")
	t.check(group.position.is_equal_approx((group.members[0].position + group.members[1].position) * 0.5), "it stands between the two")
	t.check(absf(float(group.members[0].column + group.members[1].column) * 0.5 - float(columns - 1) * 0.5) <= 1.0, "near the middle of the gate")
	t.check(group.facing.is_equal_approx(first.facing) and group.target == "gate", "facing the gate like everyone else")
	# A second wide one takes other places and cannot push the first aside.
	var boss := RefCounted.new()
	var boss_group: AttackLines.Slot = wide.claim(boss, "gate", "", 0.0, 3, true)
	t.check(boss_group != null and boss_group.members.size() == 3, "a three-wide claim finds three more places")
	var overlap: bool = false
	for member: AttackLines.Slot in boss_group.members:
		if group.members.has(member):
			overlap = true
	t.check(not overlap and not wide.displaced.has(brute), "without taking the places of the other wide one")
	t.check(group.members[0].occupant == brute, "which still holds its own")
	# The displaced find places behind.
	for pushed: Object in wide.displaced.duplicate():
		var place: AttackLines.Slot = wide.claim(pushed, "gate")
		t.check(place != null and place.members.is_empty() and (place.row == 1 or place.line != "gate"), "someone pushed aside finds a place behind or beside")
	# Releasing a wide place frees every member, and the row behind steps up into them.
	var behind: int = 0
	for slot: AttackLines.Slot in wide.lines.gate.slots:
		if slot.row == 1 and slot.occupant != null:
			behind += 1
	wide.release(boss_group)
	var emptied: int = 0
	for member: AttackLines.Slot in boss_group.members:
		if member.occupant == null:
			emptied += 1
	t.equal(emptied, 3, "releasing a wide place frees all of its places")
	var stepping: Array = wide.advance_rows("gate")
	t.check(stepping.size() >= 1 and stepping.size() <= mini(3, behind), "those waiting close behind step forward into the gap (%d of %d)" % [
		stepping.size(), behind])
	var stepped_forward: bool = true
	for move: Array in stepping:
		if (move[1] as AttackLines.Slot).row != 0 or (move[1] as AttackLines.Slot).occupant != move[0]:
			stepped_forward = false
	t.check(stepped_forward, "each into a front place of its own")
	# A line too short for the width is passed over; nothing free at all gives null.
	var none := AttackLines.new()
	none.setup(layout)
	var too_wide: AttackLines.Slot = none.claim(RefCounted.new(), "gate", "", 0.0, 99, true)
	t.check(too_wide == null, "a claim wider than every line gets nothing")
	# Closing a line names a wide occupant once.
	var closing := AttackLines.new()
	closing.setup(layout)
	var giant := RefCounted.new()
	closing.claim(giant, "gate", "", 0.0, 3, true)
	t.equal(closing.close("gate"), [giant], "closing a line lists a wide occupant once")
