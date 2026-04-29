/**
 * Optional LLM diagnosis via Custom Metadata (Ops_Incident_AI_Config__mdt).
 * Providers:
 * - OpenAI_Chat: OpenAI-compatible Chat Completions
 * - Anthropic_Messages: Anthropic Messages API (Claude)
 */
public with sharing class OpsIncidentLlmClient {
    public class DiagnosisOutcome {
        public String proposedFix;
        public Decimal confidence;
    }

    /** Unit tests only: in-memory config when __mdt rows are not practical. */
    @TestVisible
    private static Ops_Incident_AI_Config__mdt configOverride;

    private static Ops_Incident_AI_Config__mdt activeConfig() {
        return configOverride != null ? configOverride : Ops_Incident_AI_Config__mdt.getInstance('Default');
    }

    @TestVisible
    private static void clearConfigOverride() {
        configOverride = null;
    }

    /**
     * @return null if LLM disabled, misconfigured, provider unsupported, HTTP error, or parse failure.
     */
    public static DiagnosisOutcome tryDiagnose(OpsIncident__c row) {
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
        OpsIncidentIntegrationLogger.logAi(
            row != null ? row.Id : null,
            'Warning',
            'Unsupported AI provider in Ops_Incident_AI_Config.Default: ' + provider,
            provider,
            null
        );
        return null;
    }

    private static String buildUserPrompt(OpsIncident__c row) {
        return 'SourceType=' +
            row.SourceType__c +
            '\nFlowApiName=' +
            row.FlowApiName__c +
            '\nApexClass=' +
            row.ApexClass__c +
            '\nErrorMessage=\n' +
            row.ErrorMessage__c +
            '\nStackTrace=\n' +
            row.StackTrace__c;
    }

    private static DiagnosisOutcome callOpenAiCompatible(Ops_Incident_AI_Config__mdt cfg, OpsIncident__c row) {
        String path = String.isNotBlank(cfg.Relative_Api_Path__c) ? cfg.Relative_Api_Path__c.trim() : 'v1/chat/completions';
        path = path.startsWith('/') ? path.substring(1) : path;

        Decimal temp = cfg.Temperature__c != null ? cfg.Temperature__c : 0.2;
        Integer maxTok = cfg.Max_Output_Tokens__c != null ? Integer.valueOf(cfg.Max_Output_Tokens__c) : 600;
        String userPayload = buildUserPrompt(row);
        String systemPrompt = diagnosisSystemPrompt();

        Map<String, Object> body = new Map<String, Object>{
            'model' => cfg.Model__c,
            'temperature' => temp,
            'max_tokens' => maxTok,
            'messages' => new List<Object>{
                new Map<String, Object>{ 'role' => 'system', 'content' => systemPrompt },
                new Map<String, Object>{ 'role' => 'user', 'content' => userPayload }
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
                OpsIncidentIntegrationLogger.logAi(
                    row != null ? row.Id : null,
                    'Error',
                    'OpenAI-compatible call failed. HTTP ' + res.getStatusCode() + ' - ' + truncate(res.getBody(), 1500),
                    cfg.Provider__c,
                    res.getStatusCode()
                );
                return null;
            }
            return parseOpenAiChatResponse(res.getBody());
        } catch (Exception ex) {
            OpsIncidentIntegrationLogger.logAi(
                row != null ? row.Id : null,
                'Error',
                'OpenAI-compatible call exception: ' + truncate(ex.getMessage(), 1500),
                cfg.Provider__c,
                null
            );
            return null;
        }
    }

    private static DiagnosisOutcome callAnthropicMessages(Ops_Incident_AI_Config__mdt cfg, OpsIncident__c row) {
        String path = String.isNotBlank(cfg.Relative_Api_Path__c) ? cfg.Relative_Api_Path__c.trim() : 'v1/messages';
        path = path.startsWith('/') ? path.substring(1) : path;

        Decimal temp = cfg.Temperature__c != null ? cfg.Temperature__c : 0.2;
        Integer maxTok = cfg.Max_Output_Tokens__c != null ? Integer.valueOf(cfg.Max_Output_Tokens__c) : 600;

        Map<String, Object> body = new Map<String, Object>{
            'model' => cfg.Model__c,
            'temperature' => temp,
            'max_tokens' => maxTok,
            'system' => diagnosisSystemPrompt(),
            'messages' => new List<Object>{
                new Map<String, Object>{ 'role' => 'user', 'content' => buildUserPrompt(row) }
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
                OpsIncidentIntegrationLogger.logAi(
                    row != null ? row.Id : null,
                    'Error',
                    'Anthropic call failed. HTTP ' + res.getStatusCode() + ' - ' + truncate(res.getBody(), 1500),
                    cfg.Provider__c,
                    res.getStatusCode()
                );
                return null;
            }
            return parseAnthropicMessagesResponse(res.getBody());
        } catch (Exception ex) {
            OpsIncidentIntegrationLogger.logAi(
                row != null ? row.Id : null,
                'Error',
                'Anthropic call exception: ' + truncate(ex.getMessage(), 1500),
                cfg.Provider__c,
                null
            );
            return null;
        }
    }

    private static String diagnosisSystemPrompt() {
        return 'You are a senior Salesforce admin and developer. '
            + 'Given an operational incident, respond with a single JSON object ONLY, no markdown, no prose. '
            + 'Schema: {"proposedFix":"<string>","confidence":<number between 0 and 1>}. '
            + 'proposedFix must be concise, actionable steps for Salesforce (Flows, Apex, security, data).';
    }

    private static DiagnosisOutcome parseOpenAiChatResponse(String httpBody) {
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
        return parseDiagnosisJson(jsonBlob);
    }

    private static DiagnosisOutcome parseAnthropicMessagesResponse(String httpBody) {
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
        return parseDiagnosisJson(jsonBlob);
    }

    private static DiagnosisOutcome parseDiagnosisJson(String jsonBlob) {
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(jsonBlob);
        Object fixObj = parsed.get('proposedFix');
        Object confObj = parsed.get('confidence');
        if (fixObj == null) {
            return null;
        }
        DiagnosisOutcome out = new DiagnosisOutcome();
        out.proposedFix = String.valueOf(fixObj);
        if (confObj != null) {
            Decimal c = Decimal.valueOf(String.valueOf(confObj));
            if (c < 0) {
                c = 0;
            }
            if (c > 1) {
                c = 1;
            }
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

    private static String truncate(String value, Integer maxLen) {
        if (value == null || maxLen == null || maxLen <= 0) {
            return value;
        }
        return value.length() > maxLen ? value.substring(0, maxLen) : value;
    }
}
