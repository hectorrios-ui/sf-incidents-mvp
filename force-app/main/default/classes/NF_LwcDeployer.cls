/**
 * Deploys LWC source to the org via Metadata API (zip + deployRequest).
 * Uses Compression.ZipWriter (GA in Spring '25).
 * The REST deploy endpoint requires multipart/form-data with two parts:
 *   entity_content (JSON deploy options) and file (zip binary).
 * After submitting, polls the deploy status until it succeeds or fails.
 */
public with sharing class NF_LwcDeployer {

    private static final String CRLF = '\r\n';
    private static final String BOUNDARY = '----SfDeployBoundary';
    private static final Integer MAX_POLL_ATTEMPTS = 25;
    private static final Integer POLL_WAIT_MS = 3000;
    private static final String NC_BASE = 'callout:Figmalwc_Org/services/data/v64.0/metadata/deployRequest';

    public static String deployLwc(String componentName, String html, String js, String css, String metaXml) {
        if (String.isBlank(componentName) || componentName.length() > 255)
            throw new NF_FigmaApiService.FigmaLwcException('Invalid component name.');
        String folderName = componentName.substring(0, 1).toLowerCase() + componentName.substring(1);

        String packageXml = '<?xml version="1.0" encoding="UTF-8"?>'
            + '<Package xmlns="http://soap.sforce.com/2006/04/metadata">'
            + '<types><members>' + componentName + '</members><name>LightningComponentBundle</name></types>'
            + '<version>64.0</version></Package>';

        Compression.ZipWriter zipWriter = new Compression.ZipWriter();
        zipWriter.addEntry('package.xml', Blob.valueOf(packageXml));
        zipWriter.addEntry('lwc/' + folderName + '/' + folderName + '.html', Blob.valueOf(html != null ? html : ''));
        zipWriter.addEntry('lwc/' + folderName + '/' + folderName + '.js', Blob.valueOf(js != null ? js : ''));
        zipWriter.addEntry('lwc/' + folderName + '/' + folderName + '.css', Blob.valueOf(String.isNotBlank(css) ? css : ':host {}'));
        zipWriter.addEntry('lwc/' + folderName + '/' + folderName + '.js-meta.xml', Blob.valueOf(metaXml != null ? metaXml : ''));

        Blob zipBlob = zipWriter.getArchive();
        String zipB64 = EncodingUtil.base64Encode(zipBlob);

        String deployOptionsJson = '{"deployOptions":{'
            + '"allowMissingFiles":false,'
            + '"checkOnly":false,'
            + '"ignoreWarnings":true,'
            + '"rollbackOnError":true,'
            + '"singlePackage":true'
            + '}}';

        Blob bodyBlob = buildMultipartBody(deployOptionsJson, zipB64);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NC_BASE);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + BOUNDARY);
        req.setTimeout(120000);
        req.setBodyAsBlob(bodyBlob);

        Http h = new Http();
        HttpResponse res = h.send(req);
        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            String errBody = res.getBody();
            if (errBody != null && errBody.length() > 2000) errBody = errBody.substring(0, 2000) + '...';
            throw new NF_FigmaApiService.FigmaLwcException('Deploy request failed: ' + res.getStatus() + ' ' + errBody);
        }

        String resBody = res.getBody();
        Map<String, Object> result = resBody != null ? (Map<String, Object>) JSON.deserializeUntyped(resBody) : new Map<String, Object>();
        String deployId = (String) result.get('id');
        if (deployId == null) throw new NF_FigmaApiService.FigmaLwcException('No deploy id in response.');

        pollDeployResult(deployId);
        return deployId;
    }

    /**
     * Polls GET deployRequest/{id}?includeDetails=true until the deploy
     * reaches a terminal status (Succeeded / Failed / Canceled).
     * Throws with component-level error details on failure.
     */
    private static void pollDeployResult(String deployId) {
        Http h = new Http();
        for (Integer i = 0; i < MAX_POLL_ATTEMPTS; i++) {
            if (i > 0 && !Test.isRunningTest()) {
                Long endWait = System.currentTimeMillis() + POLL_WAIT_MS;
                while (System.currentTimeMillis() < endWait) { }
            }
            HttpRequest req = new HttpRequest();
            req.setEndpoint(NC_BASE + '/' + deployId + '?includeDetails=true');
            req.setMethod('GET');
            req.setTimeout(30000);

            HttpResponse res = h.send(req);
            if (res.getStatusCode() != 200) {
                throw new NF_FigmaApiService.FigmaLwcException(
                    'Deploy status check failed (HTTP ' + res.getStatusCode() + '): '
                    + truncate(res.getBody(), 1000)
                );
            }

            Map<String, Object> wrapper = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> dr = (Map<String, Object>) wrapper.get('deployResult');
            if (dr == null) continue;

            String status = (String) dr.get('status');
            if (status == null) continue;

            if (status.equalsIgnoreCase('Succeeded')) return;

            if (status.equalsIgnoreCase('Failed') || status.equalsIgnoreCase('Canceled')) {
                throw new NF_FigmaApiService.FigmaLwcException(
                    'Deployment ' + status + '. ' + extractComponentErrors(dr)
                );
            }
        }
        throw new NF_FigmaApiService.FigmaLwcException(
            'Deployment still in progress after polling. Check Deployment Status in Setup.'
        );
    }

    private static String extractComponentErrors(Map<String, Object> deployResult) {
        try {
            Map<String, Object> details = (Map<String, Object>) deployResult.get('details');
            if (details == null) return '';
            Object failuresObj = details.get('componentFailures');
            if (failuresObj == null) return '';

            List<Object> failures;
            if (failuresObj instanceof List<Object>) {
                failures = (List<Object>) failuresObj;
            } else {
                failures = new List<Object>{ failuresObj };
            }

            String msg = '';
            for (Object f : failures) {
                Map<String, Object> fail = (Map<String, Object>) f;
                String problem = (String) fail.get('problem');
                String fullName = (String) fail.get('fullName');
                Object line = fail.get('lineNumber');
                Object col = fail.get('columnNumber');
                msg += (msg.length() > 0 ? ' | ' : '')
                    + (fullName != null ? fullName : '')
                    + (line != null ? ' line ' + line : '')
                    + (col != null ? ' col ' + col : '')
                    + ': ' + (problem != null ? problem : '(unknown)');
            }
            return truncate(msg, 1500);
        } catch (Exception e) {
            return '(could not parse error details)';
        }
    }

    private static String truncate(String s, Integer maxLen) {
        if (s == null) return '';
        return s.length() > maxLen ? s.substring(0, maxLen) + '...' : s;
    }

    /**
     * Builds a multipart/form-data body containing the JSON deploy options and
     * binary zip file. Uses the base64-concatenation technique because Apex
     * HttpRequest cannot mix text and binary natively.
     */
    private static Blob buildMultipartBody(String deployOptionsJson, String zipB64) {
        String header = '--' + BOUNDARY + CRLF
            + 'Content-Disposition: form-data; name="entity_content"' + CRLF
            + 'Content-Type: application/json' + CRLF + CRLF
            + deployOptionsJson + CRLF
            + '--' + BOUNDARY + CRLF
            + 'Content-Disposition: form-data; name="file"; filename="deploy.zip"' + CRLF
            + 'Content-Type: application/zip' + CRLF + CRLF;

        String footer = CRLF + '--' + BOUNDARY + '--';

        String headerB64 = EncodingUtil.base64Encode(Blob.valueOf(header));
        while (headerB64.endsWith('=')) {
            header += ' ';
            headerB64 = EncodingUtil.base64Encode(Blob.valueOf(header));
        }

        String footerB64 = EncodingUtil.base64Encode(Blob.valueOf(footer));

        String last4 = zipB64.substring(zipB64.length() - 4, zipB64.length());
        if (last4.endsWith('=')) {
            Blob decoded = EncodingUtil.base64Decode(last4);
            HttpRequest tmp = new HttpRequest();
            tmp.setBodyAsBlob(decoded);
            String last4WithFooter = tmp.getBody() + footer;
            return EncodingUtil.base64Decode(
                headerB64 + zipB64.substring(0, zipB64.length() - 4) + EncodingUtil.base64Encode(Blob.valueOf(last4WithFooter))
            );
        }
        return EncodingUtil.base64Decode(headerB64 + zipB64 + footerB64);
    }
}
