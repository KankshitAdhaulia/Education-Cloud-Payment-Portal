import { LightningElement, wire, track } from 'lwc';
import { subscribe, MessageContext } from 'lightning/messageService';
import CART_UPDATED_CHANNEL from '@salesforce/messageChannel/cartUpdated__c';
import { NavigationMixin } from 'lightning/navigation';

export default class CartIcon extends NavigationMixin(LightningElement) {
    @track cartCount = 0;
    @track cartItems = [];

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    subscribeToMessageChannel() {
        this.subscription = subscribe(
            this.messageContext,
            CART_UPDATED_CHANNEL,
            (message) => this.handleCartUpdated(message)
        );
    }

    handleCartUpdated(message) {
        this.cartCount += 1;
        this.cartItems.push(message.recordId);
    }

    handleCartClick() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/checkout'
            },
            state: {
                cartItems: this.cartItems
            }
        });
    }
}