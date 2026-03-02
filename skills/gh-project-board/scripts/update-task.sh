#!/bin/bash
# Update task fields on a GitHub Project board
# Usage: ./update-task.sh <item-id> [--status <s>] [--stage <s>] [--blocked <b>] [--lock <l>] [--agent-owner <a>]
#
# Requires PROJECT_CONFIG environment variable or .project-config.json in skill root
# Or pass --project-id, --field-ids directly

set -euo pipefail

ITEM_ID="${1:?Usage: update-task.sh <item-id> [--status ...] [--stage ...] [--blocked ...] [--lock ...] [--agent-owner ...]}"
shift

# Parse arguments
STATUS=""
STAGE=""
BLOCKED=""
LOCK=""
AGENT_OWNER=""
PROJECT_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --status) STATUS="$2"; shift 2 ;;
    --stage) STAGE="$2"; shift 2 ;;
    --blocked) BLOCKED="$2"; shift 2 ;;
    --lock) LOCK="$2"; shift 2 ;;
    --agent-owner) AGENT_OWNER="$2"; shift 2 ;;
    --project-id) PROJECT_ID="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Try to load config from environment or file
if [ -z "$PROJECT_ID" ]; then
  CONFIG_FILE="$(dirname "$0")/../.project-config.json"
  if [ -f "$CONFIG_FILE" ]; then
    PROJECT_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['project_id'])")
  elif [ -n "${PROJECT_CONFIG:-}" ]; then
    PROJECT_ID=$(echo "$PROJECT_CONFIG" | python3 -c "import json,sys; print(json.load(sys.stdin)['project_id'])")
  else
    echo "Error: No project config found. Run setup.sh first or pass --project-id"
    exit 1
  fi
fi

# Field ID and option mappings
# These are loaded from config or can be overridden
get_field_option() {
  local FIELD_NAME="$1"
  local OPTION_VALUE="$2"
  local CONFIG_FILE="$(dirname "$0")/../.project-config.json"

  if [ -f "$CONFIG_FILE" ]; then
    python3 -c "
import json
config = json.load(open('$CONFIG_FILE'))
field = config['fields'].get('$FIELD_NAME', {})
field_id = field.get('id', '')
option_id = field.get('options', {}).get('$OPTION_VALUE', '')
print(f'{field_id}|{option_id}')
"
  else
    echo "|"
  fi
}

update_field() {
  local FIELD_NAME="$1"
  local OPTION_VALUE="$2"

  local RESULT
  RESULT=$(get_field_option "$FIELD_NAME" "$OPTION_VALUE")
  local FIELD_ID="${RESULT%%|*}"
  local OPTION_ID="${RESULT##*|}"

  if [ -n "$FIELD_ID" ] && [ -n "$OPTION_ID" ]; then
    gh project item-edit --project-id "$PROJECT_ID" --id "$ITEM_ID" \
      --field-id "$FIELD_ID" --single-select-option-id "$OPTION_ID" 2>/dev/null
    echo "  ✓ $FIELD_NAME → $OPTION_VALUE"
  else
    echo "  ✗ $FIELD_NAME: field or option not found"
  fi
}

# Status mapping
declare -A STATUS_MAP=(
  [todo]="Todo"
  [in_progress]="In Progress"
  [done]="Done"
)

# Execution Stage mapping
declare -A STAGE_MAP=(
  [spec_needed]="Spec Needed"
  [spec_drafted]="Spec Drafted"
  [spec_approved]="Spec Approved"
  [implementing]="Implementing"
  [review]="Review"
  [done]="Done"
)

# Blocked mapping
declare -A BLOCKED_MAP=(
  [yes]="Yes"
  [no]="No"
)

# Lock mapping
declare -A LOCK_MAP=(
  [locked]="Locked"
  [unlocked]="Unlocked"
)

echo "Updating task $ITEM_ID:"

[ -n "$LOCK" ] && update_field "Execution Lock" "${LOCK_MAP[$LOCK]}"
[ -n "$STATUS" ] && update_field "Status" "${STATUS_MAP[$STATUS]}"
[ -n "$STAGE" ] && update_field "Execution Stage" "${STAGE_MAP[$STAGE]}"
[ -n "$BLOCKED" ] && update_field "Blocked" "${BLOCKED_MAP[$BLOCKED]}"
[ -n "$AGENT_OWNER" ] && update_field "Agent Owner" "$AGENT_OWNER"

echo "Done."
