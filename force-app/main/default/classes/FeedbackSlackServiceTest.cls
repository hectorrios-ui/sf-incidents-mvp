@IsTest
private class FeedbackSlackServiceTest {
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    private class CapturingMock implements HttpCalloutMock {
        public String capturedBody;
        public HttpResponse respond(HttpRequest req) {
            capturedBody = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    @IsTest
    static void sendToSlack_marksSentOnSuccess() {
        Feedback__c f = new Feedback__c(
            Issue_Name__c = 'Button misalignment',
            Issue_Description__c = 'Button overlaps footer on mobile.',
            Status__c = 'New'
        );
        insert f;

        FeedbackSlackService.Request req = new FeedbackSlackService.Request();
        req.feedbackId = f.Id;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        FeedbackSlackService.sendToSlack(new List<FeedbackSlackService.Request>{ req });
        Test.stopTest();

        Feedback__c updated = [SELECT SlackMessageTs__c FROM Feedback__c WHERE Id = :f.Id];
        System.assertNotEquals(null, updated.SlackMessageTs__c);
        System.assert(updated.SlackMessageTs__c.startsWith('sent:'));
    }

    @IsTest
    static void renderAssignee_returnsNaWhenUnassigned() {
        Feedback__c f = new Feedback__c();
        System.assertEquals('n/a', FeedbackSlackService.renderAssignee(f));
    }

    @IsTest
    static void renderAssignee_returnsNameWhenNoMapping() {
        User u = [SELECT Id, Name, Username FROM User WHERE IsActive = true LIMIT 1];
        Feedback__c f = new Feedback__c(Issue_Name__c = 'x', Status__c = 'New', Assigned_To__c = u.Id);
        insert f;
        f = [SELECT Assigned_To__c, Assigned_To__r.Name, Assigned_To__r.Username FROM Feedback__c WHERE Id = :f.Id];

        FeedbackSlackService.slackIdOverrideByUsername = new Map<String, String>();
        String rendered = FeedbackSlackService.renderAssignee(f);
        System.assertEquals(u.Name, rendered, 'Should fall back to the user full name when no mapping exists.');
    }

    @IsTest
    static void renderAssignee_returnsSlackMentionWhenMapped() {
        User u = [SELECT Id, Name, Username FROM User WHERE IsActive = true LIMIT 1];
        Feedback__c f = new Feedback__c(Issue_Name__c = 'x', Status__c = 'New', Assigned_To__c = u.Id);
        insert f;
        f = [SELECT Assigned_To__c, Assigned_To__r.Name, Assigned_To__r.Username FROM Feedback__c WHERE Id = :f.Id];

        FeedbackSlackService.slackIdOverrideByUsername = new Map<String, String>{
            u.Username => 'U01TESTUSER'
        };
        String rendered = FeedbackSlackService.renderAssignee(f);
        System.assert(rendered.startsWith('<@U01TESTUSER>'), 'Expected Slack mention syntax, got: ' + rendered);
        System.assert(rendered.contains(u.Name), 'Should also include the user name after the mention.');
    }

    @IsTest
    static void recordUrl_containsLightningPathAndId() {
        Feedback__c f = new Feedback__c(Issue_Name__c = 'Link test', Status__c = 'New');
        insert f;
        String url = FeedbackSlackService.recordUrl(f.Id);
        System.assert(url.contains('/lightning/r/Feedback__c/'), 'URL should contain Lightning record path');
        System.assert(url.contains(String.valueOf(f.Id)), 'URL should contain the record Id');
    }

    @IsTest
    static void sendToSlack_payloadContainsSlackLink() {
        Feedback__c f = new Feedback__c(
            Issue_Name__c = 'Nav crash',
            Issue_Description__c = 'Crashes on load.',
            Status__c = 'New'
        );
        insert f;

        FeedbackSlackService.Request req = new FeedbackSlackService.Request();
        req.feedbackId = f.Id;

        CapturingMock mock = new CapturingMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        FeedbackSlackService.sendToSlack(new List<FeedbackSlackService.Request>{ req });
        Test.stopTest();

        System.assertNotEquals(null, mock.capturedBody, 'Payload should have been sent');
        System.assert(mock.capturedBody.contains('/lightning/r/Feedback__c/'),
            'Payload should contain a Lightning record URL');
        // Name is auto-generated (e.g. SF-NNN) — verify the Slack link open-bracket is present
        System.assert(mock.capturedBody.contains('\\u003c') || mock.capturedBody.contains('<'),
            'Payload should use Slack hyperlink syntax');
    }

    @IsTest
    static void sendToSlack_skipsWhenAlreadySent() {
        Feedback__c f = new Feedback__c(
            Issue_Name__c = 'Already delivered',
            Issue_Description__c = 'Second enqueue should be ignored.',
            Status__c = 'In Progress',
            SlackMessageTs__c = 'sent:2025-01-01T00:00:00Z'
        );
        insert f;

        FeedbackSlackService.Request req = new FeedbackSlackService.Request();
        req.feedbackId = f.Id;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        FeedbackSlackService.sendToSlack(new List<FeedbackSlackService.Request>{ req });
        Test.stopTest();

        Feedback__c updated = [SELECT SlackMessageTs__c FROM Feedback__c WHERE Id = :f.Id];
        System.assertEquals('sent:2025-01-01T00:00:00Z', updated.SlackMessageTs__c,
            'Existing SlackMessageTs__c must not be overwritten (dedupe guard).');
    }
}
