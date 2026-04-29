System.debug('Org User: ' + UserInfo.getUserName());
Map<String, Schema.SObjectField> fmap = OpsIncidentIntegrationLog__c.SObjectType.getDescribe().fields.getMap();
System.debug('All fields: ' + fmap.keySet());
System.debug('Has Stage__c: ' + fmap.containsKey('Stage__c'));

List<String> cols = new List<String>{ 'Id', 'CreatedDate' };
if (fmap.containsKey('Stage__c')) cols.add('Stage__c');
if (fmap.containsKey('Severity__c')) cols.add('Severity__c');
if (fmap.containsKey('Provider__c')) cols.add('Provider__c');
if (fmap.containsKey('HttpStatusCode__c')) cols.add('HttpStatusCode__c');
if (fmap.containsKey('Detail__c')) cols.add('Detail__c');

String soql = 'SELECT ' + String.join(cols, ',') + ' FROM OpsIncidentIntegrationLog__c ORDER BY CreatedDate DESC LIMIT 5';
System.debug('SOQL=' + soql);
List<SObject> logs = Database.query(soql);
System.debug('Rows fetched: ' + logs.size());
for (SObject row : logs) {
    System.debug('LOG => ' + row);
}
