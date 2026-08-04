"""Regression guard for #181: orchestrator spawn allowlist must be pds:-namespaced
and must cover every spawnable agent in agents/."""
import os, re, sys

src = sys.argv[1]
agents_dir = os.path.join(src, "agents")
orch = os.path.join(agents_dir, "orchestrator.md")

fm = open(orch).read().split("---")[1]
m = re.search(r"Task\(([^)]*)\)", fm)
assert m, "orchestrator.md frontmatter has no Task(...) spawn allowlist"
declared = [x.strip() for x in m.group(1).split(",") if x.strip()]
assert declared, "orchestrator Task(...) allowlist is empty"

bare = [d for d in declared if not d.startswith("pds:")]
assert not bare, (
    "orchestrator Task(...) allowlist has un-namespaced entries %s — "
    "plugin agents register as pds:<name>; bare names match nothing and "
    "empty the entire spawn roster (#181)" % bare
)

# Every agent definition except the orchestrator itself and the non-spawnable
# shared-rules mixin must be reachable.
NON_SPAWNABLE = {"orchestrator", "shared-rules"}
on_disk = {
    os.path.basename(f)[:-3]
    for f in os.listdir(agents_dir)
    if f.endswith(".md")
} - NON_SPAWNABLE
declared_names = {d.split(":", 1)[1] for d in declared}

missing = sorted(on_disk - declared_names)
assert not missing, (
    "agents present on disk but absent from the orchestrator allowlist: %s — "
    "they cannot be spawned (#181)" % missing
)
ghosts = sorted(declared_names - on_disk)
assert not ghosts, (
    "orchestrator allowlist names agents with no definition: %s" % ghosts
)
