public with sharing class OpsIncidentExceptionUtil {
    private static OpsIncidentReporter reporter = new OpsIncidentDefaultReporter();

    @TestVisible
    private static void setReporter(OpsIncidentReporter customReporter) {
        reporter = customReporter == null ? new OpsIncidentDefaultReporter() : customReporter;
    }

    public static Id reportException(Exception ex, String apexClassName, String severity, Id recordIdContext) {
        return reportException(ex, apexClassName, severity, recordIdContext, true);
    }

    public static Id reportException(
        Exception ex,
        String apexClassName,
        String severity,
        Id recordIdContext,
        Boolean enqueueDiagnosis
    ) {
        OpsIncidentReportRequest req = new OpsIncidentReportRequest();
        req.sourceType = 'Apex';
        req.severity = String.isBlank(severity) ? 'High' : severity;
        req.status = 'New';
        req.apexClass = apexClassName;
        req.recordIdContext = recordIdContext;
        req.errorMessage = ex == null ? 'Unknown exception' : ex.getMessage();
        req.stackTrace = ex == null ? null : ex.getStackTraceString();
        req.enqueueDiagnosis = enqueueDiagnosis;
        return reporter.report(req);
    }
}
