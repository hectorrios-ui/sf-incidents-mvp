import { LightningElement, api } from 'lwc';

export default class NF_IHG_modal extends LightningElement {
    @api title = 'Confirm';
    @api subtitle = '';
    @api cancelLabel = 'Cancel';
    @api confirmLabel = 'Confirm';
    @api showConfirm = false;
    @api isLoading = false;

    _isOpen = false;

    @api
    get isOpen() {
        return this._isOpen;
    }
    set isOpen(value) {
        this._isOpen = value;
    }

    @api
    open() {
        this._isOpen = true;
    }

    @api
    close() {
        this._isOpen = false;
    }

    handleClose() {
        this._isOpen = false;
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleConfirm() {
        this.dispatchEvent(new CustomEvent('confirm'));
    }
}
