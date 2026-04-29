@IsTest
private class FeedbackKpiServiceTest {

    private static User pickAnyUser() {
        return [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
    }

    private static Feedback__c insertNewFeedback(Id assignedToId) {
        Feedback__c f = new Feedback__c(
            Issue_Name__c = 'KPI Test Feedback',
            Issue_Description__c = 'Seed feedback for KPI service test.',
            Status__c = 'New',
            Assigned_To__c = assignedToId
        );
        insert f;
        return f;
    }

    // ---- Before insert ----

    @IsTest
    static void born_unassigned_stamps_no_kpis_on_insert() {
        Test.startTest();
        Feedback__c f = insertNewFeedback(null);
        Test.stopTest();

        Feedback__c reloaded = [
            SELECT AcknowledgedAt__c, TimeToAcknowledgeMinutes__c,
                   WorkStartedAt__c, TimeToStartMinutes__c,
                   ResolvedAt__c, TimeToResolveHours__c
            FROM Feedback__c WHERE Id = :f.Id
        ];
        System.assertEquals(null, reloaded.AcknowledgedAt__c);
        System.assertEquals(null, reloaded.TimeToAcknowledgeMinutes__c);
        System.assertEquals(null, reloaded.WorkStartedAt__c);
        System.assertEquals(null, reloaded.ResolvedAt__c);
    }

    @IsTest
    static void born_assigned_stamps_acknowledged_with_zero_latency() {
        User u = pickAnyUser();

        Test.startTest();
        Feedback__c f = insertNewFeedback(u.Id);
        Test.stopTest();

        Feedback__c reloaded = [
            SELECT AcknowledgedAt__c, TimeToAcknowledgeMinutes__c
            FROM Feedback__c WHERE Id = :f.Id
        ];
        System.assertNotEquals(null, reloaded.AcknowledgedAt__c, 'Should stamp AcknowledgedAt on born-assigned insert.');
        System.assertEquals(0, reloaded.TimeToAcknowledgeMinutes__c, 'Born-assigned -> triage latency should be 0.');
    }

    @IsTest
    static void born_in_progress_stamps_work_started_with_zero_wait() {
        User u = pickAnyUser();
        Feedback__c f = new Feedback__c(
            Issue_Name__c = 'Born In Progress',
            Status__c = 'In Progress',
            Assigned_To__c = u.Id
        );

        Test.startTest();
        insert f;
        Test.stopTest();

        Feedback__c reloaded = [
            SELECT AcknowledgedAt__c, TimeToAcknowledgeMinutes__c,
                   WorkStartedAt__c, TimeToStartMinutes__c
            FROM Feedback__c WHERE Id = :f.Id
        ];
        System.assertNotEquals(null, reloaded.AcknowledgedAt__c);
        System.assertEquals(0, reloaded.TimeToAcknowledgeMinutes__c);
        System.assertNotEquals(null, reloaded.WorkStartedAt__c);
        System.assertEquals(0, reloaded.TimeToStartMinutes__c);
    }

    // ---- Before update: Acknowledgement ----

    @IsTest
    static void assigning_user_stamps_acknowledged() {
        Feedback__c f = insertNewFeedback(null);
        User u = pickAnyUser();

        Test.startTest();
        f.Assigned_To__c = u.Id;
        update f;
        Test.stopTest();

        Feedback__c reloaded = [
            SELECT AcknowledgedAt__c, TimeToAcknowledgeMinutes__c
            FROM Feedback__c WHERE Id = :f.Id
        ];
        System.assertNotEquals(null, reloaded.AcknowledgedAt__c);
        System.assert(reloaded.TimeToAcknowledgeMinutes__c != null && reloaded.TimeToAcknowledgeMinutes__c >= 0);
    }

    @IsTest
    static void reassigning_user_does_not_restamp_acknowledged() {
        User u1 = pickAnyUser();
        Feedback__c f = insertNewFeedback(u1.Id);
        Datetime firstAck = [SELECT AcknowledgedAt__c FROM Feedback__c WHERE Id = :f.Id].AcknowledgedAt__c;

        Test.startTest();
        f.Assigned_To__c = null;
        update f;
        f.Assigned_To__c = u1.Id;
        update f;
        Test.stopTest();

        Datetime secondAck = [SELECT AcknowledgedAt__c FROM Feedback__c WHERE Id = :f.Id].AcknowledgedAt__c;
        System.assertEquals(firstAck, secondAck, 'AcknowledgedAt must not be overwritten after first claim.');
    }

    @IsTest
    static void status_change_alone_does_not_acknowledge() {
        Feedback__c f = insertNewFeedback(null);

        Test.startTest();
        f.Status__c = 'In Progress';
        update f;
        Test.stopTest();

        Feedback__c reloaded = [
            SELECT AcknowledgedAt__c, WorkStartedAt__c
            FROM Feedback__c WHERE Id = :f.Id
        ];
        System.assertEquals(null, reloaded.AcknowledgedAt__c, 'Status change without assignee must NOT stamp Acknowledged.');
        System.assertNotEquals(null, reloaded.WorkStartedAt__c, 'WorkStartedAt should still be stamped on status change.');
    }

    // ---- Before update: Work started ----

    @IsTest
    static void moving_to_in_progress_stamps_work_started() {
        User u = pickAnyUser();
        Feedback__c f = insertNewFeedback(u.Id);

        Test.startTest();
        f.Status__c = 'In Progress';
        update f;
        Test.stopTest();

        Feedback__c reloaded = [
            SELECT WorkStartedAt__c, TimeToStartMinutes__c, AcknowledgedAt__c
            FROM Feedback__c WHERE Id = :f.Id
        ];
        System.assertNotEquals(null, reloaded.WorkStartedAt__c);
        System.assertNotEquals(null, reloaded.TimeToStartMinutes__c);
        System.assert(reloaded.TimeToStartMinutes__c >= 0);
    }

    @IsTest
    static void moving_to_dev_in_progress_also_stamps_work_started() {
        User u = pickAnyUser();
        Feedback__c f = insertNewFeedback(u.Id);

        Test.startTest();
        f.Status__c = 'Dev In-Progress';
        update f;
        Test.stopTest();

        Feedback__c reloaded = [SELECT WorkStartedAt__c FROM Feedback__c WHERE Id = :f.Id];
        System.assertNotEquals(null, reloaded.WorkStartedAt__c);
    }

    @IsTest
    static void work_started_not_restamped_when_bouncing_statuses() {
        User u = pickAnyUser();
        Feedback__c f = insertNewFeedback(u.Id);
        f.Status__c = 'In Progress';
        update f;
        Datetime firstStart = [SELECT WorkStartedAt__c FROM Feedback__c WHERE Id = :f.Id].WorkStartedAt__c;

        Test.startTest();
        f.Status__c = 'Blocked';
        update f;
        f.Status__c = 'In Progress';
        update f;
        Test.stopTest();

        Datetime secondStart = [SELECT WorkStartedAt__c FROM Feedback__c WHERE Id = :f.Id].WorkStartedAt__c;
        System.assertEquals(firstStart, secondStart, 'WorkStartedAt must not be overwritten on later transitions.');
    }

    // ---- Before update: Resolved ----

    @IsTest
    static void moving_to_resolved_stamps_resolved() {
        User u = pickAnyUser();
        Feedback__c f = insertNewFeedback(u.Id);
        f.Status__c = 'In Progress';
        update f;

        Test.startTest();
        f.Status__c = 'Resolved';
        update f;
        Test.stopTest();

        Feedback__c reloaded = [
            SELECT ResolvedAt__c, TimeToResolveHours__c
            FROM Feedback__c WHERE Id = :f.Id
        ];
        System.assertNotEquals(null, reloaded.ResolvedAt__c);
        System.assertNotEquals(null, reloaded.TimeToResolveHours__c);
    }

    @IsTest
    static void moving_to_uat_complete_also_counts_as_resolved() {
        Feedback__c f = insertNewFeedback(null);
        f.Status__c = 'Ready for UAT';
        update f;

        Test.startTest();
        f.Status__c = 'UAT Complete';
        update f;
        Test.stopTest();

        Feedback__c reloaded = [SELECT ResolvedAt__c FROM Feedback__c WHERE Id = :f.Id];
        System.assertNotEquals(null, reloaded.ResolvedAt__c);
    }

    @IsTest
    static void does_nothing_when_nothing_relevant_changes() {
        Feedback__c f = insertNewFeedback(null);

        Test.startTest();
        f.Issue_Description__c = 'Minor edit only.';
        update f;
        Test.stopTest();

        Feedback__c reloaded = [
            SELECT AcknowledgedAt__c, WorkStartedAt__c, ResolvedAt__c
            FROM Feedback__c WHERE Id = :f.Id
        ];
        System.assertEquals(null, reloaded.AcknowledgedAt__c);
        System.assertEquals(null, reloaded.WorkStartedAt__c);
        System.assertEquals(null, reloaded.ResolvedAt__c);
    }
}
