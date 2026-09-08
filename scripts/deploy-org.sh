#!/bin/bash
# Deploy package metadata WITHOUT overwriting org Custom Metadata records.
# Relies on .forceignore excluding force-app/main/default/customMetadata/
#
# Usage: ./scripts/deploy-org.sh <org-alias>
set -euo pipefail

ORG_ALIAS="${1:-}"
if [[ -z "$ORG_ALIAS" ]]; then
  echo "Usage: $0 <org-alias>"
  echo "Example: $0 Legend"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Deploying to $ORG_ALIAS (Custom Metadata records excluded via .forceignore)..."
sf project deploy start --source-dir force-app/main/default -o "$ORG_ALIAS" -w 10

echo ""
echo "Done. Org CMDT records (Ops Incident Slack/AI Config, etc.) were not overwritten."
echo "To seed CMDT on a brand-new org once, temporarily remove the customMetadata/"
echo "line from .forceignore, deploy, re-add the line, then configure in Setup."
