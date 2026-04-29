import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateAiSummary from '@salesforce/apex/NF_IHG_CaseController.generateAiSummary';

export default class NF_IHG_guestAiSummary extends LightningElement {
    @api recordId;
    @api recordTitle;

    @track summaryText = '';
    @track generatedDate = '';

    isGenerating = false;
    hasSummary = false;

    get showEmptyState() {
        return !this.isGenerating && !this.hasSummary;
    }

    get showSummary() {
        return !this.isGenerating && this.hasSummary;
    }

    get summaryTitle() {
        return this.recordTitle || '';
    }

    async handleGenerate() {
        if (!this.recordId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'No Record',
                    message: 'A record ID is required to generate an AI summary.',
                    variant: 'warning'
                })
            );
            return;
        }

        this.isGenerating = true;
        try {
            const result = await generateAiSummary({ caseId: this.recordId });
            this.summaryText = result;
            this.generatedDate = new Intl.DateTimeFormat('en-US', {
                month: 'short',
                day: 'numeric',
                year: 'numeric',
                hour: 'numeric',
                minute: '2-digit',
                timeZoneName: 'short'
            }).format(new Date());
            this.hasSummary = true;
        } catch (error) {
            const msg = error?.body?.message || error?.message || 'Failed to generate summary.';
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' })
            );
        } finally {
            this.isGenerating = false;
        }
    }

    handleLearnMore(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('learnmore', { bubbles: true, composed: true }));
    }
}
