import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getSessionDetails from '@salesforce/apex/StripeController.getSessionDetails';
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

            if (localStorage.getItem('cart')) {
                localStorage.removeItem('cart');
                console.log('Cart emptied successfully.');
            }

            // Read the updatedCourses from localStorage
            const updatedCourses = localStorage.getItem('updatedCourses');
            if (updatedCourses) {
                this.updatedCourses = JSON.parse(updatedCourses).map(course => Object.assign({}, course));
                console.log('Retrieved updated courses:', JSON.stringify(this.updatedCourses));
                //localStorage.removeItem('updatedCourses'); // Clean up the localStorage

                // Call Apex method to create CourseOfferingParticipant records
                this.createCourseOfferingParticipant();
            }
        }
        }
    

    /**
     * Fetches session details using the session ID.
     */
    async fetchSessionDetails() {
        try {
            const result = await getSessionDetails({ sessionId: this.sessionId });
            this.customerName = result.customer_name;
            console.log('==customerName==', this.customerName);
            this.total = result.amount_total/100;
            this.paymentIntent = result.payment_intent;
            this.currency = result.currency.toUpperCase();
            this.isLoading = false;
        } catch (error) {
            console.error('Error fetching session details:', error);
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
            createCourseOfferingParticipant({ courseOrderLines: JSON.stringify(this.updatedCourses) });
            console.log('CourseOfferingParticipant records created successfully.');
        } catch (error) {
            console.error('Error creating CourseOfferingParticipant records:', error);
        }
    }
}