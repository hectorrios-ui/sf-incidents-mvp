@IsTest
private class NF_NF_FeedbackSlackServiceTest {
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

        NF_FeedbackSlackService.Request req = new NF_FeedbackSlackService.Request();
        req.feedbackId = f.Id;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        NF_FeedbackSlackService.sendToSlack(new List<NF_FeedbackSlackService.Request>{ req });
        Test.stopTest();

        Feedback__c updated = [SELECT SlackMessageTs__c FROM Feedback__c WHERE Id = :f.Id];
        System.assertNotEquals(null, updated.SlackMessageTs__c);
        System.assert(updated.SlackMessageTs__c.startsWith('sent:'));
    }

    @IsTest
    static void renderAssignee_returnsNaWhenUnassigned() {
        Feedback__c f = new Feedback__c();
        System.assertEquals('n/a', NF_FeedbackSlackService.renderAssignee(f));
    }

    @IsTest
    static void renderAssignee_returnsNameWhenNoMapping() {
        User u = [SELECT Id, Name, Username FROM User WHERE IsActive = true LIMIT 1];
        Feedback__c f = new Feedback__c(Issue_Name__c = 'x', Status__c = 'New', Assigned_To__c = u.Id);
        insert f;
        f = [SELECT Assigned_To__c, Assigned_To__r.Name, Assigned_To__r.Username FROM Feedback__c WHERE Id = :f.Id];

        NF_FeedbackSlackService.slackIdOverrideByUsername = new Map<String, String>();
        String rendered = NF_FeedbackSlackService.renderAssignee(f);
        System.assertEquals(u.Name, rendered, 'Should fall back to the user full name when no mapping exists.');
    }

    @IsTest
    static void renderAssignee_returnsSlackMentionWhenMapped() {
        User u = [SELECT Id, Name, Username FROM User WHERE IsActive = true LIMIT 1];
        Feedback__c f = new Feedback__c(Issue_Name__c = 'x', Status__c = 'New', Assigned_To__c = u.Id);
        insert f;
        f = [SELECT Assigned_To__c, Assigned_To__r.Name, Assigned_To__r.Username FROM Feedback__c WHERE Id = :f.Id];

        NF_FeedbackSlackService.slackIdOverrideByUsername = new Map<String, String>{
            u.Username => 'U01TESTUSER'
        };
        String rendered = NF_FeedbackSlackService.renderAssignee(f);
        System.assert(rendered.startsWith('<@U01TESTUSER>'), 'Expected Slack mention syntax, got: ' + rendered);
        System.assert(rendered.contains(u.Name), 'Should also include the user name after the mention.');
    }

    @IsTest
    static void recordUrl_containsLightningPathAndId() {
        Feedback__c f = new Feedback__c(Issue_Name__c = 'Link test', Status__c = 'New');
        insert f;
        String url = NF_FeedbackSlackService.recordUrl(f.Id);
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

        NF_FeedbackSlackService.Request req = new NF_FeedbackSlackService.Request();
        req.feedbackId = f.Id;

        CapturingMock mock = new CapturingMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        NF_FeedbackSlackService.sendToSlack(new List<NF_FeedbackSlackService.Request>{ req });
        Test.stopTest();

        System.assertNotEquals(null, mock.capturedBody, 'Payload should have been sent');
        System.assert(mock.capturedBody.contains('/lightning/r/Feedback__c/'),
            'Payload should contain a Lightning record URL');
        // Name is auto-generated (e.g. SF-NNN) — verify the Slack link open-bracket is present
        System.assert(mock.capturedBody.contains('\\u003c') || mock.capturedBody.contains('<'),
            'Payload should use Slack hyperlink syntax');
        System.assert(mock.capturedBody.contains(String.valueOf(f.Id)),
            'Payload should include the Salesforce record Id for Claude/MCP handoff');
        System.assert(
            mock.capturedBody.contains('Org Context') || mock.capturedBody.contains('Org Id'),
            'Payload should include org context for Claude accuracy'
        );
        System.assert(
            !mock.capturedBody.contains('Proposed fix (internal AI)'),
            'Apex must not embed AI suggestions; analysis moves to Slack/Claude'
        );
    }

    @IsTest
    static void sendToSlack_autoMentionsClaudeWhenEnabled() {
        Feedback__c f = new Feedback__c(
            Issue_Name__c = 'Auto analyze',
            Issue_Description__c = 'Should wake Claude.',
            Status__c = 'New'
        );
        insert f;

        NF_FeedbackSlackService.slackConfigOverride = new Slack_Config__mdt(
            Auto_Analyze_Enabled__c = true,
            Claude_Slack_User_Id__c = 'U0CLAUDEBOT',
            Slack_Named_Credential__c = 'Slack_Webhook'
        );

        NF_FeedbackSlackService.Request req = new NF_FeedbackSlackService.Request();
        req.feedbackId = f.Id;

        CapturingMock mock = new CapturingMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        NF_FeedbackSlackService.sendToSlack(new List<NF_FeedbackSlackService.Request>{ req });
        Test.stopTest();

        System.assertNotEquals(null, mock.capturedBody);
        System.assert(mock.capturedBody.contains('<@U0CLAUDEBOT>') || mock.capturedBody.contains('\\u003c@U0CLAUDEBOT\\u003e'),
            'Payload should @mention Claude bot. Body=' + mock.capturedBody);
        System.assert(mock.capturedBody.contains('Analyze this UAT Feedback') || mock.capturedBody.contains('Propose a concrete'),
            'Payload should include auto-analyze prompt');
    }

    @IsTest
    static void buildAutoAnalyzeBlock_returnsNullWhenDisabled() {
        NF_FeedbackSlackService.slackConfigOverride = new Slack_Config__mdt(
            Auto_Analyze_Enabled__c = false,
            Claude_Slack_User_Id__c = 'U0CLAUDEBOT'
        );
        System.assertEquals(null, NF_FeedbackSlackService.buildAutoAnalyzeBlock(new Feedback__c()));
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

        NF_FeedbackSlackService.Request req = new NF_FeedbackSlackService.Request();
        req.feedbackId = f.Id;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        NF_FeedbackSlackService.sendToSlack(new List<NF_FeedbackSlackService.Request>{ req });
        Test.stopTest();

        Feedback__c updated = [SELECT SlackMessageTs__c FROM Feedback__c WHERE Id = :f.Id];
        System.assertEquals('sent:2025-01-01T00:00:00Z', updated.SlackMessageTs__c,
            'Existing SlackMessageTs__c must not be overwritten (dedupe guard).');
    }
}
