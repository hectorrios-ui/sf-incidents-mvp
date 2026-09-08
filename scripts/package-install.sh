#!/bin/bash
# Install a package version into a target org
# Usage: ./scripts/package-install.sh <orgAlias> <packageVersionAliasOr04t>
# Example: ./scripts/package-install.sh Legend "UAT Feedback Slack Claude@0.1.0-1"
set -euo pipefail

ORG="${1:-}"
PKG="${2:-}"
if [[ -z "$ORG" || -z "$PKG" ]]; then
  echo "Usage: $0 <orgAlias> <packageVersionAliasOr04t>"
  exit 1
fi

sf package install \
  --package "$PKG" \
  --target-org "$ORG" \
  --wait 30 \
  --publish-wait 10

echo ""
echo "Installed. Post-install checklist:"
echo "  1) Named Credential Slack_Webhook → paste webhook URL"
echo "  2) Activate Flow NF_Feedback_Send_Slack_On_New"
echo "  3) Assign permission set SF_incident_MVP"
echo "  4) Configure NF Incident Slack Config (Claude id / project label)"
echo "  5) Invite Claude to the client UAT channel"
