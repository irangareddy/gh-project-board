# Examples

## Example 1: Agent Picks Up and Completes a Task

```bash
# 1. Discover available iOS tasks
gh project item-list <project-number> --owner <owner> --limit 100 --format json | \
  python3 scripts/discover.py --platform iOS --status Todo --unlocked --unowned

# Output:
# Found 3 task(s):
#  #102 |       P2 |         Todo |       — |        — | chore: remove unused imports
#  #98  |        — |         Todo |       — |        — | refactor: extract shared validator
#  #99  |        — |         Todo |       — |        — | refactor: introduce generic ViewState<T>

# 2. Claim #102 (highest priority)
scripts/update-task.sh "PVTI_<item-id>" \
  --status in_progress --stage implementing --lock locked --agent-owner "iOS Agent"

# 3. Read the issue
gh issue view 102 --json title,body

# 4. Create branch and work
git checkout develop && git pull
git checkout -b chore/issue-102-unused-imports
# ... make changes ...
git add -A && git commit -m "chore: remove unused imports (#102)"
git push -u origin chore/issue-102-unused-imports

# 5. Create PR
gh pr create --base develop \
  --title "chore: remove unused imports" \
  --body "Closes #102"

# Update to review
scripts/update-task.sh "PVTI_<item-id>" --stage review

# 6. After merge, mark done
scripts/update-task.sh "PVTI_<item-id>" \
  --status done --stage done --lock unlocked
```

## Example 2: Agent Gets Blocked

```bash
# Working on #98 (extract shared validator)
# Discovers that SharedForm.swift has unmerged changes from another PR

# Mark as blocked
scripts/update-task.sh "PVTI_<item-id>" --blocked yes --lock unlocked

# Comment on the issue
gh issue comment 98 --body "Blocked by #95: pending PR has conflicts with SharedForm. Will resume after #95 is merged."

# Pick up next available task
gh project item-list <project-number> --owner <owner> --limit 100 --format json | \
  python3 scripts/discover.py --platform iOS --status Todo --unlocked --unowned
```

## Example 3: Check for Unblocked Tasks

```bash
# Check if any of my previously blocked tasks are now unblocked
gh project item-list <project-number> --owner <owner> --limit 100 --format json | \
  python3 scripts/discover.py --agent-owner "iOS Agent" --was-blocked

# Output:
# Found 1 task(s):
#  #98  |        — |  In Progress |      No |        — | refactor: extract shared validator

# Re-claim and continue
scripts/update-task.sh "PVTI_<item-id>" --lock locked --blocked no --stage implementing
```

## Example 4: Bulk Triage New Issues

```bash
# Add all open issues to the project with Platform=iOS
for num in $(gh issue list --state open --json number -q '.[].number'); do
  gh project item-add <project-number> --owner <owner> \
    --url "https://github.com/<owner>/<repo>/issues/$num" \
    --format json 2>/dev/null && echo "Added #$num" || echo "Skip #$num"
done
```
