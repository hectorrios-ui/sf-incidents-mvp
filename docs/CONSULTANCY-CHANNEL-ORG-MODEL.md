# Consultancy model: 1 channel ↔ 1 UAT sandbox ↔ Claude in Slack

## Is Slack-only context enough?

**Good enough for triage accuracy** if every Slack alert includes an explicit **Org Context** block (org id, type, sandbox flag, My Domain host, project label). Claude in Slack already proved it can reason from hostname/edition — making that explicit reduces wrong assumptions.

**Not enough for deep org reads** (related records, metadata inventory, live SOQL) unless you later connect Salesforce Hosted MCP to the **Slack** Claude bot. That’s optional Phase 3 for Slack — not Claude Code.

## Recommended operating model

```text
1 Slack channel  ↔  1 client UAT sandbox  ↔  1 webhook  ↔  same Claude Slack agent
```

| Client | Channel | Salesforce org | Named Credential |
|--------|---------|----------------|------------------|
| Acme | `#uat-acme` | Acme UAT sandbox | `Slack_Webhook` in Acme org |
| Contoso | `#uat-contoso` | Contoso UAT sandbox | `Slack_Webhook` in Contoso org |

**Same Claude Slack app** can be invited to many channels. Isolation comes from:
- each org posts only to its channel webhook
- each message carries that org’s Org Context + Project Label
- consultants work in the client channel only

## Concerns (and how we handle them)

### 1) Cross-client data leakage
- **Risk:** one shared Claude bot sees multiple channels  
- **Mitigation:** private channels per client; least-privilege invites; never put two clients’ webhooks into one channel  
- **Rule:** Feedback from Org A must never post to Client B’s channel  

### 2) Wrong org assumptions (edition, sandbox vs DE)
- **Risk:** Claude suggests Enterprise-only features  
- **Mitigation:** Org Context block on every message (`OrganizationType`, `IsSandbox`, host) + prompt text telling Claude to obey it  

### 3) Multiple sandboxes per client
- Still **1 channel : 1 sandbox**. If client has UAT + SIT, use `#uat-acme` and `#sit-acme` (two webhooks / two org configs).  

### 4) Same Claude agent everywhere
- Fine. One Claude Slack agent is OK.  
- Do **not** need one Claude install per client.  
- Do need one **Slack Incoming Webhook** (or channel binding) per sandbox.  

### 5) Shared consultancy Slack workspace
- Prefer private client channels  
- Channel topic/description: `Client=Acme | Org=00D… | Sandbox=UAT`  
- Set `Project_Label__c` on `NF_Incident_Slack_Config.Default` per org (e.g. `Acme-UAT`)  

## Setup checklist per client engagement

1. Deploy Feedback package to that client’s UAT sandbox  
2. Create private Slack channel `#uat-<client>`  
3. Create Incoming Webhook **into that channel only** → Named Credential in that org  
4. Invite Claude to that channel  
5. Set CMDT Default: Auto Analyze + Claude user id + **Project Label**  
6. Smoke test: create Feedback → message shows Org Context + @Claude  

## What “more accurate” means in practice

| Layer | Provides |
|-------|----------|
| Slack message + Org Context | Edition/sandbox/host/project (this change) |
| Screenshot in thread | UI evidence (Claude vision) |
| Salesforce MCP on Slack Claude | Live record/metadata queries (optional later) |

For consultancy UAT triage, **Org Context + screenshots + 1:1 channel/org** is the right baseline.
