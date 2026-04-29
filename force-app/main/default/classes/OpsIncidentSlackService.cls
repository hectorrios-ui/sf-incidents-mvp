public with sharing class OpsIncidentSlackService {
    private static final String DEFAULT_NC = 'Slack_Webhook';

    /**
     * Named Credential API name from Custom Metadata (record DeveloperName = Default).
     * Per project: change Ops_Incident_Slack_Config.Default → Slack_Named_Credential__c.
     */
    private static String resolveCalloutEndpoint() {
        Ops_Incident_Slack_Config__mdt row = Ops_Incident_Slack_Config__mdt.getInstance('Default');
        String apiName =
            (row != null && String.isNotBlank(row.Slack_Named_Credential__c))
                ? row.Slack_Named_Credential__c.trim()
                : DEFAULT_NC;
        return 'callout:' + apiName;
    }

    public class Request {
        @InvocableVariable(required=true label='Ops Incident Id')
        public Id incidentId;
    }

    @InvocableMethod(label='Send Ops Incident To Slack' description='Posts an OpsIncident__c alert to Slack via incoming webhook.')
    public static void sendToSlack(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        List<Id> incidentIds = new List<Id>();
        for (Request req : requests) {
            if (req != null && req.incidentId != null) {
                incidentIds.add(req.incidentId);
            }
        }
        if (!incidentIds.isEmpty()) {
            sendToSlackAsync(incidentIds);
        }
    }

    @future(callout=true)
    public static void sendToSlackAsync(List<Id> incidentIds) {
        sendToSlackNow(incidentIds);
    }

    public static void sendToSlackNow(List<Id> incidentIds) {
        if (incidentIds == null || incidentIds.isEmpty()) {
            return;
        }

        List<OpsIncident__c> incidents = [
            SELECT Id, Name, SourceType__c, Severity__c, Status__c, ErrorMessage__c, FlowApiName__c, ApexClass__c, RecordIdContext__c, SlackMessageTs__c,
                ProposedFix__c, AIConfidence__c, StackTrace__c
            FROM OpsIncident__c
            WHERE Id IN :incidentIds
        ];

        Http http = new Http();
        List<OpsIncident__c> updates = new List<OpsIncident__c>();

        for (OpsIncident__c incident : incidents) {
            // Safety guard: do not send duplicate notifications once marked as sent.
            if (String.isNotBlank(incident.SlackMessageTs__c)) {
                continue;
            }
            // Avoid premature posts from the flow transaction before async diagnosis finishes.
            if (incident.Status__c != 'Diagnosed' || String.isBlank(incident.ProposedFix__c)) {
                continue;
            }
            HttpRequest req = new HttpRequest();
            req.setEndpoint(resolveCalloutEndpoint());
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            req.setBody(buildPayload(incident));

            OpsIncident__c toUpdate = new OpsIncident__c(Id = incident.Id);
            try {
                HttpResponse res = http.send(req);
                if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                    toUpdate.SlackMessageTs__c = 'sent:' + Datetime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
                } else {
                    OpsIncidentIntegrationLogger.logSlack(
                        incident.Id,
                        'Error',
                        'Slack delivery failed. HTTP ' + res.getStatusCode() + ' - ' + truncate(res.getBody(), 1000),
                        res.getStatusCode()
                    );
                    toUpdate.StackTrace__c = appendSlackDeliveryNote(incident.StackTrace__c, 'Slack delivery failed. HTTP ' + res.getStatusCode() + ' - ' + truncate(res.getBody(), 1000));
                }
            } catch (Exception ex) {
                OpsIncidentIntegrationLogger.logSlack(
                    incident.Id,
                    'Error',
                    'Slack delivery exception: ' + truncate(ex.getMessage(), 1000),
                    null
                );
                toUpdate.StackTrace__c = appendSlackDeliveryNote(incident.StackTrace__c, 'Slack delivery exception: ' + truncate(ex.getMessage(), 1000));
            }
            updates.add(toUpdate);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static String buildPayload(OpsIncident__c i) {
        String title = ':rotating_light: *Ops Incident* ' + safe(i.Name) + ' (' + safe(i.Severity__c) + ')';
        String details =
            '*Source:* ' + safe(i.SourceType__c) + '\n' +
            '*Status:* ' + safe(i.Status__c) + '\n' +
            '*Flow:* ' + safe(i.FlowApiName__c) + '\n' +
            '*Apex:* ' + safe(i.ApexClass__c) + '\n' +
            '*Record Context:* ' + safe(i.RecordIdContext__c);
        String err = '*Error:*\n```' + safe(truncate(i.ErrorMessage__c, 1200)) + '```';
        String fix = '*Proposed fix (rule-based):*\n' + safe(truncate(i.ProposedFix__c, 1500));
        String conf =
            '*AI confidence:* ' +
            (i.AIConfidence__c != null ? String.valueOf((i.AIConfidence__c * 100).setScale(0)) + '%' : 'n/a');

        Map<String, Object> payload = new Map<String, Object>{
            'text' => 'Ops Incident ' + safe(i.Name),
            'blocks' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => title }
                },
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => details }
                },
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => err }
                },
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => fix }
                },
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => conf }
                }
            }
        };
        return JSON.serialize(payload);
    }

    private static String appendSlackDeliveryNote(String existing, String note) {
        String n = truncate(note, 2000);
        if (String.isBlank(existing)) {
            return '[Delivery] ' + n;
        }
        return truncate(existing + '\n[Delivery] ' + n, 32768);
    }

    private static String safe(String value) {
        return String.isBlank(value) ? 'n/a' : value;
    }

    private static String truncate(String value, Integer maxLen) {
        if (value == null || maxLen == null || maxLen <= 0) {
            return value;
        }
        return value.length() > maxLen ? value.substring(0, maxLen) : value;
    }
}
