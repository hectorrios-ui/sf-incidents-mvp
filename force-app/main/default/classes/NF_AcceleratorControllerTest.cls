@IsTest
public class NF_AcceleratorControllerTest {

    @TestSetup
    static void makeData() {
        List<NF_Accelerator__c> assets = new List<NF_Accelerator__c>{
            new NF_Accelerator__c(
                Name = 'Service Cloud Case Triage Starter',
                Description__c = 'Pre-built flows and screen flows for case triage and routing in Service Cloud.',
                Tags__c = 'case,triage,routing,service,omni-channel',
                Cloud__c = 'Service Cloud',
                Industry__c = 'Cross-Industry',
                Source__c = 'Playg',
                Source_URL__c = 'https://live.playg.app/play/case-triage-starter',
                Quality_Badge__c = 'Verified',
                Complexity__c = 'Low',
                Asset_Owner__c = 'Jane Smith',
                Last_Updated__c = Date.today().addMonths(-2),
                Estimated_Hours_Saved__c = 40,
                Use_Count__c = 12
            ),
            new NF_Accelerator__c(
                Name = 'Omni-Channel Routing Blueprint',
                Description__c = 'Configuration templates for Omni-Channel skill-based routing.',
                Tags__c = 'omni-channel,routing,skills,service,agent',
                Cloud__c = 'Service Cloud',
                Industry__c = 'Cross-Industry',
                Source__c = 'Google Drive',
                Source_URL__c = 'https://drive.google.com/drive/folders/example',
                Quality_Badge__c = 'Verified',
                Complexity__c = 'Medium',
                Asset_Owner__c = 'John Doe',
                Last_Updated__c = Date.today().addMonths(-1),
                Estimated_Hours_Saved__c = 30,
                Use_Count__c = 8
            ),
            new NF_Accelerator__c(
                Name = 'CPQ Quote Template Pack',
                Description__c = 'Standard quote templates and discount approval flows for CPQ.',
                Tags__c = 'cpq,quote,discount,approval,sales',
                Cloud__c = 'Sales Cloud',
                Industry__c = 'Cross-Industry',
                Source__c = 'OneDrive',
                Source_URL__c = 'https://onedrive.example.com/cpq-templates',
                Quality_Badge__c = 'Needs Review',
                Complexity__c = 'Medium',
                Asset_Owner__c = 'Alex Johnson',
                Last_Updated__c = Date.today().addMonths(-8),
                Estimated_Hours_Saved__c = 20,
                Use_Count__c = 3
            )
        };
        insert assets;
    }

    @IsTest
    static void testGetRecommendationsServiceCloud() {
        NF_AcceleratorController.ProjectContext ctx = new NF_AcceleratorController.ProjectContext();
        ctx.recordId = 'TESTPROJECT001';
        ctx.cloud = 'Service Cloud';
        ctx.industry = 'Healthcare';
        ctx.useCase = 'Case routing and triage';
        ctx.keywords = 'omni-channel routing';

        Test.startTest();
        NF_AcceleratorController.RecommendationResponse resp =
            NF_AcceleratorController.getRecommendations(ctx);
        Test.stopTest();

        System.assertNotEquals(null, resp);
        System.assert(resp.results.size() > 0, 'Should return at least one result');
        System.assertNotEquals(null, resp.aiNarrative);
        // Service Cloud assets should score higher
        System.assertEquals('Service Cloud Case Triage Starter', resp.results[0].name);
    }

    @IsTest
    static void testGetRecommendationsSalesCloud() {
        NF_AcceleratorController.ProjectContext ctx = new NF_AcceleratorController.ProjectContext();
        ctx.recordId = 'TESTPROJECT002';
        ctx.cloud = 'Sales Cloud';
        ctx.industry = 'Financial Services';
        ctx.useCase = 'Quote to cash';
        ctx.keywords = 'cpq quote approval';

        Test.startTest();
        NF_AcceleratorController.RecommendationResponse resp =
            NF_AcceleratorController.getRecommendations(ctx);
        Test.stopTest();

        System.assert(resp.results.size() > 0);
        // CPQ asset should surface for Sales Cloud + CPQ keywords
        Boolean foundCpq = false;
        for (NF_AcceleratorController.AcceleratorResult r : resp.results) {
            if (r.name.contains('CPQ')) foundCpq = true;
        }
        System.assert(foundCpq, 'CPQ asset should be in results');
    }

    @IsTest
    static void testSearchAccelerators() {
        NF_Accelerator__c acc = [SELECT Id FROM NF_Accelerator__c WHERE Name LIKE '%Routing%' LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ acc.Id });

        Test.startTest();
        List<NF_AcceleratorController.AcceleratorResult> results =
            NF_AcceleratorController.searchAccelerators('routing', null, null, null, null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find the routing asset');
        System.assertEquals('Omni-Channel Routing Blueprint', results[0].name);
    }

    @IsTest
    static void testSaveFeedbackUseful() {
        NF_Accelerator__c acc = [SELECT Id FROM NF_Accelerator__c LIMIT 1];
        Integer useBefore = (Integer)[SELECT Use_Count__c FROM NF_Accelerator__c WHERE Id = :acc.Id].Use_Count__c;

        Test.startTest();
        NF_AcceleratorController.saveFeedback(acc.Id, 'PROJ001', true, 'Very helpful!', 85);
        Test.stopTest();

        NF_Accelerator_Feedback__c fb = [
            SELECT Is_Useful__c, Comments__c FROM NF_Accelerator_Feedback__c
            WHERE Accelerator__c = :acc.Id LIMIT 1
        ];
        System.assertEquals(true, fb.Is_Useful__c);
        System.assertEquals('Very helpful!', fb.Comments__c);

        Integer useAfter = (Integer)[SELECT Use_Count__c FROM NF_Accelerator__c WHERE Id = :acc.Id].Use_Count__c;
        System.assertEquals(useBefore + 1, useAfter, 'Use count should increment');
    }

    @IsTest
    static void testSaveFeedbackNotUseful() {
        NF_Accelerator__c acc = [SELECT Id FROM NF_Accelerator__c LIMIT 1];

        Test.startTest();
        NF_AcceleratorController.saveFeedback(acc.Id, 'PROJ001', false, 'Not relevant', 30);
        Test.stopTest();

        NF_Accelerator_Feedback__c fb = [
            SELECT Is_Useful__c FROM NF_Accelerator_Feedback__c
            WHERE Accelerator__c = :acc.Id LIMIT 1
        ];
        System.assertEquals(false, fb.Is_Useful__c);
    }

    @IsTest
    static void testFeedbackUpsertNoDuplicate() {
        NF_Accelerator__c acc = [SELECT Id FROM NF_Accelerator__c LIMIT 1];

        Test.startTest();
        NF_AcceleratorController.saveFeedback(acc.Id, 'PROJ001', true, 'First', 80);
        NF_AcceleratorController.saveFeedback(acc.Id, 'PROJ001', false, 'Changed mind', 80);
        Test.stopTest();

        List<NF_Accelerator_Feedback__c> fbs = [
            SELECT Id FROM NF_Accelerator_Feedback__c
            WHERE Accelerator__c = :acc.Id
        ];
        System.assertEquals(1, fbs.size(), 'Should upsert, not create duplicates');
    }
}
