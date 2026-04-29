import { LightningElement, api, track } from 'lwc';

const VIEWS = {
    LANDING: 'landing',
    CASE_CREATION: 'caseCreation',
    AI_SUMMARY: 'aiSummary',
    HOTEL_VIEW: 'hotelView',
    CASE_RECORD: 'caseRecord'
};

const TILE_TO_VIEW = {
    sccView: VIEWS.CASE_RECORD,
    hotelView: VIEWS.HOTEL_VIEW,
    cxboContact: VIEWS.HOTEL_VIEW,
    caseCreation: VIEWS.CASE_CREATION,
    caseCode: VIEWS.CASE_CREATION,
    aiSummary: VIEWS.AI_SUMMARY
};

const VIEW_LABELS = {
    [VIEWS.CASE_CREATION]: 'Case Creation LWC',
    [VIEWS.AI_SUMMARY]: 'AI Summary LWC',
    [VIEWS.HOTEL_VIEW]: 'Hotel View',
    [VIEWS.CASE_RECORD]: 'SCC Case View'
};

export default class NF_IHG_serviceConsole extends LightningElement {
    @api recordId;

    @track currentView = VIEWS.LANDING;
    @track activeRecordId = null;
    @track activeRecordTitle = '';

    // ─── Computed state getters ───────────────────────────────────────────────

    get isLanding() { return this.currentView === VIEWS.LANDING; }
    get isCaseCreation() { return this.currentView === VIEWS.CASE_CREATION; }
    get isAiSummary() { return this.currentView === VIEWS.AI_SUMMARY; }
    get isHotelView() { return this.currentView === VIEWS.HOTEL_VIEW; }
    get isCaseRecordView() { return this.currentView === VIEWS.CASE_RECORD; }

    get currentViewLabel() {
        return VIEW_LABELS[this.currentView] || '';
    }

    // ─── Navigation ───────────────────────────────────────────────────────────

    handleTileSelect(event) {
        const { tileId } = event.detail;
        const targetView = TILE_TO_VIEW[tileId];
        if (!targetView) return;

        // Only pass recordId when it matches the expected object type for the target view.
        // Account IDs start with '001', Case IDs start with '500'.
        const id = this.recordId || null;
        if (targetView === VIEWS.HOTEL_VIEW) {
            this.activeRecordId = id && id.startsWith('001') ? id : null;
        } else if (targetView === VIEWS.CASE_RECORD) {
            this.activeRecordId = id && id.startsWith('500') ? id : null;
        } else {
            this.activeRecordId = null;
        }
        this.activeRecordTitle = '';
        this.currentView = targetView;
    }

    handleBackToLanding() {
        this.currentView = VIEWS.LANDING;
        this.activeRecordId = null;
        this.activeRecordTitle = '';
    }

    // ─── Cross-component events ───────────────────────────────────────────────

    handleCaseSelected(event) {
        const { caseId, caseData } = event.detail;
        this.activeRecordId = caseId;
        this.activeRecordTitle = caseData?.subject || '';
        this.currentView = VIEWS.CASE_RECORD;
    }

    handleHotelCaseOpen(event) {
        const { caseId } = event.detail;
        this.activeRecordId = caseId;
        this.activeRecordTitle = '';
        this.currentView = VIEWS.CASE_RECORD;
    }
}
