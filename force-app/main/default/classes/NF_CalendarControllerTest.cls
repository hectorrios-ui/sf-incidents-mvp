/********************************************************************************************
 * Author       :  Danish
 * Class Name   :  NF_CalendarControllerTest
 * Test Class   :  NF_CalendarControllerTest
 * Description  :  Test class for NF_CalendarController
 * Created Date :  July/03/2025
 *  
 ********************************************************************************************/
@isTest
public class NF_CalendarControllerTest {
    
    @isTest
    static void testGetRecordsInDateRange() {
        
        // Arrange test data
        Date today = Date.today();
        Date startDate = today.addDays(-10);
        Date endDate = today.addDays(10);
        
        Account acc1 = new Account(
            Name = 'Test Account 1',
            SLAExpirationDate__c = today.addDays(-5)
        );
        Account acc2 = new Account(
            Name = 'Test Account 2',
            SLAExpirationDate__c = today.addDays(5)
        );
        Account acc3 = new Account(
            Name = 'Test Account 3',
            SLAExpirationDate__c = today.addDays(15) // outside range
        );
        
        insert new List<Account>{ acc1, acc2, acc3 };
        
        Test.startTest();
            Map<String, List<NF_CalendarController.RecordWrapper>> result = 
                NF_CalendarController.getRecordsInDateRange(startDate, endDate, 'Account', 'SLAExpirationDate__c');
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, result, 'Result map should not be null');
        System.assertEquals(true, result.containsKey(String.valueOf(acc1.SLAExpirationDate__c)));
        System.assertEquals(true, result.containsKey(String.valueOf(acc2.SLAExpirationDate__c)));
        System.assertEquals(false, result.containsKey(String.valueOf(acc3.SLAExpirationDate__c)), 'Should not include accounts outside range');
        
        List<NF_CalendarController.RecordWrapper> recsOnDay1 = result.get(String.valueOf(acc1.SLAExpirationDate__c));
        System.assertEquals(1, recsOnDay1.size(), 'Should have 1 record on acc1 SLA date');
        System.assertEquals(acc1.Id, recsOnDay1[0].id);
        
        List<NF_CalendarController.RecordWrapper> recsOnDay2 = result.get(String.valueOf(acc2.SLAExpirationDate__c));
        System.assertEquals(1, recsOnDay2.size(), 'Should have 1 record on acc2 SLA date');
        System.assertEquals(acc2.Id, recsOnDay2[0].id);
    }

    @isTest
    static void testGetRecordsInDateRange_invalidFieldGracefulFallback() {
        Date today = Date.today();
        Date startDate = today.addDays(-1);
        Date endDate = today.addDays(1);

        Test.startTest();
            Map<String, List<NF_CalendarController.RecordWrapper>> result =
                NF_CalendarController.getRecordsInDateRange(startDate, endDate, 'Account', 'NotARealField__c');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result map should not be null on failures.');
        System.assertEquals(0, result.size(), 'Invalid field should gracefully return an empty map.');
    }
}