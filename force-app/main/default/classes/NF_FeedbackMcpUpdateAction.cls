/**
 * Invocable: update Feedback__c Status / Solution / Assigned To for Claude / MCP agents.
 */
public with sharing class NF_FeedbackMcpUpdateAction {
    public class Request {
        @InvocableVariable(required=false label='Feedback Name')
        public String feedbackName;

        @InvocableVariable(required=false label='Feedback Id')
        public Id feedbackId;

        @InvocableVariable(required=false label='Status')
        public String status;

        @InvocableVariable(required=false label='Solution')
        public String solution;

        @InvocableVariable(required=false label='Assigned To User Id')
        public Id assignedToId;
    }

    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Record Id')
        public Id feedbackId;
    }

    @InvocableMethod(
        label='Update Feedback From MCP'
        description='Update Status, Solution, and/or Assigned To on a Feedback__c record identified by Name or Id.'
        category='UAT Feedback'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null) {
            return results;
        }
        for (Request req : requests) {
            results.add(updateOne(req));
        }
        return results;
    }

    private static Result updateOne(Request req) {
        Result out = new Result();
        out.success = false;
        if (req == null) {
            out.message = 'Request is required.';
            return out;
        }
        Feedback__c row = NF_FeedbackMcpGetAction.findFeedback(req.feedbackId, req.feedbackName);
        if (row == null) {
            out.message = 'Feedback not found. Pass feedbackName (e.g. SF-017) or feedbackId.';
            return out;
        }

        Boolean anyChange = false;
        Feedback__c patch = new Feedback__c(Id = row.Id);
        if (String.isNotBlank(req.status)) {
            patch.Status__c = req.status.trim();
            anyChange = true;
        }
        if (req.solution != null) {
            patch.Solution__c = req.solution;
            anyChange = true;
        }
        if (req.assignedToId != null) {
            patch.Assigned_To__c = req.assignedToId;
            anyChange = true;
        }
        if (!anyChange) {
            out.message = 'No fields to update. Provide status, solution, and/or assignedToId.';
            out.feedbackId = row.Id;
            return out;
        }

        try {
            update patch;
            out.success = true;
            out.feedbackId = row.Id;
            out.message = 'Updated Feedback ' + row.Name;
        } catch (Exception ex) {
            out.message = 'Update failed: ' + ex.getMessage();
            out.feedbackId = row.Id;
        }
        return out;
    }
}
