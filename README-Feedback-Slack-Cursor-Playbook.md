# Feedback to Slack to Cursor Playbook

This playbook describes the full operating model for UAT feedback using:

- Salesforce (`Feedback__c`) as system of record
- Slack as internal real-time collaboration channel
- Cursor Slack integration (`@cursor`) to execute code work quickly

Reference: [Cursor Slack Integration Docs](https://cursor.com/es/docs/integrations/slack)

---

## 1) Business Goal

Reduce UAT cycle time and rework by standardizing how feedback moves from:

1. Feedback item creation in Salesforce
2. Immediate internal Slack visibility
3. Fast engineering follow-up using Cursor Cloud Agents
4. Traceable closure back in Salesforce

---

## 0) From-Scratch Setup (new org / new project)

This section documents every manual step needed before the package deploys and runs. Do these **once per org** in order.

---

### Step 1 — Create a Slack Incoming Webhook

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From Scratch**.
2. Name it (e.g. `UAT Feedback Bot`), select your workspace → **Create App**.
3. In the app settings sidebar → **Incoming Webhooks** → toggle **Activate Incoming Webhooks** ON.
4. Click **Add New Webhook to Workspace** → pick the target channel (e.g. `#uat-feedback-project-alpha`) → **Allow**.
5. Copy the generated webhook URL — looks like:
   `https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX`

---

### Step 2 — Update the Slack Named Credential URL

The `Slack_Webhook` Named Credential shell is already deployed with the package (URL placeholder = `REPLACE_ME`).

Setup → **Named Credentials** → `Slack Webhook` → **Edit** → paste the webhook URL from Step 1 → **Save**.

That's it. No need to create the credential from scratch.

---

### Step 3 — Set the AI API key in the External Credential

The `LLM_Provider_API_Key` External Credential shell is deployed with the package but **the secret value never deploys via metadata** — Salesforce strips it for security. You must set it manually every time on a new org.

Setup → **Named Credentials** → **External Credentials** tab → `LLM Provider API Key` → **Principals** section → click the principal row → **Edit** → paste your AI API key (`sk-ant-api03-...` for Anthropic, `sk-...` for OpenAI) into the `x-api-key` field → **Save**.

> ⚠️ If this step is skipped, the AI callout silently fails and the Slack message shows `Proposed fix: n/a` with no error. Always verify with a smoke test after setup.

> The key is stored as an `x-api-key` header value injected automatically on every callout — your Apex never sees the raw key.

---

### Step 4 — (Already done) AI Named Credential

`LLM_Provider_API` Named Credential is deployed with the package pointing to `https://api.anthropic.com`. No action needed unless switching to a different AI provider base URL.

---

### Step 5 — Grant permission to the External Credential

The running user (or integration user) must be granted access to the External Credential principal, otherwise callouts silently fail.

Setup → **Named Credentials** → **External Credentials** → `LLM Provider API Key` → **Principals** → click your principal → **Permission Sets** → add `SF_incident_MVP` (or your integration permission set).

---

### Step 6 — Deploy the package

```bash
sf project deploy start --source-dir force-app/main/default -o <your-org-alias>
```

---

### Step 7 — Activate the Flow

Setup → **Flows** → `Feedback_Send_Slack_On_New` → **Activate**.

---

### Step 8 — Configure Custom Metadata

#### Slack config
Setup → **Custom Metadata Types** → `Ops Incident Slack Config` → **Manage Records** → `Default`:
- **Slack Named Credential**: `Slack_Webhook`

#### AI config
Setup → **Custom Metadata Types** → `Ops Incident AI Config` → **Manage Records** → `Default`:
- **Enabled**: ✅
- **Named Credential Api Name**: `LLM_Provider_API`
- **Provider**: `Anthropic_Messages` (or `OpenAI_Chat`)
- **Model**: `claude-sonnet-4-6` (or your preferred model)
- **Temperature**: `0.2`
- **Max Output Tokens**: `600`
- **Relative Api Path**: `v1/messages` (or `v1/chat/completions` for OpenAI)

---

### Step 9 — (Optional) Map Slack user IDs for @-mentions

Setup → **Custom Metadata Types** → `Slack User Mapping` → **Manage Records** → **New** for each teammate:
- **Salesforce Username**: their full SF username (e.g. `hector.rios@company.com.uatsb`)
- **Slack User Id**: their Slack member ID — found in Slack by clicking their avatar → ⋯ → **Copy member ID** (looks like `U01ABCDEF`)

---

### Credential inventory (what lives where)

| Credential | Type | Purpose | Contains secret? |
|---|---|---|---|
| `Slack_Webhook` | Legacy Named Credential | Slack incoming webhook URL | Yes — URL is the token |
| `LLM_Provider_API_Key` | External Credential | AI API key storage | Yes — set manually in Setup |
| `LLM_Provider_API` | Named Credential | AI provider base URL + auth | No — references External Credential |

> ⚠️ **Never commit credential files to git.** They are excluded via `.forceignore`. Recreate them in each org manually using this guide.

---

## 2) Current Technical Baseline (already built)

### Salesforce side

- `Feedback__c` auto-notifies Slack when:
  - `Status__c = New`
  - `SlackMessageTs__c` is blank
- `SlackMessageTs__c` prevents duplicate sends.
- Slack payload includes:
  - Feedback metadata (status, type, persona, link, description)
  - Internal-only AI suggestion (`proposedFix`)
  - AI confidence

### AI side (agnostic provider)

- Provider selected by metadata (`Ops_Incident_AI_Config__mdt`):
  - `OpenAI_Chat`
  - `Anthropic_Messages`
- No AI fields are written to client-facing `Feedback__c`.
- AI suggestion is visible only in internal Slack message.

### Security / access

- `SF_incident_MVP` permission set updated for new fields/classes.
- Named Credential and External Credential already in place for Slack and AI.

---

## 3) Architecture

```text
Feedback__c created/updated (Status = New)
    -> Record-Triggered Flow
    -> Apex: FeedbackSlackService (async callout)
        -> FeedbackLlmAdvisor (optional AI suggestion)
        -> Slack message to internal channel
        -> Feedback__c.SlackMessageTs__c = sent:timestamp

Slack thread
    -> Team triage discussion
    -> @cursor command to implement fix
    -> PR generated/reviewed
    -> Feedback status updated in Salesforce
```

---

## 4) Slack Channel Design

Use one internal channel per delivery stream/team, for example:

- `#uat-feedback-project-alpha`
- `#uat-feedback-project-beta`

Message policy:

- Keep Slack messages internal only.
- Do not post client-sensitive data beyond what is needed to triage.
- Use threads for each feedback item.

---

## 4b) Slack @-mentions for the assignee (optional but recommended)

To have the Slack message actually ping the person in `Assigned_To__c` (not just show their name), Salesforce needs their Slack user ID. This is done via a Custom Metadata Type and is a one-time setup per team member.

### How to find a user's Slack ID

1. In Slack, open the person's profile (click their avatar).
2. Click the three-dot menu in the profile panel.
3. Click **Copy member ID**. The ID looks like `U01ABCDEF` or `W03ABCDEF`.

### Create the mapping record

1. Setup -> **Custom Metadata Types** -> `Slack User Mapping` -> **Manage Records** -> **New**.
2. Fill:
   - **Label**: a human-friendly name, e.g. `Alice Smith`.
   - **Slack User Mapping Name**: the API name, e.g. `alice_smith`.
   - **Salesforce Username**: the full SF `User.Username`, e.g. `alice.smith@company.com.uatsb`.
   - **Slack User Id**: the `U...` / `W...` ID you copied.
3. Save. Repeat for each teammate who will appear in `Assigned_To__c`.

### What you will see in the Slack message

- Mapping exists -> `Assigned To: <@U01ABCDEF> (Alice Smith)` which Slack renders as a real @-mention, notifying the person.
- No mapping exists -> `Assigned To: Alice Smith` (plain name, no ping).
- Unassigned -> `Assigned To: n/a`.

## 5) Cursor in Slack: Setup

Follow official install flow: [Cursor Slack Integration](https://cursor.com/es/docs/integrations/slack)

High-level steps:

1. Connect Slack in Cursor integrations dashboard.
2. Connect GitHub repository access.
3. Configure default repo/model/channel settings.
4. In Slack, mention `@cursor` to run Cloud Agents.

---

## 6) Operational Workflow (Day-to-day)

### A) Triage

1. Feedback is created in Salesforce (`Status = New`).
2. Slack message appears with issue details + AI suggestion.
3. Team validates if AI suggestion is useful.

### B) Implementation

In Slack thread, run:

- `@Cursor in your-repo-name, implement fix for Feedback INC-XXXX based on this thread`

Optional:

- `@Cursor branch=main autopr=false implement the fix and add tests`

### C) Validation

1. Review PR.
2. Deploy to sandbox/UAT.
3. QA/UAT retest.
4. Update `Feedback__c` status (`Ready for UAT`, `Resolved`, etc.).

### D) Closure

1. Link PR/commit in Salesforce notes or solution field.
2. Mark final status (`Resolved`/`UAT Complete`).

---

## 7) Command Templates for Slack

Use these as copy/paste templates.

### Template 1: Quick fix attempt

`@Cursor in <repo>, fix this UAT feedback using the thread context and open a PR.`

### Template 2: Controlled fix (no auto PR)

`@Cursor branch=main autopr=false in <repo>, propose code changes + tests for this feedback.`

### Template 3: Follow-up refinement

`@Cursor update the previous changes to handle edge case <x> and improve test coverage.`

---

## 8) KPI and ROI Tracking

### Lifecycle signals

Three distinct cycle-time signals are tracked separately, because "someone noticed it", "someone claimed it", and "someone is working on it" are different events in real teams:

1. **Acknowledged** - a human claims ownership (`Assigned_To__c` goes null -> value).
2. **Work Started** - Status first enters `In Progress` or `Dev In-Progress`.
3. **Resolved** - Status first enters `Resolved` or `UAT Complete`.

Born-assigned records (i.e. `Assigned_To__c` already set at insert) are treated as acknowledged at creation (triage latency = 0). Filter them out of "natural triage" reports if needed.

### Fields stamped automatically (on `Feedback__c`)

| Field API                          | Type     | Set by                             | When                                          |
| ---------------------------------- | -------- | ---------------------------------- | --------------------------------------------- |
| `FirstSlackPostAt__c`              | DateTime | `FeedbackSlackService` (async)     | On first successful Slack 2xx post            |
| `AcknowledgedAt__c`                | DateTime | `FeedbackKpiService` (before ins/upd) | First time `Assigned_To__c` becomes non-null |
| `TimeToAcknowledgeMinutes__c`      | Number   | `FeedbackKpiService`               | Same event, minutes from `CreatedDate`        |
| `WorkStartedAt__c`                 | DateTime | `FeedbackKpiService`               | First time `Status__c` is `In Progress` / `Dev In-Progress` |
| `TimeToStartMinutes__c`            | Number   | `FeedbackKpiService`               | Same event, minutes from `AcknowledgedAt__c`  |
| `ResolvedAt__c`                    | DateTime | `FeedbackKpiService`               | First time `Status__c` is `Resolved` / `UAT Complete` |
| `TimeToResolveHours__c`            | Number   | `FeedbackKpiService`               | Same event, hours from `CreatedDate`          |

Trigger: `FeedbackTrigger` (before insert + before update) -> `FeedbackKpiService`.
No extra DML; values are written in the same transaction as the edit.

### Reports you can build now

1. **Triage speed** - avg `TimeToAcknowledgeMinutes__c` by project/sprint (excluding born-assigned).
2. **Queue wait** - avg `TimeToStartMinutes__c` - signals capacity starvation vs triage issues.
3. **Active cycle** - diff between `ResolvedAt__c` and `WorkStartedAt__c` in a report - the raw resolution speed once work actually starts.
4. **Total cycle** - avg `TimeToResolveHours__c` by type/persona.
5. **Slack delivery reliability** - count where `FirstSlackPostAt__c` is not null / total records created as `New`.
6. **Reopen rate** - `Reopened` count / resolved count.
7. **AI usefulness rate** - `Useful` vs `Not Useful` by reviewer (manual tagging or picklist to add later).

### Why three signals instead of one

Managers can now answer three different operational questions with separate numbers:

- *"Are we slow to triage?"* -> high `TimeToAcknowledgeMinutes__c`.
- *"Do we have enough hands?"* -> high `TimeToStartMinutes__c` (items claimed but sitting in queue).
- *"Are we slow once we start?"* -> resolved minus work-started gap.

This is the distinction between "we need a better process" and "we need more people", which a single time-to-resolve number would hide.

### ROI estimate

`Savings = (minutes saved per feedback / 60) * monthly feedback volume * loaded hourly rate`

`Net value = Savings - (AI usage cost + maintenance effort cost)`

### Pilot baseline checklist

- Measure 2 weeks pre-rollout (no automation) - use existing `CreatedDate`, `LastModifiedDate` as proxies.
- Turn on automation; measure 4 weeks post-rollout using the new KPI fields.
- Compare averages; statistically significant only if monthly volume >= ~50 feedback items.

---

## 9) Governance and Guardrails

- Keep AI output internal (Slack only), not client-visible fields.
- Treat AI suggestion as recommendation, not source of truth.
- Require human approval before code merge.
- Maintain rollback plan and incident logging.
- Review prompt quality and false-positive rate weekly during pilot.

---

## 10) Pilot Plan (30-45 days)

### Scope

- 2-3 projects with meaningful feedback volume
- Same process, same KPI tracking, same review cadence

### Success criteria

- >= 20% reduction in triage-to-assignment time
- >= 65% AI suggestion usefulness
- >= 90% Slack delivery reliability
- Positive net value after operating cost

### No-go criteria

- No measurable cycle-time reduction
- Low volume that cannot justify maintenance
- Unacceptable AI signal quality after tuning

---

## 11) What to Improve Next (if pilot succeeds)

1. Add routing logic by feedback type/persona to specific Slack channels.
2. Add attachment-aware prompting (metadata first, multimodal later).
3. Add strategy-driven reporter config by metadata (default/event/noop patterns).
4. Add dashboard views for KPI monitoring in Salesforce.

