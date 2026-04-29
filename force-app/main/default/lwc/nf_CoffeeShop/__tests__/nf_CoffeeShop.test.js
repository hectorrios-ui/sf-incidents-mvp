import { createElement } from 'lwc';
import NfCoffeeShop from 'c/nf_CoffeeShop';
import { ShowToastEventName } from 'lightning/platformShowToastEvent';

describe('c-nf-coffee-shop', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('should display welcome screen on initial load', () => {
        const element = createElement('c-nf-coffee-shop', {
            is: NfCoffeeShop
        });
        document.body.appendChild(element);

        const welcomeScreen = element.shadowRoot.querySelector('.welcome-screen');
        expect(welcomeScreen).toBeTruthy();
    });

    it('should navigate to home screen when get started is clicked', () => {
        const element = createElement('c-nf-coffee-shop', {
            is: NfCoffeeShop
        });
        document.body.appendChild(element);

        const getStartedBtn = element.shadowRoot.querySelector('.btn-primary');
        getStartedBtn.click();

        return Promise.resolve().then(() => {
            const homeScreen = element.shadowRoot.querySelector('.home-screen');
            expect(homeScreen).toBeTruthy();
        });
    });

    it('should show error toast when placing order with empty cart', () => {
        const element = createElement('c-nf-coffee-shop', {
            is: NfCoffeeShop
        });
        document.body.appendChild(element);

        const toastHandler = jest.fn();
        element.addEventListener(ShowToastEventName, toastHandler);

        element.currentView = 'order';
        element.orderItems = [];

        return Promise.resolve().then(() => {
            const placeOrderBtn = element.shadowRoot.querySelector('.btn-primary.btn-full');
            placeOrderBtn.click();

            return Promise.resolve();
        }).then(() => {
            expect(toastHandler).toHaveBeenCalled();
            expect(toastHandler.mock.calls[0][0].detail.variant).toBe('error');
            expect(toastHandler.mock.calls[0][0].detail.message).toContain('empty');
        });
    });

    it('should show success toast when placing order with items', () => {
        const element = createElement('c-nf-coffee-shop', {
            is: NfCoffeeShop
        });
        document.body.appendChild(element);

        const toastHandler = jest.fn();
        element.addEventListener(ShowToastEventName, toastHandler);

        element.currentView = 'order';
        element.orderItems = [
            { id: '1', name: 'Caffe Mocha', priceNum: 4.53, qty: 2 },
            { id: '2', name: 'Flat White', priceNum: 3.53, qty: 1 }
        ];

        return Promise.resolve().then(() => {
            const placeOrderBtn = element.shadowRoot.querySelector('.btn-primary.btn-full');
            placeOrderBtn.click();

            return Promise.resolve();
        }).then(() => {
            expect(toastHandler).toHaveBeenCalled();
            expect(toastHandler.mock.calls[0][0].detail.variant).toBe('success');
            expect(toastHandler.mock.calls[0][0].detail.title).toContain('Success');
            expect(toastHandler.mock.calls[0][0].detail.message).toContain('3 item(s)');
        });
    });

    it('should clear order items after successful order placement', () => {
        const element = createElement('c-nf-coffee-shop', {
            is: NfCoffeeShop
        });
        document.body.appendChild(element);

        element.currentView = 'order';
        element.orderItems = [
            { id: '1', name: 'Caffe Mocha', priceNum: 4.53, qty: 1 }
        ];

        return Promise.resolve().then(() => {
            const placeOrderBtn = element.shadowRoot.querySelector('.btn-primary.btn-full');
            placeOrderBtn.click();

            return Promise.resolve();
        }).then(() => {
            expect(element.orderItems).toEqual([]);
            expect(element.currentView).toBe('home');
        });
    });

    it('should add item to order when add button is clicked', () => {
        const element = createElement('c-nf-coffee-shop', {
            is: NfCoffeeShop
        });
        document.body.appendChild(element);

        element.currentView = 'home';

        return Promise.resolve().then(() => {
            const addBtn = element.shadowRoot.querySelector('.btn-add');
            addBtn.click();

            return Promise.resolve();
        }).then(() => {
            expect(element.orderItems.length).toBeGreaterThan(0);
        });
    });

    it('should calculate correct order total', () => {
        const element = createElement('c-nf-coffee-shop', {
            is: NfCoffeeShop
        });
        document.body.appendChild(element);

        element.orderItems = [
            { id: '1', priceNum: 4.53, qty: 2 },
            { id: '2', priceNum: 3.53, qty: 1 }
        ];

        const expectedTotal = (4.53 * 2 + 3.53 * 1 + 1).toFixed(2);
        expect(element.orderTotal).toBe('$ ' + expectedTotal);
    });

    it('should display Place Order button text', () => {
        const element = createElement('c-nf-coffee-shop', {
            is: NfCoffeeShop
        });
        document.body.appendChild(element);

        element.currentView = 'order';
        element.orderItems = [{ id: '1', priceNum: 4.53, qty: 1 }];

        return Promise.resolve().then(() => {
            const placeOrderBtn = element.shadowRoot.querySelector('.btn-primary.btn-full');
            expect(placeOrderBtn.textContent).toBe('Place Order');
        });
    });
});
