public class OpsIncidentReportRequest {
    public String sourceType = 'Apex';
    public String severity = 'Medium';
    public String status = 'New';
    public String apexClass;
    public String flowApiName;
    public Id recordIdContext;
    public String errorMessage;
    public String stackTrace;
    public Boolean enqueueDiagnosis = true;
}
