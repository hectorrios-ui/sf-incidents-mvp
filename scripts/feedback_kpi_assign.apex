/*
 * Step 2 of the Feedback KPI smoke test: simulates a human claiming the item.
 *
 * Assigns the most recent KPI-smoke-test Feedback__c to the running user.
 * This stamps AcknowledgedAt__c and TimeToAcknowledgeMinutes__c (triage latency).
 *
 * Status is NOT changed in this step, because in real life "someone claimed
 * it" happens before "someone is actively working on it" - the person may
 * still be busy with a prior item.
 *
 * Expected post-run state:
 *   - AcknowledgedAt__c           = not null
 *   - TimeToAcknowledgeMinutes__c = minutes between creation and now
 *   - WorkStartedAt__c            = null
 *   - ResolvedAt__c               = null
 *
 * Execute with:
 *   sf apex run --file scripts/feedback_kpi_assign.apex -o OrgFarm
 */

List<Feedback__c> rows = [
    SELECT Id, Status__c, Assigned_To__c
    FROM Feedback__c
    WHERE Issue_Name__c LIKE 'KPI smoke test -%'
    ORDER BY CreatedDate DESC
    LIMIT 1
];

if (rows.isEmpty()) {
    System.debug('No KPI smoke test feedback found. Run feedback_kpi_smoketest.apex first.');
    return;
}

Feedback__c target = rows[0];
if (target.Assigned_To__c != null) {
    System.debug('Latest feedback ' + target.Id + ' is already assigned. Skipping.');
    return;
}

target.Assigned_To__c = UserInfo.getUserId();
update target;

System.debug('Assigned ' + target.Id + ' to ' + UserInfo.getUserName());
System.debug('AcknowledgedAt__c + TimeToAcknowledgeMinutes__c should now be stamped.');
System.debug('Re-check with feedback_kpi_recheck.apex, then later run feedback_kpi_flip_inprogress.apex.');
