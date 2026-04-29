@IsTest
private class OpsIncidentLlmClientTest {
    private class OpenAiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String assistantContent = JSON.serialize(
                new Map<String, Object>{ 'proposedFix' => 'Use exact match filters for encrypted fields.', 'confidence' => 0.72 }
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

    private class AnthropicMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getEndpoint().contains('/v1/messages'), 'Expected Anthropic messages endpoint.');
            System.assertEquals('2023-06-01', req.getHeader('anthropic-version'));
            String assistantContent = JSON.serialize(
                new Map<String, Object>{ 'proposedFix' => 'Set default values before DML in Flow.', 'confidence' => 0.64 }
            );
            Map<String, Object> root = new Map<String, Object>{
                'content' => new List<Object>{
                    new Map<String, Object>{ 'type' => 'text', 'text' => assistantContent }
                }
            };
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(root));
            return res;
        }
    }

    private class FailingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('provider unavailable for maintenance');
            return res;
        }
    }

    private class ExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('simulated transport exception');
        }
    }

    @IsTest
    static void tryDiagnose_parsesOpenAiStyleResponse() {
        OpsIncidentLlmClient.configOverride = new Ops_Incident_AI_Config__mdt(
            Enabled__c = true,
            Named_Credential_Api_Name__c = 'Test_OpenAI_NC',
            Model__c = 'gpt-test',
            Provider__c = 'OpenAI_Chat',
            Temperature__c = 0.1,
            Max_Output_Tokens__c = 100,
            Relative_Api_Path__c = 'v1/chat/completions'
        );

        OpsIncident__c row = new OpsIncident__c(
            SourceType__c = 'Flow',
            ErrorMessage__c = 'encrypted field like error',
            FlowApiName__c = 'My_Flow'
        );

        Test.setMock(HttpCalloutMock.class, new OpenAiMock());
        try {
            Test.startTest();
            OpsIncidentLlmClient.DiagnosisOutcome out = OpsIncidentLlmClient.tryDiagnose(row);
            Test.stopTest();

            System.assertNotEquals(null, out, 'Expected LLM outcome.');
            System.assert(out.proposedFix.containsIgnoreCase('exact'), 'Expected proposed fix text.');
            System.assertEquals(0.72, out.confidence);
        } finally {
            OpsIncidentLlmClient.clearConfigOverride();
        }
    }

    @IsTest
    static void tryDiagnose_returnsNullWhenDisabled() {
        OpsIncidentLlmClient.clearConfigOverride();
        OpsIncident__c row = new OpsIncident__c(ErrorMessage__c = 'x');
        System.assertEquals(null, OpsIncidentLlmClient.tryDiagnose(row));
    }

    @IsTest
    static void tryDiagnose_parsesAnthropicResponse() {
        OpsIncidentLlmClient.configOverride = new Ops_Incident_AI_Config__mdt(
            Enabled__c = true,
            Named_Credential_Api_Name__c = 'Test_Anthropic_NC',
            Model__c = 'claude-3-5-haiku-latest',
            Provider__c = 'Anthropic_Messages',
            Temperature__c = 0.1,
            Max_Output_Tokens__c = 200,
            Relative_Api_Path__c = 'v1/messages'
        );
        OpsIncident__c row = new OpsIncident__c(
            SourceType__c = 'Apex',
            ErrorMessage__c = 'Attempt to de-reference a null object',
            ApexClass__c = 'MyHandler'
        );
        Test.setMock(HttpCalloutMock.class, new AnthropicMock());
        try {
            Test.startTest();
            OpsIncidentLlmClient.DiagnosisOutcome out = OpsIncidentLlmClient.tryDiagnose(row);
            Test.stopTest();
            System.assertNotEquals(null, out);
            System.assert(out.proposedFix.containsIgnoreCase('default values'));
            System.assertEquals(0.64, out.confidence);
        } finally {
            OpsIncidentLlmClient.clearConfigOverride();
        }
    }

    @IsTest
    static void tryDiagnose_returnsNullForUnsupportedProvider() {
        OpsIncidentLlmClient.configOverride = new Ops_Incident_AI_Config__mdt(
            Enabled__c = true,
            Named_Credential_Api_Name__c = 'NC',
            Model__c = 'some-model',
            Provider__c = 'Unsupported'
        );
        try {
            OpsIncident__c row = new OpsIncident__c(ErrorMessage__c = 'x');
            System.assertEquals(null, OpsIncidentLlmClient.tryDiagnose(row));
        } finally {
            OpsIncidentLlmClient.clearConfigOverride();
        }
    }

    @IsTest
    static void tryDiagnose_returnsNullOnProviderHttpFailure() {
        OpsIncidentLlmClient.configOverride = new Ops_Incident_AI_Config__mdt(
            Enabled__c = true,
            Named_Credential_Api_Name__c = 'Test_OpenAI_NC',
            Model__c = 'gpt-test',
            Provider__c = 'OpenAI_Chat',
            Relative_Api_Path__c = 'v1/chat/completions'
        );
        Test.setMock(HttpCalloutMock.class, new FailingMock());
        try {
            OpsIncident__c row = new OpsIncident__c(ErrorMessage__c = 'x');
            System.assertEquals(null, OpsIncidentLlmClient.tryDiagnose(row));
        } finally {
            OpsIncidentLlmClient.clearConfigOverride();
        }
    }

    @IsTest
    static void tryDiagnose_returnsNullOnProviderException() {
        OpsIncidentLlmClient.configOverride = new Ops_Incident_AI_Config__mdt(
            Enabled__c = true,
            Named_Credential_Api_Name__c = 'Test_Anthropic_NC',
            Model__c = 'claude-test',
            Provider__c = 'Anthropic_Messages',
            Relative_Api_Path__c = 'v1/messages'
        );
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());
        try {
            OpsIncident__c row = new OpsIncident__c(ErrorMessage__c = 'x');
            System.assertEquals(null, OpsIncidentLlmClient.tryDiagnose(row));
        } finally {
            OpsIncidentLlmClient.clearConfigOverride();
        }
    }
}
