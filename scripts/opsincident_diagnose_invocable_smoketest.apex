OpsIncidentDiagnosisService.Request req = new OpsIncidentDiagnosisService.Request();
req.incidentId = 'a01gL00000s1613QAA';

OpsIncidentDiagnosisService.diagnose(new List<OpsIncidentDiagnosisService.Request>{ req });
System.debug('DIAGNOSE_INVOKED=true');
