/**
 * Calls an AI vision API (Claude or OpenAI) with image (base64) + prompt to generate LWC code.
 * Parses response into HTML, JS, CSS, meta XML.
 * Provider selection: if OpenAI_Api_Key__c is set, uses GPT-4o; otherwise uses Claude.
 */
public with sharing class NF_ClaudeLwcService {
    private static final String ANTHROPIC_VERSION = '2023-06-01';
    private static final String CLAUDE_MODEL = 'claude-sonnet-4-20250514';
    private static final String OPENAI_MODEL = 'gpt-4o';
    private static final Integer MAX_TOKENS = 8192;

    public class LwcCodeResult {
        @AuraEnabled public String html;
        @AuraEnabled public String js;
        @AuraEnabled public String css;
        @AuraEnabled public String metaXml;
        @AuraEnabled public String componentName;
        @AuraEnabled public String rawResponse;
    }

    /**
     * Send image (base64 JPEG) + prompt to AI provider; parse out LWC file contents.
     * Uses OpenAI if OpenAI_Api_Key__c is set; otherwise Claude.
     */
    public static LwcCodeResult generateLwc(String imageBase64, String frameName, String prefix) {
        return generateLwcFromImages(new List<String>{ imageBase64 }, null, frameName, prefix);
    }

    /**
     * Send multiple images + prompt to AI provider in a single request.
     * imageMediaTypes: optional; when null or size mismatch, defaults to image/jpeg per image.
     */
    public static LwcCodeResult generateLwcFromImages(List<String> imagesBase64, List<String> imageMediaTypes, String frameName, String prefix) {
        NF_Figmalwc_Settings__c settings = NF_Figmalwc_Settings__c.getInstance();
        String openAiKey = settings != null ? settings.OpenAI_Api_Key__c : null;
        String claudeKey = settings != null ? settings.Claude_Api_Key__c : null;

        Boolean useOpenAi = String.isNotBlank(openAiKey);
        if (!useOpenAi && String.isBlank(claudeKey)) {
            throw new FigmaLwcException('No AI API key set. Set Claude_Api_Key__c or OpenAI_Api_Key__c in NF_Figmalwc_Settings__c (Setup > Custom Settings).');
        }

        String prompt = buildPrompt(frameName, prefix);
        if (imagesBase64.size() > 1) {
            prompt += '\n\nIMPORTANT: You are receiving ' + imagesBase64.size() + ' design screenshots. '
                + 'They are ordered by filename and represent different screens/views of the same app. '
                + 'Study ALL images together and build a single LWC that includes every screen, '
                + 'using tracked view state and navigation between them.';
        }

        String text;
        if (useOpenAi) {
            text = callOpenAiMulti(openAiKey, imagesBase64, imageMediaTypes, prompt);
        } else {
            text = callClaudeMulti(claudeKey, imagesBase64, imageMediaTypes, prompt);
        }
        imagesBase64 = null;

        return parseLwcFromResponse(text, prefix);
    }

    private static String mediaTypeForIndex(List<String> imageMediaTypes, Integer i) {
        if (imageMediaTypes == null || i >= imageMediaTypes.size()) return 'image/jpeg';
        String t = imageMediaTypes[i];
        return String.isNotBlank(t) ? t : 'image/jpeg';
    }

    private static String callClaudeMulti(String apiKey, List<String> imagesBase64, List<String> imageMediaTypes, String prompt) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.anthropic.com/v1/messages');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-api-key', apiKey);
        req.setHeader('anthropic-version', ANTHROPIC_VERSION);
        req.setTimeout(120000);

        List<Object> contentBlocks = new List<Object>();
        for (Integer i = 0; i < imagesBase64.size(); i++) {
            contentBlocks.add(new Map<String, Object>{
                'type' => 'image',
                'source' => new Map<String, Object>{
                    'type' => 'base64',
                    'media_type' => mediaTypeForIndex(imageMediaTypes, i),
                    'data' => imagesBase64[i]
                }
            });
        }
        contentBlocks.add(new Map<String, Object>{ 'type' => 'text', 'text' => prompt });

        Map<String, Object> body = new Map<String, Object>{
            'model' => CLAUDE_MODEL,
            'max_tokens' => MAX_TOKENS,
            'temperature' => 0.3,
            'messages' => new List<Map<String, Object>>{
                new Map<String, Object>{ 'role' => 'user', 'content' => contentBlocks }
            }
        };

        req.setBody(JSON.serialize(body));
        body = null;
        contentBlocks = null;

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            String errBody = res.getBody();
            if (errBody != null && errBody.contains('8000') && errBody.contains('pixel')) {
                throw new FigmaLwcException('One or more images exceed Claude\'s 8000px limit. Export frames at lower resolution (max 8000px on the longest side) and try again.');
            }
            if (errBody != null && errBody.length() > 1000) errBody = errBody.substring(0, 1000) + '...';
            throw new FigmaLwcException('Claude API error: ' + res.getStatus() + ' ' + errBody);
        }

        String rawBody = res.getBody();
        Map<String, Object> resBody = (Map<String, Object>) JSON.deserializeUntyped(rawBody);
        rawBody = null;
        List<Object> content = (List<Object>) resBody.get('content');
        resBody = null;
        String text = '';
        if (content != null) {
            for (Object c : content) {
                Map<String, Object> block = (Map<String, Object>) c;
                if ('text'.equals(block.get('type'))) text += block.get('text');
            }
        }
        content = null;
        return text;
    }

    private static String callOpenAiMulti(String apiKey, List<String> imagesBase64, List<String> imageMediaTypes, String prompt) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.openai.com/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setTimeout(120000);

        List<Object> contentBlocks = new List<Object>();
        for (Integer i = 0; i < imagesBase64.size(); i++) {
            String mediaType = mediaTypeForIndex(imageMediaTypes, i);
            contentBlocks.add(new Map<String, Object>{
                'type' => 'image_url',
                'image_url' => new Map<String, Object>{
                    'url' => 'data:' + mediaType + ';base64,' + imagesBase64[i]
                }
            });
        }
        contentBlocks.add(new Map<String, Object>{ 'type' => 'text', 'text' => prompt });

        Map<String, Object> body = new Map<String, Object>{
            'model' => OPENAI_MODEL,
            'max_tokens' => MAX_TOKENS,
            'temperature' => 0.3,
            'messages' => new List<Map<String, Object>>{
                new Map<String, Object>{ 'role' => 'user', 'content' => contentBlocks }
            }
        };

        req.setBody(JSON.serialize(body));
        body = null;
        contentBlocks = null;

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            String errBody = res.getBody();
            if (errBody != null && errBody.length() > 1000) errBody = errBody.substring(0, 1000) + '...';
            throw new FigmaLwcException('OpenAI API error: ' + res.getStatus() + ' ' + errBody);
        }

        String rawBody = res.getBody();
        Map<String, Object> resBody = (Map<String, Object>) JSON.deserializeUntyped(rawBody);
        rawBody = null;
        List<Object> choices = (List<Object>) resBody.get('choices');
        resBody = null;
        if (choices == null || choices.isEmpty()) throw new FigmaLwcException('OpenAI returned no choices.');
        Map<String, Object> firstChoice = (Map<String, Object>) choices.get(0);
        Map<String, Object> message = (Map<String, Object>) firstChoice.get('message');
        String text = message != null ? (String) message.get('content') : '';
        choices = null;
        return text != null ? text : '';
    }

    private static String buildPrompt(String frameName, String prefix) {
        String p = (prefix != null && prefix.length() > 0) ? prefix : 'nF_';
        String f = (frameName != null && frameName.length() > 0) ? frameName : 'Component';
        String safeName = f.replaceAll('[^a-zA-Z0-9]', '');
        if (safeName.length() == 0) safeName = 'Component';
        String componentName = p + safeName;

        return 'Create and deploy an LWC POC from this design.\n\n'

            + 'Use a production-quality design-to-code approach:\n'
            + '- Semantic HTML structure, SLDS where appropriate\n'
            + '- Clean LWC naming and folder structure (single component)\n'
            + '- Output will be deployed as-is; generate code that compiles and runs with no human iteration\n\n'

            + 'You are being given the actual design image(s) — the same as if you had opened the Figma URL and taken a screenshot. '
            + 'Treat these images as the single source of truth. Build from what you SEE in the image: match the screens, navigation (tabs, back, view switching), colors, typography, and layout exactly. '
            + 'Do not substitute generic layouts or placeholder content; do not assume. Use only what is visible in the provided image(s).\n\n'

            + 'COMPONENT: ' + componentName + '\n\n'

            + 'OUTPUT FORMAT (exactly four code blocks, no commentary):\n'
            + '1. ```html  - the <template> file\n'
            + '2. ```javascript  - the .js controller\n'
            + '3. ```css  - the .css stylesheet\n'
            + '4. ```xml  - the .js-meta.xml (apiVersion 64.0, isExposed true, targets: AppPage, HomePage, RecordPage)\n\n'

            + 'DESIGN FIDELITY (this is the most important requirement):\n'
            + '- Match the exact colors, gradients, shadows, and border-radius from the design\n'
            + '- Extract the exact hex colors visible in the image and use CSS custom properties (--primary, --accent, etc.)\n'
            + '- Reproduce typography: font sizes, weights, letter-spacing, line-height as seen in the design\n'
            + '- Match the exact spacing, padding, and margins visible in the design\n'
            + '- If the design shows multiple screens/views, implement ALL of them with navigation between views\n\n'

            + 'ICONS AND IMAGES:\n'
            + '- Use inline SVG for icons with strict constraints: viewBox="0 0 24 24", width/height 20-24px max\n'
            + '- SVG icons must use ONLY basic elements: <circle>, <rect>, <line>, <polyline>, <polygon>, <path>\n'
            + '- Each SVG <path> d= attribute must be UNDER 80 characters — short arcs and lines only\n'
            + '- Icon examples (use these exact patterns):\n'
            + '  Search: <svg viewBox="0 0 24 24" width="20" height="20"><circle cx="11" cy="11" r="7" fill="none" stroke="currentColor" stroke-width="2"/><line x1="16" y1="16" x2="22" y2="22" stroke="currentColor" stroke-width="2"/></svg>\n'
            + '  Plus: <svg viewBox="0 0 24 24" width="20" height="20"><line x1="12" y1="5" x2="12" y2="19" stroke="currentColor" stroke-width="2"/><line x1="5" y1="12" x2="19" y2="12" stroke="currentColor" stroke-width="2"/></svg>\n'
            + '  Star: <svg viewBox="0 0 24 24" width="16" height="16"><polygon points="12,2 15,9 22,9 16,14 18,21 12,17 6,21 8,14 2,9 9,9" fill="gold"/></svg>\n'
            + '  Arrow/chevron: <svg viewBox="0 0 24 24" width="20" height="20"><polyline points="9,18 15,12 9,6" fill="none" stroke="currentColor" stroke-width="2"/></svg>\n'
            + '- For product/card images: use a <div> with CSS gradients and border-radius to suggest the product shape — NOT large SVGs\n'
            + '  Example coffee image: div with background: radial-gradient(ellipse, #8B4513 40%, #5C3317 100%); border-radius: 50%; aspect-ratio: 1;\n'
            + '- NEVER generate SVG paths longer than 80 characters\n'
            + '- NEVER use emoji or text placeholders like [icon] or (image)\n\n'

            + 'INTERACTIVITY AND VIEW MANAGEMENT:\n'
            + '- Wire up all buttons, tabs, category filters, and navigation with real JS handlers\n'
            + '- Use tracked properties and reactive state for view switching, selections, quantities, etc.\n'
            + '- Populate data arrays with realistic mock data matching the design (product names, prices, descriptions, ratings)\n'
            + '- Implement functional search filtering, category filtering, add-to-cart, size selection — whatever the design implies\n\n'

            + 'MULTI-SCREEN RULE (critical for layout):\n'
            + '- If the design shows multiple screens (welcome, home, detail, cart, etc.), use a tracked "currentView" property\n'
            + '- Show ONLY ONE view at a time using lwc:if={isWelcomeView}, lwc:if={isHomeView}, etc.\n'
            + '- ALL views must be INSIDE the single .app-container div — NEVER place views as siblings outside it\n'
            + '- The HTML structure must be: <template> → single .app-container div → lwc:if blocks for each view\n'
            + '- NEVER render multiple views simultaneously — only the active view should be in the DOM\n\n'

            + 'NAVIGATION AND STYLE — MATCH THE IMAGE EXACTLY (this is what separates good from great output):\n'
            + '- Bottom nav: Use a single row of nav items (e.g. Home, Search, Cart, Profile). Each item: icon (SVG) + label. Track currentView as a string (e.g. \'home\', \'search\', \'cart\', \'profile\'). In JS: handleNav(evt) or handleNavHome() etc. that set currentView. Use getters: get isHomeView() { return this.currentView === \'home\'; } and same for each tab. In the template, give the active tab a class (e.g. class={navItemClass}) so it is visually highlighted (bold, accent color, or background). The nav bar must sit at the bottom INSIDE .app-container with position: absolute; bottom: 0; left: 0; right: 0; and the main content above it must have padding-bottom: 60px or 70px so it is not hidden.\n'
            + '- Back/header: If the design has a back arrow or header, wire onclick to set currentView back to the previous screen. Use a simple view stack or a single currentView that you change on back.\n'
            + '- Style from the image: Do NOT use generic grays or placeholder colors. Look at the image and copy the exact background color (often white, off-white, or a tint), the card/button colors, the border-radius (e.g. 12px, 16px, 24px), and any shadows (e.g. box-shadow: 0 2px 8px rgba(0,0,0,0.08)). Define CSS custom properties at :host or .app-container (--bg, --card-bg, --primary, --text, --radius, --shadow) and use them everywhere so the whole UI feels consistent and matches the design.\n'
            + '- Typography: Match font sizes and weights from the image (e.g. title 18px bold, body 14px, caption 12px). Use a system font stack (e.g. -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, sans-serif) if no specific font is visible.\n\n'

            + 'CSS QUALITY AND LAYOUT:\n'
            + '- The component MUST render as a centered phone-sized container:\n'
            + '  :host { display: block; max-width: 480px; margin: 0 auto; position: relative; z-index: 1; }\n'
            + '  Wrap all content in a single outer div with class "app-container" styled as:\n'
            + '  .app-container { width: 100%; max-width: 420px; height: 750px; margin: 0 auto; border-radius: 24px; overflow-y: auto; overflow-x: hidden; box-shadow: 0 8px 32px rgba(0,0,0,0.2); position: relative; }\n'
            + '- IMPORTANT: use a FIXED height (750px) on .app-container, NOT min-height — content scrolls inside via overflow-y: auto\n'
            + '- NEVER use max-height on :host — it causes overlap with other components on the page\n'
            + '- NEVER use position: fixed — it breaks out of the component container. Use position: absolute or sticky within .app-container instead\n'
            + '- Bottom navigation bars must use position: absolute; bottom: 0; width: 100%; inside .app-container (which has position: relative)\n'
            + '- When using a bottom nav, add padding-bottom (~60px) to the scrollable content area so it does not hide behind the nav\n'
            + '- Use CSS Grid and Flexbox for internal layouts\n'
            + '- Smooth transitions (0.2-0.3s) on hover, active states, and view changes\n'
            + '- Box-shadows, backdrop-filters, and gradients as seen in the design\n'
            + '- Use :host for scoping and CSS custom properties for theming\n'
            + '- All content must fit within the phone container — scrollable inside, no overflow outside\n\n'

            + 'MANDATORY LWC SYNTAX (violations = compile errors):\n'
            + '- Event handlers: onclick={handleClick}  NEVER onclick="handleClick"\n'
            + '- Dynamic values: class={computedClass}  NEVER class="{computedClass}"\n'
            + '- Conditionals: lwc:if={expr}, lwc:elseif={expr}, lwc:else\n'
            + '- No <style> or <script> tags in the template\n'
            + '- Single <template> root tag\n'
            + '- Component name must start with a lowercase letter\n'
            + '- All getter properties must use get keyword: get propertyName() { return ...; }\n'
            + '- Import { LightningElement, track } from \'lwc\';\n'
            + '- NEVER use this. inside template expressions — only use property/getter names directly\n\n'

            + 'ITERATOR KEY RULE (LWC1071 — this error is extremely common, pay close attention):\n'
            + '- Every element inside a for:each loop MUST have a key= attribute\n'
            + '- Pattern A: <template for:each={items} for:item="item"><div key={item.id}>...</div></template>\n'
            + '- Pattern B: <div for:each={items} for:item="item" key={item.id}>...</div>\n'
            + '- The key MUST be on the direct child element (Pattern A) or the same element (Pattern B)\n'
            + '- The key value must be a unique property like key={item.id} — NEVER omit it\n'
            + '- Make sure every item in your JS data arrays has an "id" property for this to work\n\n'

            + 'NO UNDEFINED IN TEMPLATE (prevents runtime "Cannot read properties of undefined"):\n'
            + '- Every property you use in the template (e.g. item.imageStyle, item.name, item.price) MUST exist on every object in the array.\n'
            + '- When building mock data arrays, give every item the same shape: include id, name, price, imageStyle, or whatever the template references — use empty string or sensible default if not applicable (e.g. imageStyle: \'\', name: \'Item\').\n'
            + '- Never reference item.someProp in the template unless someProp is guaranteed to exist on every item; otherwise the component will throw at runtime.\n\n'

            + 'OUTPUT ROBUSTNESS (prevents compiler/auto-repair errors — follow strictly):\n'
            + '- CSS: Every declaration MUST end with a semicolon. For function values (e.g. radial-gradient(...)), put the closing ); on the same line: background: radial-gradient(ellipse, #8B 40%, #5C 100%); — never leave the ) without a following semicolon. Close every { with a matching }. No unclosed blocks.\n'
            + '- HTML: End the template with </template>. Use ={expr} for bindings, never ="{expr}" or =\'{expr}\'. Every for:each must have key= on the iterated element (see iterator key rule above).\n'
            + '- JS: Close all braces and parentheses; do not leave unclosed { } or ( ). No trailing commas where invalid. Output must be parseable.\n'
            + '- CSS: Never leave the .css code block empty; output at least :host { } or one rule so the file is not empty.';
    }

    private static LwcCodeResult parseLwcFromResponse(String text, String prefix) {
        LwcCodeResult r = new LwcCodeResult();
        r.html = extractBlock(text, 'html');
        r.js = extractBlock(text, 'javascript');
        r.css = extractBlock(text, 'css');
        r.metaXml = extractBlock(text, 'xml');
        String safeName = (prefix != null && prefix.length() > 0) ? prefix.replaceAll('[^a-zA-Z0-9_]', '') : 'nF_';
        r.componentName = safeName + 'Component';
        // Only keep a short snippet for errors to avoid "JSON string exceeds heap size limit"
        r.rawResponse = (String.isBlank(r.html) || String.isBlank(r.js)) && text != null && text.length() > 0
            ? (text.length() > 2000 ? text.substring(0, 2000) + '...' : text)
            : null;
        return r;
    }

    private static String extractBlock(String text, String lang) {
        String open = '```' + lang;
        String close = '```';
        Integer start = text.indexOf(open);
        if (start < 0) return null;
        start = text.indexOf('\n', start) + 1;
        Integer endIdx = text.indexOf(close, start);
        if (endIdx < 0) endIdx = text.length();
        return text.substring(start, endIdx).trim();
    }

    public class FigmaLwcException extends Exception {}
}
