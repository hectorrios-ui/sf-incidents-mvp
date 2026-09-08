# Packaging guide — install UAT Feedback → Slack → Claude in many orgs

You asked for a **managed package**. For a consultancy installing into **many client UAT orgs**, start with an **Unlocked package** (2GP). It installs like a managed package, but:

| | Unlocked (recommended) | Managed |
|--|------------------------|---------|
| Namespace | None | Required (register once) |
| Easy for consultants | Yes | Heavier |
| IP / AppExchange | No | Yes |
| Upgrade clients | Yes (`sf package install`) | Yes |
| First-time setup | Easier | Needs packaging org + namespace |

Use **Managed** later only if you need a namespace or AppExchange listing.

---

## Prerequisites (you need these once)

1. **Dev Hub** enabled on a Salesforce org you control  
   Setup → Dev Hub → Enable  
2. Salesforce CLI logged into that Dev Hub:
   ```bash
   sf org login web -a DevHub
   sf config set target-dev-hub=DevHub
   ```
3. This repo on branch with the MVP cleanup (no Apex LLM).

You do **not** need admin on every client org yet — only Dev Hub to *create* the package. Client installs need a user who can install packages in that org.

---

## Step-by-step: create an Unlocked package (first time)

### 1) Confirm project packaging config
This repo’s `sfdx-project.json` already defines package:

- Name: `UAT Feedback Slack Claude`
- Type: set when you run `sf package create` (Unlocked)
- Path: `force-app`

### 2) Create the package container (once)
```bash
cd ~/sf-incidents-mvp
git pull
sf package create \
  --name "UAT Feedback Slack Claude" \
  --description "UAT Feedback to Slack + Claude handoff" \
  --package-type Unlocked \
  --path force-app \
  --target-dev-hub DevHub
```

This writes a `0Ho...` id into `sfdx-project.json` → `packageAliases`. **Commit that file.**

### 3) Create a version (each release)
```bash
sf package version create \
  --package "UAT Feedback Slack Claude" \
  --installation-key-bypass \
  --wait 30 \
  --code-coverage \
  --target-dev-hub DevHub
```

Wait until status = Success. Note the **04t...** Subscriber Package Version Id (also added to `packageAliases`).

Optional promote (marks as released):
```bash
sf package version promote \
  --package "UAT Feedback Slack Claude@0.1.0-1" \
  --target-dev-hub DevHub
```

### 4) Install into a client / Legend org
```bash
sf org login web -a ClientUAT -r https://test.salesforce.com

sf package install \
  --package "UAT Feedback Slack Claude@0.1.0-1" \
  --target-org ClientUAT \
  --wait 30 \
  --publish-wait 10
```

Or share an install link from Setup in the Dev Hub / partner console once promoted.

### 5) Post-install (every org) — still manual
Package does **not** include Named Credentials (install would fail / secrets can’t ship):

1. **Create Named Credential `Slack_Webhook`**
   - Setup → Named Credentials → New Legacy (or New)
   - Label: `Slack Webhook`
   - Name: `Slack_Webhook`  ← must match exactly
   - URL: your Slack Incoming Webhook URL  
   - Identity Type: Named Principal / Anonymous as your UI allows  
   - Authentication Protocol: **No Authentication**
   - Save
2. Activate Flow **Feedback_Send_Slack_On_New**  
3. Assign permission set **SF Incident MVP**  
4. Create/edit CMDT **Ops Incident Slack Config** Default (Claude user id, project label, auto-analyze)  
5. Invite Claude to that client’s private channel  

---

## Rebuild package after NC exclusion

If install failed on `NamedCredential(Slack_Webhook)`:

```bash
git pull
sf package version create \
  --package "UAT Feedback Slack Claude" \
  --installation-key-bypass \
  --wait 40 \
  --code-coverage \
  --target-dev-hub DevHub
```

Then install the **new** `04t…` version.

## What gets packaged vs excluded

Excluded via `.forceignore` (on purpose):

- `customMetadata/` records (org-specific Claude/Slack settings)  
- Experiment LWCs / Contact flexipage  
- Feedback webLinks that depend on other Slack packages  

Included: Feedback object, Slack service, KPI trigger, Flows, Slack CMDT **types**, MCP invocables, app/tab/permset, Slack_Webhook shell.

---

## If you truly need a Managed package later

1. Register a **namespace** (Partner Developer Edition / Namespace Registry).  
2. Set `"namespace": "yourns"` in `sfdx-project.json`.  
3. Create package with `--package-type Managed`.  
4. Expect more ceremony (subscriber-accessible Apex, package upgrade rules).

Don’t start here for consultancy UAT rollouts.

---

## Helper script

```bash
./scripts/package-version-create.sh DevHub
./scripts/package-install.sh ClientUAT "UAT Feedback Slack Claude@0.1.0-1"
```

---

## Common first-time errors

| Error | Fix |
|-------|-----|
| No default Dev Hub | `sf config set target-dev-hub=DevHub` |
| Code coverage | Ensure tests deploy; use `--code-coverage` |
| Named Credential install | Post-install paste webhook URL |
| Flow inactive | Activate in subscriber org |
| Permission set missing | Assign `SF_incident_MVP` |

---

## Recommended release cadence

1. Build/fix in Legend with source deploy  
2. Cut unlocked package version  
3. Install that version into client UATs  
4. Configure Slack webhook + Claude CMDT per client channel  

That gives you “install in different orgs” without managed-package complexity.
