#!/bin/bash
# Setup: Discover project configuration and field mappings
# Usage: ./setup.sh <owner> <project-number>

set -euo pipefail

OWNER="${1:?Usage: setup.sh <owner> <project-number>}"
PROJECT_NUM="${2:?Usage: setup.sh <owner> <project-number>}"

echo "Discovering project config for $OWNER project #$PROJECT_NUM..."

# Get project ID
PROJECT_ID=$(gh project list --owner "$OWNER" --format json | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data.get('projects', []):
    if p.get('number') == $PROJECT_NUM:
        print(p['id'])
        break
")

if [ -z "$PROJECT_ID" ]; then
  echo "Error: Project #$PROJECT_NUM not found for $OWNER"
  exit 1
fi

echo "Project ID: $PROJECT_ID"
echo ""

# Get all fields and their options
echo "=== FIELD MAPPINGS ==="
gh project field-list "$PROJECT_NUM" --owner "$OWNER" --format json | \
  python3 -c "
import json, sys

data = json.load(sys.stdin)
config = {
    'project_id': '$PROJECT_ID',
    'owner': '$OWNER',
    'project_number': $PROJECT_NUM,
    'fields': {}
}

for field in data.get('fields', []):
    name = field.get('name', '')
    field_id = field.get('id', '')
    options = field.get('options', [])

    if options:
        config['fields'][name] = {
            'id': field_id,
            'options': {opt['name']: opt['id'] for opt in options}
        }
        print(f\"  {name} ({field_id}):\")
        for opt in options:
            print(f\"    {opt['name']} = {opt['id']}\")
    else:
        config['fields'][name] = {'id': field_id}

# Output as JSON for scripting
import os
config_path = os.path.join(os.path.dirname(os.path.abspath('$0')), '..', '.project-config.json')
print()
print(json.dumps(config, indent=2))
"
