import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, createMessageContext } from 'lightning/messageService';
import { CloseActionScreenEvent } from "lightning/actions";
import getCourseDetails from '@salesforce/apex/CourseOfferingController.getCourseDetails';
import Cart from "@salesforce/messageChannel/Cart_Channel__c";

export default class AddToCartAction extends LightningElement {
    @api recordId;
    @track course = [];
    @track myMessage = '';
    context = createMessageContext();

    connectedCallback() {
        this.fetchCourseDetails();
    }

    fetchCourseDetails() {
        getCourseDetails({ recordId: this.recordId })
            .then(data => {
                console.log('recordId :: ', this.recordId);
                this.course = data;
                console.log('Course data retrieved:', JSON.stringify(data));

                console.log('this.course :: ' , this.course);
                console.log('this.course.CourseOfferings :: ' , this.course.CourseOfferings);
                if (this.course && this.course.CourseOfferings) {
                    const courseOffering = this.course.CourseOfferings[0];
                    const course = {
                        id: courseOffering.Id,
                        name: courseOffering.Name,
                        learningCourse: this.course.Name,
                        startingDate: courseOffering.StartDate,
                        price: courseOffering.Price__c
                    };

                    console.log('This Course>', JSON.stringify(course));

                    // Get existing cart from localStorage
                    let existingCart = JSON.parse(localStorage.getItem('cart')) || [];

                    // Add the new course to the cart
                    existingCart.push(course);

                    // Update localStorage
                    localStorage.setItem('cart', JSON.stringify(existingCart));

                    // Publish message
                    const message = {
                        messageToSend: course,
                        sourceSystem: "From LWC"
                    };
                    publish(this.context, Cart, message);

                    // Show success toast
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: 'Course added to cart',
                        variant: 'success'
                    }));
                    this.dispatchEvent(new CloseActionScreenEvent());

                    const closeEvent = new CustomEvent('closeauracomponent');
                    this.dispatchEvent(closeEvent);
                }
            })
            .catch(error => {
                console.error('Error loading course:', JSON.stringify(error));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error loading course',
                        message: error.body.message,
                        variant: 'error',
                    }),
                );
            });
    }    


    

    handleAddToCartNew() {
        
    }
}