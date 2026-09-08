# Quick Start - Deploy to New Org

This guide will help you deploy the UAT Feedback package to a fresh Salesforce org in under 10 minutes.

## Prerequisites

- Salesforce CLI installed (`npm install -g @salesforce/cli`)
- Git clone of this repository
- Slack workspace (for webhook)
- Anthropic or OpenAI API key (for AI suggestions)

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
sf project deploy start --source-dir force-app/main/default -o feedback-demo
```

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

### 2. AI API Key (Required)

1. Get your API key:
   - Anthropic: https://console.anthropic.com/
   - OpenAI: https://platform.openai.com/

2. In Salesforce:
   - Setup → Named Credentials → **External Credentials** tab
   - **LLM Provider API Key** → Principals section
   - Click the principal → Edit
   - Paste API key in `x-api-key` field → Save

3. Grant permission:
   - Setup → Permission Sets → **SF_incident_MVP**
   - Add the External Credential → Save

### 3. Activate Flow (Required)

- Setup → Flows → **Feedback_Send_Slack_On_New**
- Click **Activate**

### 4. Verify Custom Metadata (Optional - has defaults)

**Slack Config:**
- Setup → Custom Metadata Types → **Ops Incident Slack Config**
- Manage Records → **Default**
- Verify: Slack Named Credential = `Slack_Webhook`

**AI Config:**
- Setup → Custom Metadata Types → **Ops Incident AI Config**
- Manage Records → **Default**
- Verify settings:
  - Enabled: ✅
  - Provider: `Anthropic_Messages` (or `OpenAI_Chat`)
  - Model: `claude-sonnet-4-6`
  - Named Credential: `LLM_Provider_API`

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

2. Check Slack - you should see the notification!

3. In Slack thread, try:
   ```
   @Cursor analyze this feedback and suggest a fix
   ```

## What's Included

This deployment includes:

- ✅ `Feedback__c` custom object (20 fields)
- ✅ Apex classes (Slack service, AI advisor, KPI tracking)
- ✅ Trigger + Flow automation
- ✅ LWC components (Feedback button, Create case)
- ✅ Named Credentials (configured shells)
- ✅ Custom Metadata Types
- ✅ List views & record pages

## Troubleshooting

**Slack messages not sending?**
- Check Named Credential URL is correct
- Test webhook with curl to verify it works
- Check Flow is activated

**AI suggestions showing "n/a"?**
- Verify API key is set in External Credential
- Check permission set grants access to credential
- Review Custom Metadata AI config

**Deployment errors?**
- Run: `sf project deploy start --source-dir force-app/main/default -o your-org --dry-run`
- Check API version compatibility (currently 64.0)

## Next Steps

- Read the full setup guide: [README-Feedback-Slack-Cursor-Playbook.md](./README-Feedback-Slack-Cursor-Playbook.md)
- Configure Cursor Slack integration: https://cursor.com/docs/integrations/slack
- Set up KPI reports for tracking feedback cycle time

## Support

For issues or questions, check:
- Full playbook documentation
- Salesforce CLI docs: https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/
- Cursor Slack docs: https://cursor.com/docs/integrations/slack
