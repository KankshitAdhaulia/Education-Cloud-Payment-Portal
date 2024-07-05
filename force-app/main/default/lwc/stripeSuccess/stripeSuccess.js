import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getSessionDetails from '@salesforce/apex/StripeController.getSessionDetails';
import createCourseOfferingParticipant from '@salesforce/apex/StripeController.createCourseOfferingParticipant';
import fetchInvoiceURL from '@salesforce/apex/StripeController.fetchInvoiceURL';

export default class StripeSuccess extends LightningElement {
    @track sessionId;
    @track customerName;
    @track total;
    @track currency;
    @track paymentIntent;
    @track invoiceURL;
    @track isLoading = true;

    /**
     * Fetches state parameters from the current page reference.
     */
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.sessionId = currentPageReference.state.session_id;
            console.log('sessionid', this.sessionId);
            this.fetchSessionDetails();
            }
        }
    

    /**
     * Fetches session details using the session ID.
     */
    async fetchSessionDetails() {
        try {
            const result = await getSessionDetails({ sessionId: this.sessionId });
            this.customerName = result.customer_name;
            this.total = result.amount_total/100;
            this.paymentIntent = result.payment_intent;
            this.currency = result.currency.toUpperCase();
            this.isLoading = false;
            this.createCourseOfferingParticipant();
        } catch (error) {
            console.error('Error fetching session details:', error);
            console.error('Error message:', error.body ? error.body.message : error.message);
            this.isLoading = false;
        }
    }

    /**
     * Handles the action to view the invoice by fetching the invoice URL.
     */
    handleViewInvoice() {
        fetchInvoiceURL({ paymentIntent: this.paymentIntent })
            .then(result => {
                this.invoiceURL = result;
                window.open(this.invoiceURL);
            })
            .catch(error => {
                console.error('Error fetching invoice URL:', error);
            });
    }

    createCourseOfferingParticipant() {
        try {
            createCourseOfferingParticipant({ paymentIntent: this.paymentIntent });
            console.log('CourseOfferingParticipant records created successfully.');
        } catch (error) {
            console.error('Error creating CourseOfferingParticipant records:', error);
        }
    }
}