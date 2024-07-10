import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCourseDetails from '@salesforce/apex/CourseOfferingController.getCourseDetails';
import addCoursesToOrders from '@salesforce/apex/CourseOfferingController.addCoursesToOrders';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class AddToCartAction extends LightningElement {
    @api recordId;

    connectedCallback() {
        this.fetchCourseDetails();
    }

    fetchCourseDetails() {
        getCourseDetails({ recordId: this.recordId })
            .then(courseOffering => {
                if (courseOffering) {
                    const course = {
                        id: courseOffering.Id,
                        name: courseOffering.Name,
                        learningCourse: courseOffering.LearningCourse.Name,
                        startingDate: courseOffering.StartDate,
                        price: courseOffering.Price__c
                    };

                    this.addCourseToOrder([course]);

                    this.dispatchEvent(new CloseActionScreenEvent());
                }
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error loading course',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
            });
    }

    addCourseToOrder(courseOfferingList) {
        addCoursesToOrders({ courseOfferingList })
            .then(() => {

                location.reload();
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Course added to cart',
                    variant: 'success',
                    mode: 'dismissable'
                }));
            })
            .catch(error => {
                console.error('Error adding to order:', JSON.stringify(error));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error adding to order',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
            });
    }
}