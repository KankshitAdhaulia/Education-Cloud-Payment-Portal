import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, createMessageContext } from 'lightning/messageService';
import createCheckoutSession from '@salesforce/apex/StripeController.createCheckoutSession';

import validateAndAdjustPrices from '@salesforce/apex/CourseOfferingController.validateAndAdjustPrices';

import Cart from "@salesforce/messageChannel/Cart_Channel__c";

export default class CourseCart extends NavigationMixin(LightningElement) {
    @track cart = [];
    context = createMessageContext();
    subscription = null;
    @track showConfirmationModal = false;
    @track showPriceMismatchModal = false;
    courseToDelete = null;
    @track priceMismatchCourses = [];

    connectedCallback() {
        this.loadCart();
        this.subscribeMC();
    }

    async loadCart() {
        // Load the cart from localStorage

        let tempCart = JSON.parse(localStorage.getItem('cart'));
        let updatedCourses = await this.checkForPriceMismatch();
        let updatedCoursesMap = new Map(updatedCourses.map(course => [course.Id, course]));
        let mismatchFlag = false;
        
        tempCart.forEach(course => {
            let updatedCourse = updatedCoursesMap.get(course.id);

            if (updatedCourse) {

                if (course.name !== updatedCourse.Name ||
                    course.startingDate != new Date(updatedCourse.StartDate).toISOString() ||
                    course.price != updatedCourse.Price__c ||
                    course.learningCourse != updatedCourse.LearningCourse.Name
                    ) 
                {
                    mismatchFlag = true;
                }

                course.name = updatedCourse.Name;
                course.learningCourse = updatedCourse.LearningCourse.Name;
                course.startingDate = new Date(updatedCourse.StartDate).toISOString(); 
                course.price = updatedCourse.Price__c;
            }
        });

        this.showPriceMismatchModal = mismatchFlag;

        await localStorage.setItem('cart', JSON.stringify(tempCart));

        this.cart = await JSON.parse(localStorage.getItem('cart')) || [];

        return mismatchFlag;
    }

    subscribeMC() {
        if (this.subscription) {
            return;
        }
        this.subscription = subscribe(this.context, Cart, (message) => {
            // Update the cart with the new item
            this.cart = [...this.cart, message.messageToSend];
            // Save the updated cart to localStorage
            localStorage.setItem('cart', JSON.stringify(this.cart));
        });
    }

    async checkForPriceMismatch() {

        let courseIdsToSend = JSON.parse(localStorage.getItem('cart')).map(course => course.id);
        let updatedPrices = await validateAndAdjustPrices({courseIds: courseIdsToSend});
        console.log('HEY>',JSON.stringify(updatedPrices));
        return updatedPrices;

    }

    get hasItems() {
        return this.cart.length > 0;
    }

    get totalCourses() {
        return this.cart.length;
    }

    get totalAmount(){
        return this.cart.reduce((sum, course) => sum + course.price, 0);
    }

    handleDeleteCourse(event) {
        this.courseToDelete = event.currentTarget.dataset.courseId;
        this.showConfirmationModal = true;
    }

    handleCloseModal() {
        this.showConfirmationModal = false;
        this.showPriceMismatchModal = false;
        this.courseToDelete = null;
    }

    confirmDeleteCourse() {
        const courseId = this.courseToDelete;
        
        // Find index of course with matching id
        const index = this.cart.findIndex(course => course.id === courseId);
        
        if (index !== -1) {
            // Remove course from cart array
            this.cart.splice(index, 1);
            
            // Update localStorage
            localStorage.setItem('cart', JSON.stringify(this.cart));
            
            // Update component state
            this.cart = [...this.cart];
        }
        
        this.handleCloseModal();
    }

    handleConfirmPriceMismatch() {
        this.cart = this.cart.map(course => {
            const mismatchCourse = this.priceMismatchCourses.find(mismatch => mismatch.id === course.id);
            return mismatchCourse ? { ...course, price: mismatchCourse.newPrice } : course;
        });
        
        localStorage.setItem('cart', JSON.stringify(this.cart));
        this.showPriceMismatchModal = false;
    }

    async handleCheckout() {
        let mismatchFound = await this.loadCart();
        console.log('mismatchFound',JSON.stringify(!mismatchFound));

        if(!mismatchFound){
            try {
                let updatedCourses = this.cart.map(course => {
                    return {
                        ...course,
                        price: (course.price * 100).toString()
                    };
                });

                localStorage.setItem('updatedCourses', JSON.stringify(updatedCourses));

                // Create a checkout session and get the URL
                const url = await createCheckoutSession({ courseOrderLines: JSON.stringify(updatedCourses) });
                console.log('Checkout URL:', url); // Log the URL to verify it
                // Redirect to the checkout URL
                window.open(url, '_self');
                
            } catch (error) {
                // Log any errors that occur during the checkout process
                console.error('Error creating checkout session:', error);
            }
        }
        
    }
}