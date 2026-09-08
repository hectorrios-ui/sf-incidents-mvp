# Phase 3 — Salesforce MCP for UAT Feedback

Connect Claude / Cursor to the **Legend** sandbox so agents can read and update `Feedback__c` without copy-paste from Slack alone.

## Two paths (pick one to start)

| Path | Best for | Effort |
|------|----------|--------|
| **A. Salesforce DX MCP** (`@salesforce/mcp`) | Cursor + Claude Code with local SF CLI | Fast (minutes) |
| **B. Salesforce Hosted MCP** | Claude Desktop / Slack Claude with OAuth | Admin setup in org |

Start with **Path A** if you already deploy to Legend from your Mac.

---

## Path A — Salesforce DX MCP (recommended first)

### Prerequisites
```bash
sf org list
# Legend must appear as an authenticated org alias
sf org display -o Legend
```

If missing:
```bash
sf org login web -a Legend -r https://test.salesforce.com
```

### Project config (already in this branch)
This repo includes `.mcp.json` pointing DX MCP at alias `Legend`.

### Cursor
1. Open this project in Cursor  
2. Cursor Settings → MCP → ensure project `.mcp.json` is loaded  
3. Restart MCP / Cursor if needed  

### Claude Code
```bash
cd ~/sf-incidents-mvp
# .mcp.json is already here — open a Claude Code session in this folder
claude
# then /mcp to verify Salesforce DX (Legend) is connected
```

### Try it
In Cursor or Claude Code:

```text
Using Salesforce DX MCP against Legend, query Feedback__c where Name = 'SF-017'
and summarize Status, Issue_Name__c, Issue_Description__c, and Solution__c.
```

Or:

```text
Run SOQL:
SELECT Id, Name, Status__c, Issue_Name__c, Issue_Description__c
FROM Feedback__c
WHERE Status__c = 'New'
ORDER BY CreatedDate DESC
LIMIT 10
```

---

## Path B — Salesforce Hosted MCP Servers

Use this when Claude (Desktop / enterprise) should talk to Legend over OAuth without local SF CLI.

Docs: [Connect Claude with Salesforce Hosted MCP Servers](https://developer.salesforce.com/blogs/2026/05/connect-claude-with-salesforce-hosted-mcp-servers)

### 1) Activate hosted servers (Legend)
1. Setup → search **MCP Servers**
2. **Salesforce Servers** tab
3. Activate servers you need (at least SObject / data access)
4. Copy each **Server URL** (sandbox URLs differ from prod)

### 2) External Client App
1. Setup → **External Client App Manager** → New  
2. Enable OAuth  
3. Callback URL:
   - Claude Desktop: `https://claude.ai/api/mcp/auth_callback`
   - Claude Code: `http://localhost:38000/callback`
4. Scopes:
   - `refresh_token` / `offline_access`
   - `mcp_api` (Access Salesforce Hosted MCP Servers)
5. Security: enable PKCE; typically uncheck “Require secret for Web Server / Refresh Token Flow” per Salesforce Claude guide
6. Copy Consumer Key (+ Secret if required)

### 3) Connect Claude Code
```bash
claude mcp add --transport http salesforce-sobject-all "PASTE_SERVER_URL" \
  --callback-port 38000 \
  --client-id "PASTE_CONSUMER_KEY" \
  --client-secret
```

Then in Claude: `/mcp` → authenticate.

### 4) Expose Feedback-specific tools (this package)
This branch deploys two Invocable Apex actions you can register as **custom hosted MCP tools**:

| Invocable label | Class | Purpose |
|-----------------|-------|---------|
| Get Feedback For MCP | `NF_FeedbackMcpGetAction` | Load Feedback by `SF-017` or Id → JSON summary |
| Update Feedback From MCP | `NF_FeedbackMcpUpdateAction` | Update Status / Solution / Assigned To |

Setup → MCP Servers → create/configure a **custom** server → add Apex Action tools → select those invocables.

After that, Claude can call tools by name instead of inventing SOQL.

---

## Deploy Apex MCP actions to Legend

```bash
git fetch origin
git checkout cursor/salesforce-mcp-phase3-2c5f
git pull

sf project deploy start --source-dir force-app/main/default -o Legend
sf org assign permset -n SF_incident_MVP -o Legend
```

---

## End-to-end loop (target UX)

```text
Feedback created in Legend
  → Slack alert (+ auto @Claude)
  → Claude uses MCP: Get Feedback For MCP (SF-017)
  → Claude proposes fix in thread
  → Human approves
  → Cursor implements + PR
  → Claude uses MCP: Update Feedback From MCP (Status=In Progress, Solution=...)
```

### Sample prompts

**Analyze**
```text
Get Feedback SF-017 from Legend via MCP. Propose a concrete fix and list metadata to change.
```

**Close the loop**
```text
Update Feedback SF-017: Status = In Progress, Solution = "<short note + PR link>".
```

---

## Security notes
- MCP uses the authenticated user’s Salesforce permissions (`SF_incident_MVP` required for Feedback access).
- Prefer Hosted MCP + ECA for shared team Claude; prefer DX MCP for individual developers with local org auth.
- Do not commit Consumer Secrets or API keys.

## What’s next (Phase 4)
- Standardize PR link writeback into `Solution__c`
- Optional Slack Workflow if Claude emoji-only replies continue
- KPI dashboard on triage cycle time
