trigger FeedbackTrigger on Feedback__c (before insert, before update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        FeedbackKpiService.stampKpisOnInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        FeedbackKpiService.stampKpis(Trigger.new, Trigger.oldMap);
    }
}
