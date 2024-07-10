import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPendingOrders from '@salesforce/apex/CourseOfferingController.getPendingOrders';
import getOrderLineItems from '@salesforce/apex/CourseOfferingController.getOrderLineItems';
import createCheckoutSession from '@salesforce/apex/StripeController.createCheckoutSession';
import validateAndAdjustPrices from '@salesforce/apex/CourseOfferingController.validateAndAdjustPrices';
import deleteCourseOrderAndItems from '@salesforce/apex/CourseOfferingController.deleteCourseOrderAndItems';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CourseCart extends NavigationMixin(LightningElement) {
    @track cart = [];
    @track showConfirmationModal = false;
    @track showPriceMismatchModal = false;
    courseLineItemToDelete = null;
    @track priceMismatchCourses = [];




    connectedCallback() {
        this.loadCart();
    }

    loadCart() {
        getPendingOrders()
            .then(pendingOrders => {
                if (pendingOrders && pendingOrders.length > 0) {
                    const orderIdVal = pendingOrders[0].Id;
                    getOrderLineItems({ orderId : orderIdVal })
                        .then(items => {
                            
                            this.cart = items.map(item => {
                            
                                return {
                                    id: item.Id,
                                    courseid: item.Course_Offering__c,
                                    name: item.Course_Offering__r.Name,
                                    learningCourse: item.Course_Offering__r.LearningCourse.Name,
                                    startingDate: item.Course_Offering__r.StartDate,
                                    price: item.Course_Offering__r.Price__c
                                };
                            });
                            this.checkForPriceMismatch();
                        });
                }
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error loading cart',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
            });
    }




     async checkForPriceMismatch() {
        try {
            let ids = this.cart.map(item => item.courseid);
            let updatedPrices = await validateAndAdjustPrices({ courseIds: ids });
            let mismatches = false;
            this.cart = this.cart.map(course => {
                let updatedCourse = updatedPrices.find(p => p.Id === course.courseid);

                if (updatedCourse) {
                    if (course.price !== updatedCourse.Price__c) {
                        mismatches = true;
                        course.price = updatedCourse.Price__c;
                    }
                }
                return course;
            });


            

            this.showPriceMismatchModal = mismatches;
        } catch (error) {
            console.error('Error validating and adjusting prices:', error);
        }
    }




    get hasItems() {
        return this.cart.length > 0;
    }




    get totalCourses() {
        return this.cart.length;
    }




    get totalAmount() {
        return this.cart.reduce((sum, course) => sum + course.price, 0);
    }




    handleDeleteCourse(event) {
        this.courseLineItemToDelete = event.currentTarget.dataset.courseId;
        this.showConfirmationModal = true;
    }




    handleCloseModal() {
        this.showConfirmationModal = false;
        
        this.courseToDelete = null;
    }




    confirmDeleteCourse() {
        const courseLineItemId = this.courseLineItemToDelete;
        deleteCourseOrderAndItems({ courseIds: courseLineItemId })
            .then(() => {
                const index = this.cart.findIndex(course => course.id == courseLineItemId);
                    if (index !== -1) {
                        this.cart.splice(index, 1);
                    }

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Course removed',
                        message: 'Course removed from cart successfully',
                        variant: 'info',
                    })
                );
            })
            .catch(error => {
                console.error('Error deleting course order and items:', error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to delete course order and items. Please try again later.',
                        variant: 'error',
                    })
                );
            })
            .finally(() => {
                this.handleCloseModal();
            });
    }




    handleConfirmPriceMismatch() {
        this.cart = this.cart.map(course => {
            const mismatchCourse = this.priceMismatchCourses.find(mismatch => mismatch.Id === course.id);
            return mismatchCourse ? { ...course, price: mismatchCourse.newPrice } : course;
        });

        this.showPriceMismatchModal = false;
    }




    async handleCheckout() {
        try {
            await this.checkForPriceMismatch();

            if (!this.showPriceMismatchModal) {
                let updatedCourses = this.cart.map(course => ({
                    ...course,
                    price: (course.price * 100).toString(),
                }));
                const url = await createCheckoutSession({ courseOrderLines: JSON.stringify(updatedCourses) });
                window.open(url, '_self');
            }
        } catch (error) {
            console.error('Error handling checkout:', error);
        }
    }
}