/*
 * Re-sends the most recent KPI smoke test feedback through FeedbackSlackService
 * directly (bypassing the flow). Use this to verify a channel/webhook wiring
 * after fixing an earlier issue that left records with null SlackMessageTs__c.
 *
 * Execute with:
 *   sf apex run --file scripts/feedback_slack_nudge_latest.apex -o OrgFarm
 */

List<Feedback__c> rows = [
    SELECT Id, SlackMessageTs__c
    FROM Feedback__c
    WHERE Issue_Name__c LIKE 'KPI smoke test -%'
    AND SlackMessageTs__c = null
    ORDER BY CreatedDate DESC
    LIMIT 1
];

if (rows.isEmpty()) {
    System.debug('No unsent KPI smoke test feedback found. Nothing to nudge.');
    return;
}

Feedback__c target = rows[0];
System.debug('Nudging Feedback__c ' + target.Id + ' through FeedbackSlackService...');

FeedbackSlackService.Request req = new FeedbackSlackService.Request();
req.feedbackId = target.Id;
FeedbackSlackService.sendToSlack(new List<FeedbackSlackService.Request>{ req });

System.debug('Queued async Slack send. Run scripts/feedback_kpi_recheck.apex in a few seconds.');
