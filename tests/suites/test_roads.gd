extends TestCase
## Road auto-tiling: every neighbourhood must pick a piece that really joins
## the neighbours it is drawn for.


func test_every_mask_gets_a_valid_piece() -> void:
	for mask in range(16):
		var piece := CityData.road_piece(mask)
		var model := str(piece["model"])
		var rotation := int(piece["rotation"])
		check(CityData.ROAD_PIECES.has(model), "unknown road model for mask %d" % mask)
		check(rotation >= 0 and rotation < 4, "bad rotation for mask %d" % mask)
		var drawn := CityData.rotate_mask(int(CityData.ROAD_PIECES[model]), rotation)
		if mask == 0:
			continue
		if mask == CityData.DIR_N or mask == CityData.DIR_E or mask == CityData.DIR_S or mask == CityData.DIR_W:
			check((drawn & mask) != 0, "the piece reaches the only neighbour, mask %d" % mask)
		else:
			equal(drawn, mask, "the piece joins every neighbour, mask %d" % mask)


func test_rotation_turns_the_other_way() -> void:
	# A road running north-south, turned a quarter, runs east-west.
	equal(CityData.rotate_mask(CityData.DIR_N | CityData.DIR_S, 1), CityData.DIR_E | CityData.DIR_W, "straight rotated")
	# A corner opening to the south and west, turned a quarter, opens south and east.
	equal(CityData.rotate_mask(CityData.DIR_S | CityData.DIR_W, 1), CityData.DIR_E | CityData.DIR_S, "corner rotated")
	# Four quarter turns are a full circle.
	for mask in range(16):
		equal(CityData.rotate_mask(mask, 4), mask, "four turns restore mask %d" % mask)


func test_known_layouts() -> void:
	var cross := CityData.DIR_N | CityData.DIR_E | CityData.DIR_S | CityData.DIR_W
	var cross_piece := CityData.road_piece(cross)
	equal(str(cross_piece["model"]), "road-intersection", "a crossroads uses the intersection")
	equal(int(cross_piece["rotation"]), 0, "the crossroads is not rotated")

	var straight := CityData.road_piece(CityData.DIR_N | CityData.DIR_S)
	equal(str(straight["model"]), "road-straight", "north-south uses a straight road")
	equal(int(straight["rotation"]), 0, "north-south is the unrotated straight")

	var sideways := CityData.road_piece(CityData.DIR_E | CityData.DIR_W)
	equal(str(sideways["model"]), "road-straight", "east-west uses a straight road")
	equal(int(sideways["rotation"]), 1, "east-west is the straight turned once")

	var corner := CityData.road_piece(CityData.DIR_S | CityData.DIR_W)
	equal(str(corner["model"]), "road-corner", "south-west uses a corner")
	equal(int(corner["rotation"]), 0, "the unrotated corner opens south-west")

	var tee := CityData.road_piece(
		CityData.DIR_N | CityData.DIR_E | CityData.DIR_W
	)
	equal(str(tee["model"]), "road-split", "a T uses the split piece")
	equal(
		CityData.rotate_mask(int(CityData.ROAD_PIECES["road-split"]), int(tee["rotation"])),
		CityData.DIR_N | CityData.DIR_E | CityData.DIR_W,
		"the split piece joins the three neighbours"
	)


func test_isolated_and_dead_end_roads_still_render() -> void:
	var alone := CityData.road_piece(0)
	check(not str(alone["model"]).is_empty(), "an isolated road still has a model")
	var dead_end := CityData.road_piece(CityData.DIR_W)
	check(not str(dead_end["model"]).is_empty(), "a dead end still has a model")
	check(int(dead_end["rotation"]) >= 0, "a dead end has a rotation")


func test_road_mask_reads_the_grid() -> void:
	var cells := {
		Vector2i(0, 0): "road",
		Vector2i(1, 0): "road",
		Vector2i(0, 1): "road",
		Vector2i(5, 5): "house_a",
	}
	equal(CityData.road_mask(cells, Vector2i(0, 0)), CityData.DIR_E | CityData.DIR_S, "east and south neighbours")
	equal(CityData.road_mask(cells, Vector2i(1, 0)), CityData.DIR_W, "west neighbour")
	equal(CityData.road_mask(cells, Vector2i(9, 9)), 0, "empty space has no neighbours")
	equal(CityData.road_mask(cells, Vector2i(5, 5)), 0, "buildings are not roads")
