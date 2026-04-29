/*
 * Re-check the most recent Feedback KPI smoke-test record.
 * Run this at any point in the smoke-test sequence to see current state.
 *
 * Execute with:
 *   sf apex run --file scripts/feedback_kpi_recheck.apex -o OrgFarm
 */

List<Feedback__c> rows = [
    SELECT Id, Name, Status__c, CreatedDate, Assigned_To__c,
           SlackMessageTs__c, FirstSlackPostAt__c,
           AcknowledgedAt__c, TimeToAcknowledgeMinutes__c,
           WorkStartedAt__c, TimeToStartMinutes__c,
           ResolvedAt__c, TimeToResolveHours__c
    FROM Feedback__c
    WHERE Issue_Name__c LIKE 'KPI smoke test -%'
    ORDER BY CreatedDate DESC
    LIMIT 1
];

if (rows.isEmpty()) {
    System.debug('No KPI smoke test feedback found. Run feedback_kpi_smoketest.apex first.');
    return;
}

Feedback__c f = rows[0];
System.debug('Latest KPI smoke-test feedback:');
System.debug('  Id                           = ' + f.Id);
System.debug('  Name                         = ' + f.Name);
System.debug('  Status                       = ' + f.Status__c);
System.debug('  CreatedDate                  = ' + f.CreatedDate);
System.debug('  Assigned_To__c               = ' + f.Assigned_To__c);
System.debug('  SlackMessageTs__c            = ' + f.SlackMessageTs__c);
System.debug('  FirstSlackPostAt__c          = ' + f.FirstSlackPostAt__c);
System.debug('  AcknowledgedAt__c            = ' + f.AcknowledgedAt__c);
System.debug('  TimeToAcknowledgeMinutes__c  = ' + f.TimeToAcknowledgeMinutes__c);
System.debug('  WorkStartedAt__c             = ' + f.WorkStartedAt__c);
System.debug('  TimeToStartMinutes__c        = ' + f.TimeToStartMinutes__c);
System.debug('  ResolvedAt__c                = ' + f.ResolvedAt__c);
System.debug('  TimeToResolveHours__c        = ' + f.TimeToResolveHours__c);
