/**
 * Stamps KPI / cycle-time fields on Feedback__c as its lifecycle progresses.
 *
 * Signals tracked:
 *   - Acknowledged: a human claims ownership (Assigned_To__c becomes non-null).
 *                   If the record is born with Assigned_To__c already set, it is
 *                   treated as acknowledged at creation (time-to-ack = 0).
 *   - Work Started: Status first enters an actively-worked state
 *                   ('In Progress' or 'Dev In-Progress').
 *   - Resolved:     Status first enters a terminal resolution state
 *                   ('Resolved' or 'UAT Complete').
 *
 * Derived durations:
 *   - TimeToAcknowledgeMinutes__c = Created -> Acknowledged (triage latency)
 *   - TimeToStartMinutes__c       = Acknowledged -> Work Started (queue wait)
 *   - TimeToResolveHours__c       = Created -> Resolved (total cycle)
 *
 * Designed for before-insert and before-update triggers so it only mutates the
 * in-memory records and requires no extra DML.
 */
public with sharing class FeedbackKpiService {

    @TestVisible
    private static final Set<String> WORK_STARTED_STATUSES = new Set<String>{
        'In Progress',
        'Dev In-Progress'
    };

    @TestVisible
    private static final Set<String> TERMINAL_RESOLVED_STATUSES = new Set<String>{
        'Resolved',
        'UAT Complete'
    };

    public static void stampKpisOnInsert(List<Feedback__c> newList) {
        if (newList == null || newList.isEmpty()) {
            return;
        }
        Datetime now = Datetime.now();
        for (Feedback__c row : newList) {
            if (row.Assigned_To__c != null && row.AcknowledgedAt__c == null) {
                row.AcknowledgedAt__c = now;
                row.TimeToAcknowledgeMinutes__c = 0;
            }
            if (WORK_STARTED_STATUSES.contains(row.Status__c) && row.WorkStartedAt__c == null) {
                row.WorkStartedAt__c = now;
                row.TimeToStartMinutes__c = 0;
            }
            if (TERMINAL_RESOLVED_STATUSES.contains(row.Status__c) && row.ResolvedAt__c == null) {
                row.ResolvedAt__c = now;
                row.TimeToResolveHours__c = 0;
            }
        }
    }

    public static void stampKpis(List<Feedback__c> newList, Map<Id, Feedback__c> oldMap) {
        if (newList == null || newList.isEmpty() || oldMap == null) {
            return;
        }

        Set<Id> needsCreatedDate = new Set<Id>();
        for (Feedback__c row : newList) {
            if (row.CreatedDate == null && oldMap.containsKey(row.Id)) {
                needsCreatedDate.add(row.Id);
            }
        }

        Map<Id, Datetime> createdDateById = new Map<Id, Datetime>();
        if (!needsCreatedDate.isEmpty()) {
            for (Feedback__c fresh : [
                SELECT Id, CreatedDate
                FROM Feedback__c
                WHERE Id IN :needsCreatedDate
            ]) {
                createdDateById.put(fresh.Id, fresh.CreatedDate);
            }
        }

        Datetime now = Datetime.now();
        for (Feedback__c row : newList) {
            Feedback__c old = oldMap.get(row.Id);
            if (old == null) {
                continue;
            }

            Datetime createdAt = row.CreatedDate != null ? row.CreatedDate : createdDateById.get(row.Id);

            if (old.Assigned_To__c == null
                && row.Assigned_To__c != null
                && row.AcknowledgedAt__c == null) {
                row.AcknowledgedAt__c = now;
                if (createdAt != null) {
                    row.TimeToAcknowledgeMinutes__c = minutesBetween(createdAt, now);
                }
            }

            Boolean statusChanged = row.Status__c != old.Status__c;

            if (statusChanged
                && WORK_STARTED_STATUSES.contains(row.Status__c)
                && !WORK_STARTED_STATUSES.contains(old.Status__c)
                && row.WorkStartedAt__c == null) {
                row.WorkStartedAt__c = now;
                Datetime ackAt = row.AcknowledgedAt__c;
                if (ackAt != null) {
                    row.TimeToStartMinutes__c = minutesBetween(ackAt, now);
                }
            }

            if (statusChanged
                && TERMINAL_RESOLVED_STATUSES.contains(row.Status__c)
                && !TERMINAL_RESOLVED_STATUSES.contains(old.Status__c)
                && row.ResolvedAt__c == null) {
                row.ResolvedAt__c = now;
                if (createdAt != null) {
                    row.TimeToResolveHours__c = hoursBetween(createdAt, now);
                }
            }
        }
    }

    private static Decimal minutesBetween(Datetime startAt, Datetime endAt) {
        Long diffMs = endAt.getTime() - startAt.getTime();
        if (diffMs < 0) {
            diffMs = 0;
        }
        Decimal minutes = Decimal.valueOf(diffMs) / (1000.0 * 60.0);
        return minutes.setScale(2);
    }

    private static Decimal hoursBetween(Datetime startAt, Datetime endAt) {
        Long diffMs = endAt.getTime() - startAt.getTime();
        if (diffMs < 0) {
            diffMs = 0;
        }
        Decimal hours = Decimal.valueOf(diffMs) / (1000.0 * 60.0 * 60.0);
        return hours.setScale(2);
    }
}
