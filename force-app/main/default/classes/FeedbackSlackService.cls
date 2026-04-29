public with sharing class FeedbackSlackService {
    private static final String DEFAULT_NC = 'Slack_Webhook';

    @TestVisible
    private static Map<String, String> slackIdOverrideByUsername;

    public class Request {
        @InvocableVariable(required=true label='Feedback Id')
        public Id feedbackId;
    }

    @InvocableMethod(label='Send Feedback To Slack' description='Posts a Feedback__c alert to Slack via incoming webhook.')
    public static void sendToSlack(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }
        List<Id> ids = new List<Id>();
        for (Request req : requests) {
            if (req != null && req.feedbackId != null) {
                ids.add(req.feedbackId);
            }
        }
        if (!ids.isEmpty()) {
            sendToSlackAsync(ids);
        }
    }

    @future(callout=true)
    public static void sendToSlackAsync(List<Id> feedbackIds) {
        if (feedbackIds == null || feedbackIds.isEmpty()) {
            return;
        }

        List<Feedback__c> rows = [
            SELECT Id, Name, Issue_Name__c, Issue_Description__c, Status__c, Type__c, Persona__c,
                   Assigned_To__c, Assigned_To__r.Name, Assigned_To__r.Username,
                   Link_To_Record__c, SlackMessageTs__c
            FROM Feedback__c
            WHERE Id IN :feedbackIds
        ];

        Http http = new Http();
        List<Feedback__c> updates = new List<Feedback__c>();
        for (Feedback__c row : rows) {
            if (String.isNotBlank(row.SlackMessageTs__c)) {
                continue;
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint(resolveCalloutEndpoint());
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            FeedbackLlmAdvisor.SuggestionOutcome suggestion = FeedbackLlmAdvisor.trySuggest(row);
            req.setBody(buildPayload(row, suggestion));

            try {
                HttpResponse res = http.send(req);
                if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                    Datetime postedAt = Datetime.now();
                    updates.add(new Feedback__c(
                        Id = row.Id,
                        SlackMessageTs__c = 'sent:' + postedAt.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
                        FirstSlackPostAt__c = postedAt
                    ));
                }
            } catch (Exception ex) {
                // Intentionally swallow to keep async notification non-blocking.
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static String resolveCalloutEndpoint() {
        Ops_Incident_Slack_Config__mdt row = Ops_Incident_Slack_Config__mdt.getInstance('Default');
        String apiName =
            (row != null && String.isNotBlank(row.Slack_Named_Credential__c))
                ? row.Slack_Named_Credential__c.trim()
                : DEFAULT_NC;
        return 'callout:' + apiName;
    }

    @TestVisible
    private static String recordUrl(Id recordId) {
        return URL.getOrgDomainUrl().toExternalForm()
            + '/lightning/r/Feedback__c/' + recordId + '/view';
    }

    private static String buildPayload(Feedback__c f, FeedbackLlmAdvisor.SuggestionOutcome suggestion) {
        String nameLink = '<' + recordUrl(f.Id) + '|' + safe(f.Name) + '>';
        String title = ':memo: *UAT Feedback* ' + safe(f.Issue_Name__c) + ' (' + nameLink + ')';
        String descriptionText = stripHtml(f.Issue_Description__c);
        String body =
            '*Status:* ' + safe(f.Status__c) + '\n' +
            '*Type:* ' + safe(f.Type__c) + '\n' +
            '*Persona:* ' + safe(f.Persona__c) + '\n' +
            '*Assigned To:* ' + renderAssignee(f) + '\n' +
            (String.isNotBlank(f.Link_To_Record__c) ? '*Reproducible on record:* ' + f.Link_To_Record__c + '\n' : '') +
            '\n*Issue Description:*\n' + (String.isNotBlank(descriptionText) ? truncate(descriptionText, 1800) : 'n/a');

        List<Object> blocks = new List<Object>{
            new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => title }
            },
            new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => body }
            }
        };

        if (suggestion != null && String.isNotBlank(suggestion.proposedFix)) {
            String suggestionText = '*Proposed fix (internal AI):* ' + truncate(suggestion.proposedFix, 1500);
            String confidenceText = '*AI confidence:* '
                + (suggestion.confidence != null ? String.valueOf((suggestion.confidence * 100).setScale(0)) + '%' : 'n/a');
            blocks.add(new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => suggestionText + '\n' + confidenceText }
            });
        }

        Map<String, Object> payload = new Map<String, Object>{
            'text' => 'UAT Feedback ' + safe(f.Name),
            'blocks' => blocks
        };
        return JSON.serialize(payload);
    }

    @TestVisible
    private static String renderAssignee(Feedback__c f) {
        if (f.Assigned_To__c == null) {
            return 'n/a';
        }
        String name = (f.Assigned_To__r != null && String.isNotBlank(f.Assigned_To__r.Name))
            ? f.Assigned_To__r.Name
            : null;
        String username = (f.Assigned_To__r != null) ? f.Assigned_To__r.Username : null;

        String slackId = lookupSlackUserId(username);
        if (String.isNotBlank(slackId)) {
            return '<@' + slackId + '>' + (String.isNotBlank(name) ? ' (' + name + ')' : '');
        }
        return String.isNotBlank(name) ? name : String.valueOf(f.Assigned_To__c);
    }

    private static String lookupSlackUserId(String username) {
        if (String.isBlank(username)) {
            return null;
        }
        if (slackIdOverrideByUsername != null) {
            return slackIdOverrideByUsername.get(username);
        }
        for (Slack_User_Mapping__mdt row : Slack_User_Mapping__mdt.getAll().values()) {
            if (row.Salesforce_Username__c == username) {
                return row.Slack_User_Id__c;
            }
        }
        return null;
    }

    private static String stripHtml(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        return value
            .replaceAll('<[^>]*>', ' ')
            .replace('&amp;',  '&')
            .replace('&quot;', '"')
            .replace('&#39;',  '\'')
            .replace('&lt;',   '<')
            .replace('&gt;',   '>')
            .replace('&nbsp;', ' ')
            .replaceAll('\\s+', ' ')
            .trim();
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
