OpsIncident__c row = new OpsIncident__c(
    SourceType__c = 'Flow',
    ErrorMessage__c = 'System.NullPointerException: Attempt to de-reference a null object',
    FlowApiName__c = 'Demo_Flow'
);

OpsIncidentLlmClient.DiagnosisOutcome out = OpsIncidentLlmClient.tryDiagnose(row);
System.debug('HAS_OUTCOME=' + (out != null));
if (out != null) {
    System.debug('PROPOSED_FIX=' + out.proposedFix);
    System.debug('CONFIDENCE=' + out.confidence);
}
