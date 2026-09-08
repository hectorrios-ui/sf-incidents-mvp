@IsTest
private class FeedbackMcpActionsTest {
    @IsTest
    static void getFeedback_byName_returnsSummary() {
        Feedback__c f = new Feedback__c(
            Issue_Name__c = 'Domain setup',
            Issue_Description__c = 'Need custom domain steps.',
            Status__c = 'New'
        );
        insert f;
        f = [SELECT Name FROM Feedback__c WHERE Id = :f.Id];

        FeedbackMcpGetAction.Request req = new FeedbackMcpGetAction.Request();
        req.feedbackName = f.Name;

        Test.startTest();
        List<FeedbackMcpGetAction.Result> results = FeedbackMcpGetAction.execute(
            new List<FeedbackMcpGetAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].found);
        System.assertEquals(f.Id, results[0].feedbackId);
        System.assert(results[0].summaryJson.contains('Domain setup'));
        System.assert(results[0].summaryJson.contains(f.Name));
    }

    @IsTest
    static void getFeedback_missing_returnsNotFound() {
        FeedbackMcpGetAction.Request req = new FeedbackMcpGetAction.Request();
        req.feedbackName = 'SF-DOES-NOT-EXIST';

        List<FeedbackMcpGetAction.Result> results = FeedbackMcpGetAction.execute(
            new List<FeedbackMcpGetAction.Request>{ req }
        );
        System.assertEquals(false, results[0].found);
    }

    @IsTest
    static void updateFeedback_setsSolutionAndStatus() {
        Feedback__c f = new Feedback__c(
            Issue_Name__c = 'Update me',
            Issue_Description__c = 'Body',
            Status__c = 'New'
        );
        insert f;

        FeedbackMcpUpdateAction.Request req = new FeedbackMcpUpdateAction.Request();
        req.feedbackId = f.Id;
        req.status = 'In Progress';
        req.solution = 'Documented custom domain setup in sandbox.';

        Test.startTest();
        List<FeedbackMcpUpdateAction.Result> results = FeedbackMcpUpdateAction.execute(
            new List<FeedbackMcpUpdateAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].success, results[0].message);
        Feedback__c updated = [SELECT Status__c, Solution__c FROM Feedback__c WHERE Id = :f.Id];
        System.assertEquals('In Progress', updated.Status__c);
        System.assertEquals('Documented custom domain setup in sandbox.', updated.Solution__c);
    }
}
