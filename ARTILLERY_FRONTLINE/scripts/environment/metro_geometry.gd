extends "res://scripts/environment/hospital_geometry.gd"
## A subway concourse, using the same defendable footprint but its own cover,
## tunnel and trains. Decorative pieces have no projectile collision so the
## lanes are always clear to shoot; the inherited barricades are physical.

func _ready() -> void:
	super._ready()
	for child: Node in get_children():
		var n: String = child.name
		if n.begins_with("Hospital") or n.begins_with("Emergency") or n.begins_with("Medical") or n.begins_with("Entrance") or n.begins_with("Canopy") or n.begins_with("Facade") or n.begins_with("WestClinic") or n.begins_with("EastClinic") or n.begins_with("Clinic") or n.begins_with("WestAmbulance") or n.begins_with("EastAmbulance"):
			remove_child(child)
			child.free()
	# Replace the inherited ground before placing the rails and ceiling.
	_box("MetroFloor", Vector3(0, -0.25, -77), Vector3(150, 0.5, 190), "concrete", true)
	_box("TunnelEnd", Vector3(0, 10, -136), Vector3(78, 20, 3), "concrete", true)
	_box("TunnelOpening", Vector3(0, 7, -134.4), Vector3(21, 14, 0.2), "rubber")
	_box("Ceiling", Vector3(0, 18.5, -91), Vector3(77, 1, 89), "concrete")
	for index: int in 7:
		var z: float = -55.0 - index * 12.0
		_box("CeilingBeam%d" % index, Vector3(0, 17.8, z), Vector3(77, 1, 1.2), "trim")
		for side: int in [-1, 1]:
			_box("PlatformColumn%d_%d" % [side, index], Vector3(side * 30, 8.5, z), Vector3(1.2, 17, 1.2), "concrete")
	for side: int in [-1, 1]:
		var x: float = side * 25.0
		_box("TrainBody%d" % side, Vector3(x, 3, -94), Vector3(6, 6, 51), "white")
		_box("TrainRoof%d" % side, Vector3(x, 6.2, -94), Vector3(6.2, 0.5, 51), "trim")
		_box("TrainStripe%d" % side, Vector3(x - side * 3.04, 2.5, -94), Vector3(0.12, 0.6, 50), "red")
		for index: int in 6:
			var z: float = -115.0 + index * 7.5
			_box("TrainWindow%d_%d" % [side, index], Vector3(x - side * 3.06, 4.1, z), Vector3(0.13, 1.5, 4), "glass")
			_box("TrainDoor%d_%d" % [side, index], Vector3(x - side * 3.08, 2.6, z + 3.0), Vector3(0.14, 4.1, 0.2), "trim")
		_box("PlatformEdge%d" % side, Vector3(side * 20.8, 0.08, -94), Vector3(0.35, 0.12, 50), "yellow")
	for x: float in [-4.5, -2.5, 2.5, 4.5]:
		_box("Rail%s" % x, Vector3(x, 0.08, -92), Vector3(0.16, 0.15, 83), "trim")
	for index: int in 25:
		_box("Sleeper%d" % index, Vector3(0, 0.03, -52 - index * 3), Vector3(10, 0.08, 0.35), "trim")
	_box("StationSign", Vector3(0, 14.5, -134.1), Vector3(14, 2, 0.2), "red")
