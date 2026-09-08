#!/bin/bash
#
# Deploy UAT Feedback Package to a New Org
# Usage: ./scripts/deploy-to-new-org.sh [org-alias]
#

set -e

ORG_ALIAS="${1:-feedback-demo}"

echo "=========================================="
echo "UAT Feedback Package Deployment"
echo "Target Org: $ORG_ALIAS"
echo "=========================================="
echo ""

# Check if SF CLI is installed
if ! command -v sf &> /dev/null; then
    echo "❌ Salesforce CLI not found. Please install it first:"
    echo "   npm install -g @salesforce/cli"
    exit 1
fi

echo "✅ Salesforce CLI found"
echo ""

# Check if user wants to create a scratch org or use existing
read -p "Create new scratch org? (y/n): " CREATE_SCRATCH

if [[ "$CREATE_SCRATCH" =~ ^[Yy]$ ]]; then
    echo "Creating scratch org..."
    
    # Create scratch org definition if it doesn't exist
    if [ ! -f "config/project-scratch-def.json" ]; then
        echo "Creating scratch org definition..."
        mkdir -p config
        cat > config/project-scratch-def.json << 'EOF'
{
  "orgName": "UAT Feedback Demo",
  "edition": "Developer",
  "features": ["EnableSetPasswordInApi"],
  "settings": {
    "lightningExperienceSettings": {
      "enableS1DesktopEnabled": true
    },
    "mobileSettings": {
      "enableS1EncryptedStoragePref2": false
    }
  }
}
EOF
    fi
    
    sf org create scratch -f config/project-scratch-def.json -a "$ORG_ALIAS" -d 30 -w 10
    echo "✅ Scratch org created: $ORG_ALIAS"
else
    echo "Using existing org. Make sure you're logged in:"
    echo "   sf org login web -a $ORG_ALIAS"
    read -p "Press Enter to continue..."
fi

echo ""
echo "=========================================="
echo "Step 1: Deploying metadata..."
echo "=========================================="

sf project deploy start --source-dir force-app/main/default -o "$ORG_ALIAS" -w 10

echo ""
echo "✅ Metadata deployed successfully!"
echo ""

echo "=========================================="
echo "Step 2: Post-deployment configuration"
echo "=========================================="

echo ""
echo "⚠️  MANUAL STEPS REQUIRED:"
echo ""
echo "1. Configure Slack Webhook:"
echo "   - Create incoming webhook at https://api.slack.com/apps"
echo "   - Setup → Named Credentials → Slack_Webhook"
echo "   - Paste webhook URL"
echo ""
echo "2. Configure AI API Key:"
echo "   - Setup → Named Credentials → External Credentials"
echo "   - LLM Provider API Key → Principals → Edit"
echo "   - Add your API key to x-api-key field"
echo ""
echo "3. Activate the Flow:"
echo "   - Setup → Flows → Feedback_Send_Slack_On_New → Activate"
echo ""
echo "4. Configure Custom Metadata:"
echo "   - Ops_Incident_Slack_Config → Default"
echo "   - Ops_Incident_AI_Config → Default"
echo ""
echo "5. (Optional) Map Slack User IDs:"
echo "   - Setup → Custom Metadata Types → Slack User Mapping"
echo ""

echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Open your org:"
echo "   sf org open -o $ORG_ALIAS"
echo ""
echo "Full setup guide:"
echo "   See README-Feedback-Slack-Cursor-Playbook.md"
echo ""
