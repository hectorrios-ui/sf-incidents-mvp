public with sharing class OpsIncidentDefaultReporter implements OpsIncidentReporter {
    public Id report(OpsIncidentReportRequest request) {
        OpsIncidentReportRequest req = request == null ? new OpsIncidentReportRequest() : request;

        OpsIncident__c incident = new OpsIncident__c(
            SourceType__c = String.isBlank(req.sourceType) ? 'Apex' : req.sourceType,
            Severity__c = String.isBlank(req.severity) ? 'Medium' : req.severity,
            Status__c = String.isBlank(req.status) ? 'New' : req.status,
            ApexClass__c = req.apexClass,
            FlowApiName__c = req.flowApiName,
            RecordIdContext__c = req.recordIdContext,
            ErrorMessage__c = truncate(req.errorMessage, 32768),
            StackTrace__c = truncate(req.stackTrace, 32768)
        );
        insert incident;

        if (req.enqueueDiagnosis == true) {
            OpsIncidentDiagnosisService.Request dReq = new OpsIncidentDiagnosisService.Request();
            dReq.incidentId = incident.Id;
            OpsIncidentDiagnosisService.diagnose(new List<OpsIncidentDiagnosisService.Request>{ dReq });
        }
        return incident.Id;
    }

    private static String truncate(String value, Integer maxLen) {
        if (value == null || maxLen == null || maxLen <= 0) {
            return value;
        }
        return value.length() > maxLen ? value.substring(0, maxLen) : value;
    }
}
