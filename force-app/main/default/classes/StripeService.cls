/**
 * *********************************************************
 * Apex Class Name    : StripeService
 * Created Date       : June 3, 2024
 * @description       : This class contains business logic and interacts with the Stripe API.
 * @developer         : Kankshit Adhaulia
 * Modification Log:
 * Ver   Date         Author               Modification
 * 1.0   03-06-2024   Kankshit Adhaulia    Initial Version
 * *********************************************************
 */
public with sharing class StripeService {
    private static final String CHECKOUT_ENDPOINT = 'Callout:Stripe_NC/v1/checkout/sessions';
    private static final String CONTENT_TYPE = 'application/x-www-form-urlencoded';
    private static final String CANCEL_URL = 'https://concretio5.my.site.com/s/success-page/s/payment-cancel';
    private static final String SUCCESS_URL = 'https://concretio5.my.site.com/educationPaymentPortal/s/success-page?session_id={CHECKOUT_SESSION_ID}';
    private static final String SINGAPORE_CURRENCY = 'SGD';
    private static final Integer QUANTITY = 1;

    /**
     * *********************************************************
     * @Method Name    : createCheckoutSession
     * @description    : This method creates a Stripe Checkout session by sending an HTTP
     *                   POST request to the Stripe API with the required parameters.
     * @param          : courseOrderLines - JSON string containing order lines
     * @param          : userId - The ID of the user creating the session
     * @return         : String - The URL of the created Stripe Checkout session.
     * @throws         : AuraHandledException - If the session creation fails or an error occurs.
     * *********************************************************
     */
    public static String createCheckoutSession(String courseOrderLines, String userId) {
        try {
            String contactId = getUserContactId(userId);
            String body = buildRequestBody(courseOrderLines, contactId);
            HttpResponse res = sendHttpRequest(CHECKOUT_ENDPOINT, 'POST', body, true);
            return handleCreateCheckoutSessionResponse(res);
        } catch (Exception e) {
            throw new AuraHandledException('Error occurred while creating the Stripe Checkout session.');
        }
    }

    /**
     * *********************************************************
     * @Method Name    : createCourseOfferingParticipant
     * @description    : This method creates Course Offering Participant records based on 
     *                   the provided payment intent. It queries order line items related 
     *                   to the payment intent and creates corresponding participant records.
     * @param          : paymentIntent - The payment intent ID associated with the order.
     * *********************************************************
     */
    public static void createCourseOfferingParticipant(String paymentIntent) {
        try {
            List<CourseOfferingParticipant> courseOfferingParticipantList = buildCourseOfferingParticipantList(paymentIntent);
            if (!courseOfferingParticipantList.isEmpty()) {
                insert courseOfferingParticipantList;
                            }
        } catch (Exception e) {
            throw new AuraHandledException('Error creating course offering participants.');
        }
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
    public static Map<String, Object> getSessionDetails(String sessionId) {
        try {
            HttpResponse res = sendHttpRequest(CHECKOUT_ENDPOINT + '/' + sessionId + '?expand[0]=invoice', 'GET', null, false);
            return handleGetSessionDetailsResponse(res);
        } catch (Exception e) {
            throw new AuraHandledException('Error occurred while retrieving session details.');
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
    public static String fetchInvoiceURL(String paymentIntent) {
        try {
            return [SELECT Hosted_Invoice_URL__c FROM Order__c WHERE Payment_Intent__c = :paymentIntent LIMIT 1].Hosted_Invoice_URL__c;
        } catch (Exception e) {
            throw new AuraHandledException('Error occurred while fetching invoice URL.');
        }
    }

    /**
     * *********************************************************
     * @Method Name    : handleCreateCheckoutSessionResponse
     * @description    : This helper method handles the response from the Stripe API
     *                   when creating a checkout session.
     * @param          : res - The HttpResponse from the Stripe API.
     * @return         : String - The URL of the created Stripe Checkout session.
     * @throws         : AuraHandledException - If the session creation fails.
     * *********************************************************
     */
    private static String handleCreateCheckoutSessionResponse(HttpResponse res) {
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) responseMap.get('url');
        } else {
            throw new AuraHandledException('Failed to create Stripe Checkout session.');
        }
    }

    /**
     * *********************************************************
     * @Method Name    : buildRequestBody
     * @description    : This helper method constructs the URL-encoded request body
     *                   for the Stripe Checkout session creation request.
     * @param          : courseOrderLines - JSON string containing order lines.
     * @param          : contactId - The ID of the contact associated with the user.
     * @return         : String - The URL-encoded request body.
     * *********************************************************
     */
    private static String buildRequestBody(String courseOrderLines, String contactId) {
        List<Object> parsedJson = (List<Object>) JSON.deserializeUntyped(courseOrderLines);
        Map<String, String> params = initializeParams();
        addLineItemsToParams(parsedJson, params);
        params.put('mode', 'payment');
        params.put('success_url', SUCCESS_URL);
        addPaymentMethodsToParams(params);
        return convertMapToUrlEncodedString(params);
    }

    /**
     * *********************************************************
     * @Method Name    : initializeParams
     * @description    : This helper method initializes the parameters for the request body.
     * @return         : Map<String, String> - The initialized parameters.
     * *********************************************************
     */
    private static Map<String, String> initializeParams() {
        Map<String, String> params = new Map<String, String>();
        params.put('cancel_url', CANCEL_URL);
        params.put('allow_promotion_codes', 'true');
        params.put('currency', SINGAPORE_CURRENCY);
        params.put('invoice_creation[enabled]', 'true');
        params.put('client_reference_id', UserInfo.getUserId());
        return params;
    }

    /**
     * *********************************************************
     * @Method Name    : addLineItemsToParams
     * @description    : This helper method adds line items to the request parameters.
     * @param          : parsedJson - List of course order lines.
     * @param          : params - The request parameters map.
     * *********************************************************
     */
    private static void addLineItemsToParams(List<Object> parsedJson, Map<String, String> params) {
        Integer iterationNumber = 0; 
        for (Object obj : parsedJson) {
            Map<String, Object> courseInfo = (Map<String, Object>) obj;
            String name = (String) courseInfo.get('name');
            String price = (String) courseInfo.get('price');
            params.put('line_items[' + iterationNumber + '][price_data][product_data][name]', name);
            params.put('line_items[' + iterationNumber + '][price_data][currency]', SINGAPORE_CURRENCY);
            params.put('line_items[' + iterationNumber + '][price_data][unit_amount]', String.valueOf(price));
            params.put('line_items[' + iterationNumber + '][quantity]', String.valueOf(QUANTITY));
            iterationNumber++;
        }
    }

    /**
     * *********************************************************
     * @Method Name    : addPaymentMethodsToParams
     * @description    : This helper method adds payment methods to the request parameters.
     * @param          : params - The request parameters map.
     * *********************************************************
     */
    private static void addPaymentMethodsToParams(Map<String, String> params) {
        List<String> paymentMethodTypes = new List<String>{'card', 'paynow', 'grabpay'};
        for (Integer i = 0; i < paymentMethodTypes.size(); i++) {
            params.put('payment_method_types[' + i + ']', paymentMethodTypes[i]);
        }
    }

    /**
     * *********************************************************
     * @Method Name    : buildCourseOfferingParticipantList
     * @description    : This helper method builds the list of Course Offering Participant
     *                   records based on the provided payment intent.
     * @param          : paymentIntent - The payment intent ID associated with the order.
     * @return         : List<CourseOfferingParticipant> - The list of Course Offering Participant records.
     * *********************************************************
     */
    private static List<CourseOfferingParticipant> buildCourseOfferingParticipantList(String paymentIntent) {
        List<CourseOfferingParticipant> courseOfferingParticipantList = new List<CourseOfferingParticipant>();
        for (Order_Line_Item__c lineItem : [SELECT Id, Course_Offering__c, Order__c, Order__r.Contact__c, Course_Offering__r.StartDate, Course_Offering__r.EndDate FROM Order_Line_Item__c WHERE Order__r.Payment_Intent__c = :paymentIntent]) {
            if (lineItem.Course_Offering__c == null || lineItem.Order__r.Contact__c == null) {
                continue;
            }
            CourseOfferingParticipant participant = new CourseOfferingParticipant();
            participant.CourseOfferingId = lineItem.Course_Offering__c ?? null;
            participant.ParticipantContactId = lineItem.Order__r.Contact__c ?? null;
            participant.ParticipantAffiliation = 'Student';
            participant.StartDate = (lineItem.Course_Offering__r.StartDate != null) ? lineItem.Course_Offering__r.StartDate.date() : null;
            participant.EndDate = (lineItem.Course_Offering__r.EndDate != null) ? lineItem.Course_Offering__r.EndDate.date() : null;
            
            courseOfferingParticipantList.add(participant);
        }
        return courseOfferingParticipantList;
    }

    /**
     * *********************************************************
     * @Method Name    : handleGetSessionDetailsResponse
     * @description    : This helper method handles the response from the Stripe API
     *                   when retrieving session details.
     * @param          : res - The HttpResponse from the Stripe API.
     * @return         : Map<String, Object> - The session details including customer information.
     * @throws         : AuraHandledException - If the session retrieval fails.
     * *********************************************************
     */
    private static Map<String, Object> handleGetSessionDetailsResponse(HttpResponse res) {
        if (res.getStatusCode() == 200) {
            Map<String, Object> sessionData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> customerDetails = (Map<String, Object>) sessionData.get('customer_details');
            if (customerDetails != null) {
                sessionData.put('customer_name', (String) customerDetails.get('name'));
            }
            updateCourseOrder(sessionData);
            return sessionData;
        } else {
            throw new AuraHandledException('Failed to retrieve session details.');
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
            throw new AuraHandledException('No contact found for user ID.');
        }

        try {
            Order__c matchingOrder = findMatchingOrder(contactId);
            updateMatchingOrder(matchingOrder, sessionData, invoiceDetails);
        } catch (Exception e) {
            throw new AuraHandledException('Error updating order.');
        }
    }

    /**
     * *********************************************************
     * @Method Name    : findMatchingOrder
     * @description    : This helper method finds the matching order for a given contact ID.
     * @param          : contactId - The contact ID.
     * @return         : Order__c - The matching order.
     * @throws         : AuraHandledException - If no matching order is found.
     * *********************************************************
     */
    private static Order__c findMatchingOrder(String contactId) {
        List<Order__c> orders = [SELECT Id FROM Order__c WHERE Contact__c = :contactId AND Status__c = 'Pending' LIMIT 1];
        if (orders.isEmpty()) {
            throw new AuraHandledException('No matching order found for contact ID.');
        }
        return orders[0];
    }

    /**
     * *********************************************************
     * @Method Name    : updateMatchingOrder
     * @description    : This helper method updates the matching order with the session data.
     * @param          : matchingOrder - The matching order.
     * @param          : sessionData - The session data map.
     * @param          : invoiceDetails - The invoice details map.
     * @throws         : AuraHandledException - If the order update fails.
     * *********************************************************
     */
    private static void updateMatchingOrder(Order__c matchingOrder, Map<String, Object> sessionData, Map<String, Object> invoiceDetails) {
        matchingOrder.Session_Id__c = (String) sessionData.get('id');
        if (invoiceDetails != null) {
            matchingOrder.Hosted_Invoice_URL__c = (String) invoiceDetails.get('hosted_invoice_url');
            matchingOrder.Payment_Intent__c = (String) sessionData.get('payment_intent');
            matchingOrder.Status__c = ((String) invoiceDetails.get('status') == 'paid') ? 'Success' : 'Pending';
            matchingOrder.Total_Amount__c = ((Decimal) invoiceDetails.get('amount_paid')) / 100.0;
            matchingOrder.Name = (String) invoiceDetails.get('number');
            matchingOrder.Order_Date__c = System.today();
            matchingOrder.Currency__c = ((String) invoiceDetails.get('currency')).toUpperCase();
        }
        update matchingOrder;
    }

    /**
     * *********************************************************
     * @Method Name    : getUserContactId
     * @description    : This method retrieves the Contact Id associated with a given User Id.
     * @param userId   : String - The Id of the User whose Contact Id is to be retrieved.
     * @return         : String - The Contact Id associated with the given User Id, or null if no contact is found.
     * *********************************************************
     */
    private static String getUserContactId(String userId) {
        if (userId == null) {
            return null;
        }
        try {
            User user = [SELECT ContactId FROM User WHERE Id = :userId LIMIT 1];
            return user != null ? user.ContactId : null;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * *********************************************************
     * @Method Name    : sendHttpRequest
     * @description    : This helper method sends an HTTP request and returns the response.
     * @param          : endpoint - The endpoint URL for the request.
     * @param          : method - The HTTP method.
     * @param          : body - The request body.
     * @param          : setContentType - Boolean indicating whether to set the Content-Type header.
     * @return         : HttpResponse - The HTTP response.
     * @throws         : AuraHandledException - If the request fails or an error occurs.
     * *********************************************************
     */
    private static HttpResponse sendHttpRequest(String endpoint, String method, String body, Boolean setContentType) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);
        if (setContentType) {
            req.setHeader('Content-Type', CONTENT_TYPE);
        }
        if (body != null) {
            req.setBody(body);
        }
        Http http = new Http();
        return http.send(req);
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
}
