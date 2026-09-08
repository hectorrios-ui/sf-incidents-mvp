#!/bin/bash
# Create a new Unlocked package version for "UAT Feedback Slack Claude"
# Usage: ./scripts/package-version-create.sh [DevHubAlias]
set -euo pipefail

DEVHUB="${1:-DevHub}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Using Dev Hub: $DEVHUB"
sf config set target-dev-hub="$DEVHUB"

# Create package container if alias missing
if ! grep -q '"UAT Feedback Slack Claude"' sfdx-project.json 2>/dev/null || ! grep -q '0Ho' sfdx-project.json 2>/dev/null; then
  echo "Package alias not found — creating Unlocked package container..."
  sf package create \
    --name "UAT Feedback Slack Claude" \
    --description "UAT Feedback to Slack + Claude handoff" \
    --package-type Unlocked \
    --path force-app \
    --target-dev-hub "$DEVHUB"
  echo "Commit sfdx-project.json after this (packageAliases updated)."
fi

echo "Creating package version (this can take several minutes)..."
sf package version create \
  --package "UAT Feedback Slack Claude" \
  --installation-key-bypass \
  --wait 40 \
  --code-coverage \
  --target-dev-hub "$DEVHUB"

echo ""
echo "Done. Check sfdx-project.json packageAliases for the new 04t id."
echo "Install with: ./scripts/package-install.sh <orgAlias> \"UAT Feedback Slack Claude@x.y.z-N\""
