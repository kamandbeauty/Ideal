#!/usr/bin/env python3
"""Fail the build unless the headless test report passed with enough checks."""
import json
import pathlib
import sys

MINIMUM_CHECKS = 2250
REQUIRED_SUITES = (
    "test_governor",
    "test_polish",
    "test_combat",
    "test_playthrough",
    "test_campaign",
    "test_edge_cases",
    "test_explosives",
    "test_project",
)

path = pathlib.Path(sys.argv[1])
text = path.read_text() if path.is_file() else ""
assert text.strip(), "test report is missing or empty: %s" % path
report = json.loads(text)
assert report["passed"] and not report["failures"], report["failures"]
assert report["checks"] >= MINIMUM_CHECKS, "only %d checks ran" % report["checks"]
suites = report.get("suites") or {}
missing = [name for name in REQUIRED_SUITES if int(suites.get(name, 0)) < 1]
assert not missing, "required suites ran no checks (skipped or crashed): %s" % missing
print("PASS: %d checks in %d suites; %s" % (report["checks"], len(suites), report["scope"]))
