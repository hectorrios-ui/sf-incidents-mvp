import { LightningElement, api, track } from 'lwc';
import { createRecord } from 'lightning/uiRecordApi';
import CASE_OBJECT from '@salesforce/schema/Case';
import CONTACT_ID_FIELD from '@salesforce/schema/Case.ContactId';
import STATUS_FIELD from '@salesforce/schema/Case.Status';
import ORIGIN_FIELD from '@salesforce/schema/Case.Origin';

export default class NF_CreateCase extends LightningElement {
    @api recordId;

    @track isLoading = false;
    @track showSuccess = false;
    @track errorMessage = '';
    @track caseNumber = '';

    handleCreateCase() {
        this.isLoading = true;
        this.errorMessage = '';

        const fields = {};
        fields[CONTACT_ID_FIELD.fieldApiName] = this.recordId;
        fields[STATUS_FIELD.fieldApiName] = 'New';
        fields[ORIGIN_FIELD.fieldApiName] = 'Web';

        createRecord({ apiName: CASE_OBJECT.objectApiName, fields })
            .then(result => {
                this.caseNumber = result.fields.CaseNumber?.value ?? result.id;
                this.showSuccess = true;
                this.isLoading = false;
            })
            .catch(error => {
                this.errorMessage = error?.body?.message ?? 'An unexpected error occurred.';
                this.isLoading = false;
            });
    }
}
