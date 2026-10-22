class_name Puzzle
extends RefCounted
## One level: a rows x cols letter grid fully covered by hidden words.
## Cells are addressed by index (row * cols + col). Pure data, no UI.

var id: String = ""
var theme_id: String = ""
var theme_name: String = ""
## Every theme in the grid (one, or two in two-theme chapters); theme_id is the first.
var theme_ids: PackedStringArray = PackedStringArray()
var theme_names: PackedStringArray = PackedStringArray()
## The answers are written out above the grid (instead of empty slots).
var listed: bool = false
## The theme name stays hidden until a word from that theme is found.
var mystery: bool = false
var rows: int = 0
var cols: int = 0
## One uppercase letter per cell.
var letters: PackedStringArray = PackedStringArray()
## Each entry: {"word": String, "cells": PackedInt32Array, "theme": int} in reading
## order; "theme" indexes theme_ids.
var words: Array[Dictionary] = []
## Cells that start dark (letter hidden until a neighbouring word is found).
var shadows: PackedInt32Array = PackedInt32Array()
## Cells that light their whole row and column when their word is found.
var beacons: PackedInt32Array = PackedInt32Array()


static func from_dict(d: Dictionary, theme_names: Dictionary = {}) -> Puzzle:
	var p: Puzzle = Puzzle.new()
	p.id = str(d.get("id", ""))
	p.theme_id = str(d.get("theme", ""))
	p.theme_ids = PackedStringArray([p.theme_id])
	for t: Variant in d.get("themes", []):
		if not p.theme_ids.has(str(t)):
			p.theme_ids.append(str(t))
	for t: String in p.theme_ids:
		p.theme_names.append(str(theme_names.get(t, t.capitalize())))
	p.theme_name = " & ".join(p.theme_names)
	p.listed = bool(d.get("listed", false))
	p.mystery = bool(d.get("mystery", false))
	var grid: Array = d.get("grid", [])
	p.rows = grid.size()
	p.cols = str(grid[0]).length() if p.rows > 0 else 0
	for row: Variant in grid:
		var s: String = str(row)
		for i: int in s.length():
			p.letters.append(s[i])
	for w: Variant in d.get("words", []):
		var cells: PackedInt32Array = PackedInt32Array()
		for c: Variant in (w as Dictionary).get("p", []):
			cells.append(int(c))
		p.words.append({"word": str((w as Dictionary).get("w", "")), "cells": cells, "theme": int((w as Dictionary).get("t", 0))})
	for c: Variant in d.get("shadows", []):
		p.shadows.append(int(c))
	for c: Variant in d.get("beacons", []):
		p.beacons.append(int(c))
	return p


func to_dict() -> Dictionary:
	var grid: Array = []
	for r: int in rows:
		var s: String = ""
		for c: int in cols:
			s += letters[r * cols + c]
		grid.append(s)
	var ws: Array = []
	for w: Dictionary in words:
		var e: Dictionary = {"w": w["word"], "p": Array(w["cells"])}
		if theme_ids.size() > 1:
			e["t"] = int(w.get("theme", 0))
		ws.append(e)
	var d: Dictionary = {"id": id, "theme": theme_id, "grid": grid, "words": ws}
	if theme_ids.size() > 1:
		d["themes"] = Array(theme_ids)
	if listed:
		d["listed"] = true
	if mystery:
		d["mystery"] = true
	if not shadows.is_empty():
		d["shadows"] = Array(shadows)
	if not beacons.is_empty():
		d["beacons"] = Array(beacons)
	return d


## The theme title as the player sees it: in a mystery level each theme name
## shows only once one of its words is found (`found` is LevelState.found).
func shown_theme(found: PackedByteArray) -> String:
	if not mystery:
		return theme_name
	var parts: PackedStringArray = PackedStringArray()
	for t: int in theme_names.size():
		parts.append(shown_theme_part(t, found))
	if parts.size() == 1 and parts[0] == "???":
		return "Mystery theme"
	return " & ".join(parts)


## One theme's name, or "???" while it is still a mystery.
func shown_theme_part(t: int, found: PackedByteArray) -> String:
	if not mystery:
		return theme_names[t]
	for i: int in words.size():
		if int(words[i].get("theme", 0)) == t and i < found.size() and found[i] != 0:
			return theme_names[t]
	return "???"


func cell_count() -> int:
	return rows * cols


func row_of(cell: int) -> int:
	return cell / cols


func col_of(cell: int) -> int:
	return cell % cols


func is_adjacent(a: int, b: int) -> bool:
	var dr: int = absi(row_of(a) - row_of(b))
	var dc: int = absi(col_of(a) - col_of(b))
	return dr + dc == 1


## Orthogonal neighbours of a cell.
func neighbors(cell: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var r: int = row_of(cell)
	var c: int = col_of(cell)
	if r > 0:
		out.append(cell - cols)
	if r < rows - 1:
		out.append(cell + cols)
	if c > 0:
		out.append(cell - 1)
	if c < cols - 1:
		out.append(cell + 1)
	return out


## Which word owns each cell (-1 if none; a valid puzzle has none).
func owner_map() -> PackedInt32Array:
	var owners: PackedInt32Array = PackedInt32Array()
	owners.resize(cell_count())
	owners.fill(-1)
	for i: int in words.size():
		for c: int in words[i]["cells"]:
			owners[c] = i
	return owners


func word_text(cells: PackedInt32Array) -> String:
	var s: String = ""
	for c: int in cells:
		s += letters[c]
	return s


func longest_word() -> int:
	var n: int = 0
	for w: Dictionary in words:
		n = maxi(n, str(w["word"]).length())
	return n
