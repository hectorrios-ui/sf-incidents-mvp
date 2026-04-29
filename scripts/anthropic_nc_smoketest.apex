HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Anthropic_API/v1/messages');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('anthropic-version', '2023-06-01');
req.setBody('{"model":"claude-3-5-haiku-latest","max_tokens":10,"messages":[{"role":"user","content":"ping"}]}');

HttpResponse res = new Http().send(req);
System.debug('STATUS=' + res.getStatusCode());
System.debug('BODY=' + res.getBody());
