/**
 * Diagnosis for OpsIncident__c: optional LLM (Custom Metadata Ops_Incident_AI_Config__mdt) with rule-based fallback.
 */
public with sharing class OpsIncidentDiagnosisService {

    public class Request {
        @InvocableVariable(required=true label='Ops Incident Id')
        public Id incidentId;
    }

    @InvocableMethod(
        label='Diagnose Ops Incident'
        description='Queues async diagnose; Slack notification is handled by a separate Diagnosed-status flow.'
    )
    public static void diagnose(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }
        List<Id> ids = new List<Id>();
        for (Request r : requests) {
            if (r != null && r.incidentId != null) {
                ids.add(r.incidentId);
            }
        }
        if (ids.isEmpty()) {
            return;
        }
        List<OpsIncident__c> eligible = [
            SELECT Id
            FROM OpsIncident__c
            WHERE Id IN :ids
            AND Status__c = 'New'
            AND SlackMessageTs__c = null
        ];
        if (eligible.isEmpty()) {
            return;
        }
        List<Id> eligibleIds = new List<Id>();
        for (OpsIncident__c row : eligible) {
            eligibleIds.add(row.Id);
        }
        System.enqueueJob(new OpsIncidentDiagnoseAndNotifyJob(eligibleIds));
    }

    public static void diagnoseInCurrentTransaction(List<Id> ids) {
        if (ids == null || ids.isEmpty()) {
            return;
        }
        List<OpsIncident__c> rows = [
            SELECT Id, SourceType__c, ErrorMessage__c, StackTrace__c, FlowApiName__c, ApexClass__c
            FROM OpsIncident__c
            WHERE Id IN :ids
        ];

        List<OpsIncident__c> toUpdate = new List<OpsIncident__c>();
        for (OpsIncident__c row : rows) {
            DiagnosisResult d = analyzeWithOptionalLlm(row);
            toUpdate.add(
                new OpsIncident__c(
                    Id = row.Id,
                    ProposedFix__c = d.proposedFix,
                    AIConfidence__c = d.confidence,
                    Status__c = 'Diagnosed'
                )
            );
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private class DiagnosisResult {
        String proposedFix;
        Decimal confidence;
    }

    private static DiagnosisResult analyzeWithOptionalLlm(OpsIncident__c row) {
        OpsIncidentLlmClient.DiagnosisOutcome llm = OpsIncidentLlmClient.tryDiagnose(row);
        if (llm != null && String.isNotBlank(llm.proposedFix)) {
            DiagnosisResult d = new DiagnosisResult();
            d.proposedFix = llm.proposedFix;
            d.confidence = llm.confidence != null ? llm.confidence : 0.55;
            return d;
        }
        return ruleBasedAnalyze(row);
    }

    private static DiagnosisResult ruleBasedAnalyze(OpsIncident__c row) {
        DiagnosisResult out = new DiagnosisResult();
        String combinedText = '';
        if (String.isNotBlank(row.ErrorMessage__c)) {
            combinedText += ' ' + row.ErrorMessage__c;
        }
        if (String.isNotBlank(row.StackTrace__c)) {
            combinedText += ' ' + row.StackTrace__c;
        }
        String lower = combinedText.toLowerCase();
        String src = row.SourceType__c;

        // Encrypted field / LIKE
        if (lower.contains('encrypted') && (lower.contains('like') || lower.contains('operator'))) {
            out.proposedFix =
                'This error often means a filter used LIKE/CONTAINS on an encrypted field. ' +
                'Change filters to exact match (=) for those fields, or remove optional filters that expand to empty LIKE patterns.';
            // Percent fields in Apex: 0.0–1.0 (e.g. 0.85 = 85%)
            out.confidence = 0.85;
            return out;
        }

        // Null / dereference
        if (lower.contains('null pointer') || lower.contains('attempt to de-reference') || lower.contains('de-reference a null')) {
            out.proposedFix =
                'Likely a null value where the Flow/Apex expects a record or field. ' +
                'Add null/default checks, Decision branches for blank inputs, or guard clauses in Apex before dereferencing.';
            out.confidence = 0.75;
            return out;
        }

        // Governor / limits
        if (lower.contains('too many soql') || lower.contains('101') || lower.contains('governor') || lower.contains('heap size')) {
            out.proposedFix =
                'Governor limit hit. Reduce SOQL/DML in loops, bulkify triggers, use collections, or move logic to async/batch.';
            out.confidence = 0.80;
            return out;
        }

        // Flow-specific
        if (src == 'Flow' || (lower.contains('flow') && lower.contains('fault'))) {
            out.proposedFix =
                'Open the Flow in Flow Builder, check the fault path and the element mentioned in the error. ' +
                'Verify Get Records returned rows, required inputs are populated, and user has field/object access.';
            out.confidence = 0.65;
            return out;
        }

        // Apex
        if (src == 'Apex' || String.isNotBlank(row.ApexClass__c)) {
            out.proposedFix =
                'Review the stack trace line numbers in ' + safeName(row.ApexClass__c) +
                '. Add test coverage, null checks, and verify bulk patterns in triggers/handlers.';
            out.confidence = 0.60;
            return out;
        }

        // Validation / duplicate
        if (lower.contains('validation') && lower.contains('rule')) {
            out.proposedFix = 'Inspect the Validation Rule on the object; adjust criteria or error message, or fix upstream data.';
            out.confidence = 0.70;
            return out;
        }
        if (lower.contains('duplicate') && lower.contains('rule')) {
            out.proposedFix = 'Review Duplicate Rules and matching conditions; dedupe key or bypass for system/integration user if appropriate.';
            out.confidence = 0.65;
            return out;
        }

        // Default
        out.proposedFix =
            'Collect full debug log or Flow fault path. Reproduce in sandbox, then narrow to the failing element or line. ' +
            'If this repeats, add structured logging (custom object or Platform Event) at the failure point.';
        out.confidence = 0.35;
        return out;
    }

    private static String safeName(String s) {
        return String.isBlank(s) ? 'the listed Apex class' : s;
    }
}
