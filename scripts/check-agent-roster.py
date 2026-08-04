"""Regression guards for the agent roster (#181).

Three properties, all derived from what's actually on disk rather than a
hardcoded list, so adding an agent fails loudly until it's wired up everywhere:

  1. The orchestrator's Task(...) spawn allowlist is pds:-namespaced, names
     nothing undefined, and covers every spawnable agent.
  2. The SubagentStart roster-check hook's fallback list covers the same set.
  3. Prose that states the roster size states the right number.

(1) is the #181 defect itself: bare names match nothing, and a zero-match
allowlist empties the entire spawn roster.
(2) is the same defect in a second location, where it inverted the hook's
signal instead of breaking dispatch.
(3) is drift that made the real roster harder to see — the docs said 8 for a
9-agent roster, and the missing one was the shepherd, which was also the agent
missing from (1).

Usage: python3 scripts/check-agent-roster.py <repo-root>
"""
import os
import re
import sys

src = sys.argv[1] if len(sys.argv) > 1 else "."
agents_dir = os.path.join(src, "agents")

# `shared-rules` is an inherited mixin, not an agent. The orchestrator is an
# agent but cannot appear in its own spawn allowlist.
MIXINS = {"shared-rules"}
NOT_SELF_SPAWNABLE = {"orchestrator"}

on_disk = {
    os.path.basename(f)[:-3]
    for f in os.listdir(agents_dir)
    if f.endswith(".md")
} - MIXINS

spawnable = on_disk - NOT_SELF_SPAWNABLE

# --- 1. Orchestrator spawn allowlist ---------------------------------------
orch = os.path.join(agents_dir, "orchestrator.md")
frontmatter = open(orch).read().split("---")[1]
match = re.search(r"Task\(([^)]*)\)", frontmatter)
assert match, "orchestrator.md frontmatter has no Task(...) spawn allowlist"

declared = [x.strip() for x in match.group(1).split(",") if x.strip()]
assert declared, "orchestrator Task(...) allowlist is empty"

bare = [d for d in declared if not d.startswith("pds:")]
assert not bare, (
    "orchestrator Task(...) allowlist has un-namespaced entries %s — "
    "plugin agents register as pds:<name>; bare names match nothing and "
    "empty the entire spawn roster (#181)" % bare
)

declared_names = {d.split(":", 1)[1] for d in declared}

missing = sorted(spawnable - declared_names)
assert not missing, (
    "agents present on disk but absent from the orchestrator allowlist: %s — "
    "they cannot be spawned (#181)" % missing
)

ghosts = sorted(declared_names - on_disk)
assert not ghosts, (
    "orchestrator allowlist names agents with no definition: %s" % ghosts
)

# --- 2. roster-check hook fallback list -------------------------------------
hook_path = os.path.join(src, "hooks", "scripts", "roster-check.sh")
if os.path.exists(hook_path):
    hook_src = open(hook_path).read()
    # The fallback branch is the only `case` line listing agent names with |.
    fallback = re.search(
        r"^\s*(orchestrator\|[a-z|]+)\)\s*exit 0", hook_src, re.MULTILINE
    )
    assert fallback, (
        "roster-check.sh has no recognisable agent fallback list — if its "
        "structure changed, update this guard alongside it"
    )
    hook_names = set(fallback.group(1).split("|"))
    hook_missing = sorted(on_disk - hook_names)
    assert not hook_missing, (
        "roster-check.sh fallback list is missing agents %s — spawning them "
        "would emit a spurious 'unknown agent type' warning (#181)"
        % hook_missing
    )
    assert "pds:" in hook_src, (
        "roster-check.sh does not handle the pds: namespace — live spawns "
        "report agent_type as pds:<name>, so bare-only matching warns on "
        "every legitimate spawn (#181)"
    )

# --- 3. Documented roster size ----------------------------------------------
count = len(on_disk)
DOC_CLAIMS = [
    ("README.md", r"agents/\s*#?\s*(\d+) agent definitions"),
    ("CLAUDE.md", r"agents/\s*—\s*(\d+) agent definitions"),
    ("docs/teams.md", r"PDS provides (\d+) agents"),
    ("docs/whitepaper.md", r"\(`agents/` directory\): (\d+) role definitions"),
]
stale = []
for rel, pattern in DOC_CLAIMS:
    path = os.path.join(src, rel)
    if not os.path.exists(path):
        continue
    found = re.search(pattern, open(path).read())
    if found and int(found.group(1)) != count:
        stale.append("%s says %s" % (rel, found.group(1)))

assert not stale, (
    "roster is %d agents but docs disagree: %s — a wrong count is how the "
    "shepherd stayed invisible long enough to be left out of the spawn "
    "allowlist entirely" % (count, "; ".join(stale))
)
