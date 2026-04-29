public with sharing class OpsIncidentDiagnoseAndNotifyJob implements Queueable, Database.AllowsCallouts {
    private final List<Id> incidentIds;

    public OpsIncidentDiagnoseAndNotifyJob(List<Id> incidentIds) {
        this.incidentIds = incidentIds == null ? new List<Id>() : incidentIds.clone();
    }

    public void execute(QueueableContext context) {
        if (incidentIds.isEmpty()) {
            return;
        }
        OpsIncidentDiagnosisService.diagnoseInCurrentTransaction(incidentIds);
    }
}
