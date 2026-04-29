import { LightningElement, api, track } from 'lwc';
import { createRecord } from 'lightning/uiRecordApi';
import FEEDBACK_OBJECT from '@salesforce/schema/Feedback__c';
import ISSUE_NAME_FIELD from '@salesforce/schema/Feedback__c.Issue_Name__c';
import ISSUE_DESC_FIELD from '@salesforce/schema/Feedback__c.Issue_Description__c';
import TYPE_FIELD from '@salesforce/schema/Feedback__c.Type__c';
import STATUS_FIELD from '@salesforce/schema/Feedback__c.Status__c';
import LINK_FIELD from '@salesforce/schema/Feedback__c.Link_To_Record__c';

export default class NF_FeedbackButton extends LightningElement {
    @api recordId;

    @track showForm = false;
    @track showSuccess = false;
    @track isLoading = false;
    @track errorMessage = '';
    @track feedbackName = '';

    @track issueName = '';
    @track issueDescription = '';
    @track selectedType = 'Defect';

    get typeOptions() {
        return [
            { label: 'Defect', value: 'Defect' },
            { label: 'Question', value: 'Question' },
            { label: 'Incremental Enhancement', value: 'Incremental Enhancement' },
            { label: 'New Enhancement', value: 'New Enhancement' }
        ];
    }

    handleOpen() { this.showForm = true; }
    handleCancel() { this.showForm = false; this.errorMessage = ''; }
    handleReset() { this.showSuccess = false; this.issueName = ''; this.issueDescription = ''; this.selectedType = 'Defect'; }

    handleNameChange(e) { this.issueName = e.detail.value; }
    handleDescChange(e) { this.issueDescription = e.detail.value; }
    handleTypeChange(e) { this.selectedType = e.detail.value; }

    handleSubmit() {
        if (!this.issueName || !this.issueDescription) {
            this.errorMessage = 'Please fill in all required fields.';
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';

        const fields = {};
        fields[ISSUE_NAME_FIELD.fieldApiName]  = this.issueName;
        fields[ISSUE_DESC_FIELD.fieldApiName]  = this.issueDescription;
        fields[TYPE_FIELD.fieldApiName]        = this.selectedType;
        fields[STATUS_FIELD.fieldApiName]      = 'New';
        fields[LINK_FIELD.fieldApiName]        = window.location.href;

        createRecord({ apiName: FEEDBACK_OBJECT.objectApiName, fields })
            .then(result => {
                this.feedbackName = result.fields.Name?.value ?? result.id;
                this.showForm = false;
                this.showSuccess = true;
                this.isLoading = false;
            })
            .catch(error => {
                this.errorMessage = error?.body?.message ?? 'An unexpected error occurred.';
                this.isLoading = false;
            });
    }
}
