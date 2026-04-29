@IsTest
public class NF_IHG_CaseControllerTest {

    @TestSetup
    static void makeData() {
        Account hotel = new Account(Name = 'Tiger Hotel');
        insert hotel;

        Contact guest = new Contact(
            FirstName = 'Ashley',
            LastName = 'James',
            Email = 'ashley@email.com',
            Phone = '3031234567',
            AccountId = hotel.Id
        );
        insert guest;

        Case openCase = new Case(
            Subject = 'Room had smoking smell',
            Status = 'Open',
            Reason = 'Other',
            ContactId = guest.Id,
            AccountId = hotel.Id
        );
        insert openCase;
    }

    @IsTest
    static void testSearchGuestsByLastName() {
        Test.startTest();
        NF_IHG_CaseController.SearchResult result =
            NF_IHG_CaseController.searchGuests(null, null, 'James', null);
        Test.stopTest();
        System.assertEquals(1, result.totalGuests, 'Should find 1 guest');
        System.assertEquals(1, result.guests[0].openCases.size(), 'Should have 1 open case');
    }

    @IsTest
    static void testSearchGuestsByEmail() {
        Test.startTest();
        NF_IHG_CaseController.SearchResult result =
            NF_IHG_CaseController.searchGuests(null, null, null, 'ashley@email.com');
        Test.stopTest();
        System.assertEquals(1, result.totalGuests);
    }

    @IsTest
    static void testCreateCase() {
        Contact guest = [SELECT Id, AccountId FROM Contact LIMIT 1];
        NF_IHG_CaseController.CaseInput input = new NF_IHG_CaseController.CaseInput();
        input.contactId = guest.Id;
        input.accountId = guest.AccountId;
        input.subject = 'Test Case';
        input.description = 'Test description';
        input.caseReason = 'Other';
        input.status = 'New';

        Test.startTest();
        NF_IHG_CaseController.CaseWrapper result =
            NF_IHG_CaseController.createCase(input);
        Test.stopTest();

        System.assertNotEquals(null, result.id);
        System.assertEquals('Test Case', result.subject);
    }

    @IsTest
    static void testCreateGuestAndCase() {
        NF_IHG_CaseController.CaseInput input = new NF_IHG_CaseController.CaseInput();
        input.subject = 'New Guest Case';
        input.status = 'New';

        Test.startTest();
        NF_IHG_CaseController.CaseWrapper result =
            NF_IHG_CaseController.createGuestAndCase(
                'John', 'Doe', 'john@doe.com', '3031112222', null, input
            );
        Test.stopTest();

        System.assertNotEquals(null, result.id);
    }

    @IsTest
    static void testGetCasesByContact() {
        Contact guest = [SELECT Id FROM Contact LIMIT 1];
        Test.startTest();
        List<NF_IHG_CaseController.CaseWrapper> cases =
            NF_IHG_CaseController.getCasesByContact(guest.Id);
        Test.stopTest();
        System.assertEquals(1, cases.size());
    }

    @IsTest
    static void testGetCasesByAccount() {
        Account hotel = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<NF_IHG_CaseController.CaseWrapper> cases =
            NF_IHG_CaseController.getCasesByAccount(hotel.Id);
        Test.stopTest();
        System.assertEquals(1, cases.size());
    }

    @IsTest
    static void testUpdateCaseStatus() {
        Case cs = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        NF_IHG_CaseController.CaseWrapper result =
            NF_IHG_CaseController.updateCaseStatus(cs.Id, 'Escalated');
        Test.stopTest();
        System.assertEquals('Escalated', result.status);
    }

    @IsTest
    static void testGenerateAiSummary() {
        Case cs = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        String summary = NF_IHG_CaseController.generateAiSummary(cs.Id);
        Test.stopTest();
        System.assertNotEquals(null, summary);
        System.assert(summary.length() > 0);
    }
}
