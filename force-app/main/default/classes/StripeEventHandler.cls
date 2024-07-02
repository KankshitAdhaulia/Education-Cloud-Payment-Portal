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
 * Modification Log:
 * Ver   Date         Author               Modification
 * 1.0   24-06-2024   Kankshit Adhaulia    Initial Version
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
    public static Id handleCheckoutSessionCompleted(Map<String, Object> session) {
        return upsertOrder(session, true);
    }

    /**
     * *********************************************************
     * @Method Name    : handleInvoicePaid
     * @description    : This method handles the invoice.paid event.
     * @param session  : Map<String, Object> - The data from the Stripe webhook session.
     * @return         : Id - The Id of the updated Order.
     * *********************************************************
     */
    public static Id handleInvoicePaid(Map<String, Object> session) {
        return upsertOrder(session, false);
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
    private static Id upsertOrder(Map<String, Object> session, Boolean isCreate) {
        Id orderId = null;
        if (!isCreate) {
            orderId = getOrderIdByPaymentIntent((String) session.get('payment_intent'));
        }
        Order__c order = isCreate ? new Order__c() : new Order__c(Id = orderId);
        try {
            if (isCreate) {
                order.Session_Id__c = (String) session.get('id');
                order.Payment_Intent__c = (String) session.get('payment_intent');
                order.Order_Date__c = System.today();
                order.Contact__c = getContactId((String) session.get('client_reference_id'));
                insert order;
            } else {
                order.Name = (String) session.get('number');
                order.Total_Amount__c = ((Decimal) session.get('amount_paid'))/100.0;
                order.Status__c = ((String) session.get('status') == 'paid') ? 'Success' : 'Pending';
                order.Payment_Intent__c = (String) session.get('payment_intent');
                order.Hosted_Invoice_URL__c = (String) session.get('hosted_invoice_url');
                order.Currency__c = ((String) session.get('currency')).toUpperCase();
                update order;

                List<Order_Line_Item__c> orderLineItems = createOrderLineItems(session, order.Id);
                if (!orderLineItems.isEmpty()) {
                    insert orderLineItems;
                }
            }   
        } catch (Exception e) {
            System.debug('Error upserting Course Order: ' + e.getMessage());
        }
        return order.Id;
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
     * @Method Name    : createOrderLineItems
     * @description    : This method creates a list of Order Line Items based on the data
     *                   received from the Stripe webhook session and associates them with an Order.
     * @param session  : Map<String, Object> - The data from the Stripe webhook session.
     * @param orderId  : Id - The Id of the Order to associate the Line Items with.
     * @return         : List<Order_Line_Item__c> - The list of created Order Line Items.
     * *********************************************************
     */
    private static List<Order_Line_Item__c> createOrderLineItems(Map<String, Object> session, Id orderId) {
        Set<String> lineItemDescriptionSet = new Set<String>();
        Map<String, Object> lines = (Map<String, Object>) session.get('lines');
        List<Object> lineItems = (List<Object>) lines.get('data');

        for (Object lineItemObj : lineItems) {
            Map<String, Object> lineItem = (Map<String, Object>) lineItemObj;
            lineItemDescriptionSet.add((String) lineItem.get('description'));
        }

        Map<String, Id> courseOfferingNameToIdMap = getCourseOfferingNameToIdMap(lineItemDescriptionSet);
        List<Order_Line_Item__c> orderLineItems = new List<Order_Line_Item__c>();
        for (Object lineItemObj : lineItems) {
            Map<String, Object> lineItem = (Map<String, Object>) lineItemObj;
            Order_Line_Item__c orderLineItem = new Order_Line_Item__c();
            orderLineItem.Order__c = orderId;
            orderLineItem.Price__c = ((Decimal) lineItem.get('amount'))/100.0;
            orderLineItem.Currency__c = ((String) lineItem.get('currency')).toUpperCase();
            orderLineItem.Course_Offering__c = courseOfferingNameToIdMap.get((String) lineItem.get('description'));
            orderLineItems.add(orderLineItem);
        }
        return orderLineItems;
    }

    /**
     * *********************************************************
     * @Method Name    : getCourseOfferingNameToIdMap
     * @description    : This method retrieves a map of Course Offering names to their IDs
     *                   based on the provided set of line item descriptions.
     * @param lineItemDescriptionSet : Set<String> - The set of line item descriptions.
     * @return                       : Map<String, Id> - A map of Course Offering names to their IDs.
     * *********************************************************
     */
    private static Map<String, Id> getCourseOfferingNameToIdMap(Set<String> lineItemDescriptionSet) {
        Map<String, Id> courseOfferingNameToIdMap = new Map<String, Id>();
        for (CourseOffering c : [SELECT Id, Name FROM CourseOffering WHERE Name IN :lineItemDescriptionSet]) {
            courseOfferingNameToIdMap.put(c.Name, c.Id);
        }
        return courseOfferingNameToIdMap;
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
            System.debug('Order Id is null');
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
