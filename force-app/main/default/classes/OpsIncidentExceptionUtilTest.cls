@IsTest
private class OpsIncidentExceptionUtilTest {
    @IsTest
    static void reportException_createsIncident_withoutDiagnosisQueue() {
        Exception ex;
        try {
            String s = null;
            s.length();
        } catch (Exception caught) {
            ex = caught;
        }

        Test.startTest();
        Id incidentId = OpsIncidentExceptionUtil.reportException(
            ex,
            'OpsIncidentExceptionUtilTest',
            'High',
            null,
            false
        );
        Test.stopTest();

        OpsIncident__c incident = [
            SELECT SourceType__c, Severity__c, Status__c, ApexClass__c, ErrorMessage__c, StackTrace__c
            FROM OpsIncident__c
            WHERE Id = :incidentId
        ];
        System.assertEquals('Apex', incident.SourceType__c);
        System.assertEquals('High', incident.Severity__c);
        System.assert(incident.Status__c == 'New' || incident.Status__c == 'Diagnosed');
        System.assertEquals('OpsIncidentExceptionUtilTest', incident.ApexClass__c);
        System.assert(incident.ErrorMessage__c != null);
    }
}
