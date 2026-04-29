public with sharing class NF_IHG_CaseController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class CaseWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String caseReason;
        @AuraEnabled public String description;
        @AuraEnabled public String medium;
        @AuraEnabled public String contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String reservationNumber;
        @AuraEnabled public String propertyName;
        @AuraEnabled public String checkInDate;
        @AuraEnabled public String checkOutDate;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String ownerId;
        @AuraEnabled public String ownerName;
    }

    public class GuestWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String ihgRewardsNumber;
        @AuraEnabled public String ihgRewardsStatus;
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public List<CaseWrapper> openCases;
    }

    public class SearchResult {
        @AuraEnabled public List<GuestWrapper> guests;
        @AuraEnabled public Integer totalGuests;
    }

    public class CaseInput {
        @AuraEnabled public String contactId;
        @AuraEnabled public String accountId;
        @AuraEnabled public String subject;
        @AuraEnabled public String description;
        @AuraEnabled public String caseReason;
        @AuraEnabled public String medium;
        @AuraEnabled public String reservationNumber;
        @AuraEnabled public String propertyName;
        @AuraEnabled public String checkInDate;
        @AuraEnabled public String checkOutDate;
        @AuraEnabled public String status;
    }

    // ─── Search ───────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static SearchResult searchGuests(
        String reservationNumber,
        String firstName,
        String lastName,
        String email
    ) {
        try {
            String query = buildContactQuery(reservationNumber, firstName, lastName, email);
            List<Contact> contacts = Database.query(query);

            Set<Id> contactIds = new Set<Id>();
            for (Contact c : contacts) {
                contactIds.add(c.Id);
            }

            Map<Id, List<Case>> casesByContact = new Map<Id, List<Case>>();
            if (!contactIds.isEmpty()) {
                for (Case cs : [
                    SELECT Id, CaseNumber, Subject, Status, Reason, Description,
                           CreatedDate, OwnerId, Owner.Name, AccountId, Account.Name,
                           ContactId
                    FROM Case
                    WHERE ContactId IN :contactIds
                      AND Status != 'Closed'
                    ORDER BY CreatedDate DESC
                    LIMIT 200
                ]) {
                    if (!casesByContact.containsKey(cs.ContactId)) {
                        casesByContact.put(cs.ContactId, new List<Case>());
                    }
                    casesByContact.get(cs.ContactId).add(cs);
                }
            }

            List<GuestWrapper> guests = new List<GuestWrapper>();
            for (Contact c : contacts) {
                GuestWrapper g = new GuestWrapper();
                g.id = c.Id;
                g.firstName = c.FirstName;
                g.lastName = c.LastName;
                g.name = c.Name;
                g.email = c.Email;
                g.phone = c.Phone;
                g.ihgRewardsNumber = c.IHG_Rewards_Number__c;
                g.ihgRewardsStatus = c.IHG_Rewards_Status__c;
                g.accountId = c.AccountId;
                g.accountName = c.Account != null ? c.Account.Name : null;
                g.openCases = new List<CaseWrapper>();

                if (casesByContact.containsKey(c.Id)) {
                    for (Case cs : casesByContact.get(c.Id)) {
                        g.openCases.add(mapCaseToWrapper(cs));
                    }
                }
                guests.add(g);
            }

            SearchResult result = new SearchResult();
            result.guests = guests;
            result.totalGuests = guests.size();
            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error searching guests: ' + e.getMessage());
        }
    }

    // ─── Get Cases by Contact ─────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<CaseWrapper> getCasesByContact(Id contactId) {
        try {
            List<Case> cases = [
                SELECT Id, CaseNumber, Subject, Status, Reason, Description,
                       CreatedDate, OwnerId, Owner.Name, AccountId, Account.Name,
                       ContactId, Contact.Name
                FROM Case
                WHERE ContactId = :contactId
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            List<CaseWrapper> result = new List<CaseWrapper>();
            for (Case cs : cases) {
                result.add(mapCaseToWrapper(cs));
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching cases: ' + e.getMessage());
        }
    }

    // ─── Get Cases by Account (Hotel) ─────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<CaseWrapper> getCasesByAccount(Id accountId) {
        try {
            List<Case> cases = [
                SELECT Id, CaseNumber, Subject, Status, Reason, Description,
                       CreatedDate, OwnerId, Owner.Name, AccountId, Account.Name,
                       ContactId, Contact.Name
                FROM Case
                WHERE AccountId = :accountId
                ORDER BY CreatedDate DESC
                LIMIT 20
            ];
            List<CaseWrapper> result = new List<CaseWrapper>();
            for (Case cs : cases) {
                result.add(mapCaseToWrapper(cs));
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching hotel cases: ' + e.getMessage());
        }
    }

    // ─── Get Single Case ──────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static CaseWrapper getCaseById(Id caseId) {
        try {
            Case cs = [
                SELECT Id, CaseNumber, Subject, Status, Reason, Description,
                       CreatedDate, OwnerId, Owner.Name, AccountId, Account.Name,
                       ContactId, Contact.Name, Contact.Email, Contact.Phone
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            return mapCaseToWrapper(cs);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching case: ' + e.getMessage());
        }
    }

    // ─── Create Case ──────────────────────────────────────────────────────────

    @AuraEnabled
    public static CaseWrapper createCase(CaseInput input) {
        try {
            Case newCase = new Case();
            newCase.ContactId = input.contactId;
            newCase.AccountId = input.accountId;
            newCase.Subject = input.subject;
            newCase.Description = input.description;
            newCase.Reason = input.caseReason;
            newCase.Status = String.isNotBlank(input.status) ? input.status : 'New';
            newCase.Origin = 'Phone';
            if (String.isNotBlank(input.reservationNumber)) {
                newCase.Reservation_Number__c = input.reservationNumber;
            }
            if (String.isNotBlank(input.propertyName)) {
                newCase.Property_Name__c = input.propertyName;
            }
            if (String.isNotBlank(input.checkInDate)) {
                newCase.Check_In_Date__c = Date.valueOf(input.checkInDate);
            }
            if (String.isNotBlank(input.checkOutDate)) {
                newCase.Check_Out_Date__c = Date.valueOf(input.checkOutDate);
            }

            insert newCase;

            return getCaseById(newCase.Id);
        } catch (Exception e) {
            throw new AuraHandledException('Error creating case: ' + e.getMessage());
        }
    }

    // ─── Create Guest (Contact) + Case ───────────────────────────────────────

    @AuraEnabled
    public static CaseWrapper createGuestAndCase(
        String firstName,
        String lastName,
        String email,
        String phone,
        String ihgRewardsNumber,
        CaseInput caseInput
    ) {
        try {
            Contact newContact = new Contact();
            newContact.FirstName = firstName;
            newContact.LastName = lastName;
            newContact.Email = email;
            newContact.Phone = phone;
            if (String.isNotBlank(ihgRewardsNumber)) {
                newContact.IHG_Rewards_Number__c = ihgRewardsNumber;
            }
            insert newContact;

            caseInput.contactId = newContact.Id;
            return createCase(caseInput);
        } catch (Exception e) {
            throw new AuraHandledException('Error creating guest and case: ' + e.getMessage());
        }
    }

    // ─── Update Case Status ───────────────────────────────────────────────────

    @AuraEnabled
    public static CaseWrapper updateCaseStatus(Id caseId, String status) {
        try {
            Case cs = new Case(Id = caseId, Status = status);
            update cs;
            return getCaseById(caseId);
        } catch (Exception e) {
            throw new AuraHandledException('Error updating case: ' + e.getMessage());
        }
    }

    // ─── Generate AI Summary (mock — replace with Einstein API callout) ───────

    @AuraEnabled
    public static String generateAiSummary(Id caseId) {
        try {
            Case cs = [
                SELECT Id, Subject, Description, Reason, Status,
                       Contact.Name, Account.Name, CreatedDate
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            // In production, replace this with an Einstein Prompt Template callout.
            String summary = buildMockSummary(cs);
            return summary;
        } catch (Exception e) {
            throw new AuraHandledException('Error generating AI summary: ' + e.getMessage());
        }
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    private static CaseWrapper mapCaseToWrapper(Case cs) {
        CaseWrapper w = new CaseWrapper();
        w.id = cs.Id;
        w.caseNumber = cs.CaseNumber;
        w.subject = cs.Subject;
        w.status = cs.Status;
        w.caseReason = cs.Reason;
        w.description = cs.Description;
        w.createdDate = cs.CreatedDate;
        w.ownerId = cs.OwnerId;
        w.ownerName = cs.Owner != null ? cs.Owner.Name : null;
        w.accountId = cs.AccountId;
        w.accountName = cs.Account != null ? cs.Account.Name : null;
        w.contactId = cs.ContactId;
        w.contactName = cs.Contact != null ? cs.Contact.Name : null;
        return w;
    }

    private static String buildContactQuery(
        String reservationNumber,
        String firstName,
        String lastName,
        String email
    ) {
        List<String> conditions = new List<String>();
        if (String.isNotBlank(firstName)) {
            conditions.add('FirstName LIKE \'%' + String.escapeSingleQuotes(firstName) + '%\'');
        }
        if (String.isNotBlank(lastName)) {
            conditions.add('LastName LIKE \'%' + String.escapeSingleQuotes(lastName) + '%\'');
        }
        if (String.isNotBlank(email)) {
            conditions.add('Email = \'' + String.escapeSingleQuotes(email) + '\'');
        }
        if (String.isNotBlank(reservationNumber)) {
            conditions.add('Reservation_Number__c = \'' + String.escapeSingleQuotes(reservationNumber) + '\'');
        }

        String baseQuery = 'SELECT Id, FirstName, LastName, Name, Email, Phone, '
            + 'IHG_Rewards_Number__c, IHG_Rewards_Status__c, AccountId, Account.Name '
            + 'FROM Contact';

        if (!conditions.isEmpty()) {
            baseQuery += ' WHERE ' + String.join(conditions, ' AND ');
        }
        baseQuery += ' ORDER BY LastName ASC LIMIT 50';
        return baseQuery;
    }

    private static String buildMockSummary(Case cs) {
        String contactName = cs.Contact != null ? cs.Contact.Name : 'The guest';
        String property = cs.Account != null ? cs.Account.Name : 'an IHG property';
        String reason = String.isNotBlank(cs.Reason) ? cs.Reason : 'a service concern';
        return contactName + ' submitted a concern regarding ' + reason
            + ' during their stay at ' + property + '. '
            + 'Case subject: ' + cs.Subject + '. '
            + 'Current status: ' + cs.Status + '. '
            + 'This summary was auto-generated — always validate AI responses.';
    }
}
