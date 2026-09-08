# Auto-analyze Feedback in Slack (no copy-paste)

When a Feedback alert posts, Salesforce can **@mention Claude automatically** with an analyze prompt.

## Setup in Legend (once)

### 1) Get Claude’s Slack member ID
1. In Slack, open the Claude / ClaudeForce bot profile
2. ⋯ → **Copy member ID** (looks like `U0ABCDEF`)

### 2) Deploy this branch
```bash
git fetch origin
git checkout cursor/auto-mention-claude-on-feedback-2c5f
git pull
sf project deploy start --source-dir force-app/main/default -o Legend
```

### 3) Turn it on in Custom Metadata
Setup → Custom Metadata Types → **Slack Config** → **Default** → Edit:

| Field | Value |
|--------|--------|
| Auto Analyze Enabled | ✅ |
| Claude Slack User Id | `U0ABCDEF` (your bot id) |
| Auto Analyze Prompt | (optional — leave blank for default) |
| Slack Named Credential | `Slack_Webhook` |

### 4) Make sure Claude can see the channel
Invite the Claude bot to `#todo-uat-feedback-demo` (or your UAT channel).

### 5) Test
Create Feedback Status = New.

Slack should include a line like:
```text
@Claude Analyze this UAT Feedback. Propose a concrete Salesforce fix...
Feedback: `SF-00N` · Record Id: `a0X...`
```

Claude should wake without anyone copy-pasting.

## Notes
- Mention is in both Block Kit and the top-level `text` field (many bots listen to `text`).
- If your Claude app only responds to slash commands / app mentions in a special way, you may still need a Slack Workflow as backup.
- Cursor can be added the same way later with a Cursor bot user id.
