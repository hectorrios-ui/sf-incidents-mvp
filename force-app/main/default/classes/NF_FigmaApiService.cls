/**
 * Calls Figma REST API to export a node as PNG and return base64 for Claude vision.
 * Requires NF_Figmalwc_Settings__c.Figma_Token__c (Hierarchy default).
 */
public with sharing class NF_FigmaApiService {
    private static final String FIGMA_BASE = 'https://api.figma.com/v1';

    /**
     * Parse file key from Figma URL. Supports:
     * - https://www.figma.com/file/FILE_KEY/Name
     * - https://figma.com/file/FILE_KEY/Name
     * - https://www.figma.com/design/FILE_KEY/Name
     * - https://www.figma.com/proto/FILE_KEY/Name (prototype links)
     * Case-insensitive for host and path (File, DESIGN, Proto, etc.).
     */
    /**
     * Extracts file key preserving original case (Figma API can be case-sensitive).
     * Path (file/design/proto) is matched case-insensitively; key is taken from raw URL.
     */
    public static String parseFileKeyFromUrl(String url) {
        if (String.isBlank(url)) return null;
        String raw = url.trim();
        String u = raw.toLowerCase();
        String afterPath = null;
        if (u.contains('figma.com/file/')) {
            Integer idx = u.indexOf('figma.com/file/') + 15;
            afterPath = raw.substring(idx);
        } else if (u.contains('figma.com/design/')) {
            Integer idx = u.indexOf('figma.com/design/') + 17;
            afterPath = raw.substring(idx);
        } else if (u.contains('figma.com/proto/')) {
            Integer idx = u.indexOf('figma.com/proto/') + 16;
            afterPath = raw.substring(idx);
        }
        if (afterPath == null || afterPath.length() == 0) return null;
        List<String> segs = afterPath.split('/');
        String key = segs.size() > 0 ? segs[0].split('\\?')[0].trim() : null;
        return String.isNotBlank(key) ? key : null;
    }

    /**
     * Parse node ID from URL query (e.g. ?node-id=1-515 or &node-id=1-515).
     * Converts 1-515 to 1:515 for API.
     */
    public static String parseNodeIdFromUrl(String url) {
        if (String.isBlank(url)) return null;
        String u = url.trim();
        Integer idx = u.indexOf('node-id=');
        if (idx < 0) return null;
        String rest = u.substring(idx + 8);
        Integer amp = rest.indexOf('&');
        String val = amp >= 0 ? rest.substring(0, amp) : rest;
        val = val.split('\\s')[0];
        return val.replace('-', ':');
    }

    /**
     * Get image URL for a node from Figma /v1/images/:file_key.
     * Returns the first image URL (PNG).
     * On 404, retries with first page node if we had a URL node-id (proto node ids often don't match file tree).
     */
    public static String getImageUrl(String fileKey, String nodeId) {
        String token = getFigmaToken();
        if (String.isBlank(token)) throw new FigmaLwcException('Figma token not set. Set NF_Figmalwc_Settings__c.Figma_Token__c in Setup.');
        if (String.isBlank(fileKey)) throw new FigmaLwcException('Invalid Figma URL: could not parse file key. Use figma.com/file/..., figma.com/design/..., or figma.com/proto/...');

        String ids = String.isNotBlank(nodeId) ? nodeId : getFirstPageNodeId(fileKey, token);
        if (String.isBlank(ids)) throw new FigmaLwcException('Could not determine node ID. Add ?node-id=1-515 to the Figma URL or use a file with a single frame.');

        Http h = new Http();
        System.debug(LoggingLevel.INFO, 'FigmaApi: requesting images fileKey=' + fileKey + ', ids=' + ids);
        String imageUrl = getImageUrlForIds(h, token, fileKey, ids);
        if (imageUrl != null) return imageUrl;
        if (String.isNotBlank(nodeId)) {
            System.debug(LoggingLevel.INFO, 'FigmaApi: 404 on node from URL, trying first page node');
            String fallbackId = getFirstPageNodeId(fileKey, token);
            if (String.isNotBlank(fallbackId)) imageUrl = getImageUrlForIds(h, token, fileKey, fallbackId);
        }
        if (imageUrl != null) return imageUrl;
        String keyLower = fileKey.toLowerCase();
        if (!keyLower.equals(fileKey)) {
            System.debug(LoggingLevel.INFO, 'FigmaApi: retrying with lowercase file key');
            imageUrl = getImageUrlForIds(h, token, keyLower, ids);
            if (imageUrl != null) return imageUrl;
            String fallbackId = getFirstPageNodeId(keyLower, token);
            if (String.isNotBlank(fallbackId)) imageUrl = getImageUrlForIds(h, token, keyLower, fallbackId);
        }
        if (imageUrl != null) return imageUrl;
        throw new FigmaLwcException('Figma API returned 404. File key: ' + fileKey + ', node id tried: ' + ids + '. Check: (1) Your token has access to this file; (2) File is not Community-only; (3) Try the file link instead of proto, or remove node-id to use first frame.');
    }

    private static String getImageUrlForIds(Http h, String token, String fileKey, String ids) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(FIGMA_BASE + '/images/' + fileKey + '?ids=' + EncodingUtil.urlEncode(ids, 'UTF-8') + '&format=jpg&scale=0.75');
        req.setMethod('GET');
        req.setHeader('X-Figma-Token', token);
        req.setTimeout(120000);
        HttpResponse res = h.send(req);
        System.debug(LoggingLevel.INFO, 'FigmaApi: /images response status=' + res.getStatusCode() + ', body length=' + (res.getBody() != null ? res.getBody().length() : 0));
        if (res.getStatusCode() == 404) return null;
        if (res.getStatusCode() == 429) throw new FigmaLwcException(buildRateLimitMessage(res));
        if (res.getStatusCode() != 200) throw new FigmaLwcException('Figma API error: ' + res.getStatus() + ' ' + res.getBody());
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Object> images = (Map<String, Object>) body.get('images');
        if (images == null || images.isEmpty()) throw new FigmaLwcException('Figma returned no image for node.');
        Object firstUrl = images.get(ids);
        return firstUrl != null ? String.valueOf(firstUrl) : null;
    }

    /**
     * Get a node id to export: first frame of first page, or first page (canvas) if no frames.
     * Uses depth=2 so we get pages and their top-level children (frames).
     */
    private static String getFirstPageNodeId(String fileKey, String token) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(FIGMA_BASE + '/files/' + fileKey + '?depth=2');
        req.setMethod('GET');
        req.setHeader('X-Figma-Token', token);
        req.setTimeout(60000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 404) return null;
        if (res.getStatusCode() == 429) throw new FigmaLwcException(buildRateLimitMessage(res));
        if (res.getStatusCode() != 200) return null;
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Object> doc = (Map<String, Object>) body.get('document');
        if (doc == null) return null;
        List<Object> pages = (List<Object>) doc.get('children');
        if (pages == null || pages.isEmpty()) return null;
        Map<String, Object> firstPage = (Map<String, Object>) pages.get(0);
        List<Object> pageChildren = (List<Object>) firstPage.get('children');
        if (pageChildren != null && !pageChildren.isEmpty()) {
            Map<String, Object> firstChild = (Map<String, Object>) pageChildren.get(0);
            Object frameId = firstChild.get('id');
            if (frameId != null) return String.valueOf(frameId);
        }
        Object pageId = firstPage.get('id');
        return pageId != null ? String.valueOf(pageId) : null;
    }

    /**
     * Fetch image from URL and return base64 (for Claude).
     */
    public static String getImageAsBase64(String imageUrl) {
        if (String.isBlank(imageUrl)) throw new FigmaLwcException('Image URL is blank.');
        HttpRequest req = new HttpRequest();
        req.setEndpoint(imageUrl);
        req.setMethod('GET');
        req.setTimeout(60000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 429) throw new FigmaLwcException(buildRateLimitMessage(res));
        if (res.getStatusCode() != 200) throw new FigmaLwcException('Failed to fetch image: ' + res.getStatus());
        return EncodingUtil.base64Encode(res.getBodyAsBlob());
    }

    private static String getFigmaToken() {
        NF_Figmalwc_Settings__c s = NF_Figmalwc_Settings__c.getInstance();
        return s != null ? s.Figma_Token__c : null;
    }

    private static String buildRateLimitMessage(HttpResponse res) {
        String msg = 'Figma rate limit exceeded (429).';
        if (res != null && res.getHeader('Retry-After') != null) {
            String raw = res.getHeader('Retry-After').trim();
            Integer sec = raw.isNumeric() ? Integer.valueOf(raw) : null;
            if (sec != null && sec >= 1) {
                if (sec <= 3600)
                    msg += ' Figma suggests retry after ' + sec + ' seconds.';
                else if (sec <= 86400)
                    msg += ' Figma suggests retry in about ' + (sec / 3600) + ' hour(s).';
                else
                    msg += ' Figma suggests retry in about ' + (sec / 86400) + ' day(s).';
            } else
                msg += ' Wait a minute and try again.';
        } else
            msg += ' Wait a minute and try again.';
        return msg;
    }

    public class FigmaLwcException extends Exception {}
}
