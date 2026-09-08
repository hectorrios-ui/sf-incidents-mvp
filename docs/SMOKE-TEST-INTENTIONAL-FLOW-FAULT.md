# Smoke test: intentional Flow fault → Feedback → Claude fix

## Is this reasonable?
Yes. It exercises the real loop:
1. Feedback created → Slack alert (+ @Claude / Org Context)
2. A second Flow faults on purpose
3. You log a Feedback about the fault
4. Claude proposes the concrete fix

## What we planted
Flow: **Feedback Mark In Progress After Slack**

- Trigger: Feedback **updated** when `SlackMessageTs__c` becomes non-null (after Slack send)
- Action: set `Status__c` = `In-Progress`
- **Bug:** valid picklist value is `In Progress` (space), not `In-Progress` (hyphen)
- Element name includes `INTENTIONAL_BUG` so it’s obvious in Setup

## Steps on Legend

```bash
git fetch origin
git checkout cursor/intentional-flow-fault-smoke-test-2c5f
git pull
./scripts/deploy-org.sh Legend
# or: sf project deploy start --source-dir force-app/main/default -o Legend
```

1. Confirm Flow is **Active** (Setup → Flows)
2. Create Feedback: Status = New, clear description of anything
3. Wait for Slack message (and `SlackMessageTs__c` stamped)
4. Open Setup → **Paused and Failed Flow Interviews** (or email/debug log) — you should see a fault on the bad picklist value
5. Create a **new** Feedback item describing the error, e.g.:

> Flow “Feedback Mark In Progress After Slack” fails after Slack is sent.
> Error looks like invalid Status picklist / restricted picklist.
> Expected: Status moves to In Progress after Slack notification.

6. Claude should suggest changing `In-Progress` → `In Progress` in the Flow update element

## After the demo
- Fix the Flow (or deactivate it)
- Don’t leave an intentional fault Active in a client UAT long-term
