# Pitch + request: Salesforce UAT Feedback ↔ Claude in Slack

**Audience:** Delivery lead / Slack admin / Salesforce admin  
**From:** Salesforce developer  
**Goal:** Approve a small, scoped MVP that turns UAT Feedback into Slack-native triage with Claude — without Apex calling OpenAI/Anthropic.

---

## 1) The pitch (30 seconds)

UAT Feedback already lives in Salesforce. The team already collaborates in Slack. Claude already sits in Slack.

**Today’s gap:** Claude only sees a text snippet (and often guesses). Screenshots pasted into Feedback never reach Slack. Org edition/context is easy to get wrong across many client sandboxes.

**Proposal:** Keep Salesforce as system of record. Post rich Slack alerts (facts + org context + auto-@Claude). Next increment: (a) connect Claude in Slack to the org via Salesforce Hosted MCP, and (b) forward Feedback screenshots into the thread automatically.

**Operating model for consultancy:**  
`1 private Slack channel ↔ 1 client UAT sandbox ↔ same Claude Slack agent`

No Claude Desktop required for the delivery team. No per-developer API keys in Apex.

---

## 2) Why this beats “Apex calls an LLM”

| Old approach | New approach |
|--------------|--------------|
| Named Credential + API keys in every org | Claude in Slack (company standard) |
| Silent callout failures / token pain | Collaboration where humans already are |
| Suggestion frozen at insert time | Thread can iterate with screenshots + org tools |
| Extra integration to maintain | One less Apex integration point |

---

## 3) Formal request — please approve

I am requesting approval to continue / operationalize this MVP with light admin support.

### Ask from **Salesforce Admin**
1. Keep Hosted **MCP Servers** activatable on UAT orgs (when we roll client-by-client).  
2. Create/maintain an **External Client App** with `mcp_api` for Claude in Slack (not Claude Code).  
3. Confirm Feedback package + `SF_incident_MVP` permission set can be assigned to integration/triage users.

### Ask from **Slack / Claude workspace Admin**
1. Confirm **Claude in Slack** may be invited to private client UAT channels.  
2. Connect **Salesforce Hosted MCP** to the Claude Slack bot (workspace-level).  
3. Confirm Claude Slack app can **read files/images** in those channels.  
4. Approve a Slack **Bot token** app (or extend existing) with `chat:write` + `files:write` so Salesforce can upload Feedback screenshots into the thread (next build).

### Ask from **Delivery lead**
1. Endorse the **1 channel : 1 UAT sandbox** rule for client isolation.  
2. Allow a 1–2 client pilot.  
3. Approve next engineering slice: **Feedback image → Slack thread**.

### What I will own as developer
- Package maintain / deploy (without overwriting org CMDT config)  
- Slack payload quality (org context, auto-@Claude, Record Id)  
- Image-forwarding Apex + Named Credential wiring  
- Docs + smoke tests per client channel  

### What I will not ask for
- Company-wide Claude Desktop rollout  
- Storing LLM API keys in Salesforce for this use case  
- One shared Slack channel for multiple clients  

---

## 4) MVP scope (in / out)

### In (now / next)
- Feedback capture in Salesforce  
- Slack notification + org context + auto-@Claude  
- KPI timestamps  
- Optional MCP invocable actions (ready when Slack Claude is org-connected)  
- **Next:** push screenshots from Feedback rich text/Files into the Slack thread  

### Out (for now)
- Apex → OpenAI/Anthropic callouts  
- Claude Code / Desktop as the team workflow  
- Auto-merging code without human review  

---

## 5) Success criteria (pilot)

1. New Feedback → Slack in &lt; 1 minute with org context.  
2. Claude wakes without copy-paste.  
3. Screenshot on Feedback appears in the Slack thread (after image slice).  
4. Claude answer cites org facts (edition/sandbox) correctly.  
5. No client-A data in client-B channel.

---

## 6) Suggested reply from leadership

> Approved for pilot on [Client/Channel]. SF Admin + Slack Admin to enable MCP + file scopes. Dev to deliver Feedback→Slack image forwarding next.

---

Thanks — happy to walk through a live demo on Legend / a client UAT channel.
