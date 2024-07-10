import { LightningElement, track } from 'lwc';

export default class ParentComponent extends LightningElement {
    @track cart = [];

    handleAddToCart(event) {
        const course = event.detail;
        this.cart = [...this.cart, course];
    }

    handleCheckout(event) {
        const cartItems = event.detail;
        // Implement checkout logic here, such as calling an Apex method to create an order
        console.log('Checkout items:', cartItems);
    }
}