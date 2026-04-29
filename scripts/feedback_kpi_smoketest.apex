/*
 * Step 1 of the Feedback KPI smoke test.
 *
 * Creates a single Feedback__c with Status = 'New'. This triggers the
 * record-triggered flow Feedback_Send_Slack_On_New, which enqueues
 * FeedbackSlackService.sendToSlackAsync.
 *
 * Do NOT flip the status in this script. In real life a UAT user does
 * not create and resolve a feedback in the same breath. The follow-up
 * scripts simulate the human actions with natural gaps between them.
 *
 * After running this script, wait ~5-10 seconds and run:
 *   sf apex run --file scripts/feedback_kpi_recheck.apex -o OrgFarm
 *
 * Expected post-run state:
 *   - AcknowledgedAt__c            = null
 *   - ResolvedAt__c                = null
 *   - SlackMessageTs__c            = sent:...  (populated by @future)
 *   - FirstSlackPostAt__c          = not null  (populated by @future)
 */

Feedback__c seed = new Feedback__c(
    Issue_Name__c = 'KPI smoke test - ' + Datetime.now().format('yyyy-MM-dd HH:mm:ss'),
    Issue_Description__c =
        '<p><b>Steps to reproduce:</b></p>'
        + '<ol>'
        + '<li>Open the Case record page as a Service Agent persona.</li>'
        + '<li>Click the "Create Child Case" quick action in the highlights panel.</li>'
        + '<li>Fill Subject and Description, leave Priority blank, click Save.</li>'
        + '</ol>'
        + '<p><b>Expected:</b> Child case is created and linked as ParentId on the new record.</p>'
        + '<p><b>Actual:</b> Save fails with "FIELD_CUSTOM_VALIDATION_EXCEPTION: Priority is required" '
        + 'even though the Priority field is not displayed on the quick action layout. '
        + 'This blocks agents from escalating calls when they cannot see the field.</p>'
        + '<p><b>Environment:</b> UAT sandbox, Lightning Experience, Chrome 124 on macOS.</p>',
    Status__c = 'New'
);
insert seed;

System.debug('Inserted Feedback__c ' + seed.Id + ' as New.');
System.debug('Flow will enqueue the async Slack send. Re-check in a few seconds with feedback_kpi_recheck.apex.');
System.debug('Then run feedback_kpi_flip_inprogress.apex to simulate acknowledgement.');
