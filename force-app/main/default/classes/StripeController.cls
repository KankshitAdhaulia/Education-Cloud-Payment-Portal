/**
 * *********************************************************
 * Apex Class Name    : StripeController
 * Created Date       : June 3, 2024
 * @description       : This class handles the creation of a Stripe Checkout session.
 *                      It sets up the necessary request parameters and sends an HTTP POST
 *                      request to Stripe's API to create a checkout session.
 * @developer         : Kankshit Adhaulia
 * Modification Log:
 * Ver   Date         Author               Modification
 * 1.0   03-06-2024   Kankshit Adhaulia    Initial Version
 * *********************************************************
 */
public with sharing class StripeController {
    /**
     * *********************************************************
     * @Method Name    : createCheckoutSession
     * @description    : This method creates a Stripe Checkout session by delegating
     *                   to the StripeService class.
     * @param          : courseOrderLines - JSON string containing order lines.
     * @return         : String - The URL of the created Stripe Checkout session.
     * @throws         : AuraHandledException - If the session creation fails or an error occurs.
     * *********************************************************
     */
    @AuraEnabled
    public static String createCheckoutSession(String courseOrderLines) {
        return StripeService.createCheckoutSession(courseOrderLines, UserInfo.getUserId());
    }

    /**
     * *********************************************************
     * @Method Name    : createCourseOfferingParticipant
     * @description    : This method creates Course Offering Participant records by
     *                   delegating to the StripeService class.
     * @param          : paymentIntent - The payment intent ID associated with the order.
     * *********************************************************
     */
    @AuraEnabled
    public static void createCourseOfferingParticipant(String paymentIntent) {
        StripeService.createCourseOfferingParticipant(paymentIntent);
    }

    /**
     * *********************************************************
     * @Method Name    : getSessionDetails
     * @description    : This method retrieves the details of a Stripe Checkout session
     *                   by delegating to the StripeService class.
     * @param          : sessionId - The ID of the checkout session.
     * @return         : Map<String, Object> - The session details including customer information.
     * @throws         : AuraHandledException - If the session retrieval fails or an error occurs.
     * *********************************************************
     */
    @AuraEnabled
    public static Map<String, Object> getSessionDetails(String sessionId) {
        return StripeService.getSessionDetails(sessionId);
    }

    /**
     * *********************************************************
     * @Method Name    : fetchInvoiceURL
     * @description    : This method fetches the invoice URL from the Invoice__c object
     *                   based on the payment intent by delegating to the StripeService class.
     * @param          : paymentIntent - The payment intent ID.
     * @return         : String - The hosted invoice URL.
     * @throws         : AuraHandledException - If the query fails or an error occurs.
     * *********************************************************
     */
    @AuraEnabled
    public static String fetchInvoiceURL(String paymentIntent) {
        return StripeService.fetchInvoiceURL(paymentIntent);
    }
}