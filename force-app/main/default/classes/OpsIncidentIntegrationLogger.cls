public with sharing class OpsIncidentIntegrationLogger {
    public static void logAi(Id incidentId, String severity, String detail, String provider, Integer httpStatusCode) {
        log(incidentId, 'AI_Diagnosis', severity, detail, provider, httpStatusCode);
    }

    public static void logSlack(Id incidentId, String severity, String detail, Integer httpStatusCode) {
        log(incidentId, 'Slack_Delivery', severity, detail, 'Slack', httpStatusCode);
    }

    private static void log(
        Id incidentId,
        String stage,
        String severity,
        String detail,
        String provider,
        Integer httpStatusCode
    ) {
        try {
            OpsIncidentIntegrationLog__c row = new OpsIncidentIntegrationLog__c();
            row.OpsIncident__c = incidentId;
            row.Stage__c = String.isBlank(stage) ? 'AI_Diagnosis' : stage;
            row.Severity__c = String.isBlank(severity) ? 'Error' : severity;
            row.Detail__c = truncate(detail, 32768);
            row.Provider__c = truncate(provider, 80);
            if (httpStatusCode != null) {
                row.HttpStatusCode__c = httpStatusCode;
            }
            insert row;
        } catch (Exception ignored) {
            // Never block incident processing because logging failed.
        }
    }

    private static String truncate(String value, Integer maxLen) {
        if (value == null || maxLen == null || maxLen <= 0) {
            return value;
        }
        return value.length() > maxLen ? value.substring(0, maxLen) : value;
    }
}
