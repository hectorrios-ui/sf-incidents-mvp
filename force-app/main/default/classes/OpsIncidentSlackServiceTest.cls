@IsTest
private class OpsIncidentSlackServiceTest {
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('internal_error');
            return res;
        }
    }

    @IsTest
    static void sendToSlack_marksSentOnSuccess() {
        OpsIncident__c incident = new OpsIncident__c(
            SourceType__c = 'Flow',
            Severity__c = 'High',
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'Test error',
            ProposedFix__c = 'Apply null checks in flow variables.',
            AIConfidence__c = 0.65
        );
        insert incident;

        OpsIncidentSlackService.Request req = new OpsIncidentSlackService.Request();
        req.incidentId = incident.Id;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        OpsIncidentSlackService.sendToSlack(new List<OpsIncidentSlackService.Request>{ req });
        Test.stopTest();

        OpsIncident__c updated = [SELECT SlackMessageTs__c FROM OpsIncident__c WHERE Id = :incident.Id];
        System.assertNotEquals(null, updated.SlackMessageTs__c, 'Slack timestamp marker should be populated.');
        System.assert(updated.SlackMessageTs__c.startsWith('sent:'), 'Slack timestamp marker should start with sent:');
    }

    @IsTest
    static void sendToSlack_savesFailureMessage() {
        OpsIncident__c incident = new OpsIncident__c(
            SourceType__c = 'Apex',
            Severity__c = 'Critical',
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'Another test error',
            ProposedFix__c = 'Bulkify trigger handler and remove DML in loops.',
            AIConfidence__c = 0.7
        );
        insert incident;

        OpsIncidentSlackService.Request req = new OpsIncidentSlackService.Request();
        req.incidentId = incident.Id;

        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Test.startTest();
        OpsIncidentSlackService.sendToSlack(new List<OpsIncidentSlackService.Request>{ req });
        Test.stopTest();

        OpsIncident__c updated = [SELECT StackTrace__c FROM OpsIncident__c WHERE Id = :incident.Id];
        System.assertNotEquals(null, updated.StackTrace__c, 'Failure details should be captured on Stack Trace.');
        System.assert(updated.StackTrace__c.contains('Slack delivery failed'), 'Failure message should indicate Slack delivery failed.');
    }

    @IsTest
    static void sendToSlack_skipsWhenAlreadySent() {
        OpsIncident__c incident = new OpsIncident__c(
            SourceType__c = 'Flow',
            Severity__c = 'Medium',
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'Should be skipped',
            ProposedFix__c = 'Already posted once.',
            SlackMessageTs__c = 'sent:2026-01-01T00:00:00Z'
        );
        insert incident;

        OpsIncidentSlackService.Request req = new OpsIncidentSlackService.Request();
        req.incidentId = incident.Id;

        Test.startTest();
        OpsIncidentSlackService.sendToSlack(new List<OpsIncidentSlackService.Request>{ req });
        Test.stopTest();

        OpsIncident__c updated = [SELECT SlackMessageTs__c, ProposedFix__c FROM OpsIncident__c WHERE Id = :incident.Id];
        System.assertEquals('sent:2026-01-01T00:00:00Z', updated.SlackMessageTs__c, 'Existing sent marker should remain unchanged.');
        System.assertEquals('Already posted once.', updated.ProposedFix__c, 'Incident fields should remain unchanged when skipped.');
    }

}
