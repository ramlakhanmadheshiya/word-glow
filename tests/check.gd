class_name Check
extends RefCounted
## Minimal assertion collector shared by the headless test scripts.

var suite: String
var passed: int = 0
var failures: PackedStringArray = PackedStringArray()


func _init(name: String) -> void:
	suite = name


func ok(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(what)


func eq(a: Variant, b: Variant, what: String) -> void:
	ok(a == b, "%s (got %s, expected %s)" % [what, str(a), str(b)])


## Prints a one-line verdict (plus failures) and returns the exit code.
func report() -> int:
	for f: String in failures.slice(0, 40):
		print("  FAIL: ", f)
	if failures.size() > 40:
		print("  ... and %d more" % (failures.size() - 40))
	if failures.is_empty():
		print("%s: PASS (%d checks)" % [suite, passed])
		return 0
	print("%s: FAIL (%d failed, %d passed)" % [suite, failures.size(), passed])
	return 1
