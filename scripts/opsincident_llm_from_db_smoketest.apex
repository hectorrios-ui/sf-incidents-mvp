OpsIncident__c row = [
    SELECT Id, SourceType__c, ErrorMessage__c, StackTrace__c, FlowApiName__c, ApexClass__c
    FROM OpsIncident__c
    WHERE Id = 'a01gL00000s1613QAA'
];

OpsIncidentLlmClient.DiagnosisOutcome out = OpsIncidentLlmClient.tryDiagnose(row);
System.debug('HAS_OUTCOME=' + (out != null));
if (out != null) {
    System.debug('PROPOSED_FIX=' + out.proposedFix);
    System.debug('CONFIDENCE=' + out.confidence);
}
