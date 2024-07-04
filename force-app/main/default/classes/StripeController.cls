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
    // Constants for API endpoint and request headers
    private static final String CHECKOUT_ENDPOINT = 'Callout:Stripe_NC/v1/checkout/sessions';
    private static final String CUSTOMER_ENDPOINT = 'Callout:Stripe_NC/v1/customers';
    private static final String CONTENT_TYPE = 'application/x-www-form-urlencoded';
    private static final String CANCEL_URL = 'https://concretio5.my.site.com/s/success-page/s/payment-cancel';
    private static final String SUCCESS_URL = 'https://concretio5.my.site.com/educationPaymentPortal/s/success-page?session_id={CHECKOUT_SESSION_ID}';
    private static final String SINGAPORE_CURRENCY = 'SGD';
    private static final String PRODUCT_NAME = 'Computer Science II - Fall 25';
    private static final Integer UNIT_AMOUNT = 100;
    private static final Integer QUANTITY = 1;

    /**
     * *********************************************************
     * @Method Name    : createCheckoutSession
     * @description    : This method creates a Stripe Checkout session by sending an HTTP
     *                   POST request to the Stripe API with the required parameters.
     * @return         : String - The URL of the created Stripe Checkout session.
     * @throws         : AuraHandledException - If the session creation fails or an error occurs.
     * *********************************************************
     */
    @AuraEnabled
    public static String createCheckoutSession(String courseOrderLines) {
        try {
            String contactId = getContactId(UserInfo.getUserId());
            String body = buildRequestBody(courseOrderLines, contactId);
            HttpResponse res = sendHttpRequest(CHECKOUT_ENDPOINT, 'POST', body, true);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) responseMap.get('url');
            } else {
                throw new AuraHandledException('Failed to create Stripe Checkout session: ' + res.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    private static String getContactId(String UserId){
        return [Select ContactId from User where id =: UserId LIMIT 1].ContactId;
    }

    /**
     * *********************************************************
     * @Method Name    : buildRequestBody
     * @description    : This helper method constructs the URL-encoded request body
     *                   for the Stripe Checkout session creation request.
     * @return         : String - The URL-encoded request body.
     * *********************************************************
     */
    private static String buildRequestBody(String courseOrderLines, String contactId) {

        List<Object> parsedJson = (List<Object>) JSON.deserializeUntyped(courseOrderLines);
        
        // Initialize a map to hold the parameters
        Map<String, String> params = new Map<String, String>();
        params.put('cancel_url', CANCEL_URL);
        params.put('allow_promotion_codes', 'true');
        params.put('currency', SINGAPORE_CURRENCY);
        params.put('invoice_creation[enabled]', 'true');//
        params.put('client_reference_id', UserInfo.getUserId()); // unique string to reference the Checkout Session
        
        Integer iterationNumber = 0; 
        for (Object obj : parsedJson) {
            Map<String, Object> courseInfo = (Map<String, Object>) obj;

            String id = (String) courseInfo.get('id');
            String name = (String) courseInfo.get('name');
            String learningCourse = (String) courseInfo.get('learningCourse');
            String startingDate = (String) courseInfo.get('startingDate');
            String price = (String) courseInfo.get('price');
            System.debug('HEY PRICE>>'+price);

            
            params.put('line_items[' + iterationNumber +'][price_data][product_data][name]', name);
            params.put('line_items[' + iterationNumber +'][price_data][currency]', SINGAPORE_CURRENCY);
        	params.put('line_items[' + iterationNumber +'][price_data][unit_amount]', String.valueOf(price));
        	params.put('line_items[' + iterationNumber +'][quantity]', String.valueOf(QUANTITY));
            
            iterationNumber++;
        }
        
        params.put('mode', 'payment');
        params.put('success_url', SUCCESS_URL);

        // List of payment methods
        List<String> paymentMethodTypes = new List<String>{'card', 'paynow', 'grabpay'};

        // Add payment methods to the parameters map
        for (Integer i = 0; i < paymentMethodTypes.size(); i++) {
            params.put('payment_method_types[' + i + ']', paymentMethodTypes[i]);
        }

        // Convert map to URL-encoded query string
        return convertMapToUrlEncodedString(params);

        
    }

    @AuraEnabled
    public static void createCourseOfferingParticipant(String courseOrderLines) {
        List<Object> parsedJson = (List<Object>) JSON.deserializeUntyped(courseOrderLines);
        List<CourseOfferingParticipant> CourseOfferingParticipantList = new List<CourseOfferingParticipant>();
        for (Object obj : parsedJson) {
            CourseOfferingParticipant CourseOfferingParticipantRecord = new CourseOfferingParticipant();
            Map<String, Object> courseInfo = (Map<String, Object>) obj;
            //CourseOfferingParticipantRecord.CourseOfferingId = (String) courseInfo.get('id');//	0P0F9000000XZy9KAG, //	003F900001j3bUCIAY
            CourseOfferingParticipantRecord.CourseOfferingId = '0P0F9000000XZy9KAG';
            //CourseOfferingParticipantRecord.ParticipantContactId = getParticipantContactId(UserInfo.getUserId());
            CourseOfferingParticipantRecord.ParticipantContactId = '003F900001j3bUCIAY';
            CourseOfferingParticipantList.add(CourseOfferingParticipantRecord);
        }
        insert CourseOfferingParticipantList;
    }

    private static Id getParticipantContactId(Id userId) {
        return [SELECT id, ContactId FROM User WHERE id =: userId].ContactId;
    }

    /**
     * *********************************************************
     * @Method Name    : convertMapToUrlEncodedString
     * @description    : This helper method converts a map to a URL-encoded query string.
     * @param          : params - The map containing the parameters.
     * @return         : String - The URL-encoded query string.
     * *********************************************************
     */
    private static String convertMapToUrlEncodedString(Map<String, String> params) {
        List<String> paramList = new List<String>();
        for (String key : params.keySet()) {
            paramList.add(key + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8'));
        }
        return String.join(paramList, '&');
    }


    /**
     * *********************************************************
     * @Method Name    : getSessionDetails
     * @description    : This method retrieves the details of a Stripe Checkout session
     *                   and associated customer information.
     * @param          : sessionId - The ID of the checkout session.
     * @return         : Map<String, Object> - The session details including customer information.
     * @throws         : AuraHandledException - If the session retrieval fails or an error occurs.
     * *********************************************************
     */
    @AuraEnabled
    public static Map<String, Object> getSessionDetails(String sessionId) {
        try {
            HttpResponse res = sendHttpRequest(CHECKOUT_ENDPOINT + '/' + sessionId + '?expand[0]=invoice', 'GET', null, false);

            if (res.getStatusCode() == 200) {
                Map<String, Object> sessionData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, Object> customerDetails = (Map<String, Object>) sessionData.get('customer_details');
                // Add customer name to session data if available
                if (customerDetails != null) {
                    sessionData.put('customer_name', (String) customerDetails.get('name'));
                }

              updateCourseOrder(sessionData);
                
                //String customerId = (String) sessionData.get('customer');

                //HttpResponse customerRes = sendHttpRequest(CUSTOMER_ENDPOINT + '/' + customerId, 'GET', null, false);

                return sessionData;
            } else {
                throw new AuraHandledException('Failed to retrieve session details: ' + res.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    /**
     * *********************************************************
     * @Method Name    : updateCourseOrder
     * @description    : This method updates the course order with the session data.
     * @param          : sessionData - The session data map.
     * @throws         : AuraHandledException - If the order update fails or an error occurs.
     * *********************************************************
     */
    private static void updateCourseOrder(Map<String, Object> sessionData) {
        Map<String, Object> invoiceDetails = (Map<String, Object>) sessionData.get('invoice');
        String userId = (String) sessionData.get('client_reference_id');
        String contactId = getUserContactId(userId);

        if (contactId == null) {
            throw new AuraHandledException('No contact found for user ID: ' + userId);
        }

        try {
            // Query the matching order
            List<Order__c> orders = [SELECT Id FROM Order__c WHERE Contact__c =: contactId AND Status__c = 'Pending' LIMIT 1];
            if (orders.isEmpty()) {
                throw new AuraHandledException('No matching order found for contact ID: ' + contactId);
            }

            Order__c matchingOrder = orders[0];
            matchingOrder.Session_Id__c = (String) sessionData.get('id');

            if (invoiceDetails != null) {
                matchingOrder.Hosted_Invoice_URL__c = (String) invoiceDetails.get('hosted_invoice_url');
                matchingOrder.Payment_Intent__c = (String) sessionData.get('payment_intent');
                matchingOrder.Status__c = ((String) invoiceDetails.get('status') == 'paid') ? 'Success' : 'Pending';
                matchingOrder.Total_Amount__c = ((Decimal) invoiceDetails.get('amount_paid')) / 100.0;
                //matchingOrder.Order_Date__c = System.today();
                //matchingOrder.Currency__c = ((String) invoiceDetails.get('currency')).toUpperCase();
            }

            // Update the order
            update matchingOrder;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating order: ' + e.getMessage());
        }
    }

    /**
     * *********************************************************
     * @Method Name    : getUserContactId
     * @description    : This method retrieves the Contact Id associated with a given User Id.
     * @param UserId   : String - The Id of the User whose Contact Id is to be retrieved.
     * @return         : String - The Contact Id associated with the given User Id, or null if no contact is found.
     * *********************************************************
     */
    private static String getUserContactId(String UserId) {
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
     * @Method Name    : fetchInvoiceURL
     * @description    : This method fetches the invoice URL from the Invoice__c object
     *                   based on the payment intent.
     * @param          : paymentIntent - The payment intent ID.
     * @return         : String - The hosted invoice URL.
     * @throws         : AuraHandledException - If the query fails or an error occurs.
     * *********************************************************
     */
    @AuraEnabled
    public static String fetchInvoiceURL(String paymentIntent) {
        try {
            return [SELECT Hosted_Invoice_URL__c FROM Order__c WHERE Payment_Intent__c = :paymentIntent LIMIT 1].Hosted_Invoice_URL__c;
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    /**
     * *********************************************************
     * @Method Name    : sendHttpRequest
     * @description    : This helper method sends an HTTP request and returns the response.
     * @param          : endpoint - The endpoint URL for the request.
     * @param          : method - The HTTP method 
     * @param          : body - The request body 
     * @return         : HttpResponse - The HTTP response.
     * @throws         : AuraHandledException - If the request fails or an error occurs.
     * *********************************************************
     */
    private static HttpResponse sendHttpRequest(String endpoint, String method, String body, Boolean setContentType) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);
        if(setContentType){
            req.setHeader('Content-Type', CONTENT_TYPE);
        }
        if (body != null) {
            req.setBody(body);
        }

        Http http = new Http();
        return http.send(req);
    }
}