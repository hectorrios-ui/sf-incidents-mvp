import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

const SOURCE_ICONS = {
    'Playg': 'utility:connected_apps',
    'Google Drive': 'utility:drive',
    'OneDrive': 'utility:cloud',
    'GitHub': 'utility:code',
    'Internal': 'utility:company'
};

export default class NF_AR_AcceleratorCard extends NavigationMixin(LightningElement) {
    @api accelerator;
    @api projectRecordId;

    // ─── Computed ─────────────────────────────────────────────────────────────

    get cardClass() {
        const base = 'accelerator-card';
        if (this.accelerator?.fitScore >= 70) return base + ' card--high-fit';
        if (this.accelerator?.fitScore >= 40) return base + ' card--mid-fit';
        return base + ' card--low-fit';
    }

    get qualityBadgeClass() {
        const b = this.accelerator?.qualityBadge;
        if (b === 'Verified') return 'quality-badge quality-badge--verified';
        if (b === 'Needs Review') return 'quality-badge quality-badge--review';
        return 'quality-badge';
    }

    get sourceClass() {
        return 'source-badge source-badge--' + (this.accelerator?.source || 'internal').toLowerCase().replace(' ', '-');
    }

    get sourceIcon() {
        return SOURCE_ICONS[this.accelerator?.source] || 'utility:link';
    }

    get complexityClass() {
        const c = this.accelerator?.complexity;
        if (c === 'Low') return 'meta-chip meta-chip--low';
        if (c === 'High') return 'meta-chip meta-chip--high';
        return 'meta-chip meta-chip--medium';
    }

    get showHoursSaved() {
        return this.accelerator?.estimatedHoursSaved > 0;
    }

    get hasTags() {
        return this.tagList.length > 0;
    }

    get tagList() {
        if (!this.accelerator?.tags) return [];
        return this.accelerator.tags
            .split(',')
            .map(t => t.trim())
            .filter(t => t.length > 0)
            .slice(0, 6);
    }

    get feedbackGivenClass() {
        return this.accelerator?.userFoundUseful
            ? 'feedback-given feedback-given--useful'
            : 'feedback-given feedback-given--not-useful';
    }

    get feedbackGivenIcon() {
        return this.accelerator?.userFoundUseful ? 'utility:like' : 'utility:dislike';
    }

    get feedbackGivenLabel() {
        return this.accelerator?.userFoundUseful ? 'Marked useful' : 'Marked not useful';
    }

    get hasArticle() {
        return !!this.accelerator?.articleUrl;
    }

    // ─── Events ───────────────────────────────────────────────────────────────

    handleFeedback(event) {
        const isUseful = event.currentTarget.dataset.useful === 'true';
        this.dispatchEvent(new CustomEvent('feedback', {
            detail: {
                acceleratorId: this.accelerator.id,
                isUseful,
                fitScore: this.accelerator.fitScore
            },
            bubbles: true,
            composed: true
        }));
    }

    handleOpen(event) {
        event.preventDefault();
        const url = this.accelerator?.sourceUrl;
        if (url) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url }
            });
        }
        this.dispatchEvent(new CustomEvent('assetopen', {
            detail: { acceleratorId: this.accelerator.id },
            bubbles: true,
            composed: true
        }));
    }
}