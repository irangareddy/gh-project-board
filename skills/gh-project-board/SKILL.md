---
name: gh-project-board
description: Manage GitHub Projects V2 as an autonomous agent. Discover available tasks, claim with execution locks, update status/stage/blocked fields, raise PRs linked to issues, and handle blocked workflows. Use when working with GitHub Project boards, triaging issues, or autonomously picking up and completing tasks from a project backlog.
license: MIT
compatibility: Requires gh CLI authenticated with project scopes (read:project, project)
metadata:
  author: irangareddy
  version: "1.0"
allowed-tools: Bash(gh:*) Bash(git:*) Bash(python3:*) Read
---

# GitHub Project Board Agent Skill

Operate as an autonomous agent that discovers, claims, executes, and completes tasks from a GitHub Projects V2 board using the `gh` CLI.

## Prerequisites

```bash
# Verify gh is authenticated with project scopes
gh auth status
# If missing project scopes:
gh auth refresh -h github.com -s read:project,project
```

## Setup: Load Project Config

Before any operation, the agent must load the project configuration. Run the setup script to discover the project:

```bash
scripts/setup.sh <owner> <project-number>
```

This outputs a `PROJECT_CONFIG` block that the agent should use for all subsequent operations. If no config is provided by the user, discover it:

```bash
# List projects for the org/user
gh project list --owner <owner>

# Get field IDs and option mappings
gh project field-list <project-number> --owner <owner> --format json
```

See [references/FIELD_MAPPING.md](references/FIELD_MAPPING.md) for how to parse and cache field mappings.

## Agent Lifecycle

### Step 1: Discover Available Tasks

Find tasks that are ready to be picked up:

```bash
gh project item-list <project-number> --owner <owner> --limit 100 --format json | \
  python3 scripts/discover.py --platform "<platform>" --status "Todo" --unlocked
```

**Selection criteria** (in priority order):
1. Status = `Todo`
2. Execution Lock = `Unlocked` (or unset)
3. Agent Owner = unset (no other agent has claimed it)
4. Platform matches agent's platform (e.g., `iOS`, `Android`, `Web`, `Backend`)
5. Priority: P0 > P1 > P2 > unset

### Step 2: Claim a Task

Acquire an execution lock to prevent other agents from claiming the same task:

```bash
scripts/update-task.sh <item-id> \
  --status "in_progress" \
  --stage "implementing" \
  --blocked "no" \
  --lock "locked" \
  --agent-owner "<agent-name>"
```

**Lock protocol:**
- Always check lock status before claiming
- Set lock FIRST, then update other fields
- If lock fails (another agent claimed it), move to the next task

### Step 3: Read Issue Details

```bash
# Get full issue context
gh issue view <number> --json title,body,labels,comments,assignees

# Check for linked issues or specs
gh issue view <number> --json body | python3 -c "
import json, sys
body = json.load(sys.stdin)['body']
# Look for 'Blocked by #N', 'Depends on #N', 'Spec: #N' patterns
import re
refs = re.findall(r'#(\d+)', body)
print('Referenced issues:', refs)
"
```

### Step 4: Work on the Task

```bash
# Create branch from default branch
git checkout <default-branch> && git pull
git checkout -b <type>/issue-<number>-<short-description>

# Branch naming convention:
# fix/issue-241-question-validator
# feat/issue-217-live-activities
# refactor/issue-243-generic-viewstate
# chore/issue-249-unused-imports
```

Work on the implementation, then commit and push:

```bash
git add <files>
git commit -m "<type>: <description> (#<number>)"
git push -u origin <branch-name>
```

### Step 5: Raise a PR

```bash
gh pr create --base <default-branch> \
  --title "<type>: <description>" \
  --body "$(cat <<'EOF'
## Summary
- <what was done>

Closes #<number>

## Test plan
- [ ] <verification steps>
EOF
)"

# Update stage to Review
scripts/update-task.sh <item-id> --stage "review"
```

The `Closes #<number>` keyword automatically closes the issue when the PR is merged.

### Step 6: Handle Blocked State

When the agent cannot proceed:

```bash
# Mark as blocked
scripts/update-task.sh <item-id> \
  --blocked "yes" \
  --lock "unlocked"

# Comment on the issue with the reason
gh issue comment <number> --body "Blocked by #<blocker>: <reason>"

# Move on to the next available task (back to Step 1)
```

When checking if a previously blocked task is unblocked:

```bash
gh project item-list <project-number> --owner <owner> --limit 100 --format json | \
  python3 scripts/discover.py --agent-owner "<agent-name>" --was-blocked
```

### Step 7: Complete (After Merge)

```bash
scripts/update-task.sh <item-id> \
  --status "done" \
  --stage "done" \
  --blocked "no" \
  --lock "unlocked"
```

## Decision Tree

```
Agent starts
│
├─ Has assigned in-progress task?
│   ├─ Yes → Continue working on it
│   └─ No → Discover available tasks
│
├─ Found available task?
│   ├─ Yes → Claim it (lock + assign) → Work on it
│   └─ No → Check for unblocked tasks → If none, idle
│
├─ Task complete?
│   ├─ Yes → PR → Update to Review → Wait for merge → Mark Done
│   └─ No, blocked → Mark Blocked → Release lock → Pick next task
│
└─ PR merged?
    └─ Yes → Mark Done → Release lock → Pick next task
```

## Rules

1. **One task at a time** — finish or block before picking the next
2. **Always lock before starting** — prevents race conditions
3. **Release lock when blocked** — lets humans see it needs attention
4. **Priority order** — P0 > P1 > P2 > unset
5. **Platform boundaries** — only work on tasks matching your platform
6. **Link PRs to issues** — always use `Closes #N` in PR body
7. **Comment on blockers** — explain why, link the blocking issue
8. **Don't touch other agents' tasks** — respect execution locks
