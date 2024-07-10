import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, MessageContext } from 'lightning/messageService';
import CART_UPDATED_CHANNEL from '@salesforce/messageChannel/cartUpdated__c';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class AddToCartQuickAction extends LightningElement {
    @api recordId;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.handleAddToCart();
    }

    handleAddToCart() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Added to Cart',
                message: 'Course offering added to cart successfully.',
                variant: 'success',
            }),
        );

        publish(this.messageContext, CART_UPDATED_CHANNEL, { recordId: this.recordId });

        this.dispatchEvent(new CloseActionScreenEvent());
    }
}