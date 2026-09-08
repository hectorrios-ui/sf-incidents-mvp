# MVP component inventory — UAT Feedback → Slack → Claude

Clean package after removing Apex LLM integration.

## Core MVP (required)

### Data
| Component | Purpose |
|-----------|---------|
| `Feedback__c` (+ fields, list views) | System of record for UAT feedback |
| `Feedback__c` tab | App Launcher visibility |
| `UAT_Feedback` Lightning app | Consultant workspace |

### Automation
| Component | Purpose |
|-----------|---------|
| `NF_Feedback_Send_Slack_On_New` (Flow) | When Status=New & not yet sent → call Apex |
| `NF_FeedbackSlackService` (+ test) | Post Slack message (facts, org context, auto-@Claude) |
| `NF_FeedbackTrigger` + `NF_FeedbackKpiService` (+ test) | KPI timestamps (ack / start / resolve) |

### Config (org-managed records; types deploy)
| Component | Purpose |
|-----------|---------|
| `NF_Incident_Slack_Config__mdt` | Webhook NC name, Claude user id, auto-analyze, project label |
| `Slack_User_Mapping__mdt` | Optional assignee @mentions |
| `Slack_Webhook` Named Credential | Incoming webhook URL (secret in org) |
| `SF_incident_MVP` permission set | Object/Apex/app access |

### What each Slack message includes
- Issue metadata + description (text)  
- Record Id + Lightning link  
- **Org Context** (org id/type/sandbox/host/project label)  
- Optional **@Claude** auto-analyze prompt  

---

## Ready for org-connected Claude (keep)

| Component | Purpose |
|-----------|---------|
| `NF_FeedbackMcpGetAction` | Invocable: get Feedback by Name/Id → JSON |
| `NF_FeedbackMcpUpdateAction` | Invocable: update Status/Solution/Assignee |
| `NF_FeedbackMcpActionsTest` | Coverage |

Use when Slack/Salesforce admins connect Hosted MCP to Claude in Slack.

---

## Explicitly removed from MVP package

| Removed | Why |
|---------|-----|
| `FeedbackLlmAdvisor` (+ test) | Apex LLM callouts retired |
| `Ops_Incident_AI_Config__mdt` (removed) | Was Apex LLM only |
| `LLM_Provider_API` Named Credential | No longer used |
| `LLM_Provider_API_Key` External Credential | No longer used |
| `Feedback_Mark_In_Progress_After_Slack` | Intentional fault smoke test only |

**Org cleanup (Legend):** deactivate/delete the intentional fault Flow if it was deployed; you may leave unused LLM credentials or delete them manually.

---

## Adjacent (in repo, not required for this MVP)

| Component | Notes |
|-----------|---------|
| `nF_CreateCase` LWC + Contact flexipage | Separate UX experiment |
| `nF_FeedbackButton` LWC | Optional UI entry point |
| Feedback webLinks `Send_to_Slack` / `Slack_Alerts` | Legacy Slack package links; not required for webhook path |

---

## Next build (requested)

**Feedback screenshots → Slack thread**
- Requires Slack Bot token (Web API), not Incoming Webhook alone  
- Extract images from `Issue_Description__c` (HTML) and/or Files on the record  
- Upload into the same Slack thread for Claude vision  

See `docs/PITCH-AND-REQUEST-CLAUDE-SLACK.md` for the admin ask.
