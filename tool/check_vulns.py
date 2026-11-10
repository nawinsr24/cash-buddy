#!/usr/bin/env python3
"""Checks every package in pubspec.lock against the public OSV database
(osv.dev) for known vulnerabilities. Only package names and versions are sent.
Exit code 1 when anything is found."""
import json
import re
import sys
import urllib.request

pkgs = []
name = None
for line in open("pubspec.lock"):
    m = re.match(r"^  (\S+):$", line)
    if m:
        name = m.group(1)
    m = re.match(r'^    version: "(.+)"$', line)
    if m and name:
        pkgs.append((name, m.group(1)))
        name = None

queries = [
    {"package": {"name": n, "ecosystem": "Pub"}, "version": v} for n, v in pkgs
]
found = []
for i in range(0, len(queries), 500):
    req = urllib.request.Request(
        "https://api.osv.dev/v1/querybatch",
        data=json.dumps({"queries": queries[i : i + 500]}).encode(),
        headers={"Content-Type": "application/json"},
    )
    res = json.load(urllib.request.urlopen(req, timeout=60))
    for q, r in zip(queries[i : i + 500], res["results"]):
        for v in r.get("vulns", []):
            found.append((q["package"]["name"], q["version"], v["id"]))

print(f"Checked {len(pkgs)} packages.")
for n, v, vid in found:
    print(f"VULNERABLE: {n} {v}  https://osv.dev/{vid}")
sys.exit(1 if found else 0)
