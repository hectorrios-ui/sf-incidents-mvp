import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getCasesByAccount from '@salesforce/apex/NF_IHG_CaseController.getCasesByAccount';

import ACCOUNT_NAME        from '@salesforce/schema/Account.Name';
import ACCOUNT_PHONE       from '@salesforce/schema/Account.Phone';
import ACCOUNT_FAX         from '@salesforce/schema/Account.Fax';
import ACCOUNT_WEBSITE     from '@salesforce/schema/Account.Website';
import ACCOUNT_TYPE        from '@salesforce/schema/Account.Type';
import ACCOUNT_NUMBER      from '@salesforce/schema/Account.AccountNumber';
import BILLING_STREET      from '@salesforce/schema/Account.BillingStreet';
import BILLING_CITY        from '@salesforce/schema/Account.BillingCity';
import BILLING_STATE       from '@salesforce/schema/Account.BillingState';
import BILLING_POSTAL      from '@salesforce/schema/Account.BillingPostalCode';
import BILLING_COUNTRY     from '@salesforce/schema/Account.BillingCountry';

const ACCOUNT_FIELDS = [
    ACCOUNT_NAME, ACCOUNT_PHONE, ACCOUNT_FAX, ACCOUNT_WEBSITE,
    ACCOUNT_TYPE, ACCOUNT_NUMBER,
    BILLING_STREET, BILLING_CITY, BILLING_STATE, BILLING_POSTAL, BILLING_COUNTRY
];

export default class NF_IHG_hotelView extends LightningElement {
    @api recordId;

    @track recentCases = [];
    @track showHotelInfo = true;
    @track showAddressInfo = true;
    @track showAdditionalInfo = true;

    _accountRecord;
    _accountError = false;

    // ─── Wire: Account record — only fires when recordId is a valid 15/18-char Account ID ──

    @wire(getRecord, { recordId: '$accountRecordId', fields: ACCOUNT_FIELDS })
    wiredAccount({ data, error }) {
        if (data) {
            this._accountRecord = data;
            this._accountError = false;
        } else if (error) {
            this._accountRecord = null;
            this._accountError = true;
        }
    }

    // Guard: only pass to getRecord when recordId looks like an Account (key prefix 001)
    get accountRecordId() {
        const id = this.recordId;
        if (id && (id.startsWith('001') || id.toLowerCase().startsWith('001'))) {
            return id;
        }
        return null;
    }

    get showNoRecord() {
        return !this.accountRecordId && !this._accountRecord;
    }

    get showRecordError() {
        return this._accountError;
    }

    // ─── Computed hotel data from wired record ────────────────────────────────

    get hotelData() {
        const r = this._accountRecord;
        if (!r) return {};
        return {
            name:             getFieldValue(r, ACCOUNT_NAME)    || '',
            hotelId:          getFieldValue(r, ACCOUNT_NUMBER)  || '',
            phone:            getFieldValue(r, ACCOUNT_PHONE)   || '',
            brand:            getFieldValue(r, ACCOUNT_TYPE)    || '',
            type:             getFieldValue(r, ACCOUNT_TYPE)    || '',
            street:           getFieldValue(r, BILLING_STREET)  || '',
            city:             getFieldValue(r, BILLING_CITY)    || '',
            state:            getFieldValue(r, BILLING_STATE)   || '',
            zip:              getFieldValue(r, BILLING_POSTAL)  || '',
            country:          getFieldValue(r, BILLING_COUNTRY) || '',
            website:          getFieldValue(r, ACCOUNT_WEBSITE) || '',
            fax:              getFieldValue(r, ACCOUNT_FAX)     || ''
        };
    }

    // Accordion icon toggles
    get hotelInfoIcon() {
        return this.showHotelInfo ? 'utility:chevrondown' : 'utility:chevronright';
    }
    get addressInfoIcon() {
        return this.showAddressInfo ? 'utility:chevrondown' : 'utility:chevronright';
    }
    get additionalInfoIcon() {
        return this.showAdditionalInfo ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get openCaseCount() {
        return this.recentCases.length;
    }

    get hasCases() {
        return this.recentCases.length > 0;
    }

    get hotelName() {
        return this.hotelData.name || 'Hotel';
    }

    get hotelBrand() {
        return this.hotelData.brand || 'IHG';
    }

    // ─── Wire: Related cases ──────────────────────────────────────────────────

    @wire(getCasesByAccount, { accountId: '$recordId' })
    wiredCases({ data, error }) {
        if (data) {
            this.recentCases = data.slice(0, 6).map(cs => ({
                ...cs,
                formattedDate: cs.createdDate
                    ? new Date(cs.createdDate).toLocaleString()
                    : ''
            }));
        } else if (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Could not load recent cases.',
                    variant: 'error'
                })
            );
        }
    }

    // ─── Accordion Toggles ────────────────────────────────────────────────────

    toggleHotelInfo() {
        this.showHotelInfo = !this.showHotelInfo;
    }

    toggleAddressInfo() {
        this.showAddressInfo = !this.showAddressInfo;
    }

    toggleAdditionalInfo() {
        this.showAdditionalInfo = !this.showAdditionalInfo;
    }

    // ─── Actions ─────────────────────────────────────────────────────────────

    handleFollow() {
        this.dispatchEvent(
            new ShowToastEvent({ title: 'Follow', message: 'Now following this hotel.', variant: 'success' })
        );
    }

    handleEdit() {
        this.dispatchEvent(new CustomEvent('editrecord', {
            detail: { recordId: this.recordId },
            bubbles: true,
            composed: true
        }));
    }

    handleNewNote() {
        this.dispatchEvent(new CustomEvent('newnote', {
            detail: { recordId: this.recordId },
            bubbles: true,
            composed: true
        }));
    }

    handleCaseClick(event) {
        const caseId = event.currentTarget.dataset.caseid;
        this.dispatchEvent(new CustomEvent('caseopen', {
            detail: { caseId },
            bubbles: true,
            composed: true
        }));
    }

    handleViewAll(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('viewallcases', {
            detail: { accountId: this.recordId },
            bubbles: true,
            composed: true
        }));
    }
}
