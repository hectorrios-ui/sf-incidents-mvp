@IsTest
private class OpsIncidentDiagnosisServiceTest {
    private class OpenAiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String assistantContent = JSON.serialize(
                new Map<String, Object>{ 'proposedFix' => 'LLM proposed fix from diagnosis test.', 'confidence' => 0.66 }
            );
            Map<String, Object> root = new Map<String, Object>{
                'choices' => new List<Object>{
                    new Map<String, Object>{ 'message' => new Map<String, Object>{ 'content' => assistantContent } }
                }
            };
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(root));
            return res;
        }
    }

    @IsTest
    static void diagnose_noOpWhenNullOrEmptyRequests() {
        Test.startTest();
        OpsIncidentDiagnosisService.diagnose(null);
        OpsIncidentDiagnosisService.diagnose(new List<OpsIncidentDiagnosisService.Request>());
        OpsIncidentDiagnosisService.Request blank = new OpsIncidentDiagnosisService.Request();
        OpsIncidentDiagnosisService.diagnose(new List<OpsIncidentDiagnosisService.Request>{ blank });
        Test.stopTest();
    }

    @IsTest
    static void diagnose_usesLlmWhenConfigEnabled() {
        OpsIncidentLlmClient.configOverride = new Ops_Incident_AI_Config__mdt(
            Enabled__c = true,
            Named_Credential_Api_Name__c = 'Test_OpenAI_NC',
            Model__c = 'gpt-test',
            Provider__c = 'OpenAI_Chat',
            Temperature__c = 0.1,
            Max_Output_Tokens__c = 100,
            Relative_Api_Path__c = 'v1/chat/completions'
        );
        Test.setMock(HttpCalloutMock.class, new OpenAiMock());

        OpsIncident__c i = new OpsIncident__c(
            SourceType__c = 'Flow',
            Severity__c = 'High',
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'any message for LLM path'
        );
        insert i;

        try {
            Test.startTest();
            OpsIncidentDiagnosisService.diagnoseInCurrentTransaction(new List<Id>{ i.Id });
            Test.stopTest();

            OpsIncident__c u = [SELECT ProposedFix__c, AIConfidence__c FROM OpsIncident__c WHERE Id = :i.Id];
            System.assert(u.ProposedFix__c.containsIgnoreCase('LLM proposed fix'), 'Should use LLM outcome.');
            System.assertEquals(0.66, u.AIConfidence__c);
        } finally {
            OpsIncidentLlmClient.clearConfigOverride();
        }
    }

    @IsTest
    static void diagnose_setsEncryptedLikeSuggestion() {
        OpsIncident__c i = new OpsIncident__c(
            SourceType__c = 'Flow',
            Severity__c = 'High',
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'The operator like is not supported on an encrypted field.'
        );
        insert i;

        OpsIncidentDiagnosisService.diagnoseInCurrentTransaction(new List<Id>{ i.Id });

        OpsIncident__c u = [SELECT Status__c, ProposedFix__c, AIConfidence__c FROM OpsIncident__c WHERE Id = :i.Id];
        System.assertEquals('Diagnosed', u.Status__c);
        System.assert(u.ProposedFix__c != null && u.ProposedFix__c.containsIgnoreCase('encrypted'), 'Should mention encrypted/LIKE guidance.');
        System.assert(u.AIConfidence__c != null && u.AIConfidence__c > 0, 'Confidence should be set.');
    }

    @IsTest
    static void diagnose_defaultFallback() {
        OpsIncident__c i = new OpsIncident__c(
            SourceType__c = 'Other',
            Severity__c = 'Low',
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'Something unknown happened.'
        );
        insert i;

        OpsIncidentDiagnosisService.diagnoseInCurrentTransaction(new List<Id>{ i.Id });

        OpsIncident__c u = [SELECT ProposedFix__c, AIConfidence__c FROM OpsIncident__c WHERE Id = :i.Id];
        System.assertNotEquals(null, u.ProposedFix__c);
        System.assert(u.AIConfidence__c != null);
    }

    @IsTest
    static void diagnose_nullPointerHeuristic() {
        OpsIncident__c i = new OpsIncident__c(
            SourceType__c = 'Apex',
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'System.NullPointerException: Attempt to de-reference a null object'
        );
        insert i;
        runDiagnoseAssertConfidence(i.Id, 'null');
    }

    @IsTest
    static void diagnose_governorHeuristic() {
        OpsIncident__c i = new OpsIncident__c(
            SourceType__c = 'Apex',
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'Too many SOQL queries: 101'
        );
        insert i;
        runDiagnoseAssertConfidence(i.Id, 'Governor');
    }

    @IsTest
    static void diagnose_flowFaultHeuristic() {
        OpsIncident__c i = new OpsIncident__c(
            SourceType__c = 'Flow',
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'flow fault path element fault'
        );
        insert i;
        runDiagnoseAssertConfidence(i.Id, 'Flow');
    }

    @IsTest
    static void diagnose_apexClassHeuristic() {
        OpsIncident__c i = new OpsIncident__c(
            SourceType__c = 'Apex',
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'generic error',
            ApexClass__c = 'MyTriggerHandler'
        );
        insert i;
        runDiagnoseAssertConfidence(i.Id, 'stack trace');
    }

    @IsTest
    static void diagnose_validationRuleHeuristic() {
        OpsIncident__c i = new OpsIncident__c(
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'FIELD_CUSTOM_VALIDATION_EXCEPTION: validation rule failed'
        );
        insert i;
        runDiagnoseAssertConfidence(i.Id, 'Validation Rule');
    }

    @IsTest
    static void diagnose_duplicateRuleHeuristic() {
        OpsIncident__c i = new OpsIncident__c(
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'duplicate rule blocked the save'
        );
        insert i;
        runDiagnoseAssertConfidence(i.Id, 'Duplicate');
    }

    @IsTest
    static void diagnose_stackTraceUsedInCombinedText() {
        OpsIncident__c i = new OpsIncident__c(
            SourceType__c = 'Other',
            Status__c = 'Diagnosed',
            ErrorMessage__c = 'header only',
            StackTrace__c = 'encrypted field like operator not supported'
        );
        insert i;
        runDiagnoseAssertConfidence(i.Id, 'encrypted');
    }

    private static void runDiagnoseAssertConfidence(Id incidentId, String proposedFixSubstring) {
        OpsIncidentDiagnosisService.diagnoseInCurrentTransaction(new List<Id>{ incidentId });
        OpsIncident__c u = [SELECT ProposedFix__c, AIConfidence__c FROM OpsIncident__c WHERE Id = :incidentId];
        System.assert(u.ProposedFix__c != null && u.ProposedFix__c.containsIgnoreCase(proposedFixSubstring), u.ProposedFix__c);
        System.assert(u.AIConfidence__c != null && u.AIConfidence__c > 0);
    }
}
