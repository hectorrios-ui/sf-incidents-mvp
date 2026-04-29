/**
 * Entry point for Figma → LWC (Generate & Deploy). Called from nF_FigmaToLwcRequest LWC.
 */
public with sharing class NF_FigmalwcController {

    public class GenerateResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String componentName;
        @AuraEnabled public String deployId;
        @AuraEnabled public String html;
        @AuraEnabled public String js;
        @AuraEnabled public String css;
        @AuraEnabled public String metaXml;
    }

    private static final Integer MAX_ZIP_IMAGES = 6;
    private static final Set<String> IMAGE_EXTENSIONS = new Set<String>{ 'png', 'jpg', 'jpeg', 'webp' };

    /**
     * Generate LWC from a zip of design images uploaded from the browser.
     * Extracts images, sorts by filename, sends up to MAX_ZIP_IMAGES to the AI provider.
     */
    @AuraEnabled
    public static GenerateResult generateFromZip(String zipBase64, String frameName, String prefix) {
        GenerateResult result = new GenerateResult();
        result.success = false;

        try {
            if (String.isBlank(zipBase64)) {
                result.message = 'No zip file uploaded.';
                return result;
            }

            Blob zipBlob = EncodingUtil.base64Decode(zipBase64);
            zipBase64 = null;

            Compression.ZipReader reader = new Compression.ZipReader(zipBlob);
            List<Compression.ZipEntry> entries = reader.getEntries();
            zipBlob = null;

            List<String> imageNames = new List<String>();
            Map<String, Compression.ZipEntry> entryMap = new Map<String, Compression.ZipEntry>();
            for (Compression.ZipEntry entry : entries) {
                String name = entry.getName();
                if (name.contains('__MACOSX') || name.startsWith('.')) continue;
                String ext = '';
                if (name.contains('.')) ext = name.substringAfterLast('.').toLowerCase();
                if (IMAGE_EXTENSIONS.contains(ext)) {
                    imageNames.add(name);
                    entryMap.put(name, entry);
                }
            }
            entries = null;

            if (imageNames.isEmpty()) {
                result.message = 'No image files (PNG/JPG/WEBP) found in the zip.';
                return result;
            }

            imageNames.sort();
            while (imageNames.size() > MAX_ZIP_IMAGES) {
                imageNames.remove(imageNames.size() - 1);
            }

            List<String> imagesBase64 = new List<String>();
            List<String> imageMediaTypes = new List<String>();
            for (String name : imageNames) {
                Compression.ZipEntry entry = entryMap.get(name);
                Blob imgBlob = entry.getContent();
                imagesBase64.add(EncodingUtil.base64Encode(imgBlob));
                imageMediaTypes.add(mediaTypeFromFileName(name));
                imgBlob = null;
            }
            entryMap = null;
            reader = null;

            System.debug(LoggingLevel.INFO, 'ZipUpload: extracted ' + imagesBase64.size() + ' images: ' + imageNames);

            NF_ClaudeLwcService.LwcCodeResult code = NF_ClaudeLwcService.generateLwcFromImages(imagesBase64, imageMediaTypes, frameName, prefix);
            imagesBase64 = null;

            if (String.isBlank(code.html) || String.isBlank(code.js)) {
                result.message = 'AI did not return valid LWC code. Try again or check the images.' + (String.isNotBlank(code.rawResponse) ? ' ' + code.rawResponse : '');
                return result;
            }

            String compName = deriveComponentName(prefix, frameName);
            String meta = String.isNotBlank(code.metaXml) ? code.metaXml : defaultMetaXml(compName);

            code.html = repairHtml(code.html);
            code.js = repairJs(code.js);
            code.css = repairCss(code.css);
            if (String.isBlank(code.css)) code.css = ':host {}';

            String deployId = NF_LwcDeployer.deployLwc(compName, code.html, code.js, code.css, meta);

            result.success = true;
            result.message = 'LWC deployed successfully: ' + compName + ' (Deploy ID: ' + deployId + ', ' + imageNames.size() + ' images processed)';
            result.componentName = compName;
            result.deployId = deployId;

        } catch (NF_ClaudeLwcService.FigmaLwcException e) {
            result.message = e.getMessage();
        } catch (Exception e) {
            result.message = 'Error: ' + e.getMessage() + ' (Type: ' + e.getTypeName() + ')';
        }

        return result;
    }

    @AuraEnabled
    public static GenerateResult generateAndDeploy(String figmaUrl, String frameName, String prefix) {
        GenerateResult result = new GenerateResult();
        result.success = false;

        try {
            if (String.isBlank(figmaUrl)) {
                result.message = 'Please enter a Figma URL (e.g. figma.com/file/..., design/..., or proto/...).';
                return result;
            }

            String fileKey = NF_FigmaApiService.parseFileKeyFromUrl(figmaUrl);
            String nodeId = NF_FigmaApiService.parseNodeIdFromUrl(figmaUrl);
            System.debug(LoggingLevel.INFO, 'FigmaLwc: fileKey=' + fileKey + ', nodeId=' + nodeId);

            String imageUrl = NF_FigmaApiService.getImageUrl(fileKey, nodeId);
            System.debug(LoggingLevel.INFO, 'FigmaLwc: imageUrl obtained, length=' + (imageUrl != null ? imageUrl.length() : 0));
            String imageBase64 = NF_FigmaApiService.getImageAsBase64(imageUrl);
            System.debug(LoggingLevel.INFO, 'FigmaLwc: imageBase64 length=' + (imageBase64 != null ? imageBase64.length() : 0));

            NF_ClaudeLwcService.LwcCodeResult code = NF_ClaudeLwcService.generateLwc(imageBase64, frameName, prefix);
            imageBase64 = null; // release reference to reduce heap before deploy
            System.debug(LoggingLevel.INFO, 'FigmaLwc: Claude returned html=' + (code.html != null) + ', js=' + (code.js != null));

            if (String.isBlank(code.html) || String.isBlank(code.js)) {
                result.message = 'Claude did not return valid LWC code. Try again or check the design.' + (String.isNotBlank(code.rawResponse) ? ' ' + code.rawResponse : '');
                result.html = code.html;
                result.js = code.js;
                result.css = code.css;
                result.metaXml = code.metaXml;
                result.componentName = code.componentName;
                return result;
            }

            String compName = deriveComponentName(prefix, frameName);
            String meta = String.isNotBlank(code.metaXml) ? code.metaXml : defaultMetaXml(compName);

            code.html = repairHtml(code.html);
            code.js = repairJs(code.js);
            code.css = repairCss(code.css);
            if (String.isBlank(code.css)) code.css = ':host {}';

            String deployId = NF_LwcDeployer.deployLwc(compName, code.html, code.js, code.css, meta);
            System.debug(LoggingLevel.INFO, 'FigmaLwc: deployId=' + deployId);

            result.success = true;
            result.message = 'LWC deployed successfully: ' + compName + ' (Deploy ID: ' + deployId + ')';
            result.componentName = compName;
            result.deployId = deployId;
            // Don't return full code to client on success to avoid heap limit (LWC only needs message/componentName)
            result.html = null;
            result.js = null;
            result.css = null;
            result.metaXml = null;

        } catch (NF_FigmaApiService.FigmaLwcException e) {
            result.message = e.getMessage();
        } catch (NF_ClaudeLwcService.FigmaLwcException e) {
            result.message = e.getMessage();
        } catch (Exception e) {
            result.message = 'Error: ' + e.getMessage();
            result.message += ' (Type: ' + e.getTypeName() + ')';
        }

        return result;
    }

    private static String mediaTypeFromFileName(String name) {
        if (String.isBlank(name) || !name.contains('.')) return 'image/jpeg';
        String ext = name.substringAfterLast('.').toLowerCase();
        if (ext == 'png') return 'image/png';
        if (ext == 'webp') return 'image/webp';
        return 'image/jpeg';
    }

    private static String deriveComponentName(String prefix, String frameName) {
        String p = (prefix != null && prefix.length() > 0) ? prefix.replaceAll('[^a-zA-Z0-9_]', '') : 'nF_';
        String f = (frameName != null && frameName.length() > 0) ? frameName : 'Component';
        String safe = f.replaceAll('[^a-zA-Z0-9]', '');
        if (safe.length() == 0) safe = 'Component';
        String name = p + safe;
        return name.substring(0, 1).toLowerCase() + name.substring(1);
    }

    /**
     * Repair truncated CSS:
     *  - Fix missing semicolons on declaration lines (causes "Unknown word" errors)
     *  - Remove incomplete last declaration if truncated mid-value
     *  - Close unclosed braces
     */
    private static Integer countChar(String s, String c) {
        if (String.isBlank(s) || c.length() != 1) return 0;
        Integer n = 0;
        for (Integer i = 0; i < s.length(); i++) {
            if (s.substring(i, i + 1).equals(c)) n++;
        }
        return n;
    }

    private static String repairCss(String css) {
        if (String.isBlank(css)) return css;

        List<String> lines = css.split('\n');
        List<String> fixed = new List<String>();
        for (Integer i = 0; i < lines.size(); i++) {
            String line = lines[i];
            String trimmed = line.trim();
            if (String.isBlank(trimmed) || trimmed.startsWith('/*') || trimmed.startsWith('*') || trimmed.startsWith('//')) {
                fixed.add(line);
                continue;
            }
            if (trimmed.endsWith('{') || trimmed.endsWith('}') || trimmed.endsWith(';') || trimmed.endsWith(',') || trimmed.endsWith('*/')) {
                fixed.add(line);
                continue;
            }
            // End of a value like radial-gradient(...) — add semicolon so parser doesn't hit "Unknown word" on next line
            if (trimmed.endsWith(')') && !trimmed.endsWith(');')) {
                fixed.add(line + ';');
                continue;
            }
            // Line with a colon that looks like a CSS declaration missing its semicolon (skip if value continues, e.g. "radial-gradient(")
            Integer openP = countChar(trimmed, '(');
            Integer closeP = countChar(trimmed, ')');
            if (trimmed.contains(':') && !trimmed.contains('{') && openP <= closeP) {
                fixed.add(line + ';');
                continue;
            }
            // Last line might be truncated mid-value — drop it if inside a block
            if (i == lines.size() - 1 && !trimmed.contains('{') && !trimmed.contains('}')) {
                continue;
            }
            fixed.add(line);
        }
        css = String.join(fixed, '\n');

        Integer opens = 0;
        Integer closes = 0;
        for (Integer i = 0; i < css.length(); i++) {
            String ch = css.substring(i, i + 1);
            if (ch == '{') opens++;
            else if (ch == '}') closes++;
        }
        Integer missing = opens - closes;
        if (missing > 0) {
            String suffix = '\n';
            for (Integer i = 0; i < missing; i++) suffix += '}\n';
            css += suffix;
        }
        return css;
    }

    /**
     * Repair truncated JS by closing unclosed braces/parens.
     */
    private static String repairJs(String js) {
        if (String.isBlank(js)) return js;
        Integer braces = 0;
        Integer parens = 0;
        Boolean inString = false;
        String strChar = '';
        for (Integer i = 0; i < js.length(); i++) {
            String ch = js.substring(i, i + 1);
            if (inString) {
                if (ch == strChar && (i == 0 || js.substring(i - 1, i) != '\\')) inString = false;
                continue;
            }
            if (ch == '\'' || ch == '"' || ch == '`') { inString = true; strChar = ch; }
            else if (ch == '{') braces++;
            else if (ch == '}') braces--;
            else if (ch == '(') parens++;
            else if (ch == ')') parens--;
        }
        String suffix = '';
        for (Integer i = 0; i < parens; i++) suffix += ')';
        for (Integer i = 0; i < braces; i++) suffix += '\n}';
        if (suffix.length() > 0) js += suffix + '\n';
        return js;
    }

    /**
     * Fix ="{expr}" or ='{expr}' → ={expr} by finding the matching } for the opening { (handles nested braces/ternaries).
     */
    private static String fixQuotedBindings(String html, String quote) {
        String eqQuote = '=' + quote;
        Integer idx = 0;
        while (idx < html.length()) {
            Integer start = html.indexOf(eqQuote, idx);
            if (start < 0) break;
            Integer open = start + eqQuote.length();
            if (open >= html.length()) break;
            if (html.substring(open, open + 1) != '{') {
                idx = open + 1;
                continue;
            }
            Integer braceStart = open;
            Integer depth = 1;
            Integer pos = open + 1;
            Boolean inString = false;
            String strChar = '';
            while (pos < html.length() && depth > 0) {
                String c = html.substring(pos, pos + 1);
                if (inString) {
                    if (c == strChar && (pos == 0 || html.substring(pos - 1, pos) != '\\')) inString = false;
                    pos++;
                    continue;
                }
                if (c == '\'' || c == '"') { inString = true; strChar = c; pos++; continue; }
                if (c == '{') { depth++; pos++; continue; }
                if (c == '}') { depth--; if (depth == 0) break; pos++; continue; }
                pos++;
            }
            if (depth != 0) { idx = start + 1; continue; }
            Integer braceEnd = pos;
            if (braceEnd < html.length() && html.substring(braceEnd, braceEnd + 1) == quote) {
                String expr = html.substring(braceStart, braceEnd + 1);
                String fixed = '={' + expr.substring(1, expr.length() - 1) + '}';
                html = html.substring(0, start) + fixed + html.substring(braceEnd + 1);
                idx = start + fixed.length();
            } else {
                idx = braceEnd + 1;
            }
        }
        return html;
    }

    /**
     * Remove duplicate attributes within each opening tag (fixes LWC1058 duplicate-attribute).
     * Keeps the first occurrence of each attribute name.
     */
    private static String removeDuplicateAttributes(String html) {
        Integer i = 0;
        while (i < html.length()) {
            Integer open = html.indexOf('<', i);
            if (open < 0) break;
            Integer next = open + 1;
            if (next >= html.length()) break;
            String nextCh = html.substring(next, next + 1);
            if (nextCh.equals('/') || nextCh.equals('!') || nextCh.equals('?')) {
                i = next;
                continue;
            }
            Integer close = html.indexOf('>', next);
            if (close < 0) break;
            String tagContent = html.substring(open, close + 1);
            Integer tagLen = tagContent.length();
            List<Integer> removeStart = new List<Integer>();
            List<Integer> removeEnd = new List<Integer>();
            Set<String> seen = new Set<String>();
            Integer pos = 1;
            while (pos < tagLen) {
                while (pos < tagLen && (tagContent.substring(pos, pos + 1).equals(' ') || tagContent.substring(pos, pos + 1).equals('\t') || tagContent.substring(pos, pos + 1).equals('\n') || tagContent.substring(pos, pos + 1).equals('\r'))) pos++;
                if (pos >= tagLen) break;
                Integer attrStart = pos;
                Integer nameStart = pos;
                while (pos < tagLen) {
                    String c = tagContent.substring(pos, pos + 1);
                    if (c.equals('=')) break;
                    if (c.equals(' ') || c.equals('>') || c.equals('\t') || c.equals('\n')) break;
                    pos++;
                }
                if (pos >= tagLen || !tagContent.substring(pos, pos + 1).equals('=')) { i = close + 1; break; }
                String attrName = tagContent.substring(nameStart, pos).toLowerCase();
                pos++;
                if (pos >= tagLen) break;
                String vStart = tagContent.substring(pos, pos + 1);
                Integer valueEnd = pos;
                if (vStart.equals('"')) {
                    valueEnd = tagContent.indexOf('"', pos + 1);
                    if (valueEnd < 0) break;
                    valueEnd++;
                } else if (vStart.equals('\'')) {
                    valueEnd = tagContent.indexOf('\'', pos + 1);
                    if (valueEnd < 0) break;
                    valueEnd++;
                } else if (vStart.equals('{')) {
                    Integer depth = 1;
                    valueEnd = pos + 1;
                    while (valueEnd < tagLen && depth > 0) {
                        String ch = tagContent.substring(valueEnd, valueEnd + 1);
                        if (ch.equals('{')) depth++;
                        else if (ch.equals('}')) depth--;
                        valueEnd++;
                    }
                } else {
                    i = close + 1;
                    break;
                }
                pos = valueEnd;
                if (seen.contains(attrName)) {
                    Integer start = (nameStart > 0 && tagContent.substring(nameStart - 1, nameStart).equals(' ')) ? nameStart - 1 : attrStart;
                    removeStart.add(start);
                    removeEnd.add(pos);
                } else {
                    seen.add(attrName);
                }
            }
            for (Integer r = removeStart.size() - 1; r >= 0; r--) {
                tagContent = tagContent.substring(0, removeStart[r]) + tagContent.substring(removeEnd[r]);
            }
            if (!removeStart.isEmpty()) {
                html = html.substring(0, open) + tagContent + html.substring(close + 1);
                i = open + tagContent.length();
            } else {
                i = close + 1;
            }
        }
        return html;
    }

    /**
     * Repair HTML:
     *  - Fix ="{expr}" / ='{expr}' → ={expr} (LWC1058); brace-aware so ternaries work
     *  - Remove duplicate attributes (LWC1058 duplicate-attribute)
     *  - Add missing key= on for:each elements (LWC1071)
     *  - Close unclosed template tag
     */
    private static String repairHtml(String html) {
        if (String.isBlank(html)) return html;

        // Fix quoted bindings (LWC1058): ="{expr}" or ='{expr}' → ={expr}. Brace-aware so {a ? 'x' : 'y'} works.
        html = fixQuotedBindings(html, '"');
        html = fixQuotedBindings(html, '\'');

        // Remove duplicate attributes (LWC1058 duplicate-attribute) — e.g. key= added twice
        html = removeDuplicateAttributes(html);

        // Fix missing key= on for:each elements (LWC1071)
        html = addMissingIteratorKeys(html);

        String trimmed = html.trim().toLowerCase();
        if (!trimmed.endsWith('</template>')) {
            html = html.trim() + '\n</template>';
        }
        return html;
    }

    /**
     * Find for:each iterators missing key= and add it.
     * Handles two LWC patterns:
     *   1) <template for:each={x} for:item="y"> <div ...> → key goes on <div>
     *   2) <div for:each={x} for:item="y" ...> → key goes on same <div>
     * Works on full HTML string to handle multi-line tags.
     */
    private static String addMissingIteratorKeys(String html) {
        Integer pos = 0;
        while (pos < html.length()) {
            Integer feIdx = html.indexOf('for:each=', pos);
            if (feIdx < 0) break;

            String itemVar = 'item';
            Integer fiIdx = html.indexOf('for:item="', feIdx);
            if (fiIdx > 0 && fiIdx < feIdx + 200) {
                Integer fiEnd = html.indexOf('"', fiIdx + 10);
                if (fiEnd > 0) itemVar = html.substring(fiIdx + 10, fiEnd);
            }

            Integer tagStart = html.lastIndexOf('<', feIdx);
            Integer tagEnd = html.indexOf('>', feIdx);
            if (tagStart < 0 || tagEnd < 0) { pos = feIdx + 9; continue; }

            String fullTag = html.substring(tagStart, tagEnd + 1);
            String tagLower = fullTag.toLowerCase();
            Boolean isTemplate = tagLower.startsWith('<template');

            if (isTemplate) {
                Integer childStart = html.indexOf('<', tagEnd + 1);
                if (childStart < 0) { pos = tagEnd + 1; continue; }
                if (html.substring(childStart).startsWith('</')) { pos = tagEnd + 1; continue; }

                Integer childEnd = html.indexOf('>', childStart);
                if (childEnd < 0) { pos = tagEnd + 1; continue; }

                String childTag = html.substring(childStart, childEnd + 1);
                if (!childTag.contains('key=')) {
                    String keyAttr = ' key={' + itemVar + '.id}';
                    html = html.substring(0, childEnd) + keyAttr + html.substring(childEnd);
                }
                pos = childEnd + 1;
            } else {
                if (!fullTag.contains('key=')) {
                    String keyAttr = ' key={' + itemVar + '.id}';
                    html = html.substring(0, tagEnd) + keyAttr + html.substring(tagEnd);
                }
                pos = tagEnd + 1;
            }
        }
        return html;
    }

    private static String defaultMetaXml(String componentName) {
        String folder = componentName.substring(0, 1).toLowerCase() + componentName.substring(1);
        return '<?xml version="1.0" encoding="UTF-8"?>'
            + '<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">'
            + '<apiVersion>64.0</apiVersion><isExposed>true</isExposed>'
            + '<targets><target>lightning__AppPage</target><target>lightning__HomePage</target><target>lightning__RecordPage</target></targets>'
            + '</LightningComponentBundle>';
    }
}
