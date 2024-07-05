/**
 * *********************************************************
 * Apex Class Name    : StripeEventHandler
 * Created Date       : June 25, 2024
 * @description       : This class handles specific Stripe events 
 *                      such as checkout.session.completed and 
 *                      invoice.paid. It contains the logic for 
 *                      creating and updating orders based on 
 *                      the webhook data.
 * @developer         : Kankshit Adhaulia
 * @deprecated        : This class is deprecated as of July 4, 2024. No need to handle Webhook.
 * Modification Log:
 * Ver   Date         Author               Modification
 * 1.0   24-06-2024   Kankshit Adhaulia    Initial Version
 * 2.0   04-07-2025   Kankshit Adhaulia    Deprecating this class(No need to handle Webhook)
 * *********************************************************
 */

 public class StripeEventHandler {
    /**
     * *********************************************************
     * @Method Name    : handleCheckoutSessionCompleted
     * @description    : This method handles the checkout.session.completed event.
     * @param session  : Map<String, Object> - The data from the Stripe webhook session.
     * @return         : Id - The Id of the created Order.
     * *********************************************************
     */
    public static Id handleCheckoutSessionCompleted(Map<String, Object> session, String eventType) {
        return upsertOrder(session, eventType);
    }

    /**
     * *********************************************************
     * @Method Name    : handleInvoicePaid
     * @description    : This method handles the invoice.paid event.
     * @param session  : Map<String, Object> - The data from the Stripe webhook session.
     * @return         : Id - The Id of the updated Order.
     * *********************************************************
     */
    public static Id handleInvoicePaid(Map<String, Object> session, String eventType) {
        return upsertOrder(session, eventType);
    }

    /**
     * *********************************************************
     * @Method Name    : upsertOrder
     * @description    : This method creates or updates an Order and associated Order Line Items
     *                   based on the data received from the Stripe webhook session.
     * @param session  : Map<String, Object> - The data from the Stripe webhook session.
     * @param isCreate : Boolean - True if creating a new order, false if updating an existing order.
     * @return         : Id - The Id of the created or updated Order.
     * *********************************************************
     */
    private static Id upsertOrder(Map<String, Object> session, String eventType) {
        Id orderId = null;
        if(eventType == 'checkout.session.completed'){
            orderId = getRelatedCourseOrder(getContactId((String) session.get('client_reference_id')));
        }
        if (eventType == 'invoice.paid') {
            orderId = getOrderIdByPaymentIntent((String) session.get('payment_intent'));
        }
        Order__c order = new Order__c(Id = orderId);
        try {
            if (eventType == 'checkout.session.completed') {
                order.Session_Id__c = (String) session.get('id');
                order.Payment_Intent__c = (String) session.get('payment_intent');
                order.Order_Date__c = System.today();
                //order.Contact__c = getContactId((String) session.get('client_reference_id'));
                update order;
            } else {
                order.Name = (String) session.get('number');
                order.Total_Amount__c = ((Decimal) session.get('amount_paid'))/100.0;
                order.Status__c = ((String) session.get('status') == 'paid') ? 'Success' : 'Pending';
                //order.Payment_Intent__c = (String) session.get('payment_intent');
                order.Hosted_Invoice_URL__c = (String) session.get('hosted_invoice_url');
                order.Currency__c = ((String) session.get('currency')).toUpperCase();
                update order;
            }   
        } catch (Exception e) {
            System.debug('Error upserting Course Order: ' + e.getMessage());
        }
        return order.Id;
    }

    private static Id getRelatedCourseOrder(String contactId){
        return [Select id from Order__c where Contact__c =: contactId and Status__c = 'Pending' LIMIT 1].id;
    }

    /**
     * *********************************************************
     * @Method Name    : getContactId
     * @description    : This method retrieves the Contact Id associated with a given User Id.
     * @param UserId   : String - The Id of the User whose Contact Id is to be retrieved.
     * @return         : String - The Contact Id associated with the given User Id, or null if no contact is found.
     * *********************************************************
     */
    private static String getContactId(String UserId) {
        if (UserId == null) {
            return null;
        }
        try {
            User user = [SELECT ContactId FROM User WHERE Id = :UserId LIMIT 1];
            return user != null ? user.ContactId : null;
        } catch (Exception e) {
            return null;
        }
    }
    /**
     * *********************************************************
     * @Method Name    : getOrderIdByPaymentIntent
     * @description    : This method retrieves the Order Id based on the payment intent.
     * @param paymentIntent : String - The payment intent.
     * @return              : Id - The Id of the Order, or null if not found.
     * *********************************************************
     */
    private static Id getOrderIdByPaymentIntent(String paymentIntent) {
        for (Order__c currentOrder : [SELECT Id FROM Order__c WHERE Payment_Intent__c = :paymentIntent]) {
            return currentOrder.Id;
        }
        return null;
    }

    /**
     * *********************************************************
     * @Method Name    : createCourseOfferingParticipant
     * @description    : This method creates Course Offering Participants for a given Order.
     * @param orderId  : Id - The Id of the Order for which participants are to be created.
     * *********************************************************
     */
    public static void createCourseOfferingParticipant(Id orderId) {
        if (orderId == null) {
            return;
        }

        List<CourseOfferingParticipant> courseOfferingParticipantList = new List<CourseOfferingParticipant>();

        for (Order_Line_Item__c lineItem : [SELECT Course_Offering__c, Order__r.Contact__c, Course_Offering__r.StartDate, Course_Offering__r.EndDate 
                                            FROM Order_Line_Item__c 
                                            WHERE Order__c = :orderId]) {
            if (lineItem.Course_Offering__c != null && lineItem.Order__r.Contact__c != null) {
                CourseOfferingParticipant participant = new CourseOfferingParticipant();
                participant.CourseOfferingId = lineItem.Course_Offering__c ?? null;
                participant.ParticipantContactId = lineItem.Order__r.Contact__c ?? null;
                participant.ParticipationStatus = 'Enrolled';
                participant.ParticipantAffiliation = 'Student';
                participant.StartDate = (lineItem.Course_Offering__r.StartDate != null) ? lineItem.Course_Offering__r.StartDate.date() : null;
                participant.EndDate = (lineItem.Course_Offering__r.EndDate != null) ? lineItem.Course_Offering__r.EndDate.date() : null;

                courseOfferingParticipantList.add(participant);
            } else {
                System.debug('Line item or related Contact is null for line item Id: ' + lineItem.Id);
            }
        }

        if (!courseOfferingParticipantList.isEmpty()) {
            try {
                insert courseOfferingParticipantList;
            } catch (DmlException e) {
                System.debug('Error inserting Course Offering Participants: ' + e.getMessage());
            }
        } else {
            System.debug('No Course Offering Participants to insert.');
        }
    }

}