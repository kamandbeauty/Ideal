extends TestCase
## The guild hall's layout and its hand-authored navigation mesh. Everything here
## is data plus pure geometry, so it runs without a window, a physics frame or a
## baked navmesh - the actual path query happens in the play-through.


func test_nine_named_zones() -> void:
	var ids := GuildHallZones.zone_ids()
	equal(ids.size(), 9, "the hall has nine zones")
	for id in ids:
		var data := GuildHallZones.zone(id)
		check(not data.is_empty(), "zone data for " + id)
		var key := str(data["name_key"])
		check(key.begins_with("zone."), "zone label key for " + id)
		check(GuildLocale.has_key(key), "the label exists in English: " + key)
		check(not GuildLocale.missing_overrides().has(key), "and in Persian: " + key)
		not_equal(GuildLocale.text(key, "fa"), GuildLocale.text(key, "en"), "the label is really translated")


func test_zones_tile_the_floor() -> void:
	var ids := GuildHallZones.zone_ids()
	var covered := 0.0
	for id in ids:
		var rect := GuildHallZones.rect(id)
		check(rect.size.x > 0.0 and rect.size.y > 0.0, "zone has an area: " + id)
		covered += rect.size.x * rect.size.y
	var total := GuildHallZones.WIDTH * GuildHallZones.DEPTH
	almost(covered, total, "the nine zones cover the hall exactly", 0.01)
	for first in ids.size():
		for second in range(first + 1, ids.size()):
			var a := GuildHallZones.rect(ids[first])
			var b := GuildHallZones.rect(ids[second])
			check(not a.intersects(b), "zones overlap: %s / %s" % [ids[first], ids[second]])


func test_every_indoor_point_belongs_to_a_zone() -> void:
	var half_w := GuildHallZones.WIDTH * 0.5 - 0.7
	var half_d := GuildHallZones.DEPTH * 0.5 - 0.7
	var holes := 0
	for ix in 13:
		for iz in 10:
			var point := Vector3(-half_w + ix * (half_w * 2.0 / 12.0), 0.0, -half_d + iz * (half_d * 2.0 / 9.0))
			if GuildHallZones.zone_at(point).is_empty():
				holes += 1
	equal(holes, 0, "no point inside the walls is outside every zone")


func test_zone_lookup_round_trips() -> void:
	for id in GuildHallZones.zone_ids():
		equal(GuildHallZones.zone_at(GuildHallZones.center(id)), id, "centre maps to " + id)
	equal(GuildHallZones.zone_at(Vector3(0.0, 0.0, 60.0)), "", "outside the hall is not a zone")
	equal(GuildHallZones.zone("no_such_zone"), {}, "unknown zones are empty")


func test_spawns_are_walkable() -> void:
	for key in GuildHallZones.SPAWNS:
		var point := GuildHallZones.spawn(str(key))
		check(not GuildHallZones.zone_at(point).is_empty(), "spawn %s is inside the hall" % key)
		for prop in GuildHallZones.PROPS:
			check(not (prop["rect"] as Rect2).has_point(Vector2(point.x, point.z)), "spawn %s is not inside furniture" % key)


func test_furniture_stays_inside_its_zone() -> void:
	check(GuildHallZones.PROPS.size() >= 15, "the hall is furnished")
	for prop in GuildHallZones.PROPS:
		var zone_rect := GuildHallZones.rect(str(prop["zone"]))
		check(zone_rect.encloses(prop["rect"] as Rect2), "%s furniture fits in %s" % [prop["kind"], prop["zone"]])
		check(float(prop["height"]) > 0.3, "furniture has a height")


func test_furniture_does_not_overlap() -> void:
	var props := GuildHallZones.PROPS
	for first in props.size():
		for second in range(first + 1, props.size()):
			var a := props[first]["rect"] as Rect2
			var b := props[second]["rect"] as Rect2
			check(not a.intersects(b), "overlapping furniture: %s / %s" % [props[first]["kind"], props[second]["kind"]])


func test_hall_builds_all_zones_and_geometry() -> void:
	var hall := GuildHall.new()
	hall.build()
	equal(hall.zone_nodes.size(), 9, "one node per zone")
	for id in GuildHallZones.zone_ids():
		check(hall.zone_nodes.has(id), "zone node exists: " + id)
	var solids := hall.find_children("*", "CollisionShape3D", true, false)
	check(solids.size() >= 20, "walls and furniture are solid")
	var meshes := hall.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() >= 60, "the hall is actually dressed")
	hall.free()


func test_zone_signs_follow_the_language() -> void:
	var hall := GuildHall.new()
	hall.build()
	equal(hall.zone_labels.size(), 9, "every zone has a sign")
	var english: Array[String] = []
	for id in GuildHallZones.zone_ids():
		english.append((hall.zone_labels[id] as Label3D).text)
	hall.set_language("fa")
	var persian := 0
	for index in GuildHallZones.zone_ids().size():
		var id := GuildHallZones.zone_ids()[index]
		var text := (hall.zone_labels[id] as Label3D).text
		if text != english[index]:
			persian += 1
	equal(persian, 9, "all nine signs switch to Persian")
	hall.set_language("en")
	equal((hall.zone_labels["treasury"] as Label3D).text, "Treasury", "and back to English")
	hall.free()


func test_navmesh_walks_around_the_furniture() -> void:
	var hall := GuildHall.new()
	hall.build()
	check(hall.nav_region != null, "the hall has a navigation region")
	var mesh := hall.nav_region.navigation_mesh
	check(mesh != null, "the region has a mesh")
	var polygons := mesh.get_polygon_count()
	var vertices := mesh.get_vertices()
	check(polygons > 200, "the grid produced a walkable floor (%d polygons)" % polygons)
	equal(vertices.size(), polygons * 2, "every cell is two triangles")
	var blocked: Array[Rect2] = []
	for rect in GuildHallZones.obstacle_rects():
		blocked.append(rect.grow(GuildHall.NAV_MARGIN))

	var inside_furniture := 0
	var nil_area := 0
	for index in vertices.size():
		for rect in blocked:
			if rect.has_point(Vector2(vertices[index].x, vertices[index].z)):
				inside_furniture += 1
	for polygon in range(polygons):
		var indices := mesh.get_polygon(polygon)
		equal(indices.size(), 3, "polygons stay triangles")
		if indices.size() == 3:
			var a := vertices[indices[0]]
			var b := vertices[indices[1]]
			var c := vertices[indices[2]]
			var normal := (b - a).cross(c - a)
			if normal.y <= 0.0:
				nil_area += 1
	equal(inside_furniture, 0, "no walkable vertex sits inside furniture")
	equal(nil_area, 0, "every polygon faces up, so the mesh is not inside-out")
	hall.free()
