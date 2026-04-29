public with sharing class NF_AcceleratorController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class ProjectContext {
        @AuraEnabled public String recordId;
        @AuraEnabled public String cloud;
        @AuraEnabled public String industry;
        @AuraEnabled public String useCase;
        @AuraEnabled public String keywords;
    }

    public class AcceleratorResult {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public String tags;
        @AuraEnabled public String cloud;
        @AuraEnabled public String industry;
        @AuraEnabled public String source;
        @AuraEnabled public String sourceUrl;
        @AuraEnabled public String qualityBadge;
        @AuraEnabled public String complexity;
        @AuraEnabled public String assetOwner;
        @AuraEnabled public String lastUpdated;
        @AuraEnabled public Integer estimatedHoursSaved;
        @AuraEnabled public Integer useCount;
        @AuraEnabled public Decimal fitScore;
        @AuraEnabled public String fitReason;
        @AuraEnabled public String aiSummary;
        @AuraEnabled public String articleUrl;
        @AuraEnabled public Boolean userFeedbackGiven;
        @AuraEnabled public Boolean userFoundUseful;
    }

    public class RecommendationResponse {
        @AuraEnabled public List<AcceleratorResult> results;
        @AuraEnabled public Integer totalFound;
        @AuraEnabled public String aiNarrative;
        @AuraEnabled public Boolean isAiEnhanced;
    }

    // ─── Get Recommendations ─────────────────────────────────────────────────

    @AuraEnabled
    public static RecommendationResponse getRecommendations(
        String recordId,
        String cloud,
        String industry,
        String useCase,
        String keywords
    ) {
        // Flat params avoid the inner-class JSON deserialisation issue that silently nulls all fields
        ProjectContext ctx = new ProjectContext();
        ctx.recordId = recordId  != null ? recordId  : '';
        ctx.cloud    = cloud     != null ? cloud     : '';
        ctx.industry = industry  != null ? industry  : '';
        ctx.useCase  = useCase   != null ? useCase   : '';
        ctx.keywords = keywords  != null ? keywords  : '';
        return getRecommendationsInternal(ctx);
    }

    // Internal helper kept so NF_AcceleratorRecommendAction can pass a fully-built context
    public static RecommendationResponse getRecommendations(ProjectContext ctx) {
        return getRecommendationsInternal(ctx);
    }

    private static RecommendationResponse getRecommendationsInternal(ProjectContext ctx) {
        try {
            List<NF_Accelerator__c> candidates = queryCandidates(ctx);
            Map<Id, NF_Accelerator_Feedback__c> feedbackMap = getUserFeedbackMap(
                ctx.recordId,
                new Map<Id, NF_Accelerator__c>(candidates).keySet()
            );

            List<AcceleratorResult> scored = scoreAndRank(candidates, ctx, feedbackMap);

            RecommendationResponse resp = new RecommendationResponse();
            List<AcceleratorResult> capped = new List<AcceleratorResult>();
            for (Integer i = 0; i < Math.min(8, scored.size()); i++) {
                capped.add(scored[i]);
            }
            resp.results = capped;
            resp.totalFound = scored.size();

            // Attempt Einstein Prompt Template narrative — fall back to rule-based if unavailable
            String einsteinNarrative = generateEinsteinNarrative(ctx, resp.results);
            if (String.isNotBlank(einsteinNarrative)) {
                resp.aiNarrative = einsteinNarrative;
                resp.isAiEnhanced = true;
            } else {
                resp.aiNarrative = buildNarrative(ctx, resp.results);
                resp.isAiEnhanced = false;
            }
            return resp;

        } catch (Exception e) {
            throw new AuraHandledException('Error getting recommendations: ' + e.getMessage());
        }
    }

    // ─── Get Project Context from Opportunity ────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static ProjectContext getOpportunityContext(Id recordId) {
        try {
            Opportunity opp = [
                SELECT Id, Name, Type, Industry__c, Description,
                       NF_Cloud__c, NF_Use_Case__c
                FROM Opportunity
                WHERE Id = :recordId
                LIMIT 1
            ];

            ProjectContext ctx = new ProjectContext();
            ctx.recordId = opp.Id;
            ctx.cloud = opp.NF_Cloud__c;
            ctx.industry = opp.Industry__c;
            ctx.useCase = opp.NF_Use_Case__c;
            ctx.keywords = opp.Description;
            return ctx;

        } catch (Exception e) {
            // Return empty context if fields don't exist yet — graceful degradation
            ProjectContext ctx = new ProjectContext();
            ctx.recordId = recordId;
            return ctx;
        }
    }

    // ─── Save Feedback ───────────────────────────────────────────────────────

    @AuraEnabled
    public static void saveFeedback(
        Id acceleratorId,
        String projectRecordId,
        Boolean isUseful,
        String comments,
        Decimal fitScore
    ) {
        try {
            // Upsert by accelerator + project to avoid duplicates
            List<NF_Accelerator_Feedback__c> existing = [
                SELECT Id FROM NF_Accelerator_Feedback__c
                WHERE Accelerator__c = :acceleratorId
                  AND Project_Record_Id__c = :projectRecordId
                  AND CreatedById = :UserInfo.getUserId()
                LIMIT 1
            ];

            NF_Accelerator_Feedback__c fb;
            if (!existing.isEmpty()) {
                fb = existing[0];
            } else {
                fb = new NF_Accelerator_Feedback__c();
                fb.Accelerator__c = acceleratorId;
                fb.Project_Record_Id__c = projectRecordId;
                fb.Fit_Score_At_Recommendation__c = fitScore;
            }
            fb.Is_Useful__c = isUseful;
            fb.Comments__c = comments;
            upsert fb;

            // Increment use count on the accelerator when marked useful
            if (isUseful) {
                NF_Accelerator__c acc = new NF_Accelerator__c(
                    Id = acceleratorId,
                    Use_Count__c = [SELECT Use_Count__c FROM NF_Accelerator__c WHERE Id = :acceleratorId LIMIT 1].Use_Count__c + 1
                );
                update acc;
            }

        } catch (Exception e) {
            throw new AuraHandledException('Error saving feedback: ' + e.getMessage());
        }
    }

    // ─── Search (free-text override) ──────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<AcceleratorResult> searchAccelerators(
        String searchTerm,
        String cloud,
        String industry,
        String useCase,
        String recordId
    ) {
        try {
            String term = String.escapeSingleQuotes(searchTerm.trim());

            List<List<SObject>> soslResults = [
                FIND :term
                IN ALL FIELDS
                RETURNING NF_Accelerator__c(
                    Id, Name, Description__c, Tags__c, Cloud__c, Industry__c,
                    Source__c, Source_URL__c, Knowledge_Article_URL__c, Quality_Badge__c, Complexity__c,
                    Asset_Owner__c, Last_Updated__c, Estimated_Hours_Saved__c, Use_Count__c
                    WHERE Quality_Badge__c != 'Deprecated'
                    ORDER BY Use_Count__c DESC
                    LIMIT 20
                )
            ];

            List<NF_Accelerator__c> candidates = new List<NF_Accelerator__c>();
            for (SObject s : soslResults[0]) {
                candidates.add((NF_Accelerator__c) s);
            }

            // Build context from individual params — avoids inner-class deserialisation issues
            ProjectContext scoreCtx = new ProjectContext();
            scoreCtx.recordId = recordId  != null ? recordId  : '';
            scoreCtx.cloud    = cloud     != null ? cloud     : '';
            scoreCtx.industry = industry  != null ? industry  : '';
            scoreCtx.useCase  = useCase   != null ? useCase   : '';
            scoreCtx.keywords = term;

            Map<Id, NF_Accelerator_Feedback__c> feedbackMap = getUserFeedbackMap(
                scoreCtx.recordId,
                new Map<Id, NF_Accelerator__c>(candidates).keySet()
            );
            List<AcceleratorResult> scored = scoreAndRank(candidates, scoreCtx, feedbackMap);

            for (AcceleratorResult r : scored) {
                r.fitReason = 'Keyword: "' + term + '" · ' + r.fitReason;
            }
            return scored;

        } catch (Exception e) {
            throw new AuraHandledException('Error searching: ' + e.getMessage());
        }
    }

    // ─── Private: Query Candidates ────────────────────────────────────────────

    private static List<NF_Accelerator__c> queryCandidates(ProjectContext ctx) {
        List<String> conditions = new List<String>{
            'Quality_Badge__c != \'Deprecated\''
        };

        String query = 'SELECT Id, Name, Description__c, Tags__c, Cloud__c, Industry__c, '
            + 'Source__c, Source_URL__c, Knowledge_Article_URL__c, Quality_Badge__c, Complexity__c, '
            + 'Asset_Owner__c, Last_Updated__c, Estimated_Hours_Saved__c, Use_Count__c '
            + 'FROM NF_Accelerator__c '
            + 'WHERE ' + String.join(conditions, ' AND ')
            + ' ORDER BY Use_Count__c DESC, Last_Updated__c DESC '
            + 'LIMIT 50';

        return Database.query(query);
    }

    // ─── Private: Score & Rank ────────────────────────────────────────────────

    private static List<AcceleratorResult> scoreAndRank(
        List<NF_Accelerator__c> candidates,
        ProjectContext ctx,
        Map<Id, NF_Accelerator_Feedback__c> feedbackMap
    ) {
        List<ScoredResult> scored = new List<ScoredResult>();

        Set<String> contextTokens = tokenize(
            (ctx.cloud       == null ? '' : ctx.cloud) + ' ' +
            (ctx.industry    == null ? '' : ctx.industry) + ' ' +
            (ctx.useCase     == null ? '' : ctx.useCase) + ' ' +
            (ctx.keywords    == null ? '' : ctx.keywords)
        );

        for (NF_Accelerator__c acc : candidates) {
            Decimal score = 0;
            List<String> reasons = new List<String>();

            Set<String> assetTokens = tokenize(
                (acc.Tags__c         == null ? '' : acc.Tags__c) + ' ' +
                (acc.Description__c  == null ? '' : acc.Description__c) + ' ' +
                (acc.Cloud__c        == null ? '' : acc.Cloud__c) + ' ' +
                (acc.Industry__c     == null ? '' : acc.Industry__c)
            );

            // Tag overlap score (up to 50 pts)
            Integer overlap = 0;
            for (String token : contextTokens) {
                if (assetTokens.contains(token)) overlap++;
            }
            if (!contextTokens.isEmpty()) {
                Decimal tagScore = (Decimal.valueOf(overlap) / contextTokens.size()) * 50;
                score += tagScore;
                if (overlap > 0) reasons.add(overlap + ' keyword match(es)');
            }

            // Cloud match (35 pts exact; Cross-Cloud assets get neutral 0)
            if (String.isNotBlank(ctx.cloud)) {
                if (String.isNotBlank(acc.Cloud__c) && acc.Cloud__c.containsIgnoreCase(ctx.cloud)) {
                    score += 35;
                    reasons.add('Cloud match: ' + ctx.cloud);
                } else if (String.isNotBlank(acc.Cloud__c)
                    && !acc.Cloud__c.containsIgnoreCase('Cross')
                    && !acc.Cloud__c.containsIgnoreCase('All')) {
                    // Asset targets a different specific cloud — penalise
                    score -= 15;
                }
            }

            // Industry match (25 pts exact, 10 pts for Cross-Industry)
            if (String.isNotBlank(ctx.industry)) {
                if (String.isNotBlank(acc.Industry__c)
                    && acc.Industry__c.containsIgnoreCase(ctx.industry)) {
                    score += 25;
                    reasons.add('Industry match: ' + ctx.industry);
                } else if (String.isNotBlank(acc.Industry__c)
                    && acc.Industry__c.containsIgnoreCase('Cross-Industry')) {
                    score += 10;
                    reasons.add('Cross-industry asset');
                }
            }

            // Quality badge bonus (10 pts for Verified)
            if (acc.Quality_Badge__c == 'Verified') {
                score += 10;
                reasons.add('Verified asset');
            }

            // Recency bonus — assets updated in last 6 months (+5 pts)
            if (acc.Last_Updated__c != null
                && acc.Last_Updated__c >= Date.today().addMonths(-6)) {
                score += 5;
                reasons.add('Recently updated');
            }

            // Popularity bonus — capped lower so it can't override cloud/industry signals
            if (acc.Use_Count__c != null && acc.Use_Count__c > 0) {
                score += Math.min(acc.Use_Count__c, 10) * 0.3;
            }

            // Feedback penalty — if current user previously marked not useful, lower score
            if (feedbackMap.containsKey(acc.Id)) {
                NF_Accelerator_Feedback__c fb = feedbackMap.get(acc.Id);
                if (!fb.Is_Useful__c) score -= 20;
            }

            AcceleratorResult r = mapToResult(acc);
            // Normalize to 0-100: max possible raw score is 128 (50 keywords + 35 cloud + 25 industry + 10 badge + 5 recency + 3 popularity)
            Decimal normalised = (score / 128) * 100;
            r.fitScore = Math.max(0, Math.min(100, normalised)).setScale(0);
            r.fitReason = reasons.isEmpty() ? 'General match' : String.join(reasons, ' · ');
            if (feedbackMap.containsKey(acc.Id)) {
                r.userFeedbackGiven = true;
                r.userFoundUseful = feedbackMap.get(acc.Id).Is_Useful__c;
            } else {
                r.userFeedbackGiven = false;
                r.userFoundUseful = false;
            }

            scored.add(new ScoredResult(r, score));
        }

        scored.sort();
        List<AcceleratorResult> sorted = new List<AcceleratorResult>();
        for (ScoredResult s : scored) {
            sorted.add(s.result);
        }
        return sorted;
    }

    // ─── Private: User Feedback Map ──────────────────────────────────────────

    private static Map<Id, NF_Accelerator_Feedback__c> getUserFeedbackMap(
        String projectRecordId,
        Set<Id> acceleratorIds
    ) {
        Map<Id, NF_Accelerator_Feedback__c> result = new Map<Id, NF_Accelerator_Feedback__c>();
        if (String.isBlank(projectRecordId) || acceleratorIds.isEmpty()) return result;

        for (NF_Accelerator_Feedback__c fb : [
            SELECT Id, Accelerator__c, Is_Useful__c, Comments__c
            FROM NF_Accelerator_Feedback__c
            WHERE Accelerator__c IN :acceleratorIds
              AND Project_Record_Id__c = :projectRecordId
              AND CreatedById = :UserInfo.getUserId()
        ]) {
            result.put(fb.Accelerator__c, fb);
        }
        return result;
    }

    // ─── Private: Narrative ──────────────────────────────────────────────────

    private static String buildNarrative(ProjectContext ctx, List<AcceleratorResult> results) {
        if (results.isEmpty()) return 'No matching accelerators found for this project context.';

        Integer totalHours = 0;
        for (AcceleratorResult r : results) {
            if (r.estimatedHoursSaved != null) totalHours += r.estimatedHoursSaved;
        }

        String cloud = String.isNotBlank(ctx.cloud) ? ctx.cloud : 'your selected cloud';
        String industry = String.isNotBlank(ctx.industry) ? ctx.industry : 'your industry';
        return results.size() + ' accelerators matched for ' + cloud + ' / ' + industry
            + ' with an estimated ' + totalHours + ' hours of delivery savings.'
            + ' Top match: "' + results[0].name + '" (' + results[0].fitScore + '% fit).';
    }

    // ─── Private: Helpers ────────────────────────────────────────────────────

    private static AcceleratorResult mapToResult(NF_Accelerator__c a) {
        AcceleratorResult r = new AcceleratorResult();
        r.id = a.Id;
        r.name = a.Name;
        r.description = a.Description__c;
        r.tags = a.Tags__c;
        r.cloud = a.Cloud__c;
        r.industry = a.Industry__c;
        r.source = a.Source__c;
        r.sourceUrl = a.Source_URL__c;
        r.articleUrl = a.Knowledge_Article_URL__c;
        r.qualityBadge = a.Quality_Badge__c;
        r.complexity = a.Complexity__c;
        r.assetOwner = a.Asset_Owner__c;
        r.lastUpdated = a.Last_Updated__c != null ? a.Last_Updated__c.format() : '';
        r.estimatedHoursSaved = a.Estimated_Hours_Saved__c != null ? Integer.valueOf(a.Estimated_Hours_Saved__c) : 0;
        r.useCount = a.Use_Count__c != null ? Integer.valueOf(a.Use_Count__c) : 0;
        return r;
    }

    private static Set<String> tokenize(String input) {
        Set<String> tokens = new Set<String>();
        if (String.isBlank(input)) return tokens;
        for (String word : input.toLowerCase().split('[^a-z0-9]+')) {
            if (word.length() > 2) tokens.add(word);
        }
        return tokens;
    }

    // ─── Private: Einstein Prompt Template call ───────────────────────────────

    private static String generateEinsteinNarrative(
        ProjectContext ctx,
        List<AcceleratorResult> results
    ) {
        try {
            if (results.isEmpty()) return null;

            // Build a concise asset list for the prompt input
            List<String> assetLines = new List<String>();
            for (AcceleratorResult r : results) {
                assetLines.add(
                    r.name + ' (' + r.fitScore + '% fit'
                    + (r.qualityBadge == 'Verified' ? ', Verified' : '') + ')'
                    + ': ' + r.fitReason
                    + (r.estimatedHoursSaved != null && r.estimatedHoursSaved > 0
                        ? ' — ~' + r.estimatedHoursSaved + 'h saved' : '')
                );
            }

            ConnectApi.EinsteinPromptTemplateGenerationsInput input =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';
            input.isPreview = false;
            input.inputParams = new Map<String, ConnectApi.WrappedValue>();

            ConnectApi.WrappedValue wCloud = new ConnectApi.WrappedValue();
            wCloud.value = String.isNotBlank(ctx.cloud) ? ctx.cloud : 'Not specified';
            input.inputParams.put('Input:Cloud', wCloud);

            ConnectApi.WrappedValue wIndustry = new ConnectApi.WrappedValue();
            wIndustry.value = String.isNotBlank(ctx.industry) ? ctx.industry : 'Not specified';
            input.inputParams.put('Input:Industry', wIndustry);

            ConnectApi.WrappedValue wUseCase = new ConnectApi.WrappedValue();
            wUseCase.value = String.isNotBlank(ctx.useCase) ? ctx.useCase : 'Not specified';
            input.inputParams.put('Input:UseCase', wUseCase);

            ConnectApi.WrappedValue wAssets = new ConnectApi.WrappedValue();
            wAssets.value = String.join(assetLines, '\n');
            input.inputParams.put('Input:AcceleratorList', wAssets);

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'NF_AcceleratorNarrative', input
                );

            if (response != null
                && response.generations != null
                && !response.generations.isEmpty()) {
                return response.generations[0].text;
            }
            return null;

        } catch (Exception e) {
            // Gracefully fall back to rule-based narrative — Einstein may not be licensed/configured
            System.debug('Einstein narrative unavailable: ' + e.getMessage());
            return null;
        }
    }

    // Comparable wrapper for sorting by score descending
    private class ScoredResult implements Comparable {
        AcceleratorResult result;
        Decimal score;
        ScoredResult(AcceleratorResult r, Decimal s) {
            this.result = r;
            this.score = s;
        }
        public Integer compareTo(Object other) {
            ScoredResult o = (ScoredResult) other;
            if (this.score > o.score) return -1;
            if (this.score < o.score) return 1;
            return 0;
        }
    }
}
