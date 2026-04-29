HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Anthropic_API/v1/models');
req.setMethod('GET');
req.setHeader('anthropic-version', '2023-06-01');

HttpResponse res = new Http().send(req);
System.debug('STATUS=' + res.getStatusCode());
System.debug('BODY=' + res.getBody());
