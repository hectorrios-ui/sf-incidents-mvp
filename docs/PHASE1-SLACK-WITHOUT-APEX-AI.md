# Phase 1 — Slack notify without Apex AI

## What changed

`FeedbackSlackService` no longer calls `FeedbackLlmAdvisor`.

Salesforce now posts a clean Slack notification with:
- Issue metadata
- Description
- Record link + Record Id
- A short handoff line telling the team to analyze in-thread with Claude / Cursor

## Why

One less integration point in Apex:
- No OpenAI/Anthropic Named Credential required for Slack alerts
- No silent AI callout failures blocking clarity
- Claude / ClaudeForce / Cursor own analysis where collaboration already happens

## Deploy to Legend

```bash
cd ~/sf-incidents-mvp
git fetch origin
git checkout cursor/slack-notify-without-apex-ai-2c5f
git pull

sf project deploy start \
  --source-dir force-app/main/default/classes/FeedbackSlackService.cls \
  --source-dir force-app/main/default/classes/FeedbackSlackService.cls-meta.xml \
  --source-dir force-app/main/default/classes/FeedbackSlackServiceTest.cls \
  --source-dir force-app/main/default/classes/FeedbackSlackServiceTest.cls-meta.xml \
  -o Legend
```

Or deploy the whole package:

```bash
sf project deploy start --source-dir force-app/main/default -o Legend
```

## Verify

1. Create Feedback with Status = New
2. Slack message appears **without** "Proposed fix (internal AI)"
3. Message includes Record Id + "Next step" handoff line
4. In the thread, use Claude / Cursor to analyze and propose a fix

## Next (Phase 2+)

- Claude in Slack analyzes from thread context
- Salesforce MCP for on-demand org reads/writes
- Close the loop: PR link + Feedback status update
