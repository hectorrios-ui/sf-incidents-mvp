/*
 * Step 3 of the Feedback KPI smoke test: simulates someone starting actual work.
 *
 * Flips the most recent KPI-smoke-test Feedback__c to Status = 'In Progress'
 * to stamp WorkStartedAt__c and TimeToStartMinutes__c (queue wait).
 *
 * Prereq: feedback_kpi_smoketest.apex (and ideally feedback_kpi_assign.apex)
 * already ran, so AcknowledgedAt__c is set.
 *
 * Expected post-run state:
 *   - WorkStartedAt__c        = not null
 *   - TimeToStartMinutes__c   = minutes between Acknowledged and now
 *   - ResolvedAt__c           = null
 *
 * Execute with:
 *   sf apex run --file scripts/feedback_kpi_flip_inprogress.apex -o OrgFarm
 */

List<Feedback__c> rows = [
    SELECT Id, Status__c, AcknowledgedAt__c
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
if (target.Status__c == 'In Progress' || target.Status__c == 'Dev In-Progress') {
    System.debug('Latest feedback ' + target.Id + ' is already in a work-started status (' + target.Status__c + '). Skipping.');
    return;
}
if (target.AcknowledgedAt__c == null) {
    System.debug('Latest feedback ' + target.Id + ' has no Assigned_To__c yet. Run feedback_kpi_assign.apex first for a realistic queue-wait reading.');
}

target.Status__c = 'In Progress';
update target;

System.debug('Flipped ' + target.Id + ' to In Progress. WorkStartedAt__c + TimeToStartMinutes__c should now be stamped.');
System.debug('Re-check with feedback_kpi_recheck.apex, then later run feedback_kpi_flip_resolved.apex.');
