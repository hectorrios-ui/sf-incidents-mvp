# Rename map (NF_ refactor)

| Old | New |
|-----|-----|
| `Ops_Incident_Slack_Config__mdt` | `NF_Incident_Slack_Config__mdt` |
| `FeedbackSlackService` | `NF_FeedbackSlackService` |
| `FeedbackSlackServiceTest` | `NF_FeedbackSlackServiceTest` |
| `FeedbackKpiService` | `NF_FeedbackKpiService` |
| `FeedbackKpiServiceTest` | `NF_FeedbackKpiServiceTest` |
| `FeedbackMcpGetAction` | `NF_FeedbackMcpGetAction` |
| `FeedbackMcpUpdateAction` | `NF_FeedbackMcpUpdateAction` |
| `FeedbackMcpActionsTest` | `NF_FeedbackMcpActionsTest` |
| `FeedbackTrigger` | `NF_FeedbackTrigger` |
| `Feedback_Send_Slack_On_New` | `NF_Feedback_Send_Slack_On_New` |

`Feedback__c` object API name unchanged (data + reports stay stable).

## After upgrading package version
1. Activate Flow **NF Feedback Send Slack On New** (old flow name is gone)
2. Re-check CMDT: **NF Incident Slack Config** → Default  
   (recreate Default if upgrade dropped the old Ops_* record — records are not packaged)
3. Perm set still `SF_incident_MVP` (assigns new `NF_*` Apex classes)
