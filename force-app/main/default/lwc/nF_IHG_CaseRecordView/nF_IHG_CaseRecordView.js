import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCaseById from '@salesforce/apex/NF_IHG_CaseController.getCaseById';
import updateCaseStatus from '@salesforce/apex/NF_IHG_CaseController.updateCaseStatus';

const CASE_STAGES = [
    { label: 'New', value: 'New' },
    { label: 'In Progress', value: 'In Progress' },
    { label: 'Escalation', value: 'Escalated' },
    { label: 'Pending Response', value: 'Pending' },
    { label: 'Resolved', value: 'Resolved' },
    { label: 'Closed', value: 'Closed' }
];

const STATUS_OPTIONS = [
    { label: 'New', value: 'New' },
    { label: 'In Progress', value: 'In Progress' },
    { label: 'Escalated', value: 'Escalated' },
    { label: 'Pending', value: 'Pending' },
    { label: 'Resolved', value: 'Resolved' },
    { label: 'Closed', value: 'Closed' }
];

const CASE_REASON_OPTIONS = [
    { label: 'Billing Issue', value: 'Billing Issue' },
    { label: 'Room Quality', value: 'Room Quality' },
    { label: 'Smoking Complaint', value: 'Smoking Complaint' },
    { label: 'Staff Behavior', value: 'Staff Behavior' },
    { label: 'Reservation Error', value: 'Reservation Error' },
    { label: 'Rewards Points Issue', value: 'Rewards Points Issue' },
    { label: 'Maintenance Request', value: 'Maintenance Request' },
    { label: 'Other', value: 'Other' }
];

// Mock activities for demo — replace with @wire(getRelatedListRecords) in production
const MOCK_PAST_ACTIVITIES = [
    {
        id: '1',
        icon: 'utility:email',
        title: 'Email sent to guest regarding room issue',
        who: 'Ashley James',
        date: 'Sep 10, 2024'
    },
    {
        id: '2',
        icon: 'utility:call',
        title: 'Follow-up call with guest',
        who: 'Ashley James',
        date: 'Sep 10, 2024'
    }
];

export default class NF_IHG_caseRecordView extends LightningElement {
    @api recordId;

    @track caseData = {};
    @track editForm = {};
    @track showCaseDetails = true;
    @track showGuestInfo = true;
    @track showReservationInfo = true;
    @track showEditModal = false;

    isLoading = false;
    isSaving = false;

    statusOptions = STATUS_OPTIONS;
    caseReasonOptions = CASE_REASON_OPTIONS;
    activities = [];
    pastActivities = MOCK_PAST_ACTIVITIES;

    // ─── Wired case data ──────────────────────────────────────────────────────

    @wire(getCaseById, { caseId: '$recordId' })
    wiredCase({ data, error }) {
        if (data) {
            this.caseData = {
                ...data,
                guestRewardsNumber: data.contactId ? '65465165148965' : '',
                contactEmail: '',
                contactPhone: '',
                primaryLanguage: 'English',
                reservationNumber: data.reservationNumber || '',
                propertyName: data.propertyName || '',
                checkInDate: data.checkInDate || '',
                checkOutDate: data.checkOutDate || ''
            };
        } else if (error) {
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Error', message: 'Could not load case.', variant: 'error' })
            );
        }
    }

    // ─── Computed ─────────────────────────────────────────────────────────────

    get breadcrumb() {
        return `${this.caseData.accountName || 'Account'} › Cases`;
    }

    get caseStages() {
        const currentStatus = this.caseData.status || 'New';
        const currentIndex = CASE_STAGES.findIndex(s => s.value === currentStatus);
        return CASE_STAGES.map((stage, idx) => ({
            ...stage,
            cssClass: idx < currentIndex
                ? 'path-stage path-stage--complete'
                : idx === currentIndex
                ? 'path-stage path-stage--current'
                : 'path-stage'
        }));
    }

    get caseStatusClass() {
        const s = this.caseData.status;
        if (s === 'Closed' || s === 'Resolved') return 'field-value status-badge status-badge--closed';
        if (s === 'Escalated') return 'field-value status-badge status-badge--escalated';
        return 'field-value status-badge status-badge--open';
    }

    get hasActivities() {
        return this.activities.length > 0;
    }

    get milestonesStats() {
        return '2 Total · 1 High · 0 In-violation';
    }

    get aiSummaryTitle() {
        return this.caseData.subject ? `${this.caseData.subject} | ${this.caseData.accountName || ''}` : '';
    }

    // Accordion icons
    get caseDetailsIcon() { return this.showCaseDetails ? 'utility:chevrondown' : 'utility:chevronright'; }
    get guestInfoIcon() { return this.showGuestInfo ? 'utility:chevrondown' : 'utility:chevronright'; }
    get reservationInfoIcon() { return this.showReservationInfo ? 'utility:chevrondown' : 'utility:chevronright'; }

    // ─── Accordion Toggles ────────────────────────────────────────────────────

    toggleCaseDetails(event) {
        if (event.target.tagName !== 'LIGHTNING-BUTTON-ICON') {
            this.showCaseDetails = !this.showCaseDetails;
        }
    }
    toggleGuestInfo(event) {
        if (event.target.tagName !== 'LIGHTNING-BUTTON-ICON') {
            this.showGuestInfo = !this.showGuestInfo;
        }
    }
    toggleReservationInfo() {
        this.showReservationInfo = !this.showReservationInfo;
    }

    // ─── Stage progression ────────────────────────────────────────────────────

    async handleStageClick(event) {
        const stage = event.currentTarget.dataset.stage;
        if (!this.recordId || stage === this.caseData.status) return;
        try {
            const updated = await updateCaseStatus({ caseId: this.recordId, status: stage });
            this.caseData = { ...this.caseData, status: updated.status };
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Updated', message: `Case moved to ${stage}.`, variant: 'success' })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Error', message: error?.body?.message, variant: 'error' })
            );
        }
    }

    // ─── Edit Case Modal ──────────────────────────────────────────────────────

    handleEditCase(event) {
        event.stopPropagation();
        this.editForm = {
            subject: this.caseData.subject,
            status: this.caseData.status,
            caseReason: this.caseData.caseReason,
            description: this.caseData.description
        };
        this.showEditModal = true;
    }

    handleEditGuest(event) {
        event.stopPropagation();
        this.dispatchEvent(
            new ShowToastEvent({ title: 'Info', message: 'Edit guest via Contact record.', variant: 'info' })
        );
    }

    handleEditFormChange(event) {
        const field = event.target.dataset.field;
        this.editForm = { ...this.editForm, [field]: event.target.value };
    }

    handleEditModalClose() {
        this.showEditModal = false;
    }

    async handleEditModalSave() {
        if (!this.editForm.subject) {
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Validation', message: 'Subject is required.', variant: 'warning' })
            );
            return;
        }
        this.isSaving = true;
        try {
            const updated = await updateCaseStatus({
                caseId: this.recordId,
                status: this.editForm.status
            });
            this.caseData = {
                ...this.caseData,
                ...this.editForm,
                status: updated.status
            };
            this.showEditModal = false;
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Success', message: 'Case updated.', variant: 'success' })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Error', message: error?.body?.message, variant: 'error' })
            );
        } finally {
            this.isSaving = false;
        }
    }
}
