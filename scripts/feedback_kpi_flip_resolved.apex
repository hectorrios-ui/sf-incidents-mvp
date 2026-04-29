/*
 * Step 3 of the Feedback KPI smoke test.
 *
 * Flips the most recent KPI-smoke-test Feedback__c to Status = 'Resolved'
 * to simulate a human closing the issue after the fix ships.
 *
 * Expected post-run state:
 *   - ResolvedAt__c          = not null (set by FeedbackKpiService)
 *   - TimeToResolveHours__c  = actual hours elapsed since creation
 *   - AcknowledgedAt__c      = unchanged from step 2
 *
 * Run this a while after feedback_kpi_flip_inprogress.apex for a realistic
 * TimeToResolveHours__c reading.
 *
 * Execute with:
 *   sf apex run --file scripts/feedback_kpi_flip_resolved.apex -o OrgFarm
 */

List<Feedback__c> rows = [
    SELECT Id, Status__c
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
if (target.Status__c == 'Resolved' || target.Status__c == 'UAT Complete') {
    System.debug('Latest feedback ' + target.Id + ' is already resolved (' + target.Status__c + '). Skipping.');
    return;
}

target.Status__c = 'Resolved';
update target;

System.debug('Flipped ' + target.Id + ' to Resolved. ResolvedAt__c and TimeToResolveHours__c should now be stamped.');
System.debug('Re-check with feedback_kpi_recheck.apex.');
