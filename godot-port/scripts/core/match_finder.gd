class_name MatchFinder
extends RefCounted

# Match records use Dictionaries to keep the serialized test vectors engine-friendly.
# Scan order mirrors Unity: horizontal rows bottom-up, then vertical columns left-right.

static func find_runs(board: BoardModel) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	for y in range(board.height):
		var x := 0
		while x < board.width:
			var cell := board.at(x, y)
			var kind: int = cell.piece if cell != null and cell.has_piece else GameTypes.PieceKind.NONE
			if kind == GameTypes.PieceKind.NONE:
				x += 1
				continue
			var finish := x + 1
			while finish < board.width:
				var next_cell := board.at(finish, y)
				if next_cell == null or not next_cell.has_piece or next_cell.piece != kind:
					break
				finish += 1
			var length := finish - x
			if length >= 3:
				runs.append({"start": Vector2i(x, y), "length": length, "horizontal": true, "piece": kind})
			x = finish

	for x in range(board.width):
		var y := 0
		while y < board.height:
			var cell := board.at(x, y)
			var kind: int = cell.piece if cell != null and cell.has_piece else GameTypes.PieceKind.NONE
			if kind == GameTypes.PieceKind.NONE:
				y += 1
				continue
			var finish := y + 1
			while finish < board.height:
				var next_cell := board.at(x, finish)
				if next_cell == null or not next_cell.has_piece or next_cell.piece != kind:
					break
				finish += 1
			var length := finish - y
			if length >= 3:
				runs.append({"start": Vector2i(x, y), "length": length, "horizontal": false, "piece": kind})
			y = finish
	return runs

static func has_match(board: BoardModel) -> bool:
	return not find_runs(board).is_empty()

## A 2 x 2 block of one colour. It is **not** a match and never clears anything: four of the same fruit
## sitting in a square is what a settled board looks like, and the port inherited a rule that treated
## the shape as a match and swept the board for every square it could find. With five colours a fresh
## board carries one about thirty per cent of the time, so the first move the player made cleared four
## pieces that had nothing to do with it — the bug the player reported as "other fruit burst too".
##
## The function stays because the tests use it to prove those squares survive a move.
static func find_squares(board: BoardModel) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for y in range(board.height - 1):
		for x in range(board.width - 1):
			var a := board.at(x, y)
			var b := board.at(x + 1, y)
			var c := board.at(x, y + 1)
			var d := board.at(x + 1, y + 1)
			if a == null or b == null or c == null or d == null:
				continue
			if not a.has_piece or not b.has_piece or not c.has_piece or not d.has_piece:
				continue
			if a.piece == b.piece and a.piece == c.piece and a.piece == d.piece:
				squares.append(Vector2i(x, y))
	return squares

static func _run_cells(run: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var start: Vector2i = run.start
	for index in range(run.length):
		cells.append(start + (Vector2i(index, 0) if run.horizontal else Vector2i(0, index)))
	return cells

static func build_clusters(runs: Array[Dictionary]) -> Array[Dictionary]:
	var clusters: Array[Dictionary] = []
	for run in runs:
		var target_index := -1
		var cells := _run_cells(run)
		for cluster_index in range(clusters.size()):
			var cluster_cells: Array = clusters[cluster_index].cells
			var overlaps := false
			for pos in cells:
				if cluster_cells.has(pos):
					overlaps = true
					break
			if overlaps:
				target_index = cluster_index
				break
		if target_index < 0:
			clusters.append({"runs": [], "cells": [], "max_length": 0, "has_horizontal": false, "has_vertical": false})
			target_index = clusters.size() - 1
		var target: Dictionary = clusters[target_index]
		target.runs.append(run)
		target.has_horizontal = target.has_horizontal or run.horizontal
		target.has_vertical = target.has_vertical or not run.horizontal
		target.max_length = maxi(target.max_length, run.length)
		for pos in cells:
			if not target.cells.has(pos):
				target.cells.append(pos)
		clusters[target_index] = target
	return clusters

## What a match earns, in the order the shapes are worth more.
##
## A rocket points the way its line went — a horizontal four gives a horizontal rocket, and it clears
## that row — because the player who just made a line expects the rocket to run along it, not across it.
## The crossing shape (an L or a T) earns the kite, and the fan is the reward for the long line.
static func power_up_for(cluster: Dictionary) -> int:
	if cluster.has_horizontal and cluster.has_vertical:
		return GameTypes.PowerUpKind.KITE
	if cluster.max_length >= 5:
		return GameTypes.PowerUpKind.FAN
	if cluster.max_length == 4:
		for run in cluster.runs:
			if run.length == 4:
				return GameTypes.PowerUpKind.ROCKET_HORIZONTAL if run.horizontal else GameTypes.PowerUpKind.ROCKET_VERTICAL
	return GameTypes.PowerUpKind.NONE

static func choose_spawn_cell(cluster: Dictionary, preferred: Vector2i, has_preferred: bool) -> Vector2i:
	if has_preferred and cluster.cells.has(preferred):
		return preferred
	var longest: Dictionary = cluster.runs[0]
	for run in cluster.runs:
		if run.length > longest.length:
			longest = run
	var middle_index: int = int(longest.length / 2)
	return _run_cells(longest)[middle_index]

static func has_possible_move(board: BoardModel) -> bool:
	for y in range(board.height):
		for x in range(board.width):
			var cell := board.at(x, y)
			if cell == null or not cell.has_piece:
				continue
			if cell.power_up != GameTypes.PowerUpKind.NONE:
				return true
			if x + 1 < board.width and _swap_creates_match(board, Vector2i(x, y), Vector2i(x + 1, y)):
				return true
			if y + 1 < board.height and _swap_creates_match(board, Vector2i(x, y), Vector2i(x, y + 1)):
				return true
	return false

static func _swap_creates_match(board: BoardModel, a_pos: Vector2i, b_pos: Vector2i) -> bool:
	var a := board.at_pos(a_pos)
	var b := board.at_pos(b_pos)
	if a == null or b == null or not a.has_piece or not b.has_piece or a.piece == b.piece:
		return false
	var piece_a := a.piece
	var power_a := a.power_up
	a.piece = b.piece
	a.power_up = b.power_up
	b.piece = piece_a
	b.power_up = power_a
	var found := has_match(board)
	piece_a = a.piece
	power_a = a.power_up
	a.piece = b.piece
	a.power_up = b.power_up
	b.piece = piece_a
	b.power_up = power_a
	return found
