/**
 * Invocable: load Feedback__c by Name (SF-NNN) or Id for Claude / MCP agents.
 */
public with sharing class FeedbackMcpGetAction {
    public class Request {
        @InvocableVariable(required=false label='Feedback Name' description='Auto-number Name, e.g. SF-017')
        public String feedbackName;

        @InvocableVariable(required=false label='Feedback Id')
        public Id feedbackId;
    }

    public class Result {
        @InvocableVariable(label='Found')
        public Boolean found;

        @InvocableVariable(label='Summary JSON')
        public String summaryJson;

        @InvocableVariable(label='Record Id')
        public Id feedbackId;

        @InvocableVariable(label='Name')
        public String name;
    }

    @InvocableMethod(
        label='Get Feedback For MCP'
        description='Load a Feedback__c record by Name (SF-NNN) or Id and return a JSON summary for AI agents.'
        category='UAT Feedback'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null) {
            return results;
        }
        for (Request req : requests) {
            results.add(loadOne(req));
        }
        return results;
    }

    private static Result loadOne(Request req) {
        Result out = new Result();
        out.found = false;
        Feedback__c row = findFeedback(req != null ? req.feedbackId : null, req != null ? req.feedbackName : null);
        if (row == null) {
            out.summaryJson = JSON.serialize(new Map<String, Object>{
                'found' => false,
                'error' => 'Feedback not found. Pass feedbackName (e.g. SF-017) or feedbackId.'
            });
            return out;
        }
        out.found = true;
        out.feedbackId = row.Id;
        out.name = row.Name;
        out.summaryJson = JSON.serialize(toSummary(row));
        return out;
    }

    public static Feedback__c findFeedback(Id feedbackId, String feedbackName) {
        if (feedbackId != null) {
            List<Feedback__c> byId = [
                SELECT Id, Name, Issue_Name__c, Issue_Description__c, Status__c, Type__c, Persona__c,
                       Assigned_To__c, Assigned_To__r.Name, Assigned_To__r.Username,
                       Link_To_Record__c, Solution__c, SlackMessageTs__c,
                       CreatedDate, LastModifiedDate
                FROM Feedback__c
                WHERE Id = :feedbackId
                LIMIT 1
            ];
            return byId.isEmpty() ? null : byId[0];
        }
        if (String.isNotBlank(feedbackName)) {
            String name = feedbackName.trim();
            List<Feedback__c> byName = [
                SELECT Id, Name, Issue_Name__c, Issue_Description__c, Status__c, Type__c, Persona__c,
                       Assigned_To__c, Assigned_To__r.Name, Assigned_To__r.Username,
                       Link_To_Record__c, Solution__c, SlackMessageTs__c,
                       CreatedDate, LastModifiedDate
                FROM Feedback__c
                WHERE Name = :name
                LIMIT 1
            ];
            return byName.isEmpty() ? null : byName[0];
        }
        return null;
    }

    @TestVisible
    private static Map<String, Object> toSummary(Feedback__c row) {
        return new Map<String, Object>{
            'found' => true,
            'id' => row.Id,
            'name' => row.Name,
            'issueName' => row.Issue_Name__c,
            'status' => row.Status__c,
            'type' => row.Type__c,
            'persona' => row.Persona__c,
            'assignedToId' => row.Assigned_To__c,
            'assignedToName' => row.Assigned_To__r != null ? row.Assigned_To__r.Name : null,
            'linkToRecord' => row.Link_To_Record__c,
            'solution' => row.Solution__c,
            'slackMessageTs' => row.SlackMessageTs__c,
            'issueDescription' => row.Issue_Description__c,
            'createdDate' => row.CreatedDate,
            'lastModifiedDate' => row.LastModifiedDate,
            'recordUrl' => URL.getOrgDomainUrl().toExternalForm()
                + '/lightning/r/Feedback__c/' + row.Id + '/view'
        };
    }
}
