/**
 * Invocable action that Agentforce calls to get accelerator recommendations.
 * Registered as an Agent Action via GenAiFunction metadata.
 * Can also be called from Flow or Process Builder.
 */
public with sharing class NF_AcceleratorRecommendAction {

    public class Input {
        @InvocableVariable(
            label='Project Record ID'
            description='The Salesforce ID of the Opportunity or Project record'
            required=false
        )
        public String recordId;

        @InvocableVariable(
            label='Cloud'
            description='Primary Salesforce cloud for the project (e.g. Service Cloud, Sales Cloud)'
            required=false
        )
        public String cloud;

        @InvocableVariable(
            label='Industry'
            description='Industry vertical (e.g. Healthcare, Financial Services)'
            required=false
        )
        public String industry;

        @InvocableVariable(
            label='Use Case'
            description='Main use case or scope of the project'
            required=false
        )
        public String useCase;

        @InvocableVariable(
            label='Keywords'
            description='Additional keywords describing the project (comma-separated)'
            required=false
        )
        public String keywords;
    }

    public class Output {
        @InvocableVariable(
            label='Top Recommendations Summary'
            description='Bullet-point list of the top recommended accelerators with fit scores and reasons. Present this directly to the user.'
        )
        public String topRecommendationsSummary;

        @InvocableVariable(
            label='AI Narrative'
            description='A 2-3 sentence AI-generated narrative explaining why these accelerators are relevant. Include this in your response.'
        )
        public String aiNarrative;

        @InvocableVariable(
            label='Total Matches Found'
            description='Total number of accelerators found matching the project context.'
        )
        public Integer totalMatches;

        @InvocableVariable(
            label='Estimated Hours Saved'
            description='Total estimated delivery hours saved across all recommended accelerators combined.'
        )
        public Integer estimatedHoursSaved;

        @InvocableVariable(
            label='Top Asset Name'
            description='Name of the highest-ranked accelerator recommendation.'
        )
        public String topAssetName;

        @InvocableVariable(
            label='Top Asset URL'
            description='Direct link to access or download the highest-ranked accelerator.'
        )
        public String topAssetUrl;

        @InvocableVariable(
            label='Top Asset Fit Score'
            description='Fit score percentage (0-100) of the highest-ranked accelerator for this project.'
        )
        public Decimal topAssetFitScore;

        @InvocableVariable(
            label='Recommendations JSON'
            description='Full JSON array of all recommendations with complete details including Knowledge Article URLs.'
        )
        public String recommendationsJson;
    }

    @InvocableMethod(
        label='Get Accelerator Recommendations'
        description='Returns ranked NeuraFlash accelerator recommendations based on project cloud, industry, use case and keywords. Use this when a user asks about reusable assets, accelerators, templates, or starter packs for a project.'
        category='Accelerator Recommender'
    )
    public static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input inp : inputs) {
            Output out = new Output();
            try {
                NF_AcceleratorController.ProjectContext ctx = new NF_AcceleratorController.ProjectContext();
                ctx.recordId  = inp.recordId  != null ? inp.recordId  : '';
                ctx.cloud     = inp.cloud     != null ? inp.cloud     : '';
                ctx.industry  = inp.industry  != null ? inp.industry  : '';
                ctx.useCase   = inp.useCase   != null ? inp.useCase   : '';
                ctx.keywords  = inp.keywords  != null ? inp.keywords  : '';

                // If the agent didn't supply cloud/industry, look them up from the Opportunity
                // so scoring matches exactly what the LWC shows.
                if (String.isNotBlank(ctx.recordId)
                        && (String.isBlank(ctx.cloud) || String.isBlank(ctx.industry))) {
                    try {
                        Opportunity opp = [
                            SELECT NF_Cloud__c, Industry__c, NF_Use_Case__c, Description
                            FROM Opportunity
                            WHERE Id = :ctx.recordId
                            LIMIT 1
                        ];
                        if (String.isBlank(ctx.cloud)    && String.isNotBlank(opp.NF_Cloud__c))    ctx.cloud    = opp.NF_Cloud__c;
                        if (String.isBlank(ctx.industry) && String.isNotBlank(opp.Industry__c))    ctx.industry = opp.Industry__c;
                        if (String.isBlank(ctx.useCase)  && String.isNotBlank(opp.NF_Use_Case__c)) ctx.useCase  = opp.NF_Use_Case__c;
                        if (String.isBlank(ctx.keywords) && String.isNotBlank(opp.Description))    ctx.keywords = opp.Description;
                    } catch (Exception ex) {
                        // Record may not be an Opportunity — silently continue with whatever context we have
                    }
                }

                NF_AcceleratorController.RecommendationResponse resp =
                    NF_AcceleratorController.getRecommendations(ctx);

                out.totalMatches       = resp.totalFound;
                out.aiNarrative        = resp.aiNarrative;
                out.estimatedHoursSaved = 0;

                List<String> summaryLines = new List<String>();
                for (NF_AcceleratorController.AcceleratorResult r : resp.results) {
                    out.estimatedHoursSaved += (r.estimatedHoursSaved != null ? r.estimatedHoursSaved : 0);
                    String line = '• ' + r.name
                        + ' (' + r.fitScore + '% fit'
                        + (r.qualityBadge == 'Verified' ? ', ✓ Verified' : '')
                        + '): ' + r.fitReason;
                    if (String.isNotBlank(r.articleUrl)) {
                        line += ' | Documentation: ' + r.articleUrl;
                    }
                    summaryLines.add(line);
                }

                if (!resp.results.isEmpty()) {
                    NF_AcceleratorController.AcceleratorResult top = resp.results[0];
                    out.topAssetName     = top.name;
                    out.topAssetUrl      = top.sourceUrl;
                    out.topAssetFitScore = top.fitScore;
                }

                out.topRecommendationsSummary = String.join(summaryLines, '\n');
                out.recommendationsJson = JSON.serialize(resp.results);

            } catch (Exception e) {
                out.aiNarrative = 'Could not retrieve recommendations: ' + e.getMessage();
                out.totalMatches = 0;
            }
            outputs.add(out);
        }
        return outputs;
    }
}
