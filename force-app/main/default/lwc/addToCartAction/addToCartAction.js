import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCourseDetails from '@salesforce/apex/CourseOfferingController.getCourseDetails';
import addCoursesToOrders from '@salesforce/apex/CourseOfferingController.addCoursesToOrders';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class AddToCartAction extends LightningElement {
    @api recordId;

    async connectedCallback() {
        await this.fetchCourseDetails();
    }

    async fetchCourseDetails() {
        try {
            const courseOffering = await getCourseDetails({ recordId: this.recordId });
            if (courseOffering) {
                const course = {
                    id: courseOffering.Id,
                    name: courseOffering.Name,
                    learningCourse: courseOffering.LearningCourse.Name,
                    startingDate: courseOffering.StartDate,
                    price: courseOffering.Price__c
                };
                await this.addCourseToOrder([course]);
            }
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading course',
                    message: error.body.message,
                    variant: 'error',
                })
            );
        }
    }

    async addCourseToOrder(courseOfferingList) {
        try {
            await addCoursesToOrders({ courseOfferingList });
            this.dispatchEvent(new CloseActionScreenEvent());

            const closeEvent = new CustomEvent('closeauracomponent');
            this.dispatchEvent(closeEvent);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Course added to cart',
                    variant: 'success',
                })
            );

        } catch (error) {
            console.error('Error adding to order:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error adding to order',
                    message: error.body.message,
                    variant: 'error',
                })
            );
        }
    }
}