#!/usr/bin/env python3
"""Fail the build unless the headless test report passed with enough checks."""
import json
import pathlib
import sys

MINIMUM_CHECKS = 20

report = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert report["passed"] and not report["failures"], report["failures"]
assert report["checks"] >= MINIMUM_CHECKS, "only %d checks ran" % report["checks"]
print("PASS: %d checks in %d suites; %s" % (report["checks"], len(report["suites"]), report["scope"]))
