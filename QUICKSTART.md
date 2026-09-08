# Quick Start - Deploy to New Org

This guide will help you deploy the UAT Feedback package to a fresh Salesforce org in under 10 minutes.

## Prerequisites

- Salesforce CLI installed (`npm install -g @salesforce/cli`)
- Git clone of this repository
- Slack workspace (for webhook)
- Claude in Slack invited to the target channel (for auto-analyze)

## Option 1: Automated Script (Recommended)

```bash
# Run the deployment script
./scripts/deploy-to-new-org.sh my-feedback-org

# Follow the prompts
```

The script will:
1. ✅ Create a scratch org (or use existing)
2. ✅ Deploy all metadata
3. ✅ Show you the manual configuration steps

## Option 2: Manual Deployment

### Step 1: Create/Login to Org

**For scratch org:**
```bash
sf org create scratch -f config/project-scratch-def.json -a feedback-demo -d 30
```

**For sandbox/production:**
```bash
sf org login web -a my-org
```

### Step 2: Deploy

```bash
# Recommended helper (same deploy; CMDT records skipped via .forceignore)
./scripts/deploy-org.sh Legend

# Or:
sf project deploy start --source-dir force-app/main/default -o feedback-demo
```

> Custom Metadata **records** under `force-app/main/default/customMetadata/` are excluded
> from deploy (see `.forceignore`) so org settings like Claude Slack User Id are preserved.
> Configure those once in Setup. CMDT **type/field** definitions still deploy.

### Step 3: Open the Org

```bash
sf org open -o feedback-demo
```

## Post-Deployment Configuration

After deployment, you **must** configure these items manually (Salesforce doesn't allow secrets in metadata):

### 1. Slack Webhook (Required)

1. Create webhook at https://api.slack.com/apps
   - Create New App → From Scratch
   - Enable Incoming Webhooks
   - Add webhook to your channel
   - Copy the webhook URL

2. In Salesforce:
   - Setup → Named Credentials → **Slack_Webhook**
   - Edit → Paste webhook URL → Save

### 2. Assign Permission Set + open the app (Required)

Without this, **Feedback will not appear** in App Launcher.

```bash
sf org assign permset -n SF_incident_MVP -o <your-org-alias>
```

Or: Setup → Permission Sets → **SF Incident MVP** → Manage Assignments → add your user.

Then App Launcher → **UAT Feedback** (or search **Feedback**).

### 3. Activate Flow (Required)

- Setup → Flows → **NF_Feedback_Send_Slack_On_New**
- Click **Activate**

### 4. Verify Slack Custom Metadata

- Setup → Custom Metadata Types → **Slack Config**
- Manage Records → **Default**
- Slack Named Credential = `Slack_Webhook`
- Optional: Auto Analyze + Claude Slack User Id + Project Label

### 5. Map Slack Users (Optional - for @mentions)

- Setup → Custom Metadata Types → **Slack User Mapping**
- Create record for each team member:
  - Salesforce Username: `user@company.com`
  - Slack User Id: `U01ABCDEF` (from Slack profile → Copy member ID)

## Test It Out

1. Create a test feedback record:
   - App Launcher → **Feedback**
   - New → Fill required fields
   - Status = **New**
   - Save

2. Check Slack - you should see the notification (org context + optional @Claude)!

## What's Included

See `docs/MVP-COMPONENTS.md`. Core pieces:

- ✅ `Feedback__c` + tab + UAT Feedback app
- ✅ `NF_FeedbackSlackService` + KPI trigger/services
- ✅ Flow `NF_Feedback_Send_Slack_On_New`
- ✅ Slack Named Credential shell + Slack CMDT
- ✅ MCP invocables (for when Claude in Slack is org-connected)
- ❌ No Apex LLM / OpenAI / Anthropic credentials

## Troubleshooting

**Slack messages not sending?**
- Check Named Credential URL is correct
- Check Flow is activated

**Claude not waking?**
- Auto Analyze Enabled + Claude Slack User Id on Slack CMDT
- Claude invited to the channel

**Feedback not visible?**
- Assign `SF_incident_MVP` permission set

## Next Steps

- Read the full setup guide: [README-Feedback-Slack-Cursor-Playbook.md](./README-Feedback-Slack-Cursor-Playbook.md)
- Configure Cursor Slack integration: https://cursor.com/docs/integrations/slack
- Set up KPI reports for tracking feedback cycle time

## Support

For issues or questions, check:
- Full playbook documentation
- Salesforce CLI docs: https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/
- Cursor Slack docs: https://cursor.com/docs/integrations/slack
