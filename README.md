# gh-project-board

An [Agent Skill](https://agentskills.io) for autonomous task management using GitHub Projects V2.

Agents discover, claim, execute, and complete tasks from a GitHub Project board using the `gh` CLI.

```
Agent → Discover Todo → Claim (lock) → Work → PR → Done
                              ↓
                         Blocked? → Comment → Release lock → Pick next
```

## Install

```bash
npx skills add irangareddy/gh-project-board
```

## Setup

```bash
# Add project scopes to gh
gh auth refresh -h github.com -s read:project,project

# Generate project config (field IDs, option mappings)
./skills/gh-project-board/scripts/setup.sh <owner> <project-number>
```

## Project Fields

Your GitHub Project needs these single-select fields:

| Field | Options | Purpose |
|-------|---------|---------|
| **Status** | Todo, In Progress, Done | Task lifecycle |
| **Execution Lock** | Locked, Unlocked | Prevents concurrent claims |
| **Agent Owner** | Per-agent options | Who's working on it |
| **Blocked** | Yes, No | Dependency tracking |
| **Execution Stage** | Spec Needed → Done | Granular progress |
| **Platform** | iOS, Android, Web, etc. | Task routing |
| **Priority** | P0, P1, P2 | Ordering |

## Agent Lifecycle

1. **Discover** — `Todo + Unlocked + My Platform + No Owner`
2. **Claim** — Lock, set owner, move to In Progress
3. **Work** — Branch, code, commit, push
4. **PR** — `gh pr create` with `Closes #N`
5. **Blocked** — Mark blocked, release lock, comment reason, pick next
6. **Done** — Mark done, release lock

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/setup.sh` | Discover project config and field mappings |
| `scripts/discover.py` | Query and filter available tasks |
| `scripts/update-task.sh` | Update task fields (status, lock, stage, blocked) |

## References

- [`FIELD_MAPPING.md`](skills/gh-project-board/references/FIELD_MAPPING.md) — How GitHub Projects V2 fields work
- [`EXAMPLES.md`](skills/gh-project-board/references/EXAMPLES.md) — End-to-end workflow examples

## License

MIT
