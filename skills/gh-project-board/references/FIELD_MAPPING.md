# Field Mapping Reference

## How GitHub Projects V2 Fields Work

Every field in a GitHub Project has:
- A **Field ID** (e.g., `PVTSSF_abc123def456`)
- **Option IDs** for single-select fields (e.g., `a1b2c3d4` for "Todo")

To update a field, you need both the field ID and the option ID.

## Discovering Field Mappings

```bash
# List all fields with their IDs and options
gh project field-list <project-number> --owner <owner> --format json
```

The JSON output contains:
```json
{
  "fields": [
    {
      "id": "PVTSSF_...",
      "name": "Status",
      "type": "ProjectV2SingleSelectField",
      "options": [
        {"id": "a1b2c3d4", "name": "Todo"},
        {"id": "e5f6a7b8", "name": "In Progress"},
        {"id": "c9d0e1f2", "name": "Done"}
      ]
    }
  ]
}
```

## Standard Fields for Agent Workflows

The following fields are recommended for agent-driven project management:

| Field | Type | Purpose |
|-------|------|---------|
| **Status** | Single Select | Task lifecycle (Todo → In Progress → Done) |
| **Platform** | Single Select | Which platform the task belongs to |
| **Priority** | Single Select | P0 (critical) → P1 (high) → P2 (normal) |
| **Work Type** | Single Select | Feature / Bug / Chore |
| **Agent Owner** | Single Select | Which agent claimed the task |
| **Blocked** | Single Select | Yes / No |
| **Execution Lock** | Single Select | Locked / Unlocked (prevents concurrent claims) |
| **Execution Stage** | Single Select | Spec Needed → Spec Drafted → Spec Approved → Implementing → Review → Done |

## Caching Config

After running `setup.sh`, a `.project-config.json` file is created with all field mappings. This avoids repeated API calls:

```json
{
  "project_id": "PVT_...",
  "owner": "<owner>",
  "project_number": 1,
  "fields": {
    "Status": {
      "id": "PVTSSF_...",
      "options": {
        "Todo": "a1b2c3d4",
        "In Progress": "e5f6a7b8",
        "Done": "c9d0e1f2"
      }
    }
  }
}
```

## Updating Fields via gh CLI

```bash
# Single field update
gh project item-edit \
  --project-id "PVT_..." \
  --id "PVTI_..." \
  --field-id "PVTSSF_..." \
  --single-select-option-id "option-id"

# Text/date field update
gh project item-edit \
  --project-id "PVT_..." \
  --id "PVTI_..." \
  --field-id "PVTF_..." \
  --text "value"
```

## Common Gotchas

1. **Field names with spaces** — `Agent Owner` may appear as `agent Owner` or `agentOwner` in JSON output
2. **Option IDs are opaque** — don't hardcode them, always discover via `field-list`
3. **Project ID vs Number** — `item-list` uses the number, `item-edit` uses the full ID (`PVT_...`)
4. **Rate limits** — batch updates when possible, don't poll more than once per minute
