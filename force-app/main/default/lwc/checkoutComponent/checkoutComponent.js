import { LightningElement } from 'lwc';
import createCheckoutSession from '@salesforce/apex/StripeController.createCheckoutSession';

export default class CheckoutComponent extends LightningElement {
    /**
     * Handles the checkout process by creating a checkout session
     * and redirecting the user to the Stripe checkout page.
     */
    async handleCheckout() {
        console.log('checkout');
        try {
            // Create a checkout session and get the URL
            const url = await createCheckoutSession();
            // Redirect to the checkout URL
            window.location.href = url;
        } catch (error) {
            // Log any errors that occur during the checkout process
            console.error('Error creating checkout session:', error);
        }
    }
}