public with sharing class FeedbackLlmAdvisor {
    public class SuggestionOutcome {
        public String proposedFix;
        public Decimal confidence;
    }

    @TestVisible
    private static Ops_Incident_AI_Config__mdt configOverride;

    @TestVisible
    private static void clearConfigOverride() {
        configOverride = null;
    }

    private static Ops_Incident_AI_Config__mdt activeConfig() {
        return configOverride != null ? configOverride : Ops_Incident_AI_Config__mdt.getInstance('Default');
    }

    public static SuggestionOutcome trySuggest(Feedback__c row) {
        Ops_Incident_AI_Config__mdt cfg = activeConfig();
        if (cfg == null || cfg.Enabled__c != true) {
            return null;
        }
        if (String.isBlank(cfg.Named_Credential_Api_Name__c) || String.isBlank(cfg.Model__c)) {
            return null;
        }
        String provider = String.isNotBlank(cfg.Provider__c) ? cfg.Provider__c : 'OpenAI_Chat';
        if (provider == 'OpenAI_Chat') {
            return callOpenAiCompatible(cfg, row);
        }
        if (provider == 'Anthropic_Messages') {
            return callAnthropicMessages(cfg, row);
        }
        return null;
    }

    private static SuggestionOutcome callOpenAiCompatible(Ops_Incident_AI_Config__mdt cfg, Feedback__c row) {
        String path = String.isNotBlank(cfg.Relative_Api_Path__c) ? cfg.Relative_Api_Path__c.trim() : 'v1/chat/completions';
        path = path.startsWith('/') ? path.substring(1) : path;

        Decimal temp = cfg.Temperature__c != null ? cfg.Temperature__c : 0.2;
        Integer maxTok = cfg.Max_Output_Tokens__c != null ? Integer.valueOf(cfg.Max_Output_Tokens__c) : 500;

        Map<String, Object> body = new Map<String, Object>{
            'model' => cfg.Model__c,
            'temperature' => temp,
            'max_tokens' => maxTok,
            'messages' => new List<Object>{
                new Map<String, Object>{ 'role' => 'system', 'content' => systemPrompt() },
                new Map<String, Object>{ 'role' => 'user', 'content' => buildPrompt(row) }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + cfg.Named_Credential_Api_Name__c.trim() + '/' + path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);
        req.setBody(JSON.serialize(body));

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                return null;
            }
            return parseOpenAiChatResponse(res.getBody());
        } catch (Exception ex) {
            return null;
        }
    }

    private static SuggestionOutcome callAnthropicMessages(Ops_Incident_AI_Config__mdt cfg, Feedback__c row) {
        String path = String.isNotBlank(cfg.Relative_Api_Path__c) ? cfg.Relative_Api_Path__c.trim() : 'v1/messages';
        path = path.startsWith('/') ? path.substring(1) : path;

        Decimal temp = cfg.Temperature__c != null ? cfg.Temperature__c : 0.2;
        Integer maxTok = cfg.Max_Output_Tokens__c != null ? Integer.valueOf(cfg.Max_Output_Tokens__c) : 500;

        Map<String, Object> body = new Map<String, Object>{
            'model' => cfg.Model__c,
            'temperature' => temp,
            'max_tokens' => maxTok,
            'system' => systemPrompt(),
            'messages' => new List<Object>{
                new Map<String, Object>{ 'role' => 'user', 'content' => buildPrompt(row) }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + cfg.Named_Credential_Api_Name__c.trim() + '/' + path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('anthropic-version', '2023-06-01');
        req.setTimeout(120000);
        req.setBody(JSON.serialize(body));

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                return null;
            }
            return parseAnthropicMessagesResponse(res.getBody());
        } catch (Exception ex) {
            return null;
        }
    }

    private static String systemPrompt() {
        return 'You are a senior Salesforce consultant helping triage UAT findings. '
            + 'Respond with a single JSON object ONLY, no markdown, no prose. '
            + 'Schema: {"proposedFix":"<string>","confidence":<number between 0 and 1>}. '
            + 'proposedFix must be concise and actionable for internal delivery teams.';
    }

    private static String buildPrompt(Feedback__c row) {
        return 'FeedbackNumber=' + row.Name
            + '\nIssueName=' + row.Issue_Name__c
            + '\nStatus=' + row.Status__c
            + '\nType=' + row.Type__c
            + '\nPersona=' + row.Persona__c
            + '\nIssueDescription=\n' + row.Issue_Description__c;
    }

    private static SuggestionOutcome parseOpenAiChatResponse(String httpBody) {
        if (String.isBlank(httpBody)) {
            return null;
        }
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(httpBody);
        List<Object> choices = (List<Object>) root.get('choices');
        if (choices == null || choices.isEmpty()) {
            return null;
        }
        Map<String, Object> c0 = (Map<String, Object>) choices[0];
        Map<String, Object> msg = (Map<String, Object>) c0.get('message');
        if (msg == null) {
            return null;
        }
        String content = (String) msg.get('content');
        if (String.isBlank(content)) {
            return null;
        }
        String jsonBlob = extractJsonObject(content.trim());
        if (String.isBlank(jsonBlob)) {
            return null;
        }
        return parseSuggestionJson(jsonBlob);
    }

    private static SuggestionOutcome parseAnthropicMessagesResponse(String httpBody) {
        if (String.isBlank(httpBody)) {
            return null;
        }
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(httpBody);
        List<Object> contentBlocks = (List<Object>) root.get('content');
        if (contentBlocks == null || contentBlocks.isEmpty()) {
            return null;
        }
        String modelText = null;
        for (Object blockObj : contentBlocks) {
            Map<String, Object> block = (Map<String, Object>) blockObj;
            if ((String) block.get('type') == 'text' && block.get('text') != null) {
                modelText = String.valueOf(block.get('text'));
                break;
            }
        }
        if (String.isBlank(modelText)) {
            return null;
        }
        String jsonBlob = extractJsonObject(modelText.trim());
        if (String.isBlank(jsonBlob)) {
            return null;
        }
        return parseSuggestionJson(jsonBlob);
    }

    private static SuggestionOutcome parseSuggestionJson(String jsonBlob) {
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(jsonBlob);
        Object fixObj = parsed.get('proposedFix');
        Object confObj = parsed.get('confidence');
        if (fixObj == null) {
            return null;
        }
        SuggestionOutcome out = new SuggestionOutcome();
        out.proposedFix = String.valueOf(fixObj);
        if (confObj != null) {
            Decimal c = Decimal.valueOf(String.valueOf(confObj));
            if (c < 0) c = 0;
            if (c > 1) c = 1;
            out.confidence = c;
        } else {
            out.confidence = 0.55;
        }
        return out;
    }

    private static String extractJsonObject(String content) {
        if (content.startsWith('```')) {
            Integer open = content.indexOf('{');
            Integer close = content.lastIndexOf('}');
            if (open >= 0 && close > open) {
                return content.substring(open, close + 1);
            }
        }
        if (content.startsWith('{') && content.endsWith('}')) {
            return content;
        }
        Integer open = content.indexOf('{');
        Integer close = content.lastIndexOf('}');
        if (open >= 0 && close > open) {
            return content.substring(open, close + 1);
        }
        return null;
    }
}
