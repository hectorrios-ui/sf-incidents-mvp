public with sharing class ReservationSearchController {

    public class SearchInput {
        @InvocableVariable(label='Confirmation Number')
        public String confirmationNumber;

        @InvocableVariable(label='Email Address')
        public String email;

        @InvocableVariable(label='Check-In Date')
        public Date checkInDate;

        @InvocableVariable(label='Hotel Name')
        public String hotelName;

        @InvocableVariable(label='First Name')
        public String firstName;

        @InvocableVariable(label='Last Name')
        public String lastName;
    }

    public class SearchResult {
        @InvocableVariable(label='Reservations')
        public List<Reservations__c> reservations;
    }

    @InvocableMethod(label='Search Reservations' description='Searches Reservations__c with exact match filters. Uses = instead of LIKE for encrypted field compatibility.')
    public static List<SearchResult> searchReservations(List<SearchInput> inputs) {
        SearchInput inp = inputs[0];

        String q = 'SELECT Id, Name, confirmationNumber__c, EmailAddress__c, checkInDate__c, hotelName__c, frst_nm__c, lst_nm__c FROM Reservations__c';
        List<String> conditions = new List<String>();

        if (String.isNotBlank(inp.confirmationNumber)) {
            conditions.add('confirmationNumber__c = \'' + String.escapeSingleQuotes(inp.confirmationNumber) + '\'');
        }
        if (String.isNotBlank(inp.email)) {
            conditions.add('EmailAddress__c = \'' + String.escapeSingleQuotes(inp.email) + '\'');
        }
        if (inp.checkInDate != null) {
            conditions.add('checkInDate__c = ' + String.valueOf(inp.checkInDate));
        }
        if (String.isNotBlank(inp.hotelName)) {
            conditions.add('hotelName__c = \'' + String.escapeSingleQuotes(inp.hotelName) + '\'');
        }
        if (String.isNotBlank(inp.firstName)) {
            conditions.add('frst_nm__c = \'' + String.escapeSingleQuotes(inp.firstName) + '\'');
        }
        if (String.isNotBlank(inp.lastName)) {
            conditions.add('lst_nm__c = \'' + String.escapeSingleQuotes(inp.lastName) + '\'');
        }

        if (!conditions.isEmpty()) {
            q += ' WHERE ' + String.join(conditions, ' AND ');
        }
        q += ' ORDER BY Name LIMIT 200';

        SearchResult result = new SearchResult();
        result.reservations = Database.query(q);
        return new List<SearchResult>{ result };
    }
}
