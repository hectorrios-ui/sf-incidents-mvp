/********************************************************************************************
 * Author       :  Danish
 * Class Name   :  NF_CalendarController
 * Test Class   :  NF_CalendarControllerTest
 * Description  :  Apex controller to support scheduling of events by retrieving available records within 
 *                 a date range, allowing calendar-based selection of time slots in a flexible, reusable way.
 * Created Date :  July/03/2025
 * 
 * Changes Logs
 * ------------------------------------------------------------------------------------------
 * Changed By            Date               Description
 * ------------          ---------          -------------
 * Danish                July/03/2025       Initial version  
 ********************************************************************************************/
public with sharing class NF_CalendarController {
    @AuraEnabled(cacheable=true)
    public static Map<String, List<RecordWrapper>> getRecordsInDateRange(
        Date startDate, Date endDate, String objectName, String fieldName) {
        Map<String, List<RecordWrapper>> resultsMap = new Map<String, List<RecordWrapper>>();
        System.debug('start-->'+ startDate);
        System.debug('end-->'+ endDate);
        // Validate inputs
        if(String.isBlank(objectName) || String.isBlank(fieldName)) {
            return resultsMap;
        }
        
        // Dynamic query string
        String soql = String.format(
            'SELECT Id, Name, {0} FROM {1} WHERE {0} >= :startDate AND {0} <= :endDate ',new String[]{ fieldName, objectName }
        );

        try {
            List<SObject> records = Database.query(soql);

            for(SObject rec : records) {
                Date dateValue = (Date) rec.get(fieldName);
                if(dateValue != null){
                    String dateStr = String.valueOf(dateValue);
                    if (!resultsMap.containsKey(dateStr)) {
                        resultsMap.put(dateStr, new List<RecordWrapper>());
                    }
                    resultsMap.get(dateStr).add(
                        new RecordWrapper(
                            (String)rec.get('Id'),
                            (String)rec.get('Name')
                        )
                    );
                }
            }
        } catch(Exception e){
            System.debug('Error in dynamic SOQL: ' + e.getMessage());
            OpsIncidentExceptionUtil.reportException(
                e,
                'NF_CalendarController',
                'Medium',
                null,
                false
            );
            // Gracefully return empty map to the UI.
        }
        return resultsMap;
    }
    
    public class RecordWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        
        public RecordWrapper(String id, String name){
            this.id = id;
            this.name = name;
        }
    }
}