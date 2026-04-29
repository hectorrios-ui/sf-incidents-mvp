List<OpsIncidentIntegrationLog__c> logs = [
    SELECT Id, Stage__c, Severity__c, Provider__c, HttpStatusCode__c, Detail__c, CreatedDate
    FROM OpsIncidentIntegrationLog__c
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('Rows fetched: ' + logs.size());
