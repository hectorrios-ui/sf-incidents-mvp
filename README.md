# NeuraFlash Accelerator Recommender — POC

> **AI-powered asset discovery built natively in Salesforce.**  
> Surfaces the right NeuraFlash accelerator, at the right moment, for every project — from the Opportunity record and from Agentforce.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Data Model](#data-model)
4. [Scoring Algorithm](#scoring-algorithm)
5. [Components](#components)
6. [Agentforce Integration](#agentforce-integration)
7. [Knowledge Articles](#knowledge-articles)
8. [Setup & Deployment](#setup--deployment)
9. [Seed Data](#seed-data)
10. [Known Limitations & Roadmap](#known-limitations--roadmap)

---

## Overview

The Accelerator Recommender is a Salesforce-native POC that lets NeuraFlash delivery teams instantly discover relevant accelerators for any client engagement. It reads context directly from the Opportunity record (cloud, industry, use case) and ranks all available assets using a multi-signal scoring algorithm — no manual filtering required.

It is surfaced in two places:
- **LWC panel** embedded on the Opportunity Lightning Page
- **Agentforce (Einstein Copilot)** via an invocable Apex action

Both surfaces use the **same scoring engine**, so rankings are consistent regardless of how the team accesses the tool.

---

## Architecture

```
Opportunity Record
      │
      │  NF_Cloud__c, Industry__c, NF_Use_Case__c, Description
      │
      ▼
NF_AcceleratorController.getOpportunityContext()   ← @wire (LWC)
      │
      ▼
NF_AcceleratorController.getRecommendations()      ← called by LWC + NF_AcceleratorRecommendAction
      │
      ├── queryCandidates()          SOQL: all non-deprecated NF_Accelerator__c records
      ├── scoreAndRank()             multi-signal scoring (see below)
      ├── generateEinsteinNarrative() Einstein Prompt Template (falls back to rule-based)
      │
      ▼
RecommendationResponse  →  nF_AR_RecommenderPanel (LWC)
                        →  NF_AcceleratorRecommendAction (Agentforce)
```

---

## Data Model

### `NF_Accelerator__c` (Custom Object)

The core catalog of reusable assets.

| Field | Type | Description |
|---|---|---|
| `Name` | Text | Display name of the accelerator |
| `Description__c` | Long Text Area | What the asset does |
| `Tags__c` | Text | Comma/semicolon-separated keywords used in scoring |
| `Cloud__c` | Multi-Select Picklist | Target Salesforce cloud(s): Service Cloud, Sales Cloud, etc. |
| `Industry__c` | Picklist | Target industry: Healthcare, Financial Services, Cross-Industry, etc. |
| `Source__c` | Picklist | Where it lives: Google Drive, OneDrive, Playg, etc. |
| `Source_URL__c` | URL | Direct link to the asset |
| `Knowledge_Article_URL__c` | URL | Link to the Salesforce Knowledge Article with full docs |
| `Quality_Badge__c` | Picklist | Verified / In Review / Deprecated |
| `Complexity__c` | Picklist | Low / Medium / High |
| `Asset_Owner__c` | Text | Team member responsible for the asset |
| `Last_Updated__c` | Date | Used for recency scoring |
| `Estimated_Hours_Saved__c` | Number | Estimated delivery hours saved per engagement |
| `Use_Count__c` | Number | How many times the asset has been used (drives popularity scoring) |

### `NF_Accelerator_Feedback__c` (Custom Object)

Captures per-user, per-project feedback to personalise future rankings.

| Field | Type | Description |
|---|---|---|
| `Accelerator__c` | Lookup → NF_Accelerator__c | Which asset |
| `Project_Record_Id__c` | Text | Opportunity ID for scoping |
| `Is_Useful__c` | Checkbox | Thumbs up/down |
| `Comments__c` | Long Text Area | Optional notes |
| `Fit_Score_At_Recommendation__c` | Number | Score recorded at the time of recommendation |

### Opportunity Custom Fields

| Field | API Name | Type | Purpose |
|---|---|---|---|
| NF Cloud | `NF_Cloud__c` | Picklist | Primary Salesforce cloud for the engagement |
| Use Case | `NF_Use_Case__c` | Text | Short description of the main use case |

> `Industry__c` is the standard Salesforce Opportunity industry picklist.

---

## Scoring Algorithm

Every `NF_Accelerator__c` record is scored against the project context. The maximum possible raw score is **128 points**, normalised to 0–100%.

| Signal | Max Points | Logic |
|---|---|---|
| **Keyword overlap** | 50 | Tokenises context (cloud + industry + use case + keywords) and asset (tags + description + cloud + industry). Score = (overlap / context tokens) × 50 |
| **Cloud match** | +35 | `acc.Cloud__c` contains `ctx.cloud` (case-insensitive) |
| **Cloud mismatch penalty** | −15 | Asset targets a specific *different* cloud (not Cross/All) |
| **Industry exact match** | +25 | `acc.Industry__c` contains `ctx.industry` |
| **Cross-Industry bonus** | +10 | Asset is Cross-Industry (relevant to any vertical) |
| **Quality badge** | +10 | `Quality_Badge__c == 'Verified'` |
| **Recency** | +5 | `Last_Updated__c` within last 6 months |
| **Popularity** | up to +3 | `min(Use_Count__c, 10) × 0.3` |
| **Feedback penalty** | −20 | Current user previously marked asset as "not useful" for this project |

Scores are normalised: `fitScore = clamp((rawScore / 128) × 100, 0, 100)`

---

## Components

### Apex

| Class | Access | Purpose |
|---|---|---|
| `NF_AcceleratorController` | `@AuraEnabled` | Core controller: context fetch, scoring, search, feedback |
| `NF_AcceleratorRecommendAction` | `@InvocableMethod` | Agentforce invocable action wrapping the controller |

**Key methods in `NF_AcceleratorController`:**

- `getOpportunityContext(Id recordId)` — reads `NF_Cloud__c`, `Industry__c`, `NF_Use_Case__c`, `Description` from the Opportunity. Cacheable.
- `getRecommendations(String recordId, String cloud, String industry, String useCase, String keywords)` — flat-param method (avoids inner-class deserialisation issue in LWC). Returns scored + ranked `RecommendationResponse`.
- `searchAccelerators(String searchTerm, ...)` — SOSL full-text search, then scores results against project context.
- `saveFeedback(...)` — upserts an `NF_Accelerator_Feedback__c` record and increments `Use_Count__c` on positive feedback.

> **Important:** `getRecommendations` accepts **flat String parameters**, not the `ProjectContext` inner class. This is intentional — Salesforce silently nulls all fields when deserialising inner class parameters from LWC `@AuraEnabled` calls. `NF_AcceleratorRecommendAction` still passes a fully built `ProjectContext` object directly to the overloaded method.

### LWC

| Component | Purpose |
|---|---|
| `nF_AR_RecommenderPanel` | Main container. Wires Opportunity context, drives state, handles search/sort/feedback |
| `nF_AR_AcceleratorCard` | Renders a single accelerator card with score ring, tags, CTAs, and feedback buttons |

**`nF_AR_RecommenderPanel` features:**
- Auto-triggers on load if Opportunity has cloud or industry set
- Displays context as read-only pills (not editable inputs — changes belong on the Opp record)
- Shows amber warning if no cloud/industry is set
- Sort by: Best Match (fit score + hours saved tiebreaker) / Most Used / Newest
- Free-text SOSL search with context-aware re-scoring
- Clears search → reverts to ranked recommendations automatically

**`nF_AR_AcceleratorCard` features:**
- Circular fit score indicator
- Quality badge + source badge
- Cloud/Industry/Complexity chips
- Knowledge Article CTA (shown only when `Knowledge_Article_URL__c` is populated)
- External "Open" button via `NavigationMixin` (bypasses Salesforce URL interception)
- Thumbs up/down feedback buttons with optimistic UI update

---

## Agentforce Integration

### How it works

1. The `NF_AcceleratorRecommendAction` Apex class is decorated with `@InvocableMethod`.
2. In Salesforce Setup → Agents → Topics → Actions, the action is registered under the **NF Accelerator Recommender** topic.
3. When a user asks the Agentforce bot *"What accelerators do we have for this project?"*, the agent calls the action with the current record's ID.
4. The action checks if cloud/industry were passed. If not, it **auto-fetches them from the Opportunity record** — ensuring results match the LWC exactly.
5. The action returns:
   - `topRecommendationsSummary` — bullet-point list with scores, fit reasons, and Knowledge Article links
   - `aiNarrative` — 2–3 sentence Einstein-generated narrative
   - `topAssetName`, `topAssetFitScore`, `topAssetUrl` — headline stats
   - `totalMatches`, `estimatedHoursSaved` — aggregate numbers
   - `recommendationsJson` — full JSON array for advanced use

### Context priority

```
User prompt → agent-supplied cloud/industry (highest priority)
     ↓ if blank
Opportunity record fields (NF_Cloud__c, Industry__c)
     ↓ if not an Opportunity
Empty context (base scoring only)
```

### Deploying the GenAI metadata

The `GenAiFunction` metadata type cannot be reliably deployed via CLI as of SF CLI 2.x. Deploy the plugin only:

```bash
sf project deploy start --source-dir force-app/main/default/genAiPlugins -o <alias>
```

Then configure the action manually:
**Setup → Agents → [Your Agent] → Topics → NF Accelerator Recommender → Actions → New Action → Apex → Get Accelerator Recommendations**

---

## Knowledge Articles

Knowledge Articles provide full documentation for each accelerator, surfaced via the "View Knowledge Article" button on each card.

### Creating articles from existing records

Run the anonymous Apex script to bulk-create articles from all `NF_Accelerator__c` records, publish them, and write the URL back to `Knowledge_Article_URL__c`:

```bash
sf apex run --file scripts/apex/create_knowledge_articles.apex -o <alias>
```

**Prerequisites:**
- Lightning Knowledge must be enabled: Setup → Knowledge Settings → Enable Lightning Knowledge
- A custom Rich Text Area field `NF_Accelerator_Body__c` must exist on the Knowledge object

### Article URL format

Articles link to the standard Lightning record URL:
```
/lightning/r/Knowledge__kav/<ArticleId>/view
```

---

## Setup & Deployment

### Prerequisites

- Salesforce org with:
  - Lightning Knowledge enabled
  - Agentforce / Einstein Copilot enabled
  - Einstein Generative AI enabled (for Prompt Template narrative)
- SF CLI v2.124.7+

### Full deployment

```bash
# 1. Authenticate
sf org login web -a <alias>

# 2. Deploy all metadata
sf project deploy start --source-dir force-app/main/default -o <alias>

# 3. Seed accelerator data (via Data Import Wizard or CLI)
#    Import: seed-data/NF_Accelerator__c_seed.csv

# 4. Create Knowledge Articles
sf apex run --file scripts/apex/create_knowledge_articles.apex -o <alias>

# 5. Add page layout fields (manual)
#    Setup → Object Manager → Opportunity → Page Layouts
#    Add: NF Cloud, Use Case

# 6. Add LWC to Opportunity Lightning Page (manual)
#    App Builder → Opportunity Record Page → drag nF_AR_RecommenderPanel

# 7. Configure Agentforce action (manual — see Agentforce Integration above)
```

### Verify deployment

```bash
# Check Apex classes deployed
sf apex list -o <alias>

# Run anonymous Apex smoke test
sf apex run -o <alias> <<'EOF'
NF_AcceleratorController.ProjectContext ctx = new NF_AcceleratorController.ProjectContext();
ctx.cloud = 'Service Cloud';
ctx.industry = 'Healthcare';
NF_AcceleratorController.RecommendationResponse resp = NF_AcceleratorController.getRecommendations(
    '', 'Service Cloud', 'Healthcare', '', ''
);
for (NF_AcceleratorController.AcceleratorResult r : resp.results) {
    System.debug(r.name + ' → ' + r.fitScore + '%');
}
EOF
```

---

## Seed Data

Located at `seed-data/NF_Accelerator__c_seed.csv`. Contains 20 sample accelerators across:

| Cloud | Industries | Quality |
|---|---|---|
| Service Cloud, Sales Cloud, Platform, MuleSoft | Healthcare, Financial Services, Retail, Cross-Industry | 16 Verified, 3 In Review, 1 Deprecated |

Import via: **Setup → Data Import Wizard → Custom Objects → NF_Accelerator__c**

---

## Known Limitations & Roadmap

### Current limitations (POC scope)

| Limitation | Impact | Priority fix |
|---|---|---|
| Asset catalog is manually maintained via CSV | Stale data, no self-service | Admin Lightning App for CRUD on `NF_Accelerator__c` |
| Knowledge Articles created by one-time Apex script | Articles go stale | Flow/Trigger to auto-sync article on record save |
| `GenAiFunction` not CLI-deployable | Manual Setup step required | File Salesforce Known Issue; use Flow wrapper as interim |
| Scoring weights are hardcoded | Requires a deploy to tune | Custom Metadata Type `NF_Scoring_Weight__mdt` |
| Single cloud per Opportunity | Multi-cloud projects under-scored | Change `NF_Cloud__c` to Multi-Select Picklist |
| No admin reporting | Can't see which assets are most recommended | Add Reports + Dashboard for `NF_Accelerator_Feedback__c` |

### Phase 2 vision

- **Self-service asset submission** — any NeuraFlash team member submits a new accelerator via a guided Flow; it gets tagged by Einstein and queued for Verified review
- **Auto-ingestion from Google Drive/Confluence** — webhook or scheduled job detects new assets, creates `NF_Accelerator__c` + Knowledge Article automatically
- **Weight tuning UI** — scoring weights exposed as Custom Metadata, editable from Setup
- **Feedback-driven auto-promotion** — assets with 10+ "useful" votes auto-promote to Verified via a nightly scheduled Apex job
- **Multi-cloud scoring** — pass all selected clouds from a multi-select Opp field
- **Package it** — ship as an unlocked package so any NeuraFlash org can install in under 5 minutes

---

## File Structure

```
force-app/main/default/
├── classes/
│   ├── NF_AcceleratorController.cls          # Core scoring engine
│   └── NF_AcceleratorRecommendAction.cls     # Agentforce invocable action
├── lwc/
│   ├── nF_AR_RecommenderPanel/               # Main panel component
│   └── nF_AR_AcceleratorCard/                # Individual card component
├── objects/
│   ├── NF_Accelerator__c/                    # Catalog object + all fields
│   └── NF_Accelerator_Feedback__c/           # Feedback object + all fields
├── genAiPromptTemplates/
│   └── NF_AcceleratorNarrative/              # Einstein Prompt Template for narrative
└── genAiPlugins/
    └── NF_AcceleratorRecommender/            # Agentforce plugin (topic) metadata

scripts/apex/
└── create_knowledge_articles.apex            # Bulk Knowledge Article creation script

seed-data/
└── NF_Accelerator__c_seed.csv               # 20 sample accelerators
```

---

*Built by NeuraFlash Innovation Lab · POC for internal tooling + client demo purposes*

