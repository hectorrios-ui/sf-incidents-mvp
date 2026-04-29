import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRecommendations from '@salesforce/apex/NF_AcceleratorController.getRecommendations';
import getOpportunityContext from '@salesforce/apex/NF_AcceleratorController.getOpportunityContext';
import searchAccelerators from '@salesforce/apex/NF_AcceleratorController.searchAccelerators';
import saveFeedback from '@salesforce/apex/NF_AcceleratorController.saveFeedback';

export default class NF_AR_RecommenderPanel extends LightningElement {
    @api recordId;

    @track context = { cloud: '', industry: '', useCase: '', keywords: '' };
    @track results = [];
    @track searchTerm = '';
    @track narrative = '';
    @track sortBy = 'fit';

    isLoading = false;
    isSearching = false;
    hasSearched = false;

    // ─── Auto-populate context from Opportunity ───────────────────────────────

    @wire(getOpportunityContext, { recordId: '$recordId' })
    wiredContext({ data }) {
        if (data) {
            this.context = {
                cloud:     data.cloud     || '',
                industry:  data.industry  || '',
                useCase:   data.useCase   || '',
                keywords:  data.keywords  || ''
            };
            // Auto-trigger if at least cloud or industry came back pre-filled
            if (data.cloud || data.industry) {
                this.handleGetRecommendations();
            }
        }
    }

    // ─── Computed ─────────────────────────────────────────────────────────────

    get showEmptyState() { return !this.hasSearched && !this.isLoading; }
    get showNoResults()  { return this.hasSearched && !this.isLoading && this.results.length === 0; }
    get showResults()    { return this.hasSearched && !this.isLoading && this.results.length > 0; }
    get resultCount()    { return this.results.length; }

    get contextPills() {
        const pills = [];
        if (this.context.cloud)    pills.push({ key: 'cloud',    icon: 'utility:connected_apps', label: this.context.cloud });
        if (this.context.industry) pills.push({ key: 'industry', icon: 'utility:company',        label: this.context.industry });
        if (this.context.useCase)  pills.push({ key: 'useCase',  icon: 'utility:description',    label: this.context.useCase });
        return pills;
    }

    get hasContext()     { return this.contextPills.length > 0; }
    get noOppContext()   { return !this.hasContext && !this.isLoading && !this.hasSearched; }

    get sortFitVariant()    { return this.sortBy === 'fit'    ? 'brand' : 'neutral'; }
    get sortUsedVariant()   { return this.sortBy === 'used'   ? 'brand' : 'neutral'; }
    get sortNewestVariant() { return this.sortBy === 'newest' ? 'brand' : 'neutral'; }

    get displayedResults() {
        const sorted = [...this.results];
        if (this.sortBy === 'fit') {
            // Primary: fit score desc. Tiebreaker: estimated hours saved desc (higher impact first)
            sorted.sort((a, b) => {
                const scoreDiff = (b.fitScore || 0) - (a.fitScore || 0);
                if (scoreDiff !== 0) return scoreDiff;
                return (b.estimatedHoursSaved || 0) - (a.estimatedHoursSaved || 0);
            });
        } else if (this.sortBy === 'used') {
            sorted.sort((a, b) => (b.useCount || 0) - (a.useCount || 0));
        } else if (this.sortBy === 'newest') {
            sorted.sort((a, b) => {
                if (!a.lastUpdated) return 1;
                if (!b.lastUpdated) return -1;
                return new Date(b.lastUpdated) - new Date(a.lastUpdated);
            });
        }
        return sorted;
    }

    get totalHoursSaved() {
        return this.results.reduce((sum, r) => sum + (r.estimatedHoursSaved || 0), 0);
    }

    // ─── Get Recommendations ──────────────────────────────────────────────────

    async handleGetRecommendations() {
        this.isLoading = true;
        this.searchTerm = '';
        try {
            const resp = await getRecommendations({
                recordId: this.recordId || '',
                cloud:    this.context.cloud    || '',
                industry: this.context.industry || '',
                useCase:  this.context.useCase  || '',
                keywords: this.context.keywords || ''
            });
            this.results = resp.results || [];
            this.narrative = resp.aiNarrative || '';
            this.hasSearched = true;
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ─── Free-text Search ─────────────────────────────────────────────────────

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        // Clear search → reload recommendations automatically
        if (!this.searchTerm || this.searchTerm.trim() === '') {
            this.handleGetRecommendations();
        }
    }

    handleSearchKeyUp(event) {
        if (event.key === 'Enter') this.handleSearch();
    }

    async handleSearch() {
        if (!this.searchTerm || this.searchTerm.trim().length < 2) return;
        this.isSearching = true;
        this.isLoading = true;
        try {
            const results = await searchAccelerators({
                searchTerm: this.searchTerm,
                cloud:      this.context.cloud    || '',
                industry:   this.context.industry || '',
                useCase:    this.context.useCase  || '',
                recordId:   this.recordId         || ''
            });
            this.results = results || [];
            this.narrative = `Keyword search: "${this.searchTerm}" — ${this.results.length} result(s) scored against your project context.`;
            this.hasSearched = true;
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        } finally {
            this.isLoading = false;
            this.isSearching = false;
        }
    }

    // ─── Sort ─────────────────────────────────────────────────────────────────

    handleSort(event) {
        this.sortBy = event.target.dataset.sort;
    }

    // ─── Feedback ────────────────────────────────────────────────────────────

    async handleFeedback(event) {
        const { acceleratorId, isUseful, fitScore } = event.detail;
        try {
            await saveFeedback({
                acceleratorId,
                projectRecordId: this.recordId || '',
                isUseful,
                comments: '',
                fitScore
            });

            // Optimistically update the card's feedback state in-place
            this.results = this.results.map(r => {
                if (r.id === acceleratorId) {
                    return { ...r, userFeedbackGiven: true, userFoundUseful: isUseful };
                }
                return r;
            });

            this.showToast(
                isUseful ? 'Thanks!' : 'Noted',
                isUseful ? 'Feedback saved — this asset will rank higher for similar projects.' : 'Feedback saved — this asset will rank lower for similar contexts.',
                isUseful ? 'success' : 'info'
            );
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
    }

    // ─── Asset Open ──────────────────────────────────────────────────────────

    handleAssetOpen(event) {
        const { acceleratorId } = event.detail;
        const acc = this.results.find(r => r.id === acceleratorId);
        if (acc?.sourceUrl) {
            window.open(acc.sourceUrl, '_blank', 'noopener,noreferrer');
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractError(error) {
        return error?.body?.message || error?.message || 'An unexpected error occurred.';
    }
}