@IsTest
private class OpsIncidentIntegrationLoggerTest {
    @IsTest
    static void logger_insertsAiAndSlackRows() {
        OpsIncident__c incident = new OpsIncident__c(
            SourceType__c = 'Apex',
            Severity__c = 'Medium',
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'Synthetic test error'
        );
        insert incident;

        Test.startTest();
        OpsIncidentIntegrationLogger.logAi(
            incident.Id,
            'Warning',
            'AI response schema parse failed in test',
            'Anthropic_Messages',
            502
        );
        OpsIncidentIntegrationLogger.logSlack(
            incident.Id,
            'Error',
            'Slack webhook timeout in test',
            504
        );
        Test.stopTest();

        List<OpsIncidentIntegrationLog__c> rows = [
            SELECT Stage__c, Severity__c, Provider__c, HttpStatusCode__c, Detail__c
            FROM OpsIncidentIntegrationLog__c
            WHERE OpsIncident__c = :incident.Id
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(2, rows.size());
        System.assertEquals('AI_Diagnosis', rows[0].Stage__c);
        System.assertEquals('Warning', rows[0].Severity__c);
        System.assertEquals('Anthropic_Messages', rows[0].Provider__c);
        System.assertEquals(502, rows[0].HttpStatusCode__c);
        System.assert(rows[0].Detail__c.contains('schema parse'));
        System.assertEquals('Slack_Delivery', rows[1].Stage__c);
        System.assertEquals('Error', rows[1].Severity__c);
        System.assertEquals('Slack', rows[1].Provider__c);
        System.assertEquals(504, rows[1].HttpStatusCode__c);
    }
}
