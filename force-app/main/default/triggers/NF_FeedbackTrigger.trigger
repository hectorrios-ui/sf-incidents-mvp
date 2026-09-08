trigger NF_FeedbackTrigger on Feedback__c (before insert, before update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        NF_FeedbackKpiService.stampKpisOnInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        NF_FeedbackKpiService.stampKpis(Trigger.new, Trigger.oldMap);
    }
}
