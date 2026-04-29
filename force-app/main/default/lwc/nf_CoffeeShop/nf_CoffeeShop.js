import { LightningElement, track } from 'lwc';

const PRODUCTS = [
    { id: '1', name: 'Caffe Mocha', sub: 'Deep Foam', price: '$ 4.53', priceNum: 4.53, category: 'all', rating: '4.8', reviews: '230', description: 'A caffe mocha is essentially a chocolate-flavored variant of a caffe latte, combining espresso with hot milk and chocolate.' },
    { id: '2', name: 'Flat White', sub: 'Espresso', price: '$ 3.53', priceNum: 3.53, category: 'all', rating: '4.5', reviews: '120', description: 'A flat white is a coffee drink consisting of espresso with microfoam (steamed milk with small, fine bubbles and a glossy consistency).' },
    { id: '3', name: 'Caffe Latte', sub: 'Steamed Milk', price: '$ 4.00', priceNum: 4.0, category: 'latte', rating: '4.7', reviews: '185', description: 'A caffe latte is a milk coffee that is a made up of one or two shots of espresso, steamed milk and a thin layer of frothed milk on top.' },
    { id: '4', name: 'Americano', sub: 'Hot Water', price: '$ 3.00', priceNum: 3.0, category: 'americano', rating: '4.3', reviews: '95', description: 'A caffe americano is a type of coffee drink prepared by diluting an espresso with hot water, giving it a similar strength to, but different flavor from, traditionally brewed coffee.' },
    { id: '5', name: 'Macchiato', sub: 'Milk Foam', price: '$ 3.80', priceNum: 3.8, category: 'macchiato', rating: '4.6', reviews: '140', description: 'An espresso macchiato is an espresso coffee drink with a small amount of milk, usually foamed. The word macchiato means "stained" or "spotted".' },
    { id: '6', name: 'Cappuccino', sub: 'Foam & Milk', price: '$ 4.20', priceNum: 4.2, category: 'all', rating: '4.9', reviews: '310', description: 'A cappuccino is an espresso-based coffee drink that originated in Italy. It is traditionally prepared with steamed milk foam.' }
];

export default class NfCoffeeShop extends LightningElement {
    @track currentView = 'welcome';
    @track selectedCategory = 'all';
    @track selectedProductId = null;
    @track selectedSizeId = 'M';
    @track searchTerm = '';
    @track orderItems = [];

    get isWelcome() { return this.currentView === 'welcome'; }
    get isHome() { return this.currentView === 'home'; }
    get isDetail() { return this.currentView === 'detail'; }
    get isOrder() { return this.currentView === 'order'; }

    get categories() {
        const cats = [
            { id: 'all', label: 'All Coffee' },
            { id: 'macchiato', label: 'Macchiato' },
            { id: 'latte', label: 'Latte' },
            { id: 'americano', label: 'Americano' }
        ];
        return cats.map(c => ({
            ...c,
            active: c.id === this.selectedCategory,
            className: 'cat-tab' + (c.id === this.selectedCategory ? ' cat-tab-active' : '')
        }));
    }

    get filteredProducts() {
        let list = this.selectedCategory === 'all'
            ? PRODUCTS
            : PRODUCTS.filter(p => p.category === this.selectedCategory || p.category === 'all');
        if (this.searchTerm) {
            const q = this.searchTerm.toLowerCase();
            list = list.filter(p => p.name.toLowerCase().includes(q));
        }
        return list;
    }

    get selectedProduct() {
        return PRODUCTS.find(p => p.id === this.selectedProductId) || PRODUCTS[0];
    }

    get sizes() {
        return ['S', 'M', 'L'].map(s => ({
            id: s,
            label: s,
            className: 'size-btn' + (s === this.selectedSizeId ? ' size-btn-active' : '')
        }));
    }

    get hasDiscount() { return this.orderItems.length > 0; }

    get orderSubtotal() {
        const sum = this.orderItems.reduce((t, i) => t + i.priceNum * i.qty, 0);
        return '$ ' + sum.toFixed(2);
    }

    get deliveryFee() { return '$ 1.00'; }

    get orderTotal() {
        const sub = this.orderItems.reduce((t, i) => t + i.priceNum * i.qty, 0);
        return '$ ' + (sub + 1).toFixed(2);
    }

    handleGetStarted() { this.currentView = 'home'; }

    handleSearch(e) { this.searchTerm = e.target.value; }

    handleCategorySelect(e) {
        this.selectedCategory = e.target.dataset.id;
    }

    handleProductClick(e) {
        const id = e.currentTarget.dataset.id;
        if (id) {
            this.selectedProductId = id;
            this.currentView = 'detail';
        }
    }

    handleAddFromGrid(e) {
        e.stopPropagation();
        const id = e.target.dataset.id;
        this._addItem(id);
    }

    handleBackToHome() { this.currentView = 'home'; }

    handleSizeSelect(e) { this.selectedSizeId = e.target.dataset.id; }

    handleAddToOrder() {
        this._addItem(this.selectedProductId);
        this.currentView = 'order';
    }

    handleGoToOrder() { this.currentView = 'order'; }

    handleQty(e) {
        const id = e.target.dataset.id;
        const action = e.target.dataset.action;
        this.orderItems = this.orderItems
            .map(i => i.id === id ? { ...i, qty: action === 'inc' ? i.qty + 1 : Math.max(0, i.qty - 1) } : i)
            .filter(i => i.qty > 0);
    }

    handlePlaceOrder() {
        this.orderItems = [];
        this.currentView = 'home';
    }

    _addItem(productId) {
        const existing = this.orderItems.find(i => i.id === productId);
        if (existing) {
            this.orderItems = this.orderItems.map(i => i.id === productId ? { ...i, qty: i.qty + 1 } : i);
        } else {
            const p = PRODUCTS.find(pr => pr.id === productId);
            if (p) this.orderItems = [...this.orderItems, { ...p, qty: 1 }];
        }
    }
}
