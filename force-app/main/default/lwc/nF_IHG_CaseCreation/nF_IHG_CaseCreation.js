import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchGuests from '@salesforce/apex/NF_IHG_CaseController.searchGuests';
import getCasesByContact from '@salesforce/apex/NF_IHG_CaseController.getCasesByContact';
import createCase from '@salesforce/apex/NF_IHG_CaseController.createCase';
import createGuestAndCase from '@salesforce/apex/NF_IHG_CaseController.createGuestAndCase';

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

const BLANK_SEARCH = {
    reservationNumber: '',
    firstName: '',
    lastName: '',
    email: '',
    rewardsNumber: ''
};

const BLANK_CASE_FORM = {
    subject: '',
    caseReason: '',
    description: '',
    reservationNumber: '',
    propertyName: '',
    checkInDate: '',
    checkOutDate: ''
};

const BLANK_GUEST_FORM = {
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    ihgRewardsNumber: '',
    subject: '',
    caseReason: '',
    description: ''
};

export default class NF_IHG_caseCreation extends LightningElement {
    @track searchFields = { ...BLANK_SEARCH };
    @track searchResults = [];
    @track selectedGuest = null;
    @track selectedGuestCases = [];
    @track newCaseForm = { ...BLANK_CASE_FORM };
    @track newGuestForm = { ...BLANK_GUEST_FORM };

    isSearching = false;
    isLoadingCases = false;
    isSavingCase = false;
    hasSearched = false;
    searchError = '';

    showCaseModal = false;
    showNewGuestModal = false;

    caseReasonOptions = CASE_REASON_OPTIONS;

    // ─── Computed ─────────────────────────────────────────────────────────────

    get showEmptyState() {
        return !this.hasSearched && !this.isSearching;
    }

    get showResults() {
        return this.hasSearched && !this.isSearching;
    }

    get guestCount() {
        return this.searchResults.length;
    }

    get existingCaseCount() {
        return this.selectedGuestCases.length;
    }

    get hasCases() {
        return this.selectedGuestCases.length > 0;
    }

    get caseModalTitle() {
        return this.selectedGuest
            ? `New Case for ${this.selectedGuest.name}`
            : 'New Case';
    }

    // ─── Search ───────────────────────────────────────────────────────────────

    handleSearchFieldChange(event) {
        const field = event.target.dataset.field;
        this.searchFields = { ...this.searchFields, [field]: event.target.value };
    }

    async handleSearch() {
        const { reservationNumber, firstName, lastName, email } = this.searchFields;
        if (!reservationNumber && !firstName && !lastName && !email) {
            this.searchError = 'Please enter at least one search criteria.';
            return;
        }
        this.searchError = '';
        this.isSearching = true;
        this.selectedGuest = null;
        this.selectedGuestCases = [];

        try {
            const result = await searchGuests({
                reservationNumber: reservationNumber || null,
                firstName: firstName || null,
                lastName: lastName || null,
                email: email || null
            });

            this.searchResults = (result.guests || []).map(g => ({
                ...g,
                cardClass: 'guest-card'
            }));
            this.hasSearched = true;
        } catch (error) {
            this.searchError = this.extractError(error);
        } finally {
            this.isSearching = false;
        }
    }

    // ─── Guest selection ──────────────────────────────────────────────────────

    async handleGuestSelect(event) {
        const guestId = event.currentTarget.dataset.guestid;
        this.selectedGuest = this.searchResults.find(g => g.id === guestId);

        // highlight selected card
        this.searchResults = this.searchResults.map(g => ({
            ...g,
            cardClass: g.id === guestId ? 'guest-card guest-card--selected' : 'guest-card'
        }));

        this.isLoadingCases = true;
        try {
            const cases = await getCasesByContact({ contactId: guestId });
            this.selectedGuestCases = cases.map(cs => ({
                ...cs,
                formattedDate: cs.createdDate
                    ? new Date(cs.createdDate).toLocaleString()
                    : '',
                statusClass: cs.status === 'Closed' ? 'case-status case-status--closed' : 'case-status case-status--open'
            }));
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        } finally {
            this.isLoadingCases = false;
        }
    }

    // ─── Case selection ───────────────────────────────────────────────────────

    handleSelectCase(event) {
        const caseId = event.target.dataset.caseid;
        const selectedCase = this.selectedGuestCases.find(c => c.id === caseId);
        this.dispatchEvent(new CustomEvent('caseselected', {
            detail: { caseId, caseData: selectedCase },
            bubbles: true,
            composed: true
        }));
    }

    // ─── Create Case for existing guest ───────────────────────────────────────

    handleCreateCaseForGuest() {
        this.newCaseForm = { ...BLANK_CASE_FORM };
        this.showCaseModal = true;
    }

    handleCaseFormChange(event) {
        const field = event.target.dataset.field;
        this.newCaseForm = { ...this.newCaseForm, [field]: event.target.value };
    }

    handleCaseModalClose() {
        this.showCaseModal = false;
    }

    async handleCaseModalConfirm() {
        if (!this.newCaseForm.subject) {
            this.showToast('Validation', 'Subject is required.', 'warning');
            return;
        }
        this.isSavingCase = true;
        try {
            const caseInput = {
                contactId: this.selectedGuest.id,
                accountId: this.selectedGuest.accountId || null,
                subject: this.newCaseForm.subject,
                description: this.newCaseForm.description,
                caseReason: this.newCaseForm.caseReason,
                reservationNumber: this.newCaseForm.reservationNumber,
                propertyName: this.newCaseForm.propertyName,
                checkInDate: this.newCaseForm.checkInDate,
                checkOutDate: this.newCaseForm.checkOutDate,
                status: 'New'
            };
            const createdCase = await createCase({ input: caseInput });
            this.showToast('Success', `Case #${createdCase.caseNumber} created successfully.`, 'success');
            this.showCaseModal = false;
            this.dispatchEvent(new CustomEvent('caseselected', {
                detail: { caseId: createdCase.id, caseData: createdCase },
                bubbles: true,
                composed: true
            }));
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        } finally {
            this.isSavingCase = false;
        }
    }

    // ─── Create New Guest + Case ──────────────────────────────────────────────

    handleNewGuestCase() {
        this.newGuestForm = { ...BLANK_GUEST_FORM };
        this.showNewGuestModal = true;
    }

    handleGuestFormChange(event) {
        const field = event.target.dataset.field;
        this.newGuestForm = { ...this.newGuestForm, [field]: event.target.value };
    }

    handleNewGuestModalClose() {
        this.showNewGuestModal = false;
    }

    async handleNewGuestModalConfirm() {
        const { firstName, lastName, subject } = this.newGuestForm;
        if (!firstName || !lastName || !subject) {
            this.showToast('Validation', 'First Name, Last Name and Subject are required.', 'warning');
            return;
        }
        this.isSavingCase = true;
        try {
            const caseInput = {
                subject: this.newGuestForm.subject,
                description: this.newGuestForm.description,
                caseReason: this.newGuestForm.caseReason,
                status: 'New'
            };
            const createdCase = await createGuestAndCase({
                firstName: this.newGuestForm.firstName,
                lastName: this.newGuestForm.lastName,
                email: this.newGuestForm.email,
                phone: this.newGuestForm.phone,
                ihgRewardsNumber: this.newGuestForm.ihgRewardsNumber,
                caseInput
            });
            this.showToast('Success', `Guest and Case #${createdCase.caseNumber} created successfully.`, 'success');
            this.showNewGuestModal = false;
            this.dispatchEvent(new CustomEvent('caseselected', {
                detail: { caseId: createdCase.id, caseData: createdCase },
                bubbles: true,
                composed: true
            }));
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        } finally {
            this.isSavingCase = false;
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred.';
    }
}
