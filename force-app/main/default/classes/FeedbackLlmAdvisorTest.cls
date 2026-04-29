@IsTest
private class FeedbackLlmAdvisorTest {
    private class OpenAiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String assistantContent = JSON.serialize(
                new Map<String, Object>{ 'proposedFix' => 'Clarify acceptance criteria and update layout CSS.', 'confidence' => 0.68 }
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
            String assistantContent = JSON.serialize(
                new Map<String, Object>{ 'proposedFix' => 'Assign to owning squad and reproduce with script.', 'confidence' => 0.61 }
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

    @IsTest
    static void trySuggest_openAiReturnsSuggestion() {
        FeedbackLlmAdvisor.configOverride = new Ops_Incident_AI_Config__mdt(
            Enabled__c = true,
            Named_Credential_Api_Name__c = 'Test_OpenAI_NC',
            Model__c = 'gpt-test',
            Provider__c = 'OpenAI_Chat',
            Relative_Api_Path__c = 'v1/chat/completions'
        );
        Test.setMock(HttpCalloutMock.class, new OpenAiMock());
        Feedback__c f = new Feedback__c(
            Issue_Name__c = 'Header spacing issue',
            Issue_Description__c = 'Header pushes content below fold',
            Status__c = 'New'
        );
        try {
            Test.startTest();
            FeedbackLlmAdvisor.SuggestionOutcome out = FeedbackLlmAdvisor.trySuggest(f);
            Test.stopTest();
            System.assertNotEquals(null, out);
            System.assert(out.proposedFix.containsIgnoreCase('acceptance criteria'));
            System.assertEquals(0.68, out.confidence);
        } finally {
            FeedbackLlmAdvisor.clearConfigOverride();
        }
    }

    @IsTest
    static void trySuggest_returnsNullWhenDisabled() {
        FeedbackLlmAdvisor.configOverride = new Ops_Incident_AI_Config__mdt(
            Enabled__c = false
        );
        try {
            Feedback__c f = new Feedback__c(Issue_Name__c = 'x', Status__c = 'New');
            System.assertEquals(null, FeedbackLlmAdvisor.trySuggest(f));
        } finally {
            FeedbackLlmAdvisor.clearConfigOverride();
        }
    }

    @IsTest
    static void trySuggest_returnsNullForUnsupportedProvider() {
        FeedbackLlmAdvisor.configOverride = new Ops_Incident_AI_Config__mdt(
            Enabled__c = true,
            Named_Credential_Api_Name__c = 'NC',
            Model__c = 'any',
            Provider__c = 'Unsupported'
        );
        try {
            Feedback__c f = new Feedback__c(Issue_Name__c = 'x', Status__c = 'New');
            System.assertEquals(null, FeedbackLlmAdvisor.trySuggest(f));
        } finally {
            FeedbackLlmAdvisor.clearConfigOverride();
        }
    }

    @IsTest
    static void trySuggest_anthropicReturnsSuggestion() {
        FeedbackLlmAdvisor.configOverride = new Ops_Incident_AI_Config__mdt(
            Enabled__c = true,
            Named_Credential_Api_Name__c = 'Test_Anthropic_NC',
            Model__c = 'claude-test',
            Provider__c = 'Anthropic_Messages',
            Relative_Api_Path__c = 'v1/messages'
        );
        Test.setMock(HttpCalloutMock.class, new AnthropicMock());
        try {
            Feedback__c f = new Feedback__c(
                Issue_Name__c = 'Validation error',
                Issue_Description__c = 'Fails when creating account',
                Status__c = 'New'
            );
            Test.startTest();
            FeedbackLlmAdvisor.SuggestionOutcome out = FeedbackLlmAdvisor.trySuggest(f);
            Test.stopTest();
            System.assertNotEquals(null, out);
            System.assert(out.proposedFix.containsIgnoreCase('Assign to owning squad'));
            System.assertEquals(0.61, out.confidence);
        } finally {
            FeedbackLlmAdvisor.clearConfigOverride();
        }
    }
}
