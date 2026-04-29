/*
 * Smoke test variant: born-assigned feedback.
 *
 * Creates a single Feedback__c already assigned to the running user. This
 * simulates the "pre-assigned" path used when the UAT lead tags an owner
 * at creation time. AcknowledgedAt__c should be stamped to the creation
 * moment (triage latency = 0).
 *
 * After running, re-check in a few seconds with:
 *   sf apex run --file scripts/feedback_kpi_recheck.apex -o OrgFarm
 *
 * Expected post-run state:
 *   - AcknowledgedAt__c            = not null (near CreatedDate)
 *   - TimeToAcknowledgeMinutes__c  = 0
 *   - WorkStartedAt__c             = null
 *   - ResolvedAt__c                = null
 *   - SlackMessageTs__c            = sent:...  (populated by @future)
 *   - FirstSlackPostAt__c          = not null  (populated by @future)
 */

Feedback__c seed = new Feedback__c(
    Issue_Name__c = 'KPI smoke test - ' + Datetime.now().format('yyyy-MM-dd HH:mm:ss') + ' (pre-assigned)',
    Issue_Description__c =
        '<p><b>Pre-assigned scenario.</b> UAT lead tagged an owner at creation.</p>'
        + '<p>Steps to reproduce: Click New Opportunity, leave Close Date blank, click Save.</p>'
        + '<p>Expected: validation warns inline. Actual: whole page reloads, input lost.</p>',
    Status__c = 'New',
    Assigned_To__c = UserInfo.getUserId()
);
insert seed;

System.debug('Inserted born-assigned Feedback__c ' + seed.Id + ' as New, assigned to ' + UserInfo.getUserName());
System.debug('AcknowledgedAt__c should already be stamped with TimeToAcknowledgeMinutes__c = 0.');
System.debug('Flow will enqueue the async Slack send. Re-check in a few seconds with feedback_kpi_recheck.apex.');
