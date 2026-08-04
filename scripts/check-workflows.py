"""Guard against malformed GitHub Actions workflow YAML.

Motivation: a CI step named

    - name: SubagentStart roster check handles pds: namespace

is invalid YAML — a colon followed by a space ends the plain scalar, so the
mapping becomes ambiguous. GitHub reports this only as "This run likely failed
because of a workflow file issue", with no line number and no job breakdown,
and every job is skipped. The tests it was meant to run never execute, which
makes it look superficially like a passing branch until you notice the check
list is empty.

Ironically the step being added was itself a regression guard, so a typo in the
guard disabled the whole suite. That is worth a check of its own.

Degrades gracefully per the Portability of Operation principle: does a real
parse when PyYAML happens to be importable, and otherwise falls back to a
dependency-free lint for the specific failure class above. PDS's portability
contract is markdown, bash, python3 and jq only — PyYAML is never required.

Usage: python3 scripts/check-workflows.py <repo-root>
"""
import os
import re
import sys

src = sys.argv[1] if len(sys.argv) > 1 else "."
workflow_dir = os.path.join(src, ".github", "workflows")

if not os.path.isdir(workflow_dir):
    sys.exit(0)

files = [
    os.path.join(workflow_dir, f)
    for f in sorted(os.listdir(workflow_dir))
    if f.endswith((".yml", ".yaml"))
]

try:
    import yaml  # type: ignore
except ImportError:
    yaml = None

problems = []

# Matches an unquoted YAML scalar value for a `name:` or `- name:` key.
UNQUOTED_NAME = re.compile(r"^\s*-?\s*name:\s+(?![\"'])(.+?)\s*$")

for path in files:
    text = open(path).read()
    rel = os.path.relpath(path, src)

    if yaml is not None:
        try:
            parsed = yaml.safe_load(text)
        except Exception as exc:  # noqa: BLE001 - report whatever YAML says
            problems.append("%s: does not parse as YAML — %s" % (rel, exc))
            continue
        if not isinstance(parsed, dict) or "jobs" not in parsed:
            problems.append("%s: no top-level `jobs` mapping" % rel)
            continue
        for job_name, job in (parsed.get("jobs") or {}).items():
            if not isinstance(job, dict) or not job.get("steps"):
                problems.append("%s: job `%s` has no steps" % (rel, job_name))

    # Run the lint regardless — it pinpoints the line, which a parse error
    # often does not.
    for lineno, line in enumerate(text.splitlines(), 1):
        match = UNQUOTED_NAME.match(line)
        if match and ": " in match.group(1):
            problems.append(
                "%s:%d: unquoted step name contains a colon+space, which is "
                "invalid YAML — quote it: %s"
                % (rel, lineno, line.strip())
            )

if problems:
    sys.stderr.write("Workflow validation failed:\n")
    for p in problems:
        sys.stderr.write("  - %s\n" % p)
    sys.exit(1)
