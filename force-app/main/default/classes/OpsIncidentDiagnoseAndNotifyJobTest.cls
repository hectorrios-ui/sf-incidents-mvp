@IsTest
private class OpsIncidentDiagnoseAndNotifyJobTest {
    @IsTest
    static void execute_updatesIncidentToDiagnosed() {
        OpsIncident__c incident = new OpsIncident__c(
            SourceType__c = 'Flow',
            Severity__c = 'High',
            Status__c = 'New',
            ErrorMessage__c = 'NullPointerException in flow execution'
        );
        insert incident;

        // Keep queueable deterministic in tests by forcing rule-based diagnosis.
        OpsIncidentLlmClient.configOverride = new Ops_Incident_AI_Config__mdt(
            Enabled__c = false
        );
        try {
            Test.startTest();
            System.enqueueJob(new OpsIncidentDiagnoseAndNotifyJob(new List<Id>{ incident.Id }));
            Test.stopTest();
        } finally {
            OpsIncidentLlmClient.clearConfigOverride();
        }

        OpsIncident__c updated = [
            SELECT Status__c, ProposedFix__c, AIConfidence__c
            FROM OpsIncident__c
            WHERE Id = :incident.Id
        ];
        System.assertEquals('Diagnosed', updated.Status__c);
        System.assertNotEquals(null, updated.ProposedFix__c);
        System.assert(updated.AIConfidence__c != null && updated.AIConfidence__c > 0);
    }
}
