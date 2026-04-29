# Ops Incident Copilot (MVP)

Salesforce + Slack MVP: when an **Ops Incident** is created with **Status = New**, a record-triggered flow **diagnoses** the error (**optional LLM** via `Ops_Incident_AI_Config__mdt`: `OpenAI_Chat` or `Anthropic_Messages`, otherwise rule-based heuristics) and **posts a structured alert to Slack**.

## What ships in this repo

| Component | Purpose |
|-----------|---------|
| `OpsIncident__c` | Incident log (error text, diagnosis, Slack delivery marker) |
| `OpsIncidentDiagnosisService` | Invocable: LLM first (if enabled) else rules; sets `ProposedFix__c`, `AIConfidence__c` (Percent **0.0–1.0** in Apex), `Status__c = Diagnosed` |
| `OpsIncidentLlmClient` | Provider switch by metadata: `OpenAI_Chat` or `Anthropic_Messages`; expects JSON response `{ proposedFix, confidence }` |
| `Ops_Incident_AI_Config__mdt` | **LLM off by default**; set `Enabled__c`, `Named_Credential_Api_Name__c`, `Model__c`, optional path/temperature/tokens |
| `OpsIncidentSlackService` | Invocable + `@future` callout to Slack Incoming Webhook |
| `OpsIncident_Notify_Slack_On_New` | Record-triggered flow: queue async **Diagnose** when `Status = New` and Slack marker is blank |
| `OpsIncident_Send_Slack_On_Diagnosed` | Record-triggered flow: send Slack when `Status = Diagnosed` and `SlackMessageTs__c` is blank |
| `OpsIncidentIntegrationLog__c` | Structured AI/Slack integration logs (HTTP errors, exceptions) for troubleshooting |
| `Ops_Incident_Slack_Config__mdt` | Per-project: **Named Credential API name** used for Slack (default `Slack_Webhook`) |

## One-time Slack setup (per channel)

1. Slack: create or use the **project channel** (one channel per project is fine).
2. Slack app: **Incoming Webhooks** → add webhook to that channel → copy URL.
3. Salesforce **External Credential** (no auth) + **Named Credential** pointing at the webhook URL (or base URL + path pattern your org uses).
4. Permission set: grant your integration user / admins access to the **External Credential principal** (required for callouts).

## Per-project / multi-channel pattern

- **Same Salesforce package** in every org.
- **Different Slack channel per project** = different **Incoming Webhook** + usually a different **Named Credential** (e.g. `Slack_Webhook_ProjectAlpha`).
- Set **`Ops_Incident_Slack_Config.Default`** → field **Slack Named Credential API Name** to the Named Credential’s API name (no `callout:` prefix).

If the field is blank, Apex falls back to `Slack_Webhook`.

## Optional LLM (vendor-agnostic pattern)

Use **Named Credential + Custom Metadata** so the same code works across orgs; only configuration changes.

1. Create a **Named Credential** (e.g. `OpenAI_API`) whose URL is the API base (e.g. `https://api.openai.com`) and attach auth (API key header, OAuth, etc.) via **External Credential**.
2. Open **Custom Metadata Types → Ops Incident AI Config → Default** and set:
   - **LLM Enabled** = true  
   - **Named Credential API Name** = `OpenAI_API` (no `callout:` prefix)  
   - **Model** = your model id (e.g. `gpt-4o-mini`)  
   - **Provider** = `OpenAI_Chat` or `Anthropic_Messages`  
   - **Relative API Path** = `v1/chat/completions` (OpenAI default) or `v1/messages` (Anthropic default)  
   - **Temperature** / **Max Output Tokens** as desired  
3. Grant the running user permission to that External Credential (same pattern as Slack).

If LLM is disabled, misconfigured, or the HTTP call fails, diagnosis **falls back to rule-based** text (no user-facing error).

## Deploy

```bash
sf project deploy start \
  --source-dir force-app/main/default/objects/OpsIncident__c \
  --source-dir force-app/main/default/objects/Ops_Incident_Slack_Config__mdt \
  --source-dir force-app/main/default/objects/Ops_Incident_AI_Config__mdt \
  --source-dir force-app/main/default/customMetadata \
  --source-dir force-app/main/default/classes/OpsIncidentDiagnosisService.cls \
  --source-dir force-app/main/default/classes/OpsIncidentDiagnosisServiceTest.cls \
  --source-dir force-app/main/default/classes/OpsIncidentLlmClient.cls \
  --source-dir force-app/main/default/classes/OpsIncidentLlmClientTest.cls \
  --source-dir force-app/main/default/classes/OpsIncidentSlackService.cls \
  --source-dir force-app/main/default/classes/OpsIncidentSlackServiceTest.cls \
  --source-dir force-app/main/default/flows/OpsIncident_Notify_Slack_On_New.flow-meta.xml \
  --source-dir force-app/main/default/flows/OpsIncident_Send_Slack_On_Diagnosed.flow-meta.xml
```

Then **activate both flows**:
- **Setup → Flows → OpsIncident Notify Slack On New → Activate**
- **Setup → Flows → OpsIncident Send Slack On Diagnosed → Activate**.

## UI setup (manual, once per org)

- **Tab** for `Ops Incident` + add to your Lightning app navigation (optional but recommended).
- **Page layout** for `Ops Incident` with key fields visible (Status, Severity, Error, Proposed Fix, AI Confidence, Slack Message Timestamp).

## How to demo

1. Create **Ops Incident** with **Status = New** and a realistic **Error Message** (e.g. encrypted field + LIKE).
2. After save: **Status** becomes **Diagnosed**, **Proposed Fix** + **AI Confidence** populated.
3. Slack receives a message with error + proposed fix + confidence %.
4. **`SlackMessageTs__c`** is set (`sent:...`).
5. Save again with **Status still New** → **no duplicate Slack** (flow entry + Apex guard).

## Important: Percent field (`AIConfidence__c`)

In Apex, **Percent** fields use **0.0–1.0** (e.g. `0.65` = 65%). Values like `65` cause `NUMBER_OUTSIDE_VALID_RANGE`.

## Next steps (roadmap)

1. **Real sources**: Flow fault path or Apex `try/catch` → `insert new OpsIncident__c(...)`.
2. **Agentforce / other providers**: current providers are `OpenAI_Chat` + `Anthropic_Messages`; add new `Provider__c` values and branches in `OpsIncidentLlmClient` as needed.
3. **Slack actions**: Interactivity URL → Salesforce REST / Platform Event → approve / reject (no auto-deploy to prod without governance).
4. **Observability**: log object or Event Monitoring for failed callouts; retry policy.

## Tests

Run Apex tests in the org or deploy with `--test-level RunSpecifiedTests` and  
`OpsIncidentDiagnosisServiceTest,OpsIncidentLlmClientTest,OpsIncidentSlackServiceTest`.

## Support / troubleshooting

- **No Slack message**: verify Named Credential from `Ops_Incident_Slack_Config__mdt`, principal permission set, and flow **Active**.
- **Duplicate posts**: ensure `SlackMessageTs__c` is populated after first send; do not clear it unless re-notifying intentionally.
- **Flow error on save**: check debug log; common issue is invalid Percent or missing object permissions.
